import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../demo/demo_mode.dart';
import '../utils/argentina_time.dart';
import '../utils/app_tokens.dart';
import '../utils/pack_format.dart';
import '../utils/sueldo_formulas.dart';
import '../widgets/sync_indicator.dart';
import '../widgets/onboarding/tutorial_controller.dart';
import '../widgets/onboarding/guided_tutorial_overlay.dart';

class CierreScreen extends StatefulWidget {
  final int repartoId;
  final String repartoNombre;
  final Duration duration;
  final double efectivo;
  final double transferencia;
  final double cuentaCorriente;
  final List<Producto> allProducts;
  final Map<int, int> carga;
  final Map<int, int> remanente;
  final Map<int, int> totalEntregado;
  final Map<int, int> totalDevuelto;
  final Map<int, int>? productPackSizes;
  final String semana;
  final int diaSemana;
  final Future<void> Function() onFinalize;
  final int resumenId;
  final List<Map<String, dynamic>> existingGastos;

  const CierreScreen({
    super.key,
    required this.repartoId,
    required this.repartoNombre,
    required this.duration,
    required this.efectivo,
    required this.transferencia,
    required this.cuentaCorriente,
    required this.allProducts,
    required this.carga,
    this.remanente = const {},
    required this.totalEntregado,
    required this.totalDevuelto,
    this.productPackSizes,
    required this.semana,
    required this.diaSemana,
    required this.onFinalize,
    required this.resumenId,
    this.existingGastos = const [],
  });

  @override
  State<CierreScreen> createState() => _CierreScreenState();
}

class _CierreScreenState extends State<CierreScreen> {
  AppTokens get tokens => AppTokens.of(context);

  static const List<String> _dayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  final _gastoDescController = TextEditingController();
  final _gastoMontoController = TextEditingController();
  late final List<Map<String, dynamic>> _gastos;
  late final DateTime _recorridoEndAt;
  late DateTime _recorridoStartAt;
  // Raw UTC-epoch millis kept alongside the display DateTimes. We persist
  // these (not the local-converted DateTime) to resumenes.start_millis /
  // end_millis so historial detail can reconstruct the clock times
  // later. `_recorridoStartMillis` is the original `startMillis` stored
  // in active_recorridos_json — captured untransformed.
  int? _recorridoStartMillis;
  late final int _recorridoEndMillis;
  bool _cargaGastoExpanded = false;

  final GlobalKey _kCierreSueldo = GlobalKey();
  final GlobalKey _kCierreCaja = GlobalKey();
  final GlobalKey _kCierreProductos = GlobalKey();
  final GlobalKey _kCierreGastos = GlobalKey();
  final GlobalKey _kCierreFinalizar = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => TutorialController.instance.onCierreOpened(),
    );
    _gastos = List<Map<String, dynamic>>.from(
      widget.existingGastos.map((g) => Map<String, dynamic>.from(g)),
    );
    _recorridoEndAt = argentinaTime();
    _recorridoEndMillis = DateTime.now().millisecondsSinceEpoch;
    _recorridoStartAt = _recorridoEndAt.subtract(widget.duration);
    // Fallback start millis = end - duration. Replaced by the raw value
    // from active_recorridos_json once _loadRecorridoStart resolves.
    _recorridoStartMillis =
        _recorridoEndMillis - widget.duration.inMilliseconds;
    _loadRecorridoStart();
  }

  Future<void> _loadRecorridoStart() async {
    final active = await AppDatabase.instance.getActiveRecorridos();
    for (final entry in active) {
      if (entry['repartoId'] != widget.repartoId) continue;
      final startMillis = entry['startMillis'] as int?;
      if (startMillis == null) return;
      final start = DateTime.fromMillisecondsSinceEpoch(
        startMillis,
      ).toUtc().subtract(const Duration(hours: 3));
      if (!mounted) return;
      setState(() {
        _recorridoStartAt = start;
        _recorridoStartMillis = startMillis;
      });
      return;
    }
  }

  double get _totalGastos {
    double total = 0;
    for (final g in _gastos) {
      total += (g['monto'] as num).toDouble();
    }
    return total;
  }

  double get _sueldoBruto => computeSueldo(
    efectivo: widget.efectivo,
    transferencia: widget.transferencia,
    cuentaCorriente: widget.cuentaCorriente,
    gastos: _totalGastos,
  ).bruto;

  double get _sueldoNeto => computeSueldo(
    efectivo: widget.efectivo,
    transferencia: widget.transferencia,
    cuentaCorriente: widget.cuentaCorriente,
    gastos: _totalGastos,
  ).neto;

  void _addGasto() {
    if (!kDemoAllowLiveFlow && blockDemoAction(context)) return;
    final desc = _gastoDescController.text.trim();
    final monto = double.tryParse(_gastoMontoController.text) ?? 0;
    if (desc.isEmpty || monto <= 0) return;
    setState(() {
      _gastos.add({'descripcion': desc, 'monto': monto});
      _gastoDescController.clear();
      _gastoMontoController.clear();
    });
  }

  void _removeGasto(int index) async {
    if (!kDemoAllowLiveFlow && blockDemoAction(context)) return;
    final g = _gastos[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface2,
        title: Text(
          'Eliminar gasto',
          style: TextStyle(color: tokens.text, fontSize: 16),
        ),
        content: Text(
          '¿Eliminar "${g['descripcion']}" (\$${(g['monto'] as num).toDouble().toStringAsFixed(0)})?',
          style: TextStyle(color: tokens.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: tokens.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', style: TextStyle(color: tokens.danger)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      if (!mounted) return;
      setState(() => _gastos.removeAt(index));
    }
  }

  Future<void> _saveResumen() async {
    if (!kDemoAllowLiveFlow && blockDemoAction(context)) return;
    final db = AppDatabase.instance;

    // Build products JSON
    final productsList = widget.allProducts
        .where((p) {
          final sal = widget.carga[p.id] ?? 0;
          final ret = widget.remanente[p.id] ?? 0;
          final rec = widget.totalEntregado[p.id] ?? 0;
          final per = widget.totalDevuelto[p.id] ?? 0;
          return sal > 0 || ret > 0 || rec > 0 || per > 0;
        })
        .map(
          (p) => {
            'nombre': p.nombre,
            'sal': widget.carga[p.id] ?? 0,
            'ret': widget.remanente[p.id] ?? 0,
            'rec': widget.totalEntregado[p.id] ?? 0,
            'per': widget.totalDevuelto[p.id] ?? 0,
            'pack_size': widget.productPackSizes?[p.id],
          },
        )
        .toList();

    await db.updateResumenFinancials(
      resumenId: widget.resumenId,
      duracionSegundos: widget.duration.inSeconds,
      efectivo: widget.efectivo,
      transferencia: widget.transferencia,
      cuentaCorriente: widget.cuentaCorriente,
      gastos: _totalGastos,
      sueldoBruto: _sueldoBruto,
      sueldoNeto: _sueldoNeto,
      productosJson: jsonEncode(productsList),
      gastosJson: jsonEncode(_gastos),
      startMillis: _recorridoStartMillis,
      endMillis: _recorridoEndMillis,
    );

    await widget.onFinalize();
    TutorialController.instance.onResumenSaved();
    if (mounted) Navigator.pop(context);
  }

  String _formatMoney(double amount) {
    final formatted = NumberFormat(
      '#,###',
      'es_AR',
    ).format(amount.abs().round());
    if (amount < 0) return '- \$$formatted';
    return '\$$formatted';
  }

  // ignore: unused_element
  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _gastoDescController.dispose();
    _gastoMontoController.dispose();
    super.dispose();
  }

  Widget _wrapGuided(Widget child) => Stack(
    children: [
      child,
      GuidedTutorialOverlay(screen: GuidedScreen.cierre, views: _guidedViews()),
    ],
  );

  Map<GuidedStep, GuidedStepView> _guidedViews() => {
    GuidedStep.cierreSueldo: GuidedStepView(
      targetKey: _kCierreSueldo,
      title: 'Tu sueldo del día',
      body: 'Acá ves cuánto ganaste: sueldo neto, bruto, gastos y duración.',
    ),
    GuidedStep.cierreCaja: GuidedStepView(
      targetKey: _kCierreCaja,
      title: 'Balance de caja',
      body:
          'Lo que cobraste en efectivo, transferencia y lo que quedó en cuenta corriente.',
    ),
    GuidedStep.cierreProductos: GuidedStepView(
      targetKey: _kCierreProductos,
      title: 'Balance de productos',
      body:
          'Lo que saliste a vender vs lo que volvió: te ayuda a ver faltantes.',
    ),
    GuidedStep.cierreGastos: GuidedStepView(
      targetKey: _kCierreGastos,
      title: 'Gastos del día',
      body: 'Podés revisar o editar los gastos del día antes de cerrar.',
    ),
    GuidedStep.cierreFinalizar: GuidedStepView(
      targetKey: _kCierreFinalizar,
      title: 'Guardá tu resumen',
      body:
          'Tocá FINALIZAR JORNADA para guardar. ¡Listo, terminaste tu primer día!',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final now = argentinaTime();
    final dayName = DateFormat('EEEE', 'es_AR').format(now);
    final capitalized = dayName[0].toUpperCase() + dayName.substring(1);
    final dateStr =
        '$capitalized, ${now.day} de ${DateFormat('MMMM', 'es_AR').format(now)}';

    return _wrapGuided(
      PopScope(
        canPop: false,
        child: Scaffold(
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
              automaticallyImplyLeading: false,
              title: Text(
                'Resumen de cierre',
                style: TextStyle(
                  color: tokens.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              centerTitle: true,
              shape: Border(
                bottom: BorderSide(color: tokens.cardBorder, width: 1),
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                SyncIndicator(),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        KeyedSubtree(
                          key: _kCierreSueldo,
                          child: _buildDarkHeroCard(dateStr),
                        ),
                        SizedBox(height: 18),
                        KeyedSubtree(
                          key: _kCierreCaja,
                          child: _buildBalanceCajaCard(),
                        ),
                        SizedBox(height: 18),
                        if (_hasAnyProductData()) ...[
                          KeyedSubtree(
                            key: _kCierreProductos,
                            child: _buildBalanceProductosCard(),
                          ),
                          SizedBox(height: 18),
                        ],
                        KeyedSubtree(
                          key: _kCierreGastos,
                          child: _buildGastosEditCard(),
                        ),
                        SizedBox(height: 24),
                        KeyedSubtree(
                          key: _kCierreFinalizar,
                          child: _buildFinalizarButton(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── New aesthetic helpers ────────────────────────────────────

  bool _hasAnyProductData() {
    for (final p in widget.allProducts) {
      final c = widget.carga[p.id] ?? 0;
      final e = widget.totalEntregado[p.id] ?? 0;
      final r = widget.remanente[p.id] ?? 0;
      final d = widget.totalDevuelto[p.id] ?? 0;
      if (c > 0 || e > 0 || r > 0 || d > 0) return true;
    }
    return false;
  }

  String _formatDurationShort(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '$h : $m';
  }

  String _formatClock(DateTime time) => DateFormat('HH:mm').format(time);

  String _formatDurationText(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours <= 0) return '${minutes}min';
    return '${hours}h ${minutes}min';
  }

  Widget _buildDarkHeroCard(String dateStr) {
    // In dark mode the page bg + card are themselves dark navy — the
    // hero needs to sit ABOVE them, so use a brighter elevated navy.
    final heroBg = tokens.isDark
        ? const Color(0xFF1F2E47)
        : const Color(0xFF0F1B2D);
    final heroSurface2 = tokens.isDark
        ? const Color(0xFF2D3F60)
        : const Color(0xFF1F2E47);
    const heroInk = Colors.white;
    final heroInkSub = Colors.white.withValues(alpha: 0.60);
    final heroInkMuted = Colors.white.withValues(alpha: 0.45);
    final todayWeekday = argentinaTime().weekday - 1;
    final configuredDayName =
        widget.diaSemana >= 0 && widget.diaSemana < _dayNames.length
        ? _dayNames[widget.diaSemana]
        : '';
    final dayMismatch = todayWeekday != widget.diaSemana;

    return Container(
      padding: EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: heroBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: heroSurface2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Por finalizar',
              style: TextStyle(
                color: heroInk,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          SizedBox(height: 18),
          Text(dateStr, style: TextStyle(color: heroInkSub, fontSize: 13)),
          if (dayMismatch) ...[
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFFBBF24), size: 13),
                SizedBox(width: 5),
                Text(
                  'Día configurado: $configuredDayName',
                  style: TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 6),
          Text(
            _formatMoney(_sueldoNeto),
            style: TextStyle(
              color: heroInk,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Sueldo neto del día',
            style: TextStyle(color: heroInkSub, fontSize: 13),
          ),
          SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _heroMetric(
                  label: 'BRUTO',
                  value: _formatMoney(_sueldoBruto),
                  inkMuted: heroInkMuted,
                  ink: heroInk,
                ),
              ),
              Expanded(
                child: _heroMetric(
                  label: 'GASTOS',
                  value: _totalGastos > 0
                      ? '- ${_formatMoney(_totalGastos)}'
                      : _formatMoney(0),
                  inkMuted: heroInkMuted,
                  ink: heroInk,
                ),
              ),
              Expanded(
                child: _heroMetric(
                  label: 'DURACIÓN',
                  value: _formatDurationShort(widget.duration),
                  inkMuted: heroInkMuted,
                  ink: heroInk,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildRecorridoTimesBlock(
            surface: heroSurface2,
            ink: heroInk,
            muted: heroInkMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildRecorridoTimesBlock({
    required Color surface,
    required Color ink,
    required Color muted,
  }) {
    final duration = _recorridoEndAt.difference(_recorridoStartAt);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _heroMetric(
              label: 'INICIO',
              value: _formatClock(_recorridoStartAt),
              inkMuted: muted,
              ink: ink,
            ),
          ),
          Expanded(
            child: _heroMetric(
              label: 'FIN',
              value: _formatClock(_recorridoEndAt),
              inkMuted: muted,
              ink: ink,
            ),
          ),
          Expanded(
            child: _heroMetric(
              label: 'DURACIÓN',
              value: _formatDurationText(duration),
              inkMuted: muted,
              ink: ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMetric({
    required String label,
    required String value,
    required Color inkMuted,
    required Color ink,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: inkMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        SizedBox(height: 5),
        // FittedBox.scaleDown lets long amounts like "$1.234.567" stay
        // fully visible by shrinking the text instead of ellipsizing.
        // Anchored bottom-left so the visual baseline doesn't jump
        // when the digit count changes between cards.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomLeft,
          child: Text(
            value,
            style: TextStyle(
              color: ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  BoxDecoration _whiteCardDeco() => BoxDecoration(
    color: tokens.card,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 1)),
    ],
  );

  Widget _buildBalanceCajaCard() {
    final rows = <_PaymentEntry>[
      _PaymentEntry(
        icon: Icons.payments_outlined,
        iconBg: tokens.success.withValues(alpha: 0.14),
        iconColor: tokens.success,
        label: 'Efectivo',
        amount: widget.efectivo,
      ),
      _PaymentEntry(
        icon: Icons.arrow_forward_rounded,
        iconBg: tokens.primaryBlue.withValues(alpha: 0.12),
        iconColor: tokens.primaryBlue,
        label: 'Transferencia',
        amount: widget.transferencia,
      ),
      _PaymentEntry(
        icon: Icons.receipt_long_outlined,
        iconBg: tokens.warn.withValues(alpha: 0.14),
        iconColor: tokens.warn,
        label: 'Cuenta corriente',
        amount: widget.cuentaCorriente,
      ),
    ];

    return Container(
      decoration: _whiteCardDeco(),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance de caja',
            style: TextStyle(
              color: tokens.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Por medio de pago',
            style: TextStyle(color: tokens.textMuted, fontSize: 12),
          ),
          SizedBox(height: 12),
          Divider(color: tokens.cardBorder, height: 1),
          for (var i = 0; i < rows.length; i++) ...[
            _buildPaymentRow(rows[i]),
            if (i < rows.length - 1)
              Divider(color: tokens.cardBorder, height: 1, indent: 50),
          ],
          SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(_PaymentEntry r) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: r.iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(r.icon, size: 18, color: r.iconColor),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              r.label,
              style: TextStyle(
                color: tokens.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            _formatMoney(r.amount),
            style: TextStyle(
              color: tokens.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceProductosCard() {
    final productos = widget.allProducts.where((p) {
      final c = widget.carga[p.id] ?? 0;
      final e = widget.totalEntregado[p.id] ?? 0;
      final r = widget.remanente[p.id] ?? 0;
      final d = widget.totalDevuelto[p.id] ?? 0;
      return c > 0 || e > 0 || r > 0 || d > 0;
    }).toList();

    return Container(
      decoration: _whiteCardDeco(),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance de productos',
            style: TextStyle(
              color: tokens.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Salida vs retorno · diferencia',
            style: TextStyle(color: tokens.textMuted, fontSize: 12),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(flex: 5, child: Text('PRODUCTO', style: _tblHeader())),
              Expanded(
                flex: 2,
                child: Text(
                  'SAL.',
                  textAlign: TextAlign.right,
                  style: _tblHeader(),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'RET.',
                  textAlign: TextAlign.right,
                  style: _tblHeader(),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'TEÓR.',
                  textAlign: TextAlign.right,
                  style: _tblHeader(),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'REAL',
                  textAlign: TextAlign.right,
                  style: _tblHeader(),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'DIF.',
                  textAlign: TextAlign.right,
                  style: _tblHeader(),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          for (var i = 0; i < productos.length; i++) ...[
            Divider(color: tokens.cardBorder, height: 1),
            _buildProductoRow(productos[i]),
          ],
        ],
      ),
    );
  }

  TextStyle _tblHeader() => TextStyle(
    color: tokens.textMuted,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );

  Widget _buildProductoRow(Producto p) {
    final packSize = widget.productPackSizes?[p.id];
    final salRaw = widget.carga[p.id] ?? 0;
    final retRaw = widget.remanente[p.id] ?? 0;
    final teorRaw = salRaw - retRaw;
    final realRaw = widget.totalEntregado[p.id] ?? 0;
    final dif = realRaw - teorRaw;
    final sal = formatPackQty(salRaw, packSize);
    final ret = formatPackQty(retRaw, packSize);
    final teor = formatPackQty(teorRaw, packSize);
    final real = formatPackQty(realRaw, packSize);
    final difColor = dif > 0
        ? tokens.success
        : (dif < 0 ? tokens.danger : tokens.textMuted);
    final difLabel = formatPackQty(dif, packSize);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              p.nombre,
              style: TextStyle(
                color: tokens.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              sal,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: tokens.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              ret,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              teor,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: tokens.textSub,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              real,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: tokens.success,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              difLabel,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: difColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGastosEditCard() {
    return Container(
      decoration: _whiteCardDeco(),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Gastos del día',
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_totalGastos > 0)
                Text(
                  '- ${_formatMoney(_totalGastos)}',
                  style: TextStyle(
                    color: tokens.danger,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            'Editá antes de finalizar',
            style: TextStyle(color: tokens.textMuted, fontSize: 12),
          ),
          SizedBox(height: 12),
          if (_gastos.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Sin gastos cargados',
                style: TextStyle(color: tokens.textMuted, fontSize: 13),
              ),
            )
          else
            ..._gastos.asMap().entries.map((entry) {
              final i = entry.key;
              final g = entry.value;
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        (g['descripcion'] as String?) ?? '',
                        style: TextStyle(
                          color: tokens.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _formatMoney(((g['monto'] as num?)?.toDouble() ?? 0)),
                      style: TextStyle(
                        color: tokens.danger,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    SizedBox(width: 4),
                    InkWell(
                      onTap: () => _removeGasto(i),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: tokens.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          SizedBox(height: 12),
          Divider(color: tokens.cardBorder, height: 1),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _gastoDescController,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: tokens.text, fontSize: 13),
                  decoration: _flatInputDecoration('Descripción'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _gastoMontoController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: tokens.text, fontSize: 13),
                  decoration: _flatInputDecoration('\$'),
                ),
              ),
              SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _addGasto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Icon(Icons.add, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _flatInputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
    filled: true,
    fillColor: tokens.bg,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: tokens.primaryBlue, width: 1.5),
    ),
  );

  Widget _buildFinalizarButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _saveResumen,
        icon: Icon(Icons.check_circle_outline_rounded, size: 22),
        label: Text(
          'FINALIZAR JORNADA',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildResumenCard(String dateStr) {
    final todayWeekday = argentinaTime().weekday - 1; // 0=Mon, 6=Sun
    final configuredDayName =
        widget.diaSemana >= 0 && widget.diaSemana < _dayNames.length
        ? _dayNames[widget.diaSemana]
        : '';
    final dayMismatch = todayWeekday != widget.diaSemana;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESUMEN',
            style: TextStyle(
              color: tokens.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2),
          Text(
            dateStr,
            style: TextStyle(color: tokens.textMuted, fontSize: 13),
          ),
          if (dayMismatch) ...[
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.info_outline, color: tokens.warn, size: 14),
                SizedBox(width: 5),
                Text(
                  'Día configurado: $configuredDayName',
                  style: TextStyle(
                    color: tokens.warn,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 16),
          _buildResumenRow(
            Icons.payments_outlined,
            'Efectivo recibido',
            widget.efectivo,
            positive: true,
          ),
          SizedBox(height: 12),
          _buildResumenRow(
            Icons.phone_android,
            'Transferencia recibida',
            widget.transferencia,
            positive: true,
          ),
          SizedBox(height: 12),
          _buildResumenRow(
            Icons.account_balance_outlined,
            'Cuenta corriente',
            widget.cuentaCorriente,
            positive: false,
          ),
          SizedBox(height: 12),
          _buildResumenRow(
            Icons.receipt_long_outlined,
            'Gasto del día',
            _totalGastos,
            positive: false,
          ),
          SizedBox(height: 12),
          Divider(color: tokens.cardBorder),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.star_border,
                color: Colors.amber.withValues(alpha: 0.7),
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sueldo bruto',
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                _formatMoney(_sueldoBruto),
                style: TextStyle(
                  color: _sueldoBruto >= 0 ? tokens.success : tokens.danger,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sueldo neto',
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                _formatMoney(_sueldoNeto),
                style: TextStyle(
                  color: _sueldoNeto >= 0 ? tokens.success : tokens.danger,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenRow(
    IconData icon,
    String label,
    double amount, {
    required bool positive,
  }) {
    return Row(
      children: [
        Icon(icon, color: tokens.textSub, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: tokens.textSub, fontSize: 14),
          ),
        ),
        Text(
          positive ? _formatMoney(amount) : '- ${_formatMoney(amount)}',
          style: TextStyle(
            color: positive ? tokens.success : tokens.danger,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildBalanceCard() {
    // Filter to products that have any activity
    final activeProducts = widget.allProducts.where((p) {
      final sal = widget.carga[p.id] ?? 0;
      final ret = widget.remanente[p.id] ?? 0;
      final rec = widget.totalEntregado[p.id] ?? 0;
      return sal > 0 || ret > 0 || rec > 0;
    }).toList();

    int totalRet = 0;
    int totalVentReal = 0;
    for (final p in activeProducts) {
      final ret = widget.remanente[p.id] ?? 0;
      final rec = widget.totalEntregado[p.id] ?? 0;
      totalRet += ret;
      totalVentReal += rec;
    }
    final saldoEnvases = totalVentReal - totalRet;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BALANCE DE PRODUCTOS',
            style: TextStyle(
              color: tokens.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 14),
          // Table header
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'PRODUCTO',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildColHeader('SAL.'),
              _buildColHeader('RET.'),
              _buildColHeader('V. TEÓR.'),
              _buildColHeader('V. REAL'),
              _buildColHeader('DIF.'),
            ],
          ),
          SizedBox(height: 8),
          if (activeProducts.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Sin movimientos de productos',
                style: TextStyle(color: tokens.textMuted, fontSize: 13),
              ),
            )
          else
            ...activeProducts.map((p) {
              final sal = widget.carga[p.id] ?? 0;
              final ret = widget.remanente[p.id] ?? 0;
              final rec = widget.totalEntregado[p.id] ?? 0;
              final teor = sal - ret;
              final dif = rec - teor;
              return _buildProductRow(
                p.nombre,
                sal,
                ret,
                teor,
                rec,
                dif,
                widget.productPackSizes?[p.id],
              );
            }),
          if (activeProducts.isNotEmpty) ...[
            SizedBox(height: 6),
            // VAC. REC. column = empties returned (totalRet from widget.remanente);
            // LLEN. ENT. column = filled delivered (totalVentReal from
            // widget.totalEntregado). The signature is (vacios, llenos, saldo).
            _buildTotalsStrip(totalRet, totalVentReal, saldoEnvases),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalsStrip(int vacios, int llenos, int saldo) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.primaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'CONCEPTO',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildColHeader('VAC. REC.'),
              _buildColHeader('LLEN. ENT.'),
              _buildColHeader('SALDO'),
            ],
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Totales',
                  style: TextStyle(
                    color: tokens.textSub,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildColValue('$vacios u', tokens.primaryBlue),
              _buildColValue('$llenos u', tokens.textSub),
              _buildColValue(
                '${saldo > 0 ? '+' : ''}$saldo u',
                saldo < 0
                    ? tokens.danger
                    : (saldo > 0 ? tokens.success : tokens.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColHeader(String text) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: tokens.textMuted,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProductRow(
    String name,
    int sal,
    int ret,
    int teor,
    int rec,
    int dif,
    int? packSize,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              name,
              style: TextStyle(
                color: tokens.textSub,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _buildColValue(formatPackQty(sal, packSize), tokens.primaryBlue),
          _buildColValue(formatPackQty(ret, packSize), tokens.textMuted),
          _buildColValue(formatPackQty(teor, packSize), tokens.textSub),
          _buildColValue(formatPackQty(rec, packSize), tokens.primaryBlue),
          _buildColValue(
            formatPackQty(dif, packSize),
            dif < 0
                ? tokens.danger
                : (dif > 0 ? tokens.success : tokens.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildColValue(String text, Color color) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildGastosCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GASTOS',
            style: TextStyle(
              color: tokens.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          // Input row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _gastoDescController,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: tokens.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Descripción',
                      hintStyle: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 14,
                      ),
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
              ),
              SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _gastoMontoController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: tokens.text, fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 8, right: 4),
                        child: Text(
                          '\$',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      prefixIconConstraints: BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
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
              ),
              SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: _addGasto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.primaryBlue,
                    foregroundColor: tokens.text,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    elevation: 0,
                  ),
                  child: Text(
                    'Agregar',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          if (_gastos.isNotEmpty) ...[
            SizedBox(height: 12),
            // Carga group (collapsible)
            () {
              final productGastos = _gastos
                  .where((g) => g['type'] == 'producto')
                  .toList();
              final manualGastos = _gastos
                  .where((g) => g['type'] != 'producto')
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (productGastos.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => setState(
                        () => _cargaGastoExpanded = !_cargaGastoExpanded,
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              color: tokens.textMuted,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Carga',
                                style: TextStyle(
                                  color: tokens.textSub,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '- ${_formatMoney(productGastos.fold<double>(0, (s, g) => s + (g['monto'] as num).toDouble()))}',
                              style: TextStyle(
                                color: tokens.danger,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              _cargaGastoExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: tokens.textMuted,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_cargaGastoExpanded)
                      ...productGastos.map(
                        (g) => Padding(
                          padding: EdgeInsets.only(left: 24, bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  g['descripcion'] as String,
                                  style: TextStyle(
                                    color: tokens.textSub,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                '- ${_formatMoney((g['monto'] as num).toDouble())}',
                                style: TextStyle(
                                  color: tokens.danger.withValues(alpha: 0.7),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  // Manual gastos
                  ...manualGastos.map((g) {
                    final i = _gastos.indexOf(g);
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              g['descripcion'] as String,
                              style: TextStyle(
                                color: tokens.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '- ${_formatMoney((g['monto'] as num).toDouble())}',
                            style: TextStyle(
                              color: tokens.danger,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _removeGasto(i),
                            child: Icon(
                              Icons.close,
                              color: tokens.textMuted,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            }(),
          ],
        ],
      ),
    );
  }
}

class _PaymentEntry {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final double amount;
  const _PaymentEntry({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.amount,
  });
}
