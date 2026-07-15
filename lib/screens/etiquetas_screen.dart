import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/app_database.dart';
import '../demo/demo_mode.dart';
import '../utils/app_tokens.dart';
import '../widgets/sync_indicator.dart';

class EtiquetasScreen extends StatefulWidget {
  final int repartoId;
  final String repartoNombre;

  const EtiquetasScreen({
    super.key,
    required this.repartoId,
    required this.repartoNombre,
  });

  @override
  State<EtiquetasScreen> createState() => _EtiquetasScreenState();
}

class _EtiquetasScreenState extends State<EtiquetasScreen> {
  AppTokens get tokens => AppTokens.of(context);

  static const List<Color> _tagColors = [
    Color(0xFF1292D3),
    Color(0xFF2ECC71),
    Color(0xFFE67E22),
    Color(0xFF9B59B6),
    Color(0xFFE74C3C),
    Color(0xFF1ABC9C),
    Color(0xFFF1C40F),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
    Color(0xFF8BC34A),
    Color(0xFFFF5722),
    Color(0xFF3F51B5),
  ];

  // Custom color overrides loaded from DB
  Map<String, Color> _customColors = {};

  Color _colorForEtiqueta(String etiqueta) {
    final key = etiqueta.toLowerCase().trim();
    if (_customColors.containsKey(key)) return _customColors[key]!;
    final hash = key.hashCode;
    return _tagColors[hash.abs() % _tagColors.length];
  }

  static List<String> _parseEtiquetas(String etiqueta) {
    if (etiqueta.isEmpty) return [];
    return etiqueta
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  final _db = AppDatabase.instance;

  Map<String, int> _tagCounts = {};
  List<String> _allTags = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final clients = await _db.getClientesForReparto(widget.repartoId);
    final counts = <String, int>{};
    for (final c in clients) {
      for (final tag in _parseEtiquetas(c.etiqueta)) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final customColors = <String, Color>{};
    try {
      final colorEntries = await _db.getEtiquetaColors(widget.repartoId);
      for (final e in colorEntries) {
        customColors[e.nombre.toLowerCase().trim()] = Color(
          int.parse(e.colorHex, radix: 16),
        );
      }
    } catch (_) {}
    final sorted = counts.keys.toList()..sort();
    if (mounted) {
      setState(() {
        _tagCounts = counts;
        _allTags = sorted;
        _customColors = customColors;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: AppBar(
          backgroundColor: tokens.card,
          surfaceTintColor: tokens.card,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: tokens.isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: tokens.text,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'ETIQUETAS',
            style: TextStyle(
              color: tokens.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          centerTitle: false,
          shape: Border(bottom: BorderSide(color: tokens.cardBorder, width: 1)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SyncIndicator(),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (_allTags.isEmpty)
                    _buildEmptyState()
                  else
                    _buildEtiquetasList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEtiquetasList() {
    final isDark = tokens.isDark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? tokens.surface2 : tokens.card,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: tokens.cardBorder, width: 1) : null,
        boxShadow: [
          BoxShadow(
            color: Color(isDark ? 0x33000000 : 0x14000000),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Text(
                  'Tus etiquetas',
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                Spacer(),
                Text(
                  '${_allTags.length} en uso',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < _allTags.length; i++) ...[
            _buildEtiquetaRow(_allTags[i]),
            if (i < _allTags.length - 1)
              Padding(
                padding: EdgeInsets.only(left: 70),
                child: Divider(
                  color: tokens.cardBorder,
                  height: 1,
                  thickness: 1,
                ),
              ),
          ],
          SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildEtiquetaRow(String tag) {
    final color = _colorForEtiqueta(tag);
    final count = _tagCounts[tag] ?? 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openEtiquetaDetail(tag),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Tag icon — tinted bg matching the etiqueta color, soft.
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.label, color: color, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      count == 1
                          ? '1 cliente usando esta etiqueta'
                          : '$count clientes usando esta etiqueta',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tokens.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              // Palette button — rename / change color.
              GestureDetector(
                onTap: () => _showColorPicker(tag),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.palette_outlined,
                    color: tokens.textMuted,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEtiquetaDetail(String tag) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _EtiquetaDetailScreen(
          repartoId: widget.repartoId,
          tag: tag,
          tagColor: _colorForEtiqueta(tag),
        ),
      ),
    );
    // Counts may have changed if the user edited clientes from the detail
    // page (unlikely but cheap to refresh).
    _loadData();
  }

  Widget _buildEmptyState() => Padding(
    padding: EdgeInsets.symmetric(vertical: 60),
    child: Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: tokens.surface2,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.label_off_outlined,
            size: 28,
            color: tokens.textMuted,
          ),
        ),
        SizedBox(height: 14),
        Text(
          'No hay etiquetas',
          style: TextStyle(
            color: tokens.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Agregá etiquetas a tus clientes\npara verlas acá',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.textMuted, fontSize: 13),
        ),
      ],
    ),
  );

  void _showColorPicker(String tag) {
    final currentColor = _colorForEtiqueta(tag);
    final nameCtrl = TextEditingController(text: tag);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
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
                  'Editar "$tag"',
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'NOMBRE',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(color: tokens.text, fontSize: 14),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: tokens.cardBorder,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: tokens.primaryBlue),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (blockDemoAction(context)) return;
                          final newName = nameCtrl.text.trim();
                          if (newName.isEmpty ||
                              newName.toLowerCase() == tag.toLowerCase()) {
                            return;
                          }
                          await _db.renameEtiqueta(
                            widget.repartoId,
                            tag,
                            newName,
                          );
                          await _loadData();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.primaryBlue,
                          foregroundColor: tokens.text,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          elevation: 0,
                        ),
                        child: Text(
                          'Renombrar',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  'COLOR',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _tagColors.map((color) {
                    final isSelected = currentColor == color;
                    return GestureDetector(
                      onTap: () async {
                        if (blockDemoAction(context)) return;
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
                          tag.toLowerCase().trim(),
                          hex,
                        );
                        await _loadData();
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
        );
      },
    );
  }
}

/// Detail page: all clientes assigned to a single etiqueta, filterable by day.
class _EtiquetaDetailScreen extends StatefulWidget {
  final int repartoId;
  final String tag;
  final Color tagColor;
  const _EtiquetaDetailScreen({
    required this.repartoId,
    required this.tag,
    required this.tagColor,
  });

  @override
  State<_EtiquetaDetailScreen> createState() => _EtiquetaDetailScreenState();
}

class _EtiquetaDetailScreenState extends State<_EtiquetaDetailScreen> {
  AppTokens get tokens => AppTokens.of(context);

  static const List<String> _dayNamesShort = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  final _db = AppDatabase.instance;

  List<int> _workDays = [];
  int _selectedDay = -1; // -1 = all days
  List<Cliente> _clientes = [];

  @override
  void initState() {
    super.initState();
    _loadWorkDays();
  }

  Future<void> _loadWorkDays() async {
    final days = await _db.getWorkDays();
    if (mounted) {
      setState(() => _workDays = days);
      _loadClientes();
    }
  }

  Future<void> _loadClientes() async {
    final List<Cliente> all;
    if (_selectedDay == -1) {
      all = await _db.getClientesForReparto(widget.repartoId);
    } else {
      all = await _db.getClientesForRepartoDay(widget.repartoId, _selectedDay);
    }
    final lowered = widget.tag.toLowerCase().trim();
    final filtered = all.where((c) {
      return c.etiqueta
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .contains(lowered);
    }).toList();
    if (mounted) setState(() => _clientes = filtered);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: AppBar(
          backgroundColor: tokens.card,
          surfaceTintColor: tokens.card,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: tokens.isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: tokens.text,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: widget.tagColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.label, size: 13, color: widget.tagColor),
              ),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.tag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          centerTitle: false,
          shape: Border(bottom: BorderSide(color: tokens.cardBorder, width: 1)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SyncIndicator(),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (_workDays.isNotEmpty) _buildDayPillsCard(),
                  if (_workDays.isNotEmpty) SizedBox(height: 16),
                  if (_clientes.isEmpty)
                    _buildEmptyState()
                  else
                    _buildClientesCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayPillsCard() {
    final isDark = tokens.isDark;
    final children = <Widget>[_buildDayPill(label: 'TODOS', day: -1)];
    for (final i in _workDays) {
      children.add(SizedBox(width: 10));
      children.add(
        _buildDayPill(label: _dayNamesShort[i].toUpperCase(), day: i),
      );
    }
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? tokens.surface2 : tokens.card,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: tokens.cardBorder, width: 1) : null,
        boxShadow: [
          BoxShadow(
            color: Color(isDark ? 0x33000000 : 0x14000000),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // Center the pill row when it's narrower than the viewport so it
        // looks balanced (matches the centering pattern used in Carga).
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 60,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildDayPill({required String label, required int day}) {
    final isSelected = _selectedDay == day;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedDay = day);
        _loadClientes();
      },
      child: Container(
        constraints: BoxConstraints(minWidth: 56),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? tokens.primaryBlue : tokens.card,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? null
              : Border.all(color: tokens.cardBorder, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : tokens.text,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildClientesCard() {
    final isDark = tokens.isDark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? tokens.surface2 : tokens.card,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: tokens.cardBorder, width: 1) : null,
        boxShadow: [
          BoxShadow(
            color: Color(isDark ? 0x33000000 : 0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < _clientes.length; i++) ...[
            _buildClientRow(_clientes[i]),
            if (i < _clientes.length - 1)
              Padding(
                padding: EdgeInsets.only(left: 16),
                child: Divider(
                  color: tokens.cardBorder,
                  height: 1,
                  thickness: 1,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildClientRow(Cliente cliente) {
    final frecLabel = cliente.frecuencia.isNotEmpty
        ? cliente.frecuencia[0].toUpperCase() + cliente.frecuencia.substring(1)
        : '';
    final dayLabel =
        cliente.diaSemana >= 0 && cliente.diaSemana < _dayNamesShort.length
        ? _dayNamesShort[cliente.diaSemana]
        : '?';
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cliente.direccion.isNotEmpty
                      ? cliente.direccion
                      : cliente.nombre,
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  cliente.direccion.isNotEmpty && frecLabel.isNotEmpty
                      ? '${cliente.nombre} · $frecLabel'
                      : (cliente.direccion.isNotEmpty
                            ? cliente.nombre
                            : frecLabel),
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.tagColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              dayLabel,
              style: TextStyle(
                color: widget.tagColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Padding(
    padding: EdgeInsets.symmetric(vertical: 60),
    child: Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: tokens.surface2,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.label_off_outlined,
            size: 28,
            color: tokens.textMuted,
          ),
        ),
        SizedBox(height: 14),
        Text(
          'Sin clientes',
          style: TextStyle(
            color: tokens.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 4),
        Text(
          _selectedDay == -1
              ? 'Ningún cliente tiene esta etiqueta'
              : 'Ningún cliente con esta etiqueta\npara este día',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.textMuted, fontSize: 13),
        ),
      ],
    ),
  );
}
