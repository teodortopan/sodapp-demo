import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/app_database.dart';
import '../utils/app_tokens.dart';
import '../utils/pack_format.dart';
import '../widgets/sync_indicator.dart';

class ResumenAnualScreen extends StatefulWidget {
  final int repartoId;
  final String repartoNombre;

  const ResumenAnualScreen({
    super.key,
    required this.repartoId,
    required this.repartoNombre,
  });

  @override
  State<ResumenAnualScreen> createState() => _ResumenAnualScreenState();
}

class _ResumenAnualScreenState extends State<ResumenAnualScreen> {
  AppTokens get tokens => AppTokens.of(context);

  static const List<String> _monthNames = [
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

  final _db = AppDatabase.instance;

  int _selectedYear = DateTime.now().year;
  Set<int> _availableYears = {};
  bool _loading = true;

  // Yearly totals
  double _totalEfectivo = 0;
  double _totalTransferencia = 0;
  double _totalGastos = 0;
  double _totalNeto = 0;
  int _totalRecorridos = 0;
  int _totalDuracion = 0;
  int _totalClientes = 0;
  Map<String, int> _productTotals = {};
  Map<String, int> _productReturns = {};
  Map<String, int> _productPackSizes = {};
  List<_MonthSummary> _monthSummaries = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final resumenes = await _db.getResumenesForReparto(widget.repartoId);
    final entregas = await _db.getAllEntregasForReparto(widget.repartoId);
    final clientes = await _db.getClientesForReparto(widget.repartoId);

    // Find available years
    final years = <int>{};
    for (final r in resumenes) {
      if (r.fecha.isNotEmpty) {
        final y = int.tryParse(r.fecha.split('-').first);
        if (y != null) years.add(y);
      }
    }
    for (final e in entregas) {
      // semana format: "2026-W11"
      final y = int.tryParse(e.semana.split('-').first);
      if (y != null) years.add(y);
    }
    if (years.isEmpty) years.add(DateTime.now().year);

    // Filter resumenes for selected year
    final yearResumenes = resumenes.where((r) {
      if (r.fecha.isEmpty) return false;
      final y = int.tryParse(r.fecha.split('-').first);
      return y == _selectedYear;
    }).toList();

    // Calculate totals from resumenes
    double totalEfectivo = 0;
    double totalTransferencia = 0;
    double totalGastos = 0;
    double totalNeto = 0;
    int totalDuracion = 0;
    final monthlySums = <int, _MonthSummary>{};

    for (final r in yearResumenes) {
      totalEfectivo += r.efectivo;
      totalTransferencia += r.transferencia;
      totalGastos += r.gastos;
      final neto = r.sueldoBruto - r.gastos;
      totalNeto += neto;
      totalDuracion += r.duracionSegundos;

      // Parse month
      final parts = r.fecha.split('-');
      if (parts.length >= 2) {
        final month = int.tryParse(parts[1]) ?? 1;
        final ms = monthlySums.putIfAbsent(
          month,
          () => _MonthSummary(month: month),
        );
        ms.efectivo += r.efectivo;
        ms.transferencia += r.transferencia;
        ms.gastos += r.gastos;
        ms.neto += neto;
        ms.recorridos++;
        ms.duracion += r.duracionSegundos;
      }
    }

    // Calculate product totals from entregas for selected year
    final products = await _db.getAllProducts(widget.repartoId);
    final productMap = {for (final p in products) p.id: p.nombre};
    final packSizes = await _db.getProductoPackSizesForReparto(
      widget.repartoId,
    );
    final productPackSizes = <String, int>{};
    for (final entry in productMap.entries) {
      final size = packSizes[entry.key];
      if (size != null) productPackSizes[entry.value] = size;
    }
    final productTotals = <String, int>{};
    final productReturns = <String, int>{};

    for (final e in entregas) {
      final y = int.tryParse(e.semana.split('-').first);
      if (y != _selectedYear) continue;
      final name = productMap[e.productoId] ?? '?';
      if (e.entregado > 0) {
        productTotals[name] = (productTotals[name] ?? 0) + e.entregado;
      }
      if (e.devuelto > 0) {
        productReturns[name] = (productReturns[name] ?? 0) + e.devuelto;
      }
    }

    // Sort monthly summaries
    final monthList = monthlySums.values.toList()
      ..sort((a, b) => a.month.compareTo(b.month));

    if (mounted) {
      setState(() {
        _availableYears = years;
        _totalEfectivo = totalEfectivo;
        _totalTransferencia = totalTransferencia;
        _totalGastos = totalGastos;
        _totalNeto = totalNeto;
        _totalRecorridos = yearResumenes.length;
        _totalDuracion = totalDuracion;
        _totalClientes = clientes.length;
        _productTotals = productTotals;
        _productReturns = productReturns;
        _productPackSizes = productPackSizes;
        _monthSummaries = monthList;
        _loading = false;
      });
    }
  }

  String _formatMoney(double amount) {
    final abs = amount.abs().round();
    final formatted = abs.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    if (amount < 0) return '-\$$formatted';
    return '\$$formatted';
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
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
            'RESUMEN ANUAL',
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
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: tokens.primaryBlue,
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 28),
                      children: [
                        _buildAnualHero(),
                        SizedBox(height: 18),
                        if (_availableYears.isNotEmpty) ...[
                          _buildYearPills(),
                          SizedBox(height: 18),
                        ],
                        _sectionLabel('FINANCIERO'),
                        SizedBox(height: 8),
                        _buildAnualFinancialCard(),
                        SizedBox(height: 22),
                        _sectionLabel('ACTIVIDAD'),
                        SizedBox(height: 8),
                        _buildAnualActivityCard(),
                        if (_productTotals.isNotEmpty) ...[
                          SizedBox(height: 22),
                          _sectionLabel('PRODUCTOS'),
                          SizedBox(height: 8),
                          _buildAnualProductsCard(),
                        ],
                        if (_monthSummaries.isNotEmpty) ...[
                          SizedBox(height: 22),
                          _sectionLabel('POR MES'),
                          SizedBox(height: 8),
                          for (final ms in _monthSummaries)
                            _buildAnualMonthRow(ms),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── New aesthetic helpers ────────────────────────────────────

  BoxDecoration _whiteCardDeco() => BoxDecoration(
    color: tokens.card,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 1)),
    ],
  );

  Widget _sectionLabel(String text) => Padding(
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

  Widget _buildAnualHero() {
    final heroBg = tokens.isDark
        ? const Color(0xFF1F2E47)
        : const Color(0xFF0F1B2D);
    const heroInk = Colors.white;
    final heroInkSub = Colors.white.withValues(alpha: 0.60);
    final heroInkMuted = Colors.white.withValues(alpha: 0.45);
    final mesesConData = _monthSummaries.length;
    final promedioMes = mesesConData > 0 ? _totalNeto / mesesConData : 0.0;
    _MonthSummary? mejorMes;
    for (final ms in _monthSummaries) {
      if (mejorMes == null || ms.neto > mejorMes.neto) mejorMes = ms;
    }
    final mejorMesLabel = mejorMes != null
        ? _monthNames[mejorMes.month - 1]
        : '—';

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
          Text(
            'AÑO $_selectedYear',
            style: TextStyle(
              color: heroInkMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          SizedBox(height: 10),
          Text(
            _formatMoney(_totalNeto),
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
            'Neto acumulado · $_totalRecorridos jornada${_totalRecorridos == 1 ? '' : 's'}',
            style: TextStyle(color: heroInkSub, fontSize: 13),
          ),
          SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _anualHeroMetric(
                  'PROMEDIO/MES',
                  _formatMoney(promedioMes),
                  heroInkMuted,
                  heroInk,
                ),
              ),
              Expanded(
                child: _anualHeroMetric(
                  'MEJOR MES',
                  mejorMesLabel,
                  heroInkMuted,
                  heroInk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _anualHeroMetric(
    String label,
    String value,
    Color inkMuted,
    Color ink,
  ) => Column(
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
      Text(
        value,
        style: TextStyle(
          color: ink,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );

  Widget _buildYearPills() {
    final years = _availableYears.toList()..sort((a, b) => b.compareTo(a));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < years.length; i++) ...[
            _buildYearPill(years[i]),
            if (i < years.length - 1) SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildYearPill(int year) {
    final isSelected = _selectedYear == year;
    return GestureDetector(
      onTap: () {
        if (isSelected) return;
        setState(() => _selectedYear = year);
        _loadData();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.primaryBlue.withValues(alpha: 0.10)
              : tokens.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? tokens.primaryBlue : tokens.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          '$year',
          style: TextStyle(
            color: isSelected ? tokens.primaryBlue : tokens.text,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  Widget _buildAnualFinancialCard() {
    final totalRecaudado = _totalEfectivo + _totalTransferencia;
    final rows = <_FinRow>[
      _FinRow(
        icon: Icons.payments_outlined,
        iconBg: tokens.success.withValues(alpha: 0.14),
        iconColor: tokens.success,
        label: 'Efectivo',
        amount: _totalEfectivo,
      ),
      _FinRow(
        icon: Icons.arrow_forward_rounded,
        iconBg: tokens.primaryBlue.withValues(alpha: 0.12),
        iconColor: tokens.primaryBlue,
        label: 'Transferencia',
        amount: _totalTransferencia,
      ),
      _FinRow(
        icon: Icons.receipt_long_outlined,
        iconBg: tokens.warn.withValues(alpha: 0.14),
        iconColor: tokens.warn,
        label: 'Gastos',
        amount: _totalGastos,
        negative: true,
      ),
    ];
    return Container(
      decoration: _whiteCardDeco(),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total recaudado',
            style: TextStyle(color: tokens.textMuted, fontSize: 12),
          ),
          SizedBox(height: 4),
          Text(
            _formatMoney(totalRecaudado),
            style: TextStyle(
              color: tokens.text,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 14),
          Divider(color: tokens.cardBorder, height: 1),
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: rows[i].iconBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      rows[i].icon,
                      size: 16,
                      color: rows[i].iconColor,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rows[i].label,
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    rows[i].negative
                        ? '- ${_formatMoney(rows[i].amount)}'
                        : _formatMoney(rows[i].amount),
                    style: TextStyle(
                      color: rows[i].negative ? tokens.danger : tokens.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (i < rows.length - 1)
              Divider(color: tokens.cardBorder, height: 1, indent: 44),
          ],
          Divider(color: tokens.cardBorder, height: 1),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Neto',
                    style: TextStyle(
                      color: tokens.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _formatMoney(_totalNeto),
                  style: TextStyle(
                    color: _totalNeto >= 0 ? tokens.success : tokens.danger,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnualActivityCard() {
    return Container(
      decoration: _whiteCardDeco(),
      padding: EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _anualActivityCell(
              Icons.route_outlined,
              '$_totalRecorridos',
              'Recorridos',
            ),
          ),
          Container(width: 1, height: 44, color: tokens.cardBorder),
          Expanded(
            child: _anualActivityCell(
              Icons.timer_outlined,
              _formatDuration(_totalDuracion),
              'Tiempo total',
            ),
          ),
          Container(width: 1, height: 44, color: tokens.cardBorder),
          Expanded(
            child: _anualActivityCell(
              Icons.people_outline,
              '$_totalClientes',
              'Clientes',
            ),
          ),
        ],
      ),
    );
  }

  Widget _anualActivityCell(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: tokens.primaryBlue),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: tokens.text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAnualProductsCard() {
    final sorted = _productTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      decoration: _whiteCardDeco(),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        children: [
          for (var i = 0; i < sorted.length; i++) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sorted[i].key,
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        size: 12,
                        color: tokens.success,
                      ),
                      SizedBox(width: 2),
                      Text(
                        formatPackQty(
                          sorted[i].value,
                          _productPackSizes[sorted[i].key],
                        ),
                        style: TextStyle(
                          color: tokens.success,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      if ((_productReturns[sorted[i].key] ?? 0) > 0) ...[
                        SizedBox(width: 12),
                        Icon(
                          Icons.arrow_downward_rounded,
                          size: 12,
                          color: tokens.danger,
                        ),
                        SizedBox(width: 2),
                        Text(
                          formatPackQty(
                            _productReturns[sorted[i].key] ?? 0,
                            _productPackSizes[sorted[i].key],
                          ),
                          style: TextStyle(
                            color: tokens.danger,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (i < sorted.length - 1)
              Divider(color: tokens.cardBorder, height: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildAnualMonthRow(_MonthSummary ms) {
    final monthName = _monthNames[ms.month - 1];
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: _whiteCardDeco(),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: tokens.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  monthName.substring(0, 3).toUpperCase(),
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    monthName,
                    style: TextStyle(
                      color: tokens.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${ms.recorridos} jornada${ms.recorridos == 1 ? '' : 's'} · ${_formatDuration(ms.duracion)}',
                    style: TextStyle(color: tokens.textSub, fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatMoney(ms.neto),
                  style: TextStyle(
                    color: ms.neto >= 0 ? tokens.text : tokens.danger,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'NETO',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Legacy helpers — superseded by the new design above ─────────

  // ignore: unused_element
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: tokens.textSub,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFinancialCard() {
    final totalRecaudado = _totalEfectivo + _totalTransferencia;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total recaudado
          Text(
            'Total recaudado',
            style: TextStyle(color: tokens.textSub, fontSize: 12),
          ),
          SizedBox(height: 4),
          Text(
            _formatMoney(totalRecaudado),
            style: TextStyle(
              color: tokens.text,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          // Breakdown row
          Row(
            children: [
              _buildFinancialItem('Efectivo', _totalEfectivo, tokens.success),
              SizedBox(width: 16),
              _buildFinancialItem(
                'Transferencia',
                _totalTransferencia,
                tokens.primaryBlue,
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _buildFinancialItem('Gastos', _totalGastos, tokens.danger),
              SizedBox(width: 16),
              _buildFinancialItem(
                'Neto',
                _totalNeto,
                _totalNeto >= 0 ? tokens.success : tokens.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialItem(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: tokens.textMuted, fontSize: 11)),
          SizedBox(height: 2),
          Text(
            _formatMoney(amount),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildActivityCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Row(
        children: [
          _buildActivityItem(Icons.route, '$_totalRecorridos', 'Recorridos'),
          _buildActivityDivider(),
          _buildActivityItem(
            Icons.timer_outlined,
            _formatDuration(_totalDuracion),
            'Tiempo total',
          ),
          _buildActivityDivider(),
          _buildActivityItem(
            Icons.people_outline,
            '$_totalClientes',
            'Clientes',
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: tokens.primaryBlue, size: 22),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: tokens.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2),
          Text(label, style: TextStyle(color: tokens.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildActivityDivider() {
    return Container(
      width: 1,
      height: 40,
      color: tokens.text.withValues(alpha: 0.1),
    );
  }

  // ignore: unused_element
  Widget _buildProductsCard() {
    // Sort by quantity descending
    final sorted = _productTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        children: [
          for (int i = 0; i < sorted.length; i++) ...[
            if (i > 0) Divider(color: tokens.cardBorder, height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    sorted[i].key,
                    style: TextStyle(
                      color: tokens.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Entregados
                Icon(Icons.arrow_upward, size: 12, color: tokens.success),
                SizedBox(width: 2),
                Text(
                  formatPackQty(
                    sorted[i].value,
                    _productPackSizes[sorted[i].key],
                  ),
                  style: TextStyle(
                    color: tokens.success,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // Devueltos
                if ((_productReturns[sorted[i].key] ?? 0) > 0) ...[
                  SizedBox(width: 12),
                  Icon(Icons.arrow_downward, size: 12, color: tokens.danger),
                  SizedBox(width: 2),
                  Text(
                    formatPackQty(
                      _productReturns[sorted[i].key] ?? 0,
                      _productPackSizes[sorted[i].key],
                    ),
                    style: TextStyle(
                      color: tokens.danger,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildMonthCard(_MonthSummary ms) {
    final total = ms.efectivo + ms.transferencia;
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    _monthNames[ms.month - 1],
                    style: TextStyle(
                      color: tokens.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  _formatMoney(total),
                  style: TextStyle(
                    color: tokens.success,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                Text(
                  '${ms.recorridos} recorridos',
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
                Text(
                  'Efec. ${_formatMoney(ms.efectivo)}',
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
                Text(
                  'Transf. ${_formatMoney(ms.transferencia)}',
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
              ],
            ),
            if (ms.gastos > 0) ...[
              SizedBox(height: 4),
              Wrap(
                spacing: 12,
                children: [
                  Text(
                    'Gastos ${_formatMoney(ms.gastos)}',
                    style: TextStyle(
                      color: tokens.danger.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Neto ${_formatMoney(ms.neto)}',
                    style: TextStyle(
                      color: ms.neto >= 0
                          ? tokens.success.withValues(alpha: 0.7)
                          : tokens.danger.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthSummary {
  final int month;
  double efectivo = 0;
  double transferencia = 0;
  double gastos = 0;
  double neto = 0;
  int recorridos = 0;
  int duracion = 0;

  _MonthSummary({required this.month});
}

class _FinRow {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final double amount;
  final bool negative;
  const _FinRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.amount,
    this.negative = false,
  });
}
