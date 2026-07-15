import 'dart:async';
import 'dart:convert';
import 'dart:math' show sin, pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/platform_file_helper.dart';
import '../database/app_database.dart';
import '../demo/demo_mode.dart';
import '../services/afip_service.dart';
import '../services/auth_service.dart';
import '../services/invoice_pdf_service.dart';
import '../services/sync_service.dart';
import '../utils/argentina_time.dart';
import '../utils/app_tokens.dart';
import '../utils/country_codes.dart';
import '../utils/factura_guards.dart';
import '../utils/money.dart';
import '../utils/pack_format.dart';
import '../utils/parse_number.dart';
import '../widgets/address_autocomplete.dart';
import '../widgets/sync_indicator.dart';
import 'facturas_screen.dart';

class ClientesScreen extends StatefulWidget {
  final int repartoId;
  final String repartoNombre;
  final VoidCallback? onClientsChanged;
  // Optional deep-link params: open on a specific day and briefly highlight
  // a cliente. Used by Ruta's "cambiar de día" flow so the sodero lands on
  // the destination day with the moved cliente in view. Both are honored
  // only on the first load — subsequent day changes behave normally.
  final int? initialSelectedDay;
  final int? focusClienteId;

  const ClientesScreen({
    super.key,
    required this.repartoId,
    required this.repartoNombre,
    this.onClientsChanged,
    this.initialSelectedDay,
    this.focusClienteId,
  });

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AppTokens get tokens => AppTokens.of(context);

  // Deterministic color pool for etiquetas
  static const List<Color> _tagColors = [
    Color(0xFF1292D3), // blue
    Color(0xFF2ECC71), // green
    Color(0xFFE67E22), // orange
    Color(0xFF9B59B6), // purple
    Color(0xFFE74C3C), // red
    Color(0xFF1ABC9C), // teal
    Color(0xFFF1C40F), // yellow
    Color(0xFFE91E63), // pink
    Color(0xFF00BCD4), // cyan
    Color(0xFF8BC34A), // lime
    Color(0xFFFF5722), // deep orange
    Color(0xFF3F51B5), // indigo
  ];

  Map<String, Color> _customEtiquetaColors = {};

  /// Returns a consistent color for a given etiqueta string
  Color _colorForEtiqueta(String etiqueta) {
    final key = etiqueta.toLowerCase().trim();
    if (_customEtiquetaColors.containsKey(key))
      return _customEtiquetaColors[key]!;
    final hash = key.hashCode;
    return _tagColors[hash.abs() % _tagColors.length];
  }

  Widget _countryFlag(String flag, {double width = 30, double height = 22}) {
    return _countryFlagFallback(flag, width: width, height: height);
  }

  Widget _countryFlagFallback(
    String flag, {
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.primaryBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.primaryBlue.withValues(alpha: 0.35)),
      ),
      child: Text(
        countryFlagLabel(flag),
        style: TextStyle(
          color: tokens.primaryBlue,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static const List<String> _allDayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  int _selectedDay = 0;
  List<int> _workDays = [0, 1, 2, 3, 4, 5];
  List<Cliente> _clientes = [];
  List<Cliente> _filteredClientes = [];
  List<String> _allEtiquetas = []; // unique etiqueta names across reparto

  bool _editMode = false;
  late final AnimationController _shakeController;
  final _searchController = TextEditingController();

  final _db = AppDatabase.instance;

  // Guard to skip the _dbDataListener reload while this screen is mid-write
  // (same pattern as ruta_screen). Without it, the per-row reorder persist
  // raced its own reloads and corrupted the saved orden.
  int _localWriteCount = 0;
  // Reorder persist coalescing — see _persistClientOrder.
  Map<int, int>? _pendingOrdenWrite;
  bool _persistOrderRunning = false;

  // Scroll/focus support for the deep-link from Ruta's "cambiar de día".
  // _listScrollController drives the per-day cliente list. _cardKeys are
  // hooked into each rendered card so Scrollable.ensureVisible can fine-tune
  // the scroll once Flutter has laid out the target item. _highlightedClienteId
  // briefly paints a glow on the focused card; _focusApplied gates the whole
  // routine so it runs once per screen lifetime.
  final ScrollController _listScrollController = ScrollController();
  final Map<int, GlobalKey> _cardKeys = {};
  int? _highlightedClienteId;
  bool _focusApplied = false;
  Timer? _highlightTimer;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shakeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    _searchController.addListener(_filterClientes);
    _db.addDataListener(_dbDataListener);
    _loadWorkDaysAndData();
    _scheduleMidnightReload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _db.removeDataListener(_dbDataListener);
    _shakeController.dispose();
    _searchController.dispose();
    _listScrollController.dispose();
    _highlightTimer?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _dbDataListener() {
    // _localWriteCount > 0 means this screen is persisting its own writes
    // (e.g. a reorder) — reloading now would read half-applied state and
    // swap _clientes out from under the writer.
    if (!mounted || _localWriteCount > 0) return;
    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  void _scheduleMidnightReload() {
    _midnightTimer?.cancel();
    final now = argentinaTime();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: 1, seconds: 1));
    _midnightTimer = Timer(next.difference(now), () async {
      if (!mounted) return;
      await _loadData();
      _scheduleMidnightReload();
    });
  }

  void _filterClientes() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredClientes = List.of(_clientes);
      } else {
        _filteredClientes = _clientes.where((c) {
          return c.nombre.toLowerCase().contains(query) ||
              c.direccion.toLowerCase().contains(query) ||
              c.telefono.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadWorkDaysAndData() async {
    final days = await _db.getWorkDays();
    final weekday = argentinaTime().weekday;
    final todayIndex = weekday >= 1 && weekday <= 7 ? weekday - 1 : 0;
    // Deep-link day wins when the caller asked for a specific one and it's
    // an actual work day. Otherwise fall back to today (or first work day).
    final initial = widget.initialSelectedDay;
    final initialIsValid = initial != null && days.contains(initial);
    if (mounted) {
      setState(() {
        _workDays = days;
        _selectedDay = initialIsValid
            ? initial
            : days.contains(todayIndex)
            ? todayIndex
            : (days.isNotEmpty ? days.first : 0);
      });
    }
    await _loadData();
    _maybeApplyInitialFocus();
  }

  /// Run-once post-load: scroll to and briefly highlight the cliente named
  /// in `widget.focusClienteId`. Delegates to `_scrollToAndHighlight` so the
  /// in-screen cambiar-día redirect can reuse the same animation.
  void _maybeApplyInitialFocus() {
    if (_focusApplied) return;
    final targetId = widget.focusClienteId;
    if (targetId == null) return;
    _focusApplied = true;
    _scrollToAndHighlight(targetId);
  }

  /// Two-step scroll (jump to estimated offset, then ensureVisible on the
  /// now-built widget) handles the lazy ListView. Used by both the deep-link
  /// from Ruta and the in-screen cambiar-día redirect, so a sodero gets the
  /// same "land on the new day, see the cliente glow" feedback regardless of
  /// where they triggered the move from.
  void _scrollToAndHighlight(int clienteId) {
    final index = _filteredClientes.indexWhere((c) => c.id == clienteId);
    if (index < 0) {
      // Cliente isn't in the current filtered list (e.g. search filter is
      // active and excludes them). Leave scroll alone and skip the glow.
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listScrollController.hasClients) return;
      // Rough estimate of card height; refined by ensureVisible below.
      const estimatedCardHeight = 100.0;
      final maxOffset = _listScrollController.position.maxScrollExtent;
      final target = (index * estimatedCardHeight)
          .clamp(0.0, maxOffset)
          .toDouble();
      _listScrollController.jumpTo(target);
      _ensureVisibleAndHighlight(clienteId, retriesRemaining: 2);
    });
  }

  void _ensureVisibleAndHighlight(
    int clienteId, {
    required int retriesRemaining,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _cardKeys[clienteId]?.currentContext;
      if (ctx == null && retriesRemaining > 0) {
        _ensureVisibleAndHighlight(
          clienteId,
          retriesRemaining: retriesRemaining - 1,
        );
        return;
      }
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: Duration(milliseconds: 300),
          alignment: 0.2,
          curve: Curves.easeOut,
        );
      }
      setState(() => _highlightedClienteId = clienteId);
      _highlightTimer?.cancel();
      _highlightTimer = Timer(Duration(milliseconds: 2500), () {
        if (!mounted) return;
        setState(() => _highlightedClienteId = null);
      });
    });
  }

  Future<void> _loadData() async {
    final clients = await _db.getClientesForRepartoDay(
      widget.repartoId,
      _selectedDay,
    );
    // Collect all unique etiquetas across all clients in this reparto
    final allClients = await _db.getClientesForReparto(widget.repartoId);
    final etiquetaSet = <String>{};
    for (final c in allClients) {
      for (final e in _parseEtiquetas(c.etiqueta)) {
        etiquetaSet.add(e);
      }
    }
    final sortedEtiquetas = etiquetaSet.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    // Load custom etiqueta colors
    final customColors = <String, Color>{};
    try {
      final colorEntries = await _db.getEtiquetaColors(widget.repartoId);
      for (final e in colorEntries) {
        customColors[e.nombre.toLowerCase().trim()] = Color(
          int.parse(e.colorHex, radix: 16),
        );
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _clientes = clients;
        _allEtiquetas = sortedEtiquetas;
        _customEtiquetaColors = customColors;
        final activeIds = clients.map((c) => c.id).toSet();
        _cardKeys.removeWhere((id, _) => !activeIds.contains(id));
      });
      _filterClientes();
    }
  }

  void _onReorderClients(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    _moveClientToPosition(oldIndex, newIndex);
  }

  void _moveFilteredClientInFullList(Cliente item, int filteredIndex) {
    final existingIndex = _clientes.indexWhere((c) => c.id == item.id);
    if (existingIndex >= 0) {
      _clientes.removeAt(existingIndex);
    }

    final previousVisible = filteredIndex > 0
        ? _filteredClientes[filteredIndex - 1]
        : null;
    final nextVisible = filteredIndex < _filteredClientes.length - 1
        ? _filteredClientes[filteredIndex + 1]
        : null;

    if (nextVisible != null) {
      final insertIndex = _clientes.indexWhere((c) => c.id == nextVisible.id);
      if (insertIndex >= 0) {
        _clientes.insert(insertIndex, item);
        return;
      }
    }
    if (previousVisible != null) {
      final previousIndex = _clientes.indexWhere(
        (c) => c.id == previousVisible.id,
      );
      if (previousIndex >= 0) {
        _clientes.insert(previousIndex + 1, item);
        return;
      }
    }
    _clientes.insert(0, item);
  }

  /// Move a cliente from oldIndex (0-based) to newIndex0 (0-based final
  /// position) in the current filtered list. Used by the tap-the-number
  /// shortcut so the sodero doesn't have to drag through hundreds of rows.
  /// Same persistence path as drag-drop (_persistClientOrder rewrites orden
  /// for every cliente).
  void _moveClientToPosition(int oldIndex, int newIndex0) {
    if (oldIndex < 0 || oldIndex >= _filteredClientes.length) return;
    if (newIndex0 < 0 || newIndex0 >= _filteredClientes.length) return;
    if (oldIndex == newIndex0) return;
    final item = _filteredClientes.removeAt(oldIndex);
    _filteredClientes.insert(newIndex0, item);
    _moveFilteredClientInFullList(item, newIndex0);
    setState(() {});
    _persistClientOrder();
  }

  /// Edit-mode shortcut: tap a cliente's number circle and type the desired
  /// position instead of long-pressing and dragging. Empty / non-numeric
  /// inputs cancel silently. Numbers below 1 or above the day's cliente
  /// count are clamped so the sodero just gets the first or last slot
  /// instead of an error.
  Future<void> _showChangePositionDialog(
    Cliente cliente,
    int currentIndex,
  ) async {
    final total = _filteredClientes.length;
    if (total <= 1) return; // nothing meaningful to reorder
    final controller = TextEditingController();
    try {
      final entered = await showDialog<int?>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: tokens.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Mover cliente',
            style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
          ),
          // Scrollable so the keyboard popping over the autofocused field
          // can't cause a RenderFlex overflow on small viewports.
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${cliente.nombre}\nPosición actual: ${currentIndex + 1} de $total',
                  style: TextStyle(color: tokens.textSub, fontSize: 13),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(color: tokens.text, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Nueva posición (1 - $total)',
                    hintStyle: TextStyle(color: tokens.textMuted),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: tokens.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: tokens.primaryBlue),
                    ),
                  ),
                  onSubmitted: (val) {
                    final n = int.tryParse(val.trim());
                    Navigator.pop(ctx, n);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: tokens.textSub)),
            ),
            TextButton(
              onPressed: () {
                final n = int.tryParse(controller.text.trim());
                Navigator.pop(ctx, n);
              },
              child: Text('Mover', style: TextStyle(color: tokens.primaryBlue)),
            ),
          ],
        ),
      );
      if (entered == null) return; // empty input / non-numeric / cancel
      final targetZeroBased = (entered - 1).clamp(0, total - 1);
      _moveClientToPosition(currentIndex, targetZeroBased);
      // Same UX as the cambiar-día redirect: scroll to the moved cliente's
      // new slot and glow it briefly so the sodero can see what just moved.
      _scrollToAndHighlight(cliente.id);
    } finally {
      // Defer dispose past the dialog's dismiss animation. While the
      // dialog is animating out, a parent setState (from _moveClientToPosition
      // and _persistClientOrder's onDataChanged fan-out) can rebuild the
      // still-mounted TextField against the controller. Disposing
      // synchronously here means that rebuild hits a freed controller and
      // crashes with "TextEditingController used after dispose".
      Future.delayed(Duration(milliseconds: 400), controller.dispose);
    }
  }

  /// Persist the current arrangement as each cliente's `orden`. Mirrors
  /// ruta_screen._persistClientOrder: synchronous mapping snapshot, one
  /// coalescing runner, one atomic DB transaction per drained mapping, and
  /// `_localWriteCount` suppressing reloads mid-persist. The old per-row
  /// loop raced its own onDataChanged reloads and persisted half-applied
  /// permutations ("clients randomly change order on load").
  Future<void> _persistClientOrder() async {
    if (blockDemoAction(context)) {
      await _loadData();
      return;
    }
    final day = _selectedDay;
    // Clientes borrowed into this day via a temp-day override keep their
    // HOME day's orden — they pin last on the borrowed day regardless.
    _pendingOrdenWrite = {
      for (var i = 0; i < _clientes.length; i++)
        if (_clientes[i].diaSemana == day) _clientes[i].id: i,
    };
    if (_persistOrderRunning) return; // active runner picks up the mapping
    _persistOrderRunning = true;
    _localWriteCount++;
    var anyChanged = false;
    try {
      while (_pendingOrdenWrite != null) {
        final mapping = _pendingOrdenWrite!;
        _pendingOrdenWrite = null;
        anyChanged = await _db.updateClienteOrdenBatch(mapping) || anyChanged;
      }
    } finally {
      _persistOrderRunning = false;
      _localWriteCount--;
    }
    // One reconciling reload: refreshes stale in-memory `.orden` fields and
    // applies any sync pull suppressed during the persist.
    if (anyChanged && mounted && _localWriteCount == 0) {
      _loadData();
    }
  }

  void _showEtiquetaColorPicker(
    String tagName,
    void Function(void Function()) setSheetState,
  ) {
    final currentColor = _colorForEtiqueta(tagName);
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Color de "$tagName"',
                style: TextStyle(
                  color: tokens.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _tagColors.map((color) {
                  final isSelected = currentColor == color;
                  return GestureDetector(
                    onTap: () async {
                      final hex =
                          (color.a * 255)
                              .round()
                              .toRadixString(16)
                              .padLeft(2, '0') +
                          (color.r * 255)
                              .round()
                              .toRadixString(16)
                              .padLeft(2, '0') +
                          (color.g * 255)
                              .round()
                              .toRadixString(16)
                              .padLeft(2, '0') +
                          (color.b * 255)
                              .round()
                              .toRadixString(16)
                              .padLeft(2, '0');
                      await _db.setEtiquetaColor(
                        widget.repartoId,
                        tagName.toLowerCase().trim(),
                        hex,
                      );
                      await _loadData();
                      setSheetState(() {});
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: tokens.text, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? Icon(Icons.check, color: tokens.text, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // --- Etiquetas helpers ---

  /// Parse stored etiqueta string (comma-separated) into list
  List<String> _parseEtiquetas(String etiqueta) {
    if (etiqueta.isEmpty) return [];
    return etiqueta
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Join list of etiquetas into comma-separated string for storage (deduplicates case-insensitively)
  String _joinEtiquetas(List<TextEditingController> controllers) {
    final seen = <String>{};
    final result = <String>[];
    for (final c in controllers) {
      final text = c.text.trim();
      if (text.isNotEmpty && seen.add(text.toLowerCase())) {
        result.add(text);
      }
    }
    return result.join(', ');
  }

  String _formatMoney(double amount) {
    final raw = amount.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final remaining = raw.length - i;
      buffer.write(raw[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
    }
    final formatted = buffer.toString();
    if (amount < 0) return '- \$$formatted';
    return '\$$formatted';
  }

  BoxDecoration _whiteCardDeco({double radius = 16}) => BoxDecoration(
    color: tokens.card,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 1)),
    ],
  );

  Widget _sheetSectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: tokens.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _sheetFieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: tokens.textMuted,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _sheetTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      textCapitalization: textCapitalization,
      readOnly: readOnly,
      style: TextStyle(color: tokens.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: tokens.textMuted),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  String _capitalized(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Sin frecuencia';
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  String _frecLetter(String frecuencia) {
    switch (frecuencia.trim().toLowerCase()) {
      case 'semanal':
        return 'S';
      case 'quincenal':
        return 'Q';
      case 'mensual':
        return 'M';
      default:
        return '?';
    }
  }

  Future<void> _openClienteWhatsapp(Cliente cliente) async {
    if (!mounted) return;
    showDemoUpgradeSnack(
      context,
      message: 'WhatsApp no esta disponible en la demo.',
    );
  }

  Widget _buildClienteSheetHeader(BuildContext sheetContext, Cliente cliente) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border(bottom: BorderSide(color: tokens.cardBorder, width: 1)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(sheetContext),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: tokens.text,
            ),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Text(
              'Cliente',
              style: TextStyle(
                color: tokens.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClienteHeroCard(
    Cliente cliente, {
    required int activeTab,
    required ValueChanged<int> setActiveTab,
  }) {
    final address = cliente.direccion.trim().isNotEmpty
        ? cliente.direccion.trim()
        : 'Sin dirección';
    final dayName =
        cliente.diaSemana >= 0 && cliente.diaSemana < _allDayNames.length
        ? _allDayNames[cliente.diaSemana]
        : 'Sin día';
    final cc = cliente.cuentaCorriente;
    final ccColor = isMoneyNegative(cc)
        ? tokens.danger
        : isMoneyPositive(cc)
        ? tokens.success
        : tokens.text;
    final ccSubtitle = isMoneyNegative(cc)
        ? 'En deuda'
        : isMoneyPositive(cc)
        ? 'A favor'
        : 'Al día';

    return Container(
      padding: EdgeInsets.fromLTRB(18, 18, 18, 0),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.primaryBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      cliente.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (cliente.notas.trim().isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        cliente.notas.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: tokens.textMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _heroIconButton(
                    icon: Icons.location_on_outlined,
                    iconColor: tokens.primaryBlue,
                    onTap: () {},
                  ),
                  SizedBox(height: 8),
                  _heroIconButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: Color(0xFF22C55E),
                    onTap: () => _openClienteWhatsapp(cliente),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          // IntrinsicHeight + CrossAxisAlignment.stretch keeps both stat
          // cards the same height regardless of which value string is
          // taller. FRECUENCIA's value font is bumped to match CTA.
          // CORRIENTE's so the visual weight is equal.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _heroStatCard(
                    label: 'CTA. CORRIENTE',
                    value: _formatMoney(cc),
                    valueStyle: TextStyle(
                      color: ccColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    subtitle: ccSubtitle,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _heroStatCard(
                    label: 'FRECUENCIA',
                    value: _capitalized(cliente.frecuencia),
                    valueStyle: TextStyle(
                      color: tokens.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    subtitle: dayName,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          _buildClientesTabs(activeTab, setActiveTab, const [
            'Información',
            'Historial',
          ]),
        ],
      ),
    );
  }

  Widget _buildClientesTabs(
    int activeTab,
    ValueChanged<int> setActiveTab,
    List<String> labels,
  ) {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setActiveTab(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activeTab == i ? tokens.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: activeTab == i
                        ? [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: activeTab == i ? tokens.text : tokens.textMuted,
                      fontSize: 13,
                      fontWeight: activeTab == i
                          ? FontWeight.w800
                          : FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _heroIconButton({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: tokens.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
      ),
    );
  }

  Widget _heroStatCard({
    required String label,
    required String value,
    required TextStyle valueStyle,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: valueStyle,
          ),
          SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _sheetCardHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: tokens.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: tokens.textMuted, fontSize: 12)),
      ],
    );
  }

  Widget _sheetFieldBlock(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetFieldLabel(label),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tokens.surface2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildClienteEditSheetContent({
    required BuildContext sheetContext,
    required ScrollController scrollController,
    required Cliente cliente,
    required TextEditingController nombreCtrl,
    required TextEditingController direccionCtrl,
    required TextEditingController telefonoCtrl,
    required List<TextEditingController> etiquetaCtrls,
    required TextEditingController notaCtrl,
    required TextEditingController docNroCtrl,
    required int docTipo,
    required void Function(int) onDocTipoChanged,
    required String selectedCode,
    required String selectedFlag,
    required String frecuencia,
    required int activeTab,
    required ValueChanged<int> setActiveTab,
    required void Function(void Function()) setSheetState,
    required void Function(String code, String flag) onCodeChanged,
    required void Function(String freq) onFreqChanged,
    required VoidCallback onAddEtiqueta,
    required void Function(int index) onRemoveEtiqueta,
    required bool showOnMap,
    required void Function(bool) onShowOnMapChanged,
    required Widget historialSection,
    required AddressSelectedCallback onAddressPicked,
    required List<Widget> extraActions,
    required bool readOnly,
  }) {
    // dayName lookup moved into _buildClienteHeroCard — no longer needed
    // here after the DÍA field was removed from _buildClasificacionCard.
    return Column(
      children: [
        Center(
          child: Padding(
            padding: EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        _buildClienteSheetHeader(sheetContext, cliente),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              18 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildClienteHeroCard(
                  cliente,
                  activeTab: activeTab,
                  setActiveTab: setActiveTab,
                ),
                SizedBox(height: 16),
                if (activeTab == 0) ...[
                  _sheetSectionLabel('DATOS PRINCIPALES'),
                  SizedBox(height: 8),
                  _buildDatosPrincipalesCard(
                    nombreCtrl: nombreCtrl,
                    direccionCtrl: direccionCtrl,
                    telefonoCtrl: telefonoCtrl,
                    selectedCode: selectedCode,
                    selectedFlag: selectedFlag,
                    onCodeChanged: onCodeChanged,
                    onAddressPicked: onAddressPicked,
                    readOnly: readOnly,
                  ),
                  SizedBox(height: 18),
                  _sheetSectionLabel('CLASIFICACIÓN'),
                  SizedBox(height: 8),
                  _buildClasificacionCard(
                    etiquetaCtrls: etiquetaCtrls,
                    frecuencia: frecuencia,
                    setSheetState: setSheetState,
                    onFreqChanged: onFreqChanged,
                    onAddEtiqueta: onAddEtiqueta,
                    onRemoveEtiqueta: onRemoveEtiqueta,
                    readOnly: readOnly,
                  ),
                  SizedBox(height: 18),
                  _sheetSectionLabel('FACTURACIÓN'),
                  SizedBox(height: 8),
                  _buildFacturacionCard(
                    notaCtrl: notaCtrl,
                    docNroCtrl: docNroCtrl,
                    docTipo: docTipo,
                    showOnMap: showOnMap,
                    onDocTipoChanged: onDocTipoChanged,
                    onShowOnMapChanged: onShowOnMapChanged,
                    readOnly: readOnly,
                  ),
                  if (extraActions.isNotEmpty) ...[
                    SizedBox(height: 20),
                    _sheetSectionLabel('ACCIONES'),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: _whiteCardDeco(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: extraActions,
                      ),
                    ),
                  ],
                ] else ...[
                  _sheetSectionLabel('HISTORIAL'),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: _whiteCardDeco(),
                    child: historialSection,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatosPrincipalesCard({
    required TextEditingController nombreCtrl,
    required TextEditingController direccionCtrl,
    required TextEditingController telefonoCtrl,
    required String selectedCode,
    required String selectedFlag,
    required void Function(String code, String flag) onCodeChanged,
    required AddressSelectedCallback onAddressPicked,
    required bool readOnly,
  }) {
    return Container(
      decoration: _whiteCardDeco(),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetCardHeader(
            'Contacto',
            'Datos para identificar y llegar al cliente',
          ),
          SizedBox(height: 14),
          _sheetFieldBlock(
            'NOMBRE',
            _sheetTextField(
              nombreCtrl,
              'Nombre del cliente',
              textCapitalization: TextCapitalization.words,
              readOnly: readOnly,
            ),
          ),
          SizedBox(height: 14),
          _sheetFieldBlock(
            'DIRECCIÓN',
            AddressAutocomplete(
              controller: direccionCtrl,
              optionsMaxWidth: MediaQuery.sizeOf(context).width - 40,
              onAddressSelected: readOnly ? (_, _, _) {} : onAddressPicked,
              fieldBuilder: (ctx, controller, focusNode, onSubmit) => TextField(
                controller: controller,
                focusNode: focusNode,
                readOnly: readOnly,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: tokens.text, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Dirección de entrega',
                  hintStyle: TextStyle(color: tokens.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: readOnly ? null : (_) => onSubmit(),
              ),
            ),
          ),
          SizedBox(height: 14),
          _sheetFieldBlock(
            'TELÉFONO',
            Row(
              children: [
                InkWell(
                  onTap: () {
                    if (readOnly && blockDemoAction(context)) return;
                    _openCountryPicker(context, selectedCode, selectedFlag, (
                      code,
                      flag,
                    ) {
                      onCodeChanged(code, flag);
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _countryFlag(selectedFlag),
                        SizedBox(width: 6),
                        Text(
                          selectedCode,
                          style: TextStyle(color: tokens.text, fontSize: 15),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: tokens.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _sheetTextField(
                    telefonoCtrl,
                    'Número de teléfono',
                    keyboard: TextInputType.phone,
                    readOnly: readOnly,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClasificacionCard({
    required List<TextEditingController> etiquetaCtrls,
    required String frecuencia,
    required void Function(void Function()) setSheetState,
    required void Function(String freq) onFreqChanged,
    required VoidCallback onAddEtiqueta,
    required void Function(int index) onRemoveEtiqueta,
    required bool readOnly,
  }) {
    return Container(
      decoration: _whiteCardDeco(),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetCardHeader(
            'Cómo lo atendemos',
            'Frecuencia, día y etiquetas para organizar la ruta',
          ),
          SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetFieldLabel('FRECUENCIA'),
                SizedBox(height: 8),
                Row(
                  children: [
                    _buildFreqOption(
                      'Semanal',
                      'semanal',
                      frecuencia,
                      onFreqChanged,
                      enabled: !readOnly,
                    ),
                    SizedBox(width: 8),
                    _buildFreqOption(
                      'Quincenal',
                      'quincenal',
                      frecuencia,
                      onFreqChanged,
                      enabled: !readOnly,
                    ),
                    SizedBox(width: 8),
                    _buildFreqOption(
                      'Mensual',
                      'mensual',
                      frecuencia,
                      onFreqChanged,
                      enabled: !readOnly,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          _sheetFieldLabel('ETIQUETAS'),
          SizedBox(height: 8),
          Column(
            children: [
              ...List.generate(etiquetaCtrls.length, (i) {
                final isLast = i == etiquetaCtrls.length - 1;
                final tagText = etiquetaCtrls[i].text.trim();
                final tagColor = tagText.isNotEmpty
                    ? _colorForEtiqueta(tagText)
                    : tokens.cardBorder;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: !readOnly && tagText.isNotEmpty
                            ? () => _showEtiquetaColorPicker(
                                tagText,
                                setSheetState,
                              )
                            : null,
                        child: Container(
                          width: 30,
                          height: 30,
                          margin: EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: tagColor.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                            border: Border.all(color: tagColor, width: 2),
                          ),
                          child: Icon(Icons.palette, color: tagColor, size: 14),
                        ),
                      ),
                      Expanded(
                        child: _buildEtiquetaField(
                          controller: etiquetaCtrls[i],
                          hint: i == 0
                              ? 'Ej: Dispenser Frío/Calor'
                              : 'Otra etiqueta...',
                          existingEtiquetas: _allEtiquetas,
                          currentEtiquetas: etiquetaCtrls,
                          setSheetState: setSheetState,
                          requestFocus:
                              !readOnly &&
                              isLast &&
                              etiquetaCtrls[i].text.isEmpty &&
                              etiquetaCtrls.length > 1,
                          embedded: true,
                          readOnly: readOnly,
                        ),
                      ),
                      if (!readOnly && etiquetaCtrls.length > 1) ...[
                        SizedBox(width: 8),
                        InkWell(
                          onTap: () => onRemoveEtiqueta(i),
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(
                              Icons.close,
                              color: tokens.danger,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                      if (!readOnly && isLast) ...[
                        SizedBox(width: 8),
                        InkWell(
                          onTap: onAddEtiqueta,
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(
                              Icons.add,
                              color: tokens.primaryBlue,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFacturacionCard({
    required TextEditingController notaCtrl,
    required TextEditingController docNroCtrl,
    required int docTipo,
    required bool showOnMap,
    required void Function(int) onDocTipoChanged,
    required void Function(bool) onShowOnMapChanged,
    required bool readOnly,
  }) {
    return Container(
      decoration: _whiteCardDeco(),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetCardHeader(
            'Facturación y notas',
            'Documentación, notas internas y visibilidad en el mapa',
          ),
          SizedBox(height: 14),
          _sheetFieldBlock(
            'DOCUMENTO',
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButton<int>(
                    value: docTipo,
                    dropdownColor: tokens.card,
                    style: TextStyle(color: tokens.text, fontSize: 15),
                    underline: SizedBox(),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 99,
                        child: Text('Consumidor Final'),
                      ),
                      DropdownMenuItem(value: 96, child: Text('DNI')),
                      DropdownMenuItem(value: 80, child: Text('CUIT')),
                    ],
                    onChanged: readOnly
                        ? null
                        : (v) {
                            if (v != null) onDocTipoChanged(v);
                          },
                  ),
                ),
                if (docTipo != 99) ...[
                  SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: _sheetTextField(
                      docNroCtrl,
                      docTipo == 96 ? 'Nro DNI' : 'Nro CUIT',
                      keyboard: TextInputType.number,
                      readOnly: readOnly,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 14),
          _sheetFieldBlock(
            'NOTAS',
            _sheetTextField(
              notaCtrl,
              'Dejar en garage, tocar timbre...',
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              readOnly: readOnly,
            ),
          ),
          SizedBox(height: 14),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: showOnMap ? tokens.primaryBlue : tokens.cardBorder,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sheetFieldLabel('MAPA'),
                      SizedBox(height: 4),
                      Text(
                        'Mostrar en mapa',
                        style: TextStyle(color: tokens.text, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: showOnMap,
                  onChanged: readOnly ? null : onShowOnMapChanged,
                  activeThumbColor: tokens.primaryBlue,
                  inactiveThumbColor: tokens.cardBorder,
                  inactiveTrackColor: tokens.cardBorder,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Shared form content builder ---

  Widget _buildFormContent({
    required ScrollController scrollController,
    required String title,
    required TextEditingController nombreCtrl,
    required TextEditingController direccionCtrl,
    required TextEditingController telefonoCtrl,
    required List<TextEditingController> etiquetaCtrls,
    required TextEditingController notaCtrl,
    required TextEditingController docNroCtrl,
    required int docTipo,
    required void Function(int) onDocTipoChanged,
    required String selectedCode,
    required String selectedFlag,
    required String frecuencia,
    required void Function(void Function()) setSheetState,
    required void Function(String code, String flag) onCodeChanged,
    required void Function(String freq) onFreqChanged,
    required VoidCallback onAddEtiqueta,
    required void Function(int index) onRemoveEtiqueta,
    required String submitLabel,
    required VoidCallback onSubmit,
    List<Widget> extraActions = const [],
    Widget? historialSection,
    bool? showOnMap,
    void Function(bool)? onShowOnMapChanged,
    bool isEditMode = false,
    AddressSelectedCallback? onAddressPicked,
  }) {
    return SingleChildScrollView(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 250),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: tokens.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          // Dirección
          _buildLabel('DIRECCIÓN'),
          SizedBox(height: 6),
          AddressAutocomplete(
            controller: direccionCtrl,
            optionsMaxWidth: MediaQuery.sizeOf(context).width - 40,
            onAddressSelected: (formatted, lat, lng) {
              if (onAddressPicked != null) {
                onAddressPicked(formatted, lat, lng);
              }
            },
            fieldBuilder: (ctx, controller, focusNode, onSubmit) => TextField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: tokens.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Dirección de entrega',
                hintStyle: TextStyle(color: tokens.textMuted),
                filled: true,
                fillColor: tokens.bg,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: tokens.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: tokens.primaryBlue),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          SizedBox(height: 16),
          // Nombre
          _buildLabel('NOMBRE'),
          SizedBox(height: 6),
          _buildField(
            nombreCtrl,
            'Nombre del cliente',
            textCapitalization: TextCapitalization.words,
          ),
          SizedBox(height: 16),
          // Teléfono
          _buildLabel('TELÉFONO'),
          SizedBox(height: 6),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  _openCountryPicker(context, selectedCode, selectedFlag, (
                    code,
                    flag,
                  ) {
                    onCodeChanged(code, flag);
                  });
                },
                child: Container(
                  height: 48,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: tokens.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _countryFlag(selectedFlag),
                      SizedBox(width: 6),
                      Text(
                        selectedCode,
                        style: TextStyle(color: tokens.text, fontSize: 14),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        color: tokens.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _buildField(
                  telefonoCtrl,
                  'Número de teléfono',
                  keyboard: TextInputType.phone,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Frecuencia
          _buildLabel('FRECUENCIA'),
          SizedBox(height: 6),
          Row(
            children: [
              _buildFreqOption('Semanal', 'semanal', frecuencia, (v) {
                onFreqChanged(v);
              }),
              SizedBox(width: 8),
              _buildFreqOption('Quincenal', 'quincenal', frecuencia, (v) {
                onFreqChanged(v);
              }),
              SizedBox(width: 8),
              _buildFreqOption('Mensual', 'mensual', frecuencia, (v) {
                onFreqChanged(v);
              }),
            ],
          ),
          SizedBox(height: 16),
          // Etiquetas (multiple)
          _buildLabel('ETIQUETAS'),
          SizedBox(height: 6),
          ...List.generate(etiquetaCtrls.length, (i) {
            final isLast = i == etiquetaCtrls.length - 1;
            final tagText = etiquetaCtrls[i].text.trim();
            final tagColor = tagText.isNotEmpty
                ? _colorForEtiqueta(tagText)
                : tokens.cardBorder;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: tagText.isNotEmpty
                        ? () => _showEtiquetaColorPicker(tagText, setSheetState)
                        : null,
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: tagColor, width: 2),
                      ),
                      child: Icon(Icons.palette, color: tagColor, size: 14),
                    ),
                  ),
                  Expanded(
                    child: _buildEtiquetaField(
                      controller: etiquetaCtrls[i],
                      hint: i == 0
                          ? 'Ej: Dispenser Frío/Calor'
                          : 'Otra etiqueta...',
                      existingEtiquetas: _allEtiquetas,
                      currentEtiquetas: etiquetaCtrls,
                      setSheetState: setSheetState,
                      requestFocus:
                          isLast &&
                          etiquetaCtrls[i].text.isEmpty &&
                          etiquetaCtrls.length > 1,
                    ),
                  ),
                  if (etiquetaCtrls.length > 1) ...[
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => onRemoveEtiqueta(i),
                      child: Container(
                        width: 36,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(Icons.close, color: Colors.red, size: 18),
                      ),
                    ),
                  ],
                  if (isLast) ...[
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: onAddEtiqueta,
                      child: Container(
                        width: 36,
                        height: 44,
                        decoration: BoxDecoration(
                          color: tokens.primaryBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: tokens.primaryBlue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.add,
                          color: tokens.primaryBlue,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          SizedBox(height: 16),
          // Nota
          _buildLabel('NOTA DE ENTREGA'),
          SizedBox(height: 6),
          _buildField(
            notaCtrl,
            'Dejar en garage, tocar timbre...',
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          SizedBox(height: 16),
          // Factura: Tipo de Documento
          _buildLabel('FACTURACIÓN'),
          SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  height: 48,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: tokens.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.cardBorder),
                  ),
                  child: DropdownButton<int>(
                    value: docTipo,
                    dropdownColor: tokens.card,
                    style: TextStyle(color: tokens.text, fontSize: 14),
                    underline: SizedBox(),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 99,
                        child: Text('Consumidor Final'),
                      ),
                      DropdownMenuItem(value: 96, child: Text('DNI')),
                      DropdownMenuItem(value: 80, child: Text('CUIT')),
                    ],
                    onChanged: (v) {
                      if (v != null) onDocTipoChanged(v);
                    },
                  ),
                ),
              ),
              if (docTipo != 99) ...[
                SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: _buildField(
                    docNroCtrl,
                    docTipo == 96 ? 'Nro DNI' : 'Nro CUIT',
                    keyboard: TextInputType.number,
                  ),
                ),
              ],
            ],
          ),
          // Show on map toggle
          if (showOnMap != null && onShowOnMapChanged != null) ...[
            SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: showOnMap ? tokens.primaryBlue : tokens.cardBorder,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mostrar en mapa',
                    style: TextStyle(color: tokens.textSub, fontSize: 14),
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: Switch(
                    value: showOnMap,
                    onChanged: onShowOnMapChanged,
                    activeThumbColor: tokens.primaryBlue,
                    inactiveThumbColor: tokens.cardBorder,
                    inactiveTrackColor: tokens.cardBorder,
                  ),
                ),
              ],
            ),
          ],
          // Historial section (edit mode only)
          if (historialSection != null) ...[
            SizedBox(height: 20),
            historialSection,
          ],
          if (!isEditMode) ...[
            SizedBox(height: 24),
            // Submit buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: tokens.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(color: tokens.textSub),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.primaryBlue,
                        foregroundColor: tokens.text,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        submitLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          // Extra actions (edit mode only)
          if (extraActions.isNotEmpty) ...[
            SizedBox(height: 20),
            Divider(color: tokens.text.withValues(alpha: 0.1)),
            SizedBox(height: 8),
            ...extraActions,
          ],
          SizedBox(height: 12),
        ],
      ),
    );
  }

  // --- Add client ---

  void _showAddClienteDialog() {
    if (blockDemoAction(context)) return;
    final nombreCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final etiquetaCtrls = <TextEditingController>[TextEditingController()];
    final notaCtrl = TextEditingController();
    final docNroCtrl = TextEditingController();
    int docTipo = 99;
    String selectedCode = '+54';
    String selectedFlag = '🇦🇷';
    String frecuencia = 'semanal';
    // Captured from the address autocomplete when the operator picks a
    // suggestion. Dropped if they keep typing past the pick — see the
    // onSubmit check below.
    double? pickedLat;
    double? pickedLng;
    String? pickedAddrText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.85,
                maxChildSize: 0.95,
                minChildSize: 0.5,
                expand: false,
                builder: (context, scrollController) {
                  return _buildFormContent(
                    scrollController: scrollController,
                    title: 'Nuevo cliente — ${_allDayNames[_selectedDay]}',
                    nombreCtrl: nombreCtrl,
                    direccionCtrl: direccionCtrl,
                    telefonoCtrl: telefonoCtrl,
                    etiquetaCtrls: etiquetaCtrls,
                    notaCtrl: notaCtrl,
                    docNroCtrl: docNroCtrl,
                    docTipo: docTipo,
                    onDocTipoChanged: (v) {
                      setSheetState(() => docTipo = v);
                    },
                    selectedCode: selectedCode,
                    selectedFlag: selectedFlag,
                    frecuencia: frecuencia,
                    setSheetState: setSheetState,
                    onCodeChanged: (code, flag) {
                      setSheetState(() {
                        selectedCode = code;
                        selectedFlag = flag;
                      });
                    },
                    onFreqChanged: (v) {
                      setSheetState(() => frecuencia = v);
                    },
                    onAddEtiqueta: () {
                      setSheetState(() {
                        etiquetaCtrls.add(TextEditingController());
                      });
                    },
                    onRemoveEtiqueta: (i) {
                      setSheetState(() {
                        etiquetaCtrls[i].dispose();
                        etiquetaCtrls.removeAt(i);
                      });
                    },
                    submitLabel: 'Agregar',
                    onAddressPicked: (formatted, lat, lng) {
                      setSheetState(() {
                        pickedLat = lat;
                        pickedLng = lng;
                        pickedAddrText = formatted;
                      });
                    },
                    onSubmit: () {
                      final nombre = nombreCtrl.text.trim();
                      if (nombre.isEmpty) return;
                      final fullPhone = telefonoCtrl.text.trim().isNotEmpty
                          ? '$selectedCode${telefonoCtrl.text.trim()}'
                          : '';
                      final direccion = direccionCtrl.text.trim();
                      // Only forward coords if the address still matches
                      // the Google-formatted text the operator picked.
                      final useCoords =
                          pickedLat != null &&
                          pickedLng != null &&
                          pickedAddrText != null &&
                          pickedAddrText == direccion;
                      _createCliente(
                        nombre,
                        direccion,
                        fullPhone,
                        frecuencia,
                        _joinEtiquetas(etiquetaCtrls),
                        notaCtrl.text.trim(),
                        lat: useCoords ? pickedLat : null,
                        lng: useCoords ? pickedLng : null,
                      );
                      // Save doc info if not consumidor final
                      // (will be saved after client is created via _loadData callback)
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Defer one frame: the dismiss animation can still trigger a
      // TextField rebuild during the closing tick.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final ctrl in [
          nombreCtrl,
          direccionCtrl,
          telefonoCtrl,
          notaCtrl,
          docNroCtrl,
        ]) {
          ctrl.dispose();
        }
        for (final ctrl in etiquetaCtrls) {
          ctrl.dispose();
        }
      });
    });
  }

  // --- Edit client ---

  void _showEditClienteDialog(Cliente cliente) {
    final readOnly = kDemoMode;
    final nombreCtrl = TextEditingController(text: cliente.nombre);
    final direccionCtrl = TextEditingController(text: cliente.direccion);
    final notaCtrl = TextEditingController(text: cliente.notas);

    // Parse etiquetas into multiple controllers
    final existingEtiquetas = _parseEtiquetas(cliente.etiqueta);
    final etiquetaCtrls = existingEtiquetas.isEmpty
        ? <TextEditingController>[TextEditingController()]
        : existingEtiquetas.map((e) => TextEditingController(text: e)).toList();

    // Parse existing phone: strip country code prefix
    String selectedCode = '+54';
    String selectedFlag = '🇦🇷';
    String phoneNumber = '';
    if (cliente.telefono.isNotEmpty) {
      for (final c in countryCodes) {
        if (cliente.telefono.startsWith(c['code']!)) {
          selectedCode = c['code']!;
          selectedFlag = c['flag']!;
          phoneNumber = cliente.telefono.substring(c['code']!.length);
          break;
        }
      }
      if (phoneNumber.isEmpty && !cliente.telefono.startsWith('+')) {
        phoneNumber = cliente.telefono;
      }
    }
    final telefonoCtrl = TextEditingController(text: phoneNumber);
    final docNroCtrl = TextEditingController(
      text: cliente.docNro != '0' ? cliente.docNro : '',
    );
    int docTipo = cliente.docTipo;
    String frecuencia = cliente.frecuencia;
    bool showOnMapValue = cliente.showOnMap;
    int activeTab = 0; // 0 = Información, 1 = Historial

    // Captured from the address autocomplete on pick. Auto-save threads
    // them through to `_db.updateCliente` only when the typed text still
    // matches the picked suggestion.
    double? pickedLat;
    double? pickedLng;
    String? pickedAddrText;

    // Cache doc numbers per type so switching preserves them
    final docNroCache = <int, String>{};
    // Ensure current docNro is in cache
    if (cliente.docNro != '0' && cliente.docNro.isNotEmpty) {
      docNroCache[cliente.docTipo] = cliente.docNro;
    }

    // Load persisted cache from DB asynchronously
    bool cacheLoaded = false;

    // Historial state
    List<_HistEntry> historyEntries = [];
    int historyPage = 0;
    bool historyLoaded = false;

    // Auto-save debounce
    Timer? editDebounce;
    bool listenersAdded = false;
    bool sheetMounted = true;

    void doAutoSave() {
      if (readOnly) return;
      final nombre = nombreCtrl.text.trim();
      if (nombre.isEmpty) return;
      // Cache current doc number
      if (docTipo != 99 && docNroCtrl.text.trim().isNotEmpty) {
        docNroCache[docTipo] = docNroCtrl.text.trim();
      }
      final fullPhone = telefonoCtrl.text.trim().isNotEmpty
          ? '$selectedCode${telefonoCtrl.text.trim()}'
          : '';
      // Build cache JSON to persist
      final cacheJson = jsonEncode(
        docNroCache.map((k, v) => MapEntry(k.toString(), v)),
      );
      final direccion = direccionCtrl.text.trim();
      final useCoords =
          pickedLat != null &&
          pickedLng != null &&
          pickedAddrText != null &&
          pickedAddrText == direccion;
      _db.updateCliente(
        cliente.id,
        nombre: nombre,
        direccion: direccion,
        telefono: fullPhone,
        frecuencia: frecuencia,
        etiqueta: _joinEtiquetas(etiquetaCtrls),
        notas: notaCtrl.text.trim(),
        showOnMap: showOnMapValue,
        docTipo: docTipo,
        docNro: docTipo == 99 ? '0' : docNroCtrl.text.trim(),
        docNroCache: cacheJson,
        lat: useCoords ? pickedLat : null,
        lng: useCoords ? pickedLng : null,
      );
    }

    void scheduleAutoSave() {
      if (readOnly) return;
      editDebounce?.cancel();
      editDebounce = Timer(Duration(milliseconds: 800), doAutoSave);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            // Load history on first build
            if (!historyLoaded) {
              historyLoaded = true;
              _loadHistoryForClient(cliente.id, widget.repartoId).then((
                entries,
              ) {
                if (!sheetMounted) return;
                setSheetState(() => historyEntries = entries);
              });
            }

            // Load persisted doc number cache
            if (!cacheLoaded) {
              cacheLoaded = true;
              _db.getClienteDocNroCache(cliente.id).then((cacheJson) {
                if (!sheetMounted) return;
                try {
                  final cached = jsonDecode(cacheJson) as Map<String, dynamic>;
                  for (final entry in cached.entries) {
                    final key = int.tryParse(entry.key);
                    if (key != null &&
                        entry.value is String &&
                        (entry.value as String).isNotEmpty) {
                      docNroCache[key] = entry.value as String;
                    }
                  }
                  // If current type has a cached value and field is empty, fill it
                  if (docTipo != 99 &&
                      docNroCtrl.text.isEmpty &&
                      docNroCache.containsKey(docTipo)) {
                    setSheetState(() {
                      docNroCtrl.text = docNroCache[docTipo]!;
                    });
                  }
                } catch (_) {}
              });
            }

            // Add text field listeners once
            if (!readOnly && !listenersAdded) {
              listenersAdded = true;
              for (final ctrl in [
                nombreCtrl,
                direccionCtrl,
                telefonoCtrl,
                notaCtrl,
                docNroCtrl,
              ]) {
                ctrl.addListener(scheduleAutoSave);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.92,
                maxChildSize: 0.95,
                minChildSize: 0.5,
                expand: false,
                builder: (sheetContext, scrollController) {
                  return _buildClienteEditSheetContent(
                    sheetContext: sheetContext,
                    scrollController: scrollController,
                    cliente: cliente,
                    nombreCtrl: nombreCtrl,
                    direccionCtrl: direccionCtrl,
                    telefonoCtrl: telefonoCtrl,
                    etiquetaCtrls: etiquetaCtrls,
                    notaCtrl: notaCtrl,
                    docNroCtrl: docNroCtrl,
                    docTipo: docTipo,
                    onDocTipoChanged: (v) {
                      // Cache current number before switching
                      if (docTipo != 99 && docNroCtrl.text.trim().isNotEmpty) {
                        docNroCache[docTipo] = docNroCtrl.text.trim();
                      }
                      setSheetState(() {
                        docTipo = v;
                        // Restore cached number for new type
                        docNroCtrl.text = docNroCache[v] ?? '';
                      });
                      scheduleAutoSave();
                    },
                    selectedCode: selectedCode,
                    selectedFlag: selectedFlag,
                    frecuencia: frecuencia,
                    activeTab: activeTab,
                    setActiveTab: (tab) => setSheetState(() => activeTab = tab),
                    setSheetState: setSheetState,
                    onCodeChanged: (code, flag) {
                      setSheetState(() {
                        selectedCode = code;
                        selectedFlag = flag;
                      });
                      scheduleAutoSave();
                    },
                    onFreqChanged: (v) {
                      setSheetState(() => frecuencia = v);
                      scheduleAutoSave();
                    },
                    onAddEtiqueta: () {
                      if (readOnly && blockDemoAction(context)) return;
                      setSheetState(() {
                        etiquetaCtrls.add(
                          TextEditingController()
                            ..addListener(scheduleAutoSave),
                        );
                      });
                    },
                    onRemoveEtiqueta: (i) {
                      if (readOnly && blockDemoAction(context)) return;
                      setSheetState(() {
                        etiquetaCtrls[i].dispose();
                        etiquetaCtrls.removeAt(i);
                      });
                      scheduleAutoSave();
                    },
                    showOnMap: showOnMapValue,
                    onShowOnMapChanged: (v) {
                      setSheetState(() => showOnMapValue = v);
                      scheduleAutoSave();
                    },
                    historialSection: _buildHistorialSection(
                      cliente,
                      historyEntries,
                      historyPage,
                      setSheetState,
                      () async {
                        final entries = await _loadHistoryForClient(
                          cliente.id,
                          widget.repartoId,
                        );
                        setSheetState(() => historyEntries = entries);
                      },
                      (page) => setSheetState(() => historyPage = page),
                    ),
                    onAddressPicked: (formatted, lat, lng) {
                      if (readOnly && blockDemoAction(context)) return;
                      setSheetState(() {
                        pickedLat = lat;
                        pickedLng = lng;
                        pickedAddrText = formatted;
                      });
                      scheduleAutoSave();
                    },
                    readOnly: readOnly,
                    extraActions: [
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (readOnly && blockDemoAction(context)) {
                                  return;
                                }
                                Navigator.pop(sheetContext);
                                _generateFactura(cliente);
                              },
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: tokens.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: tokens.success.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Text(
                                        'GENERAR FACTURACIÓN',
                                        style: TextStyle(
                                          color: tokens.text,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(sheetContext);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FacturasScreen(
                                      clienteId: cliente.id,
                                      clienteNombre: cliente.nombre,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: tokens.primaryBlue.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: tokens.primaryBlue.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Text(
                                        'VER FACTURAS',
                                        style: TextStyle(
                                          color: tokens.text,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          if (readOnly && blockDemoAction(context)) {
                            return;
                          }
                          Navigator.pop(sheetContext);
                          _showCambiarDiaDialog(cliente);
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: tokens.primaryBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: tokens.primaryBlue.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  'CAMBIAR DE DIA',
                                  style: TextStyle(
                                    color: tokens.text,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          if (readOnly && blockDemoAction(context)) {
                            return;
                          }
                          Navigator.pop(sheetContext);
                          _confirmDarDeBaja(cliente);
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: tokens.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: tokens.danger.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  'DAR DE BAJA',
                                  style: TextStyle(
                                    color: tokens.text,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      sheetMounted = false;
      // Final save on dismiss + cleanup.
      editDebounce?.cancel();
      doAutoSave();
      // Defer controller disposal one frame: the sheet's dismiss
      // animation can still trigger a TextField rebuild during the
      // closing tick, and disposing inside that tick hits
      // "TextEditingController was used after being disposed."
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(Duration(milliseconds: 400), () {
          for (final ctrl in [
            nombreCtrl,
            direccionCtrl,
            telefonoCtrl,
            notaCtrl,
            docNroCtrl,
          ]) {
            ctrl.removeListener(scheduleAutoSave);
            ctrl.dispose();
          }
          for (final ctrl in etiquetaCtrls) {
            ctrl.dispose();
          }
        });
      });
      _loadData();
    });
  }

  // ignore: unused_element
  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    Color? labelColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: tokens.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tokens.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor ?? tokens.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.chevron_right, color: tokens.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  // --- Cambiar de día ---

  /// Mirrors the Ruta-side helper. After the sodero picks a destination day,
  /// ask whether to apply it once (until midnight) or permanently. Returns
  /// 'temp' / 'always' / null (cancelled).
  Future<String?> _askCambiarDiaScope(BuildContext parentCtx) {
    return showDialog<String>(
      context: parentCtx,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Cuándo aplicar el cambio?',
          style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.today, color: tokens.primaryBlue),
              title: Text(
                'Solo hoy',
                style: TextStyle(
                  color: tokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Mañana vuelve a su día habitual',
                style: TextStyle(color: tokens.textSub, fontSize: 12),
              ),
              onTap: () => Navigator.pop(ctx, 'temp'),
            ),
            ListTile(
              leading: Icon(Icons.event_repeat, color: tokens.primaryBlue),
              title: Text(
                'Siempre',
                style: TextStyle(
                  color: tokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'El cliente queda fijo en el nuevo día',
                style: TextStyle(color: tokens.textSub, fontSize: 12),
              ),
              onTap: () => Navigator.pop(ctx, 'always'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: tokens.textSub)),
          ),
        ],
      ),
    );
  }

  void _showCambiarDiaDialog(Cliente cliente) async {
    if (blockDemoAction(context)) return;
    final activeTempDay = await _db.getClienteActiveTempDay(cliente.id);
    if (!mounted) return;
    final effectiveCurrentDay = activeTempDay ?? cliente.diaSemana;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cambiar de día',
          style: TextStyle(color: tokens.text, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activeTempDay != null)
              ListTile(
                dense: true,
                leading: Icon(Icons.restore, color: tokens.primaryBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                title: Text(
                  'Volver a día habitual',
                  style: TextStyle(
                    color: tokens.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  _allDayNames[cliente.diaSemana],
                  style: TextStyle(color: tokens.textSub, fontSize: 12),
                ),
                onTap: () async {
                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(this.context);
                  await _db.clearClienteTempDay(cliente.id);
                  if (!mounted) return;
                  nav.pop();
                  setState(() => _selectedDay = cliente.diaSemana);
                  await _loadData();
                  if (!mounted) return;
                  _scrollToAndHighlight(cliente.id);
                  widget.onClientsChanged?.call();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        '${cliente.nombre} volvió a ${_allDayNames[cliente.diaSemana]}',
                        style: TextStyle(color: tokens.text),
                      ),
                      backgroundColor: tokens.surface2,
                    ),
                  );
                },
              ),
            ..._workDays.map((i) {
              final isCurrent = i == effectiveCurrentDay;
              return ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                title: Text(
                  _allDayNames[i],
                  style: TextStyle(
                    color: isCurrent ? tokens.primaryBlue : tokens.text,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
                trailing: isCurrent
                    ? Icon(Icons.check, color: tokens.primaryBlue, size: 18)
                    : null,
                onTap: isCurrent
                    ? null
                    : () async {
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(this.context);
                        final scope = await _askCambiarDiaScope(context);
                        if (scope == null) return;
                        if (scope == 'temp') {
                          await _db.setClienteTempDay(cliente.id, i);
                        } else {
                          await _db.moveClienteDayPermanent(cliente.id, i);
                        }
                        if (!mounted) return;
                        nav.pop();
                        // Switch the day tab to the destination day and reload
                        // so the moved cliente lands in the list. Mirrors the
                        // Ruta-side redirect: regardless of "solo hoy" or
                        // "siempre", the sodero ends up looking at the cliente
                        // in its new home with the glow highlight.
                        setState(() => _selectedDay = i);
                        await _loadData();
                        if (!mounted) return;
                        _scrollToAndHighlight(cliente.id);
                        widget.onClientsChanged?.call();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              scope == 'temp'
                                  ? '${cliente.nombre} movido a ${_allDayNames[i]} (solo hoy)'
                                  : '${cliente.nombre} movido a ${_allDayNames[i]}',
                              style: TextStyle(color: tokens.text),
                            ),
                            backgroundColor: tokens.surface2,
                          ),
                        );
                      },
              );
            }),
          ],
        ),
      ),
    );
  }

  // --- Dar de baja ---

  Future<void> _generateFactura(Cliente cliente) async {
    // 1. Check AFIP settings
    final settings = await _db.getSettings();
    if (settings.afipCuit.isEmpty || settings.afipPtoVta == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Configurá tus datos de ARCA en Mi Perfil antes de facturar',
          ),
        ),
      );
      return;
    }

    // 2. Load products and entregas for current week/day
    final now = argentinaTime();
    final semana = argentinaWeekString(at: now);
    final day = _selectedDay;
    final allProducts = await _db.getAllProducts(widget.repartoId);
    final entregas = await _db.getEntregasForClient(
      cliente.id,
      widget.repartoId,
      semana,
      day,
    );

    final items = <Map<String, dynamic>>[];
    double total = 0;

    for (final e in entregas) {
      if (e.entregado <= 0) continue;
      final product = allProducts
          .where((p) => p.id == e.productoId)
          .firstOrNull;
      if (product == null) continue;
      final price = e.precioUnitario > 0
          ? e.precioUnitario
          : await _db.getEffectivePrice(cliente.id, product.id);
      final subtotal = price * e.entregado;
      items.add({
        'nombre': product.nombre,
        'cantidad': e.entregado,
        'precioUnit': price,
        'subtotal': subtotal,
      });
      total += subtotal;
    }

    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No hay entregas para facturar')));
      return;
    }

    // P0-5 (audit, extendido por review de Codex): mismo guard que Ruta —
    // nunca facturar una línea a $0 (ver lib/utils/factura_guards.dart).
    final sinPrecio = unpricedFacturaItems(items);
    if (sinPrecio.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se puede facturar: ${sinPrecio.join(', ')} sin precio '
            'configurado. Configurá el precio del producto antes de facturar.',
          ),
        ),
      );
      return;
    }

    // 3. Confirm
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Generar Factura',
          style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cliente: ${cliente.nombre}',
              style: TextStyle(color: tokens.textSub, fontSize: 14),
            ),
            SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  '${item['nombre']} x${item['cantidad']} = \$${(item['subtotal'] as double).toStringAsFixed(2)}',
                  style: TextStyle(color: tokens.textSub, fontSize: 13),
                ),
              ),
            ),
            Divider(color: tokens.cardBorder, height: 16),
            Text(
              'Total: \$${total.toStringAsFixed(2)}',
              style: TextStyle(
                color: tokens.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: tokens.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Facturar',
              style: TextStyle(
                color: tokens.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 4. Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    try {
      final afip = AfipService(
        cuit: settings.afipCuit,
        production: settings.afipProduction,
      );

      final lastNro = await afip.getLastCbteNro(ptoVta: settings.afipPtoVta);
      final nextNro = lastNro + 1;

      final result = await afip.createInvoice(
        ptoVta: settings.afipPtoVta,
        cbteNro: nextNro,
        importeTotal: total,
      );

      final qrUrl = afip.generateQrUrl(
        ver: 1,
        fecha: result.fechaCbte,
        cbteTipo: result.cbteTipo,
        ptoVta: result.ptoVta,
        cbteNro: result.cbteNro,
        importeTotal: total,
        cae: result.cae,
      );

      final pdfPath = await InvoicePdfService.generatePdf(
        razonSocial: settings.afipRazonSocial,
        cuit: settings.afipCuit,
        domicilio: settings.afipDomicilio,
        condicionIva: settings.afipCondicionIva,
        ptoVta: result.ptoVta,
        cbteNro: result.cbteNro,
        fecha: result.fechaCbte,
        cae: result.cae,
        caeFchVto: result.caeFchVto,
        importeTotal: total,
        receptorNombre: cliente.nombre,
        receptorDocTipo: 99,
        receptorDocNro: '0',
        items: items,
        qrUrl: qrUrl,
      );

      final itemsJson = jsonEncode(items);
      await _db.createFactura(
        clienteId: cliente.id,
        repartoId: widget.repartoId,
        cbteTipo: result.cbteTipo,
        ptoVta: result.ptoVta,
        cbteNro: result.cbteNro,
        fecha: result.fechaCbte,
        importeTotal: total,
        cae: result.cae,
        caeFchVto: result.caeFchVto,
        itemsJson: itemsJson,
        receptorNombre: cliente.nombre,
        receptorDocTipo: 99,
        receptorDocNro: '0',
        pdfPath: pdfPath,
      );

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      // Ask to send
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: tokens.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Factura creada',
            style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Factura C ${result.ptoVta.toString().padLeft(4, '0')}-${result.cbteNro.toString().padLeft(8, '0')} '
            'generada exitosamente.\n\n¿Querés enviarla al cliente?',
            style: TextStyle(color: tokens.textSub),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('No', style: TextStyle(color: tokens.textSub)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await PlatformFileHelper.instance.sharePdf(pdfPath);
              },
              child: Text(
                'Compartir',
                style: TextStyle(
                  color: tokens.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al facturar: $e')));
    }
  }

  void _confirmDarDeBaja(Cliente cliente) {
    if (blockDemoAction(context)) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Dar de baja', style: TextStyle(color: tokens.text)),
        content: Text(
          '¿Dar de baja a ${cliente.nombre}? Se eliminarán todos sus datos.',
          style: TextStyle(color: tokens.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: tokens.textSub)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCliente(cliente.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: tokens.text,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Dar de baja'),
          ),
        ],
      ),
    );
  }

  // --- Helpers ---

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: tokens.text,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String hint, {
    bool autofocus = false,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLines: maxLines,
      keyboardType: keyboard,
      textCapitalization: textCapitalization,
      style: TextStyle(color: tokens.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: tokens.textMuted),
        filled: true,
        fillColor: tokens.bg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.primaryBlue),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildEtiquetaField({
    required TextEditingController controller,
    required String hint,
    required List<String> existingEtiquetas,
    required List<TextEditingController> currentEtiquetas,
    required void Function(void Function()) setSheetState,
    bool requestFocus = false,
    bool embedded = false,
    bool readOnly = false,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (readOnly) return const Iterable<String>.empty();
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<String>.empty();
        // Exclude etiquetas already used in current form
        final alreadyUsed = currentEtiquetas
            .map((c) => c.text.trim().toLowerCase())
            .toSet();
        return existingEtiquetas.where(
          (e) =>
              e.toLowerCase().contains(query) &&
              !alreadyUsed.contains(e.toLowerCase()),
        );
      },
      onSelected: (selection) {
        if (readOnly) return;
        controller.text = selection;
        setSheetState(() {});
      },
      initialValue: controller.text.isNotEmpty
          ? TextEditingValue(text: controller.text)
          : null,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        if (requestFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!focusNode.hasFocus) focusNode.requestFocus();
          });
        }
        // Keep the external controller in sync via onChanged
        return TextField(
          controller: textController,
          focusNode: focusNode,
          readOnly: readOnly,
          onTap: () {
            if (readOnly) {
              blockDemoAction(context);
              return;
            }
            Future.delayed(Duration(milliseconds: 100), () {
              if (context.mounted) {
                Scrollable.ensureVisible(
                  context,
                  duration: Duration(milliseconds: 250),
                  alignmentPolicy:
                      ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                );
              }
            });
          },
          onChanged: (value) {
            if (readOnly) return;
            controller.text = value;
            setSheetState(() {});
          },
          style: TextStyle(color: tokens.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: tokens.textMuted),
            filled: !embedded,
            fillColor: embedded ? null : tokens.bg,
            enabledBorder: embedded
                ? InputBorder.none
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: tokens.cardBorder),
                  ),
            focusedBorder: embedded
                ? InputBorder.none
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: tokens.primaryBlue),
                  ),
            contentPadding: embedded
                ? EdgeInsets.zero
                : EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: embedded,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: tokens.card,
            borderRadius: BorderRadius.circular(8),
            elevation: 8,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 150, maxWidth: 320),
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  final color = _colorForEtiqueta(option);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            option,
                            style: TextStyle(color: tokens.text, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFreqOption(
    String label,
    String value,
    String current,
    ValueChanged<String> onChanged, {
    bool enabled = true,
  }) {
    final isSelected = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: enabled
            ? () => onChanged(value)
            : () => blockDemoAction(context),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isSelected
                ? tokens.primaryBlue.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? tokens.primaryBlue : tokens.cardBorder,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? tokens.primaryBlue : tokens.textMuted,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openCountryPicker(
    BuildContext parentContext,
    String currentCode,
    String currentFlag,
    void Function(String code, String flag) onSelect,
  ) {
    String search = '';
    showModalBottomSheet(
      context: parentContext,
      backgroundColor: tokens.card,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = countryCodes.where((c) {
              final q = search.toLowerCase();
              return c['name']!.toLowerCase().contains(q) ||
                  c['code']!.contains(q);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: TextField(
                        style: TextStyle(color: tokens.text),
                        decoration: InputDecoration(
                          hintText: 'Buscar país...',
                          hintStyle: TextStyle(color: tokens.textMuted),
                          filled: true,
                          fillColor: tokens.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: tokens.cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: tokens.cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: tokens.primaryBlue),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: tokens.textMuted,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onChanged: (v) => setPickerState(() => search = v),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final c = filtered[i];
                          final isSelected =
                              c['code'] == currentCode &&
                              c['flag'] == currentFlag;
                          return ListTile(
                            leading: _countryFlag(
                              c['flag']!,
                              width: 34,
                              height: 24,
                            ),
                            title: Text(
                              c['name']!,
                              style: TextStyle(
                                color: tokens.text,
                                fontSize: 15,
                              ),
                            ),
                            trailing: Text(
                              c['code']!,
                              style: TextStyle(
                                color: isSelected
                                    ? tokens.primaryBlue
                                    : tokens.textMuted,
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            onTap: () {
                              onSelect(c['code']!, c['flag']!);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _createCliente(
    String nombre,
    String direccion,
    String telefono,
    String frecuencia,
    String etiqueta,
    String notas, {
    double? lat,
    double? lng,
  }) async {
    if (blockDemoAction(context)) return;
    await _db.createCliente(
      widget.repartoId,
      _selectedDay,
      nombre,
      direccion: direccion,
      telefono: telefono,
      frecuencia: frecuencia,
      etiqueta: etiqueta,
      notas: notas,
      lat: lat,
      lng: lng,
    );
    _loadData();
    widget.onClientsChanged?.call();
  }

  Future<void> _deleteCliente(int clienteId) async {
    if (blockDemoAction(context)) return;
    // Tombstone goes in scoped to the signed-in user so the cloud cascade
    // replays on the next sync if the immediate call below fails or the
    // device is offline. The fire-and-forget direct delete stays as the
    // happy-path fast track.
    await _db.deleteCliente(clienteId, userId: AuthService.currentUser?.id);
    SyncService.instance.deleteClienteFromCloud(clienteId);
    _loadData();
    widget.onClientsChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar — light AppBar style matching cierre/historial.
            Container(
              decoration: BoxDecoration(
                color: tokens.card,
                border: Border(
                  bottom: BorderSide(color: tokens.cardBorder, width: 1),
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: tokens.text,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'CLIENTES',
                    style: TextStyle(
                      color: tokens.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            SyncIndicator(),
            SizedBox(height: 14),
            // Day pills card — same style as etiquetas / carga.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.card,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 14,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (
                              var idx = 0;
                              idx < _workDays.length;
                              idx++
                            ) ...[
                              () {
                                final i = _workDays[idx];
                                final isSelected = _selectedDay == i;
                                final label = _allDayNames[i].length >= 3
                                    ? _allDayNames[i]
                                          .substring(0, 3)
                                          .toUpperCase()
                                    : _allDayNames[i].toUpperCase();
                                return GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedDay = i);
                                    _loadData();
                                  },
                                  child: Container(
                                    constraints: BoxConstraints(minWidth: 56),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? tokens.primaryBlue
                                          : tokens.card,
                                      borderRadius: BorderRadius.circular(12),
                                      border: isSelected
                                          ? null
                                          : Border.all(
                                              color: tokens.cardBorder,
                                              width: 1,
                                            ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : tokens.text,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                );
                              }(),
                              if (idx < _workDays.length - 1)
                                SizedBox(width: 10),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 10),
            // Search bar + Personalizado button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: tokens.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tokens.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Icon(
                              Icons.search,
                              color: tokens.textMuted,
                              size: 20,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(
                                color: tokens.text,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Buscar cliente...',
                                hintStyle: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final wasEditMode = _editMode;
                      setState(() {
                        _editMode = !_editMode;
                        if (_editMode) {
                          _searchController.clear();
                          _shakeController.repeat();
                        } else {
                          _shakeController.stop();
                          _shakeController.reset();
                        }
                      });
                      if (wasEditMode) {
                        // Exiting edit mode: reload from DB to get persisted order
                        _loadData();
                      }
                    },
                    child: Container(
                      height: 40,
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: _editMode ? tokens.primaryBlue : tokens.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _editMode
                              ? tokens.primaryBlue
                              : tokens.cardBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swap_vert,
                            color: _editMode ? tokens.text : tokens.textMuted,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Ordenar',
                            style: TextStyle(
                              color: _editMode ? tokens.text : tokens.textMuted,
                              fontSize: 12,
                              fontWeight: _editMode
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            // Client list
            Expanded(
              child: _filteredClientes.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isNotEmpty
                            ? 'Sin resultados'
                            : 'Sin clientes para ${_allDayNames[_selectedDay].toLowerCase()}',
                        style: TextStyle(color: tokens.textMuted, fontSize: 14),
                      ),
                    )
                  : _editMode
                  ? ReorderableListView.builder(
                      scrollController: _listScrollController,
                      buildDefaultDragHandles: false,
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          color: Colors.transparent,
                          elevation: 4,
                          shadowColor: Colors.black54,
                          child: child,
                        );
                      },
                      onReorder: _onReorderClients,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredClientes.length,
                      itemBuilder: (context, index) {
                        final cliente = _filteredClientes[index];
                        return _buildClienteCard(cliente, index);
                      },
                    )
                  : ListView.builder(
                      controller: _listScrollController,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredClientes.length,
                      itemBuilder: (context, index) {
                        final cliente = _filteredClientes[index];
                        return _buildClienteCard(cliente, index);
                      },
                    ),
            ),
            // Add client button
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _showAddClienteDialog,
                  icon: Icon(Icons.add, size: 20),
                  label: Text(
                    'Agregar cliente',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.primaryBlue,
                    foregroundColor: tokens.text,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClienteCard(Cliente cliente, int index) {
    final etiquetas = _parseEtiquetas(cliente.etiqueta);
    final isHighlighted = _highlightedClienteId == cliente.id;
    final cardKey = _cardKeys.putIfAbsent(cliente.id, () => GlobalKey());

    Widget card = GestureDetector(
      key: cardKey,
      onTap: () => _showEditClienteDialog(cliente),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 400),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlighted ? tokens.primaryBlue : tokens.cardBorder,
            width: isHighlighted ? 2 : 1,
          ),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: tokens.primaryBlue.withValues(alpha: 0.35),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Number circle. In edit (Ordenar) mode it doubles as a
            // shortcut to type a new position — the outer card tap is
            // intercepted here so the edit-cliente dialog doesn't open.
            Padding(
              padding: EdgeInsets.only(top: 2),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _editMode
                    ? () => _showChangePositionDialog(cliente, index)
                    : null,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _editMode
                          ? tokens.primaryBlue.withValues(alpha: 0.6)
                          : tokens.textMuted,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: _editMode ? tokens.primaryBlue : tokens.textSub,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            // Client info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cliente.direccion.isNotEmpty
                        ? cliente.direccion
                        : 'Sin dirección',
                    softWrap: true,
                    style: TextStyle(
                      color: cliente.direccion.isNotEmpty
                          ? tokens.primaryBlue
                          : tokens.text.withValues(alpha: 0.45),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.15,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  // Center-aligned row: person icon + name + frecuencia
                  // letter all sit on the same horizontal axis. Same
                  // recipe as Ruta.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 13,
                        color: tokens.textMuted,
                      ),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          cliente.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '·',
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        _frecLetter(cliente.frecuencia),
                        style: TextStyle(
                          color: tokens.textSub,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          height: 1.2,
                        ),
                      ),
                      if (!isMoneyEffectivelyZero(cliente.cuentaCorriente)) ...[
                        SizedBox(width: 8),
                        Text(
                          _formatMoney(cliente.cuentaCorriente),
                          style: TextStyle(
                            color: isMoneyNegative(cliente.cuentaCorriente)
                                ? tokens.danger
                                : tokens.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Order requested by user: notas first, etiquetas below.
                  if (cliente.notas.isNotEmpty) ...[
                    SizedBox(height: 5),
                    Text(
                      cliente.notas,
                      style: TextStyle(
                        color: tokens.text.withValues(alpha: 0.4),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (etiquetas.isNotEmpty) ...[
                    SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: etiquetas
                          .map((e) => _buildTag(e, _colorForEtiqueta(e)))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            if (_editMode) ...[
              SizedBox(width: 4),
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Icon(
                    Icons.drag_handle,
                    color: tokens.textMuted,
                    size: 18,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // iOS-style shake animation in edit mode
    if (_editMode) {
      final phase = (index % 3) * 0.33;
      card = AnimatedBuilder(
        key: ValueKey(cliente.id),
        animation: _shakeController,
        builder: (context, child) {
          final angle = sin((_shakeController.value + phase) * 2 * pi) * 0.012;
          return Transform.rotate(angle: angle, child: child);
        },
        child: card,
      );
    } else {
      card = KeyedSubtree(key: ValueKey(cliente.id), child: card);
    }

    return card;
  }

  // --- Historial helpers ---

  static const List<String> _dayAbbrs = [
    'LUN',
    'MAR',
    'MIÉ',
    'JUE',
    'VIE',
    'SÁB',
    'DOM',
  ];

  String _weekDayToDateStr(String semana, int dia) {
    final match = RegExp(r'(\d{4})-W(\d{2})').firstMatch(semana);
    if (match == null) return '??';
    final year = int.parse(match.group(1)!);
    final week = int.parse(match.group(2)!);
    final jan4 = DateTime(year, 1, 4);
    final monday = jan4
        .subtract(Duration(days: jan4.weekday - 1))
        .add(Duration(days: (week - 1) * 7));
    final date = monday.add(Duration(days: dia));
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  DateTime? _weekDayToDate(String semana, int dia) {
    final match = RegExp(r'(\d{4})-W(\d{2})').firstMatch(semana);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final week = int.parse(match.group(2)!);
    final jan4 = DateTime(year, 1, 4);
    final monday = jan4
        .subtract(Duration(days: jan4.weekday - 1))
        .add(Duration(days: (week - 1) * 7));
    return monday.add(Duration(days: dia));
  }

  /// Returns the most recent date matching the current reparto day.
  /// If today IS the reparto day, returns today. Otherwise goes back to the last occurrence.
  DateTime _mostRecentRepartoDay() {
    final now = argentinaTime();
    final todayWeekday = now.weekday; // 1=Mon..7=Sun
    final repartoDayWeekday =
        _selectedDay +
        1; // _selectedDay is 0=Mon..6=Sun, weekday is 1=Mon..7=Sun
    int daysBack = (todayWeekday - repartoDayWeekday) % 7;
    // If daysBack == 0, it means today is the reparto day — use today
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysBack));
  }

  static String _shortenProductName(String name) {
    if (name.length <= 10) return name;
    final words = name.split(' ');
    if (words.length == 1) return '${name.substring(0, 8)}…';
    return words
        .map((w) => w.length > 4 ? '${w.substring(0, 3)}.' : w)
        .join(' ');
  }

  Future<List<_HistEntry>> _loadHistoryForClient(
    int clienteId,
    int repartoId,
  ) async {
    final allEntregas = await _db.getAllEntregasForClient(clienteId, repartoId);
    final allPagos = await _db.getAllPagosForClient(clienteId, repartoId);
    final allProducts = await _db.getAllProducts(widget.repartoId);
    final productMap = {for (final p in allProducts) p.id: p};
    final productPackSizes = await _db.getProductoPackSizesForReparto(
      repartoId,
    );

    // P2.2: pre-cache effective sale price per producto referenced by any
    // legacy zero-snapshot entrega. Used as the fallback when an old row
    // has no precio_unitario stored. Never product.precio (factory cost).
    final legacyProductIds = <int>{};
    for (final e in allEntregas) {
      if (e.entregado > 0 && e.precioUnitario == 0)
        legacyProductIds.add(e.productoId);
    }
    final effectiveSalePrices = <int, double>{};
    for (final pid in legacyProductIds) {
      effectiveSalePrices[pid] = await _db.getEffectivePrice(clienteId, pid);
    }

    final grouped = <String, List<Entrega>>{};
    for (final e in allEntregas) {
      final key = '${e.semana}|${e.diaSemana}';
      grouped.putIfAbsent(key, () => []).add(e);
    }

    final pagoLookup = <String, Pago>{};
    for (final p in allPagos) {
      pagoLookup['${p.semana}|${p.diaSemana}'] = p;
    }

    // Also include pago-only entries (status markers without entregas)
    for (final p in allPagos) {
      final key = '${p.semana}|${p.diaSemana}';
      grouped.putIfAbsent(key, () => []);
    }

    final entries = <_HistEntry>[];
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final key in sortedKeys) {
      final parts = key.split('|');
      final semana = parts[0];
      final dia = int.parse(parts[1]);
      final entregas = grouped[key]!;
      final pago = pagoLookup[key];

      final deliveries = <_HistDelivery>[];
      for (final e in entregas) {
        final pName = productMap[e.productoId]?.nombre ?? '?';
        if (e.entregado > 0 || e.devuelto > 0) {
          deliveries.add(
            _HistDelivery(
              productoId: e.productoId,
              productName: _shortenProductName(pName),
              entregado: e.entregado,
              devuelto: e.devuelto,
              packSize: productPackSizes[e.productoId],
              precioUnitario: e.precioUnitario,
            ),
          );
        }
      }

      final hasDelivery = entregas.any(
        (e) => e.entregado > 0 || e.devuelto > 0,
      );
      final dateLabel = _weekDayToDateStr(semana, dia);
      final actualDate = _weekDayToDate(semana, dia);

      // P2.2: snapshot-first / effective sale price fallback. Never the
      // product.precio (factory cost) field for sale totals.
      double dayTotal = 0;
      for (final e in entregas) {
        final precio = e.precioUnitario > 0
            ? e.precioUnitario
            : (effectiveSalePrices[e.productoId] ?? 0);
        if (precio > 0) dayTotal += precio * e.entregado;
      }

      entries.add(
        _HistEntry(
          dateLabel: dateLabel,
          dayAbbr: dia >= 0 && dia < _dayAbbrs.length ? _dayAbbrs[dia] : '?',
          month: actualDate?.month ?? 1,
          year: actualDate?.year ?? DateTime.now().year,
          deliveries: deliveries,
          monto: pago?.monto ?? 0,
          totalOwed: dayTotal,
          metodoPago: pago?.metodoPago,
          noCompro:
              pago?.metodoPago == 'no_compro' || (!hasDelivery && pago == null),
          ausente: pago?.metodoPago == 'ausente',
          saltado: pago?.metodoPago == 'saltado',
          semana: semana,
          diaSemana: dia,
        ),
      );
    }
    return entries;
  }

  Widget _buildHistorialSection(
    Cliente cliente,
    List<_HistEntry> historyEntries,
    int historyPage,
    void Function(void Function()) setSheetState,
    Future<void> Function() reloadHistory,
    void Function(int) onPageChanged,
  ) {
    // Group by month
    final monthGroups = <String, List<_HistEntry>>{};
    for (final e in historyEntries) {
      final key = '${e.year}-${e.month.toString().padLeft(2, '0')}';
      monthGroups.putIfAbsent(key, () => []).add(e);
    }
    final sortedMonths = monthGroups.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final totalPages = sortedMonths.length;
    final safePage = historyPage.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
    final pageEntries = totalPages > 0
        ? monthGroups[sortedMonths[safePage]]!
        : <_HistEntry>[];
    const monthNames = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    final currentMonthLabel = totalPages > 0
        ? monthNames[int.parse(sortedMonths[safePage].split('-')[1])]
        : '';

    return GestureDetector(
      // Swipe horizontally to flip months. < / > buttons below still work
      // for tap users — the swipe is additive, never replaces them.
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        if (totalPages <= 1) return;
        final vx = details.velocity.pixelsPerSecond.dx;
        if (vx.abs() < 250) return;
        if (vx > 0 && safePage > 0) {
          onPageChanged(safePage - 1);
        } else if (vx < 0 && safePage < totalPages - 1) {
          onPageChanged(safePage + 1);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: tokens.text.withValues(alpha: 0.1)),
          SizedBox(height: 8),
          Row(
            children: [
              Text(
                'HISTORIAL',
                style: TextStyle(
                  color: tokens.textSub,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (currentMonthLabel.isNotEmpty) ...[
                SizedBox(width: 8),
                Text(
                  currentMonthLabel,
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
              ],
              Spacer(),
              GestureDetector(
                onTap: () => _showAddHistoryDialog(
                  cliente,
                  setSheetState,
                  reloadHistory,
                ),
                child: Icon(
                  Icons.add_circle_outline,
                  color: tokens.textMuted,
                  size: 20,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (historyEntries.isEmpty)
            Text(
              'Sin historial',
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            )
          else ...[
            for (int row = 0; row < ((pageEntries.length + 1) ~/ 2); row++) ...[
              if (row > 0) SizedBox(height: 6),
              Row(
                children: [
                  for (int col = 0; col < 2; col++) ...[
                    if (col > 0) SizedBox(width: 6),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final idx = row * 2 + col;
                          if (idx >= pageEntries.length)
                            return SizedBox(height: 70);
                          final entry = pageEntries[idx];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                _showEditHistoryForEntry(
                                  cliente,
                                  entry,
                                  setSheetState,
                                  reloadHistory,
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: 70,
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: tokens.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: tokens.cardBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${entry.dayAbbr} ${entry.dateLabel}',
                                          style: TextStyle(
                                            color: tokens.text.withValues(
                                              alpha: 0.6,
                                            ),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (entry.metodoPago == 'no_pago' ||
                                            (entry.monto <= 0 &&
                                                !entry.noCompro &&
                                                !entry.ausente &&
                                                !entry.saltado &&
                                                entry.totalOwed > 0))
                                          Text(
                                            '\$${entry.totalOwed.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              color: tokens.danger,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          )
                                        else if (entry.monto > 0)
                                          Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text:
                                                      '\$${entry.monto.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    color: tokens.success,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                if (entry.deuda > 0)
                                                  TextSpan(
                                                    text:
                                                        ' -\$${entry.deuda.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      color: tokens.danger,
                                                      fontSize: 8,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    Spacer(),
                                    if (entry.ausente)
                                      Text(
                                        'Ausente',
                                        style: TextStyle(
                                          color: Color(
                                            0xFFFF9800,
                                          ).withValues(alpha: 0.7),
                                          fontSize: 9,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      )
                                    else if (entry.saltado)
                                      Text(
                                        'Saltado',
                                        style: TextStyle(
                                          color: Color(
                                            0xFF1292D3,
                                          ).withValues(alpha: 0.7),
                                          fontSize: 9,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      )
                                    else if (entry.noCompro)
                                      Text(
                                        'No compró',
                                        style: TextStyle(
                                          color: Color(
                                            0xFFE53935,
                                          ).withValues(alpha: 0.7),
                                          fontSize: 9,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      )
                                    else ...[
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 2,
                                        children: entry.deliveries
                                            .where((d) => d.entregado > 0)
                                            .map(
                                              (d) => Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.arrow_upward,
                                                    size: 9,
                                                    color: tokens.success,
                                                  ),
                                                  Text(
                                                    formatPackQty(
                                                      d.entregado,
                                                      d.packSize,
                                                    ),
                                                    style: TextStyle(
                                                      color: tokens.success,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    d.productName,
                                                    style: TextStyle(
                                                      color: tokens.text
                                                          .withValues(
                                                            alpha: 0.45,
                                                          ),
                                                      fontSize: 8,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                            .toList(),
                                      ),
                                      if (entry.deliveries.any(
                                        (d) => d.devuelto > 0,
                                      ))
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 2,
                                          children: entry.deliveries
                                              .where((d) => d.devuelto > 0)
                                              .map(
                                                (d) => Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.arrow_downward,
                                                      size: 9,
                                                      color: tokens.danger,
                                                    ),
                                                    Text(
                                                      formatPackQty(
                                                        d.devuelto,
                                                        d.packSize,
                                                      ),
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFFE53935,
                                                        ),
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    SizedBox(width: 2),
                                                    Text(
                                                      d.productName,
                                                      style: TextStyle(
                                                        color: tokens.text
                                                            .withValues(
                                                              alpha: 0.45,
                                                            ),
                                                        fontSize: 8,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                              .toList(),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (totalPages > 1)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: safePage > 0
                          ? () => onPageChanged(safePage - 1)
                          : null,
                      child: Text(
                        '<',
                        style: TextStyle(
                          color: safePage > 0
                              ? tokens.textMuted
                              : tokens.cardBorder,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      currentMonthLabel,
                      style: TextStyle(
                        color: tokens.textSub,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 10),
                    GestureDetector(
                      onTap: safePage < totalPages - 1
                          ? () => onPageChanged(safePage + 1)
                          : null,
                      child: Text(
                        '>',
                        style: TextStyle(
                          color: safePage < totalPages - 1
                              ? tokens.textMuted
                              : tokens.cardBorder,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEditHistoryForEntry(
    Cliente cliente,
    _HistEntry entry,
    void Function(void Function()) setSheetState,
    Future<void> Function() reloadHistory,
  ) async {
    if (blockDemoAction(context)) return;
    final allProducts = await _db.getAllProducts(widget.repartoId);
    if (!mounted) return;
    // P2.2: prefetch effective sale prices once for any product the user
    // adds to this historical entry (snapshot fallback). Never fall back to
    // product.precio (factory cost) for sale totals.
    final effectiveSalePrices = <int, double>{};
    for (final p in allProducts) {
      effectiveSalePrices[p.id] = await _db.getEffectivePrice(cliente.id, p.id);
    }
    if (!mounted) return;

    final date = _weekDayToDate(entry.semana, entry.diaSemana);
    if (date == null) return;

    // Use data already loaded in the entry instead of re-querying DB
    final productQuantities = <int, int>{};
    final productDevueltos = <int, int>{};
    final snapshotPrices = <int, double>{};
    for (final d in entry.deliveries) {
      productQuantities[d.productoId] = d.entregado;
      productDevueltos[d.productoId] = d.devuelto;
      if (d.precioUnitario > 0) {
        snapshotPrices[d.productoId] = d.precioUnitario;
      }
    }

    // Determine estado from entry flags
    String estado = 'listo';
    String paymentMethod = 'efectivo';
    if (entry.noCompro) {
      estado = 'no_compro';
      paymentMethod = entry.monto > 0 ? 'efectivo' : 'no_pago';
    } else if (entry.ausente) {
      estado = 'ausente';
      paymentMethod = entry.monto > 0 ? 'efectivo' : 'no_pago';
    } else if (entry.saltado) {
      estado = 'saltado';
      paymentMethod = 'no_pago';
    } else if (entry.metodoPago != null) {
      paymentMethod = entry.metodoPago!;
    }
    final montoController = TextEditingController(
      text: entry.monto > 0 ? entry.monto.toStringAsFixed(0) : '',
    );

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            double calcTotal() {
              double total = 0;
              for (final e in productQuantities.entries) {
                if (e.value > 0) {
                  // P2.2: snapshot-first (historical truth), fallback to
                  // effective sale price. Never product.precio (factory cost).
                  final snapPrice = snapshotPrices[e.key];
                  if (snapPrice != null && snapPrice > 0) {
                    total += snapPrice * e.value;
                  } else {
                    total += (effectiveSalePrices[e.key] ?? 0.0) * e.value;
                  }
                }
              }
              return total;
            }

            return AlertDialog(
              backgroundColor: tokens.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Editar orden histórica',
                style: TextStyle(
                  color: tokens.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fixed date display
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: tokens.cardBorder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: tokens.primaryBlue,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                                style: TextStyle(
                                  color: tokens.text,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              _allDayNames[(date.weekday - 1).clamp(0, 6)],
                              style: TextStyle(
                                color: tokens.textSub,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Estado',
                        style: TextStyle(
                          color: tokens.textSub,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _histEstadoChip(
                              'Listo',
                              'listo',
                              tokens.success,
                              estado,
                              (v) => setDialogState(() => estado = v),
                            ),
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: _histEstadoChip(
                              'No compró',
                              'no_compro',
                              tokens.danger,
                              estado,
                              (v) => setDialogState(() => estado = v),
                            ),
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: _histEstadoChip(
                              'Ausente',
                              'ausente',
                              tokens.warn,
                              estado,
                              (v) => setDialogState(() => estado = v),
                            ),
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: _histEstadoChip(
                              'Saltado',
                              'saltado',
                              tokens.primaryBlue,
                              estado,
                              (v) => setDialogState(() => estado = v),
                            ),
                          ),
                        ],
                      ),
                      if (estado == 'listo') ...[
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                'PRODUCTOS',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Text(
                                'COMPRADO',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              flex: 5,
                              child: Text(
                                'DEVUELTO',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        ...allProducts.map((product) {
                          final qty = productQuantities[product.id] ?? 0;
                          final dev = productDevueltos[product.id] ?? 0;
                          void syncMonto(void Function() change) {
                            final oldTotal = calcTotal();
                            final currentMonto =
                                parseArgNumber(montoController.text) ?? 0.0;
                            setDialogState(change);
                            if (paymentMethod != 'no_pago' &&
                                (currentMonto == oldTotal ||
                                    montoController.text.isEmpty)) {
                              montoController.text = calcTotal()
                                  .toStringAsFixed(0);
                            }
                          }

                          return Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    _shortenProductName(product.nombre),
                                    style: TextStyle(
                                      color: tokens.text,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: _buildQtyControl(
                                    qty,
                                    onMinus: () {
                                      if (qty > 0)
                                        syncMonto(
                                          () => productQuantities[product.id] =
                                              qty - 1,
                                        );
                                    },
                                    onPlus: () {
                                      syncMonto(
                                        () => productQuantities[product.id] =
                                            qty + 1,
                                      );
                                    },
                                    onDirectInput: (v) {
                                      syncMonto(
                                        () => productQuantities[product.id] = v,
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  flex: 5,
                                  child: _buildQtyControl(
                                    dev,
                                    onMinus: () {
                                      if (dev > 0)
                                        setDialogState(
                                          () => productDevueltos[product.id] =
                                              dev - 1,
                                        );
                                    },
                                    onPlus: () {
                                      setDialogState(
                                        () => productDevueltos[product.id] =
                                            dev + 1,
                                      );
                                    },
                                    onDirectInput: (v) {
                                      setDialogState(
                                        () => productDevueltos[product.id] = v,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Total: ',
                              style: TextStyle(
                                color: tokens.textSub,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '\$${calcTotal().toStringAsFixed(0)}',
                              style: TextStyle(
                                color: tokens.primaryBlue,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ], // end if (estado == 'listo')
                      SizedBox(height: 12),
                      Text(
                        'Pago',
                        style: TextStyle(
                          color: tokens.textSub,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _histPayChip(
                              'Efectivo',
                              'efectivo',
                              paymentMethod,
                              (v) => setDialogState(() => paymentMethod = v),
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: _histPayChip(
                              'Transfer.',
                              'transferencia',
                              paymentMethod,
                              (v) => setDialogState(() => paymentMethod = v),
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: _histPayChip(
                              'No pagó',
                              'no_pago',
                              paymentMethod,
                              (v) => setDialogState(() => paymentMethod = v),
                            ),
                          ),
                        ],
                      ),
                      if (paymentMethod != 'no_pago') ...[
                        SizedBox(height: 12),
                        TextField(
                          controller: montoController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          style: TextStyle(color: tokens.text, fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Monto pagado',
                            labelStyle: TextStyle(color: tokens.textSub),
                            prefixText: '\$ ',
                            prefixStyle: TextStyle(color: tokens.textSub),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: tokens.cardBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: tokens.primaryBlue),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => AlertDialog(
                        backgroundColor: tokens.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          'Eliminar entrada',
                          style: TextStyle(
                            color: tokens.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        content: Text(
                          '¿Eliminar esta entrada del historial?',
                          style: TextStyle(color: tokens.textSub),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(color: tokens.textSub),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: Text(
                              'Eliminar',
                              style: TextStyle(color: tokens.danger),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true || !ctx.mounted) return;
                    final semana = entry.semana;
                    final dia = entry.diaSemana;
                    final repartoId = widget.repartoId;
                    // Delete all entregas and pago for this day
                    SyncService.instance.beginLocalWrites();
                    try {
                      final uid = AuthService.currentUser?.id;
                      // deleteEntregasForDay and deletePago each run an
                      // atomic recalc inside their own DB transaction. P1.1
                      // removed the buggy `cuenta_corriente = totalPaid`
                      // override that previously ran here.
                      await _db.deleteEntregasForDay(
                        cliente.id,
                        repartoId,
                        semana,
                        dia,
                        userId: uid,
                      );
                      await _db.deletePago(
                        cliente.id,
                        repartoId,
                        semana,
                        dia,
                        userId: uid,
                      );
                    } finally {
                      SyncService.instance.endLocalWrites();
                    }
                    // Refresh parent cliente list so the row's Deudor display
                    // picks up the newly-recomputed value.
                    await _loadData();
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    await reloadHistory();
                  },
                  child: Text(
                    'Eliminar',
                    style: TextStyle(color: tokens.danger),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: tokens.textSub),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final semana = entry.semana;
                    final dia = entry.diaSemana;
                    final repartoId = widget.repartoId;

                    SyncService.instance.beginLocalWrites();
                    try {
                      if (estado == 'listo') {
                        // Update all products (including zeroed-out ones)
                        final updatedIds = <int>{};
                        for (final e in productQuantities.entries) {
                          updatedIds.add(e.key);
                          final entregado = e.value;
                          final devuelto = productDevueltos[e.key] ?? 0;
                          // P2.2: snapshot-first / effective price fallback.
                          // Never product.precio. setEntrega's P1.2 CASE
                          // preserves the existing snapshot anyway, so this
                          // mostly matters for newly-added products in the
                          // edit dialog.
                          final snap = snapshotPrices[e.key] ?? 0.0;
                          final precio = snap > 0
                              ? snap
                              : (effectiveSalePrices[e.key] ?? 0.0);
                          await _db.setEntrega(
                            cliente.id,
                            repartoId,
                            e.key,
                            semana,
                            dia,
                            entregado,
                            devuelto,
                            precioUnitario: precio,
                          );
                        }
                        // Zero out old entregas that were removed
                        for (final d in entry.deliveries) {
                          if (!updatedIds.contains(d.productoId)) {
                            await _db.setEntrega(
                              cliente.id,
                              repartoId,
                              d.productoId,
                              semana,
                              dia,
                              0,
                              0,
                            );
                          }
                        }
                      } else {
                        // Delete entregas for this day since client wasn't served
                        for (final d in entry.deliveries) {
                          await _db.setEntrega(
                            cliente.id,
                            repartoId,
                            d.productoId,
                            semana,
                            dia,
                            0,
                            0,
                          );
                        }
                      }

                      // Save pago (payment or status marker)
                      if (estado != 'listo') {
                        final monto = paymentMethod != 'no_pago'
                            ? (parseArgNumber(montoController.text) ?? 0.0)
                            : 0.0;
                        await _db.setPago(
                          cliente.id,
                          repartoId,
                          semana,
                          dia,
                          estado,
                          monto,
                        );
                      } else {
                        final total = calcTotal();
                        if (paymentMethod == 'no_pago') {
                          await _db.setPago(
                            cliente.id,
                            repartoId,
                            semana,
                            dia,
                            'no_pago',
                            total,
                          );
                        } else {
                          final monto =
                              parseArgNumber(montoController.text) ?? total;
                          await _db.setPago(
                            cliente.id,
                            repartoId,
                            semana,
                            dia,
                            paymentMethod,
                            monto,
                          );
                        }
                      }

                      // P1.1: setEntrega/setPago each ran an atomic recalc
                      // inside their own transaction. Removed the buggy
                      // `cuenta_corriente = totalPaid` override that ran here.
                    } finally {
                      SyncService.instance.endLocalWrites();
                    }
                    // Refresh parent cliente list so Deudor display catches up.
                    await _loadData();

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    await reloadHistory();
                  },
                  child: Text(
                    'Guardar',
                    style: TextStyle(color: tokens.primaryBlue),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddHistoryDialog(
    Cliente cliente,
    void Function(void Function()) setSheetState,
    Future<void> Function() onSaved,
  ) async {
    if (blockDemoAction(context)) return;
    final allProducts = await _db.getAllProducts(widget.repartoId);
    if (!mounted) return;
    // P2.2: prefetch effective sale prices once so calcTotal stays sync.
    // Never use product.precio (factory cost) for sale totals.
    final effectiveSalePrices = <int, double>{};
    for (final p in allProducts) {
      effectiveSalePrices[p.id] = await _db.getEffectivePrice(cliente.id, p.id);
    }
    if (!mounted) return;

    // Default to the most recent occurrence of this reparto's day
    DateTime selectedDate = _mostRecentRepartoDay();
    final productQuantities = <int, int>{};
    final productDevueltos = <int, int>{};
    // P2.2: snapshot prices from any existingEntregas for the selected date,
    // populated when the user picks a date that has existing data.
    final snapshotPrices = <int, double>{};
    String estado = 'listo';
    String paymentMethod = 'efectivo';
    final montoController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final diaSemana = selectedDate.weekday - 1;

            double calcTotal() {
              double total = 0;
              for (final entry in productQuantities.entries) {
                if (entry.value > 0) {
                  // P2.2: snapshot-first (historical truth), fallback to
                  // effective sale price (DB-fetched). Never product.precio
                  // — that's factory cost.
                  final snapshot = snapshotPrices[entry.key] ?? 0.0;
                  final precio = snapshot > 0
                      ? snapshot
                      : (effectiveSalePrices[entry.key] ?? 0.0);
                  total += precio * entry.value;
                }
              }
              return total;
            }

            return AlertDialog(
              backgroundColor: tokens.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Agregar orden histórica',
                style: TextStyle(
                  color: tokens.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date picker
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: argentinaTime(),
                            builder: (context, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: tokens.primaryBlue,
                                  surface: tokens.card,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            selectedDate = picked;
                            // Check for existing data on this date
                            final semana = argentinaWeekString(at: picked);
                            final dia = picked.weekday - 1;
                            final existingEntregas = await _db
                                .getEntregasForClient(
                                  cliente.id,
                                  widget.repartoId,
                                  semana,
                                  dia,
                                );
                            final existingPago = await _db.getPago(
                              cliente.id,
                              widget.repartoId,
                              semana,
                              dia,
                            );
                            productQuantities.clear();
                            productDevueltos.clear();
                            snapshotPrices.clear();
                            for (final e in existingEntregas) {
                              if (e.entregado > 0)
                                productQuantities[e.productoId] = e.entregado;
                              if (e.devuelto > 0)
                                productDevueltos[e.productoId] = e.devuelto;
                              // P2.2: capture historical snapshot for display.
                              if (e.precioUnitario > 0)
                                snapshotPrices[e.productoId] = e.precioUnitario;
                            }
                            if (existingPago != null) {
                              paymentMethod = existingPago.metodoPago;
                              montoController.text = existingPago.monto > 0
                                  ? existingPago.monto.toStringAsFixed(0)
                                  : '';
                            } else {
                              paymentMethod = 'efectivo';
                              montoController.text = '';
                            }
                            setDialogState(() {});
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: tokens.cardBorder),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: tokens.primaryBlue,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                                  style: TextStyle(
                                    color: tokens.text,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                _allDayNames[diaSemana.clamp(0, 6)],
                                style: TextStyle(
                                  color: tokens.textSub,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Estado',
                        style: TextStyle(
                          color: tokens.textSub,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _histEstadoChip(
                              'Listo',
                              'listo',
                              tokens.success,
                              estado,
                              (v) => setDialogState(() => estado = v),
                            ),
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: _histEstadoChip(
                              'No compró',
                              'no_compro',
                              tokens.danger,
                              estado,
                              (v) => setDialogState(() => estado = v),
                            ),
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: _histEstadoChip(
                              'Ausente',
                              'ausente',
                              tokens.warn,
                              estado,
                              (v) => setDialogState(() => estado = v),
                            ),
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: _histEstadoChip(
                              'Saltado',
                              'saltado',
                              tokens.primaryBlue,
                              estado,
                              (v) => setDialogState(() => estado = v),
                            ),
                          ),
                        ],
                      ),
                      if (estado == 'listo') ...[
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                'PRODUCTOS',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Text(
                                'COMPRADO',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              flex: 5,
                              child: Text(
                                'DEVUELTO',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        ...allProducts.map((product) {
                          final qty = productQuantities[product.id] ?? 0;
                          final dev = productDevueltos[product.id] ?? 0;
                          void syncMonto(void Function() change) {
                            final oldTotal = calcTotal();
                            final currentMonto =
                                parseArgNumber(montoController.text) ?? 0.0;
                            setDialogState(change);
                            if (paymentMethod != 'no_pago' &&
                                (currentMonto == oldTotal ||
                                    montoController.text.isEmpty)) {
                              montoController.text = calcTotal()
                                  .toStringAsFixed(0);
                            }
                          }

                          return Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    _shortenProductName(product.nombre),
                                    style: TextStyle(
                                      color: tokens.text,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: _buildQtyControl(
                                    qty,
                                    onMinus: () {
                                      if (qty > 0)
                                        syncMonto(
                                          () => productQuantities[product.id] =
                                              qty - 1,
                                        );
                                    },
                                    onPlus: () {
                                      syncMonto(
                                        () => productQuantities[product.id] =
                                            qty + 1,
                                      );
                                    },
                                    onDirectInput: (v) {
                                      syncMonto(
                                        () => productQuantities[product.id] = v,
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  flex: 5,
                                  child: _buildQtyControl(
                                    dev,
                                    onMinus: () {
                                      if (dev > 0)
                                        setDialogState(
                                          () => productDevueltos[product.id] =
                                              dev - 1,
                                        );
                                    },
                                    onPlus: () {
                                      setDialogState(
                                        () => productDevueltos[product.id] =
                                            dev + 1,
                                      );
                                    },
                                    onDirectInput: (v) {
                                      setDialogState(
                                        () => productDevueltos[product.id] = v,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Total: ',
                              style: TextStyle(
                                color: tokens.textSub,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '\$${calcTotal().toStringAsFixed(0)}',
                              style: TextStyle(
                                color: tokens.primaryBlue,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ], // end if (estado == 'listo')
                      SizedBox(height: 12),
                      Text(
                        'Pago',
                        style: TextStyle(
                          color: tokens.textSub,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _histPayChip(
                              'Efectivo',
                              'efectivo',
                              paymentMethod,
                              (v) => setDialogState(() => paymentMethod = v),
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: _histPayChip(
                              'Transfer.',
                              'transferencia',
                              paymentMethod,
                              (v) => setDialogState(() => paymentMethod = v),
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: _histPayChip(
                              'No pagó',
                              'no_pago',
                              paymentMethod,
                              (v) => setDialogState(() => paymentMethod = v),
                            ),
                          ),
                        ],
                      ),
                      if (paymentMethod != 'no_pago') ...[
                        SizedBox(height: 12),
                        TextField(
                          controller: montoController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          style: TextStyle(color: tokens.text, fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Monto pagado',
                            labelStyle: TextStyle(color: tokens.textSub),
                            prefixText: '\$ ',
                            prefixStyle: TextStyle(color: tokens.textSub),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: tokens.cardBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: tokens.primaryBlue),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: tokens.textSub),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final semana = argentinaWeekString(at: selectedDate);
                    final dia = diaSemana;
                    final repartoId = widget.repartoId;

                    // P3.1: refuse to overwrite an existing historial entry.
                    // If a sodero already has a record for this date, they
                    // must edit the existing entry — never silently overwrite
                    // through the Agregar dialog.
                    final existingEntregas = await _db.getEntregasForClient(
                      cliente.id,
                      repartoId,
                      semana,
                      dia,
                    );
                    final existingPago = await _db.getPago(
                      cliente.id,
                      repartoId,
                      semana,
                      dia,
                    );
                    final hasExisting =
                        existingEntregas.any(
                          (e) => e.entregado > 0 || e.devuelto > 0,
                        ) ||
                        existingPago != null;
                    if (hasExisting) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Ya hay una entrada para esta fecha. Editala desde el historial existente.',
                          ),
                          backgroundColor: tokens.danger,
                          duration: Duration(seconds: 3),
                        ),
                      );
                      return;
                    }

                    SyncService.instance.beginLocalWrites();
                    try {
                      if (estado == 'listo') {
                        for (final entry in productQuantities.entries) {
                          final entregado = entry.value;
                          final devuelto = productDevueltos[entry.key] ?? 0;
                          if (entregado > 0 || devuelto > 0) {
                            // P2.2: stamp with the proper sale price. setEntrega's
                            // P1.2 CASE preserves any existing nonzero snapshot,
                            // so this only matters for new rows — but never use
                            // product.precio (factory cost).
                            final snapshot = snapshotPrices[entry.key] ?? 0.0;
                            final precio = snapshot > 0
                                ? snapshot
                                : (effectiveSalePrices[entry.key] ?? 0.0);
                            await _db.setEntrega(
                              cliente.id,
                              repartoId,
                              entry.key,
                              semana,
                              dia,
                              entregado,
                              devuelto,
                              precioUnitario: precio,
                            );
                          }
                        }
                      }

                      // Save pago (payment or status marker)
                      if (estado != 'listo') {
                        final monto = paymentMethod != 'no_pago'
                            ? (parseArgNumber(montoController.text) ?? 0.0)
                            : 0.0;
                        await _db.setPago(
                          cliente.id,
                          repartoId,
                          semana,
                          dia,
                          estado,
                          monto,
                        );
                      } else {
                        final total = calcTotal();
                        if (paymentMethod == 'no_pago') {
                          await _db.setPago(
                            cliente.id,
                            repartoId,
                            semana,
                            dia,
                            'no_pago',
                            total,
                          );
                        } else {
                          final monto =
                              parseArgNumber(montoController.text) ?? total;
                          await _db.setPago(
                            cliente.id,
                            repartoId,
                            semana,
                            dia,
                            paymentMethod,
                            monto,
                          );
                        }
                      }

                      // P1.1: setEntrega/setPago each ran an atomic recalc
                      // inside their own transaction. Removed the buggy
                      // `cuenta_corriente = totalPaid` override that ran here.
                    } finally {
                      SyncService.instance.endLocalWrites();
                    }
                    // Refresh parent cliente list so Deudor display catches up.
                    await _loadData();

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    await onSaved();
                  },
                  child: Text(
                    'Guardar',
                    style: TextStyle(color: tokens.primaryBlue),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _histPayChip(
    String label,
    String value,
    String current,
    void Function(String) onSelect,
  ) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? tokens.primaryBlue.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? tokens.primaryBlue : tokens.cardBorder,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? tokens.primaryBlue : tokens.textMuted,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _histEstadoChip(
    String label,
    String value,
    Color color,
    String current,
    void Function(String) onSelect,
  ) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : tokens.cardBorder),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: selected ? color : tokens.textMuted,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQtyControl(
    int value, {
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    ValueChanged<int>? onDirectInput,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onMinus,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: tokens.primaryBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: tokens.primaryBlue.withValues(alpha: 0.4),
                ),
              ),
              child: Center(
                child: Text(
                  '-',
                  style: TextStyle(
                    color: tokens.primaryBlue,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onDirectInput != null
                ? () async {
                    final result = await _showQtyInputDialog(value);
                    if (result != null) onDirectInput(result);
                  }
                : null,
            child: SizedBox(
              width: 30,
              height: 30,
              child: Center(
                child: Text(
                  '$value',
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onPlus,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: tokens.primaryBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: tokens.primaryBlue.withValues(alpha: 0.4),
                ),
              ),
              child: Center(
                child: Text(
                  '+',
                  style: TextStyle(
                    color: tokens.primaryBlue,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<int?> _showQtyInputDialog(int currentValue) async {
    final controller = TextEditingController(text: '$currentValue');
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cantidad',
          style: TextStyle(
            color: tokens.text,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            color: tokens.text,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            filled: true,
            fillColor: tokens.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
            child: Text(
              'OK',
              style: TextStyle(
                color: tokens.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HistEntry {
  final String dateLabel;
  final String dayAbbr;
  final int month;
  final int year;
  final List<_HistDelivery> deliveries;
  final double monto;
  final double totalOwed;
  final String? metodoPago;
  final bool noCompro;
  final bool ausente;
  final bool saltado;

  final String semana;
  final int diaSemana;

  const _HistEntry({
    required this.dateLabel,
    required this.dayAbbr,
    required this.month,
    required this.year,
    required this.deliveries,
    required this.monto,
    this.totalOwed = 0,
    this.metodoPago,
    required this.noCompro,
    this.ausente = false,
    this.saltado = false,
    required this.semana,
    required this.diaSemana,
  });

  double get deuda {
    if (noCompro || ausente || saltado || totalOwed <= 0) return 0;
    if (metodoPago == 'no_pago') return totalOwed;
    final diff = totalOwed - monto;
    return diff > 0 ? diff : 0;
  }
}

class _HistDelivery {
  final int productoId;
  final String productName;
  final int entregado;
  final int devuelto;
  final int? packSize;
  final double precioUnitario;

  const _HistDelivery({
    required this.productoId,
    required this.productName,
    required this.entregado,
    required this.devuelto,
    this.packSize,
    this.precioUnitario = 0.0,
  });
}
