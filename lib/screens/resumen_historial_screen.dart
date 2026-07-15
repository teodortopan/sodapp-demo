import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/app_database.dart';
import '../demo/demo_mode.dart';
import '../services/auth_service.dart';
import '../utils/app_tokens.dart';
import '../utils/sueldo_formulas.dart';
import '../widgets/sync_indicator.dart';

class ResumenHistorialScreen extends StatefulWidget {
  final int repartoId;
  final String repartoNombre;
  final List<int> workDays;
  final VoidCallback? onResumenDeleted;

  const ResumenHistorialScreen({
    super.key,
    required this.repartoId,
    required this.repartoNombre,
    this.workDays = const [0, 1, 2, 3, 4, 5],
    this.onResumenDeleted,
  });

  @override
  State<ResumenHistorialScreen> createState() => _ResumenHistorialScreenState();
}

class _ResumenHistorialScreenState extends State<ResumenHistorialScreen> {
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

  final _db = AppDatabase.instance;
  List<Resumene> _resumenes = [];
  // Legacy filters retained as ignored fields to preserve _showDetail's
  // closure references. The new design filters by selected month instead.
  // ignore: unused_field
  DateTime? _filterDate;
  // ignore: unused_field
  int? _filterDay;
  // YYYY-MM key of the currently-selected month. Defaults to the most
  // recent month with data on first load.
  String? _selectedMonth;

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
  static const List<String> _monthAbbrevs = [
    'ENE',
    'FEB',
    'MAR',
    'ABR',
    'MAY',
    'JUN',
    'JUL',
    'AGO',
    'SEP',
    'OCT',
    'NOV',
    'DIC',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _db.getResumenesForReparto(widget.repartoId);
    if (!mounted) return;
    setState(() {
      _resumenes = data;
      // Default-select the most recent month with data if nothing's picked
      // yet, or if the previously-picked month no longer exists after a delete.
      final months = _monthKeysDesc();
      if (months.isEmpty) {
        _selectedMonth = null;
      } else if (_selectedMonth == null || !months.contains(_selectedMonth)) {
        _selectedMonth = months.first;
      }
    });
  }

  /// All unique YYYY-MM keys present in _resumenes, sorted DESC.
  List<String> _monthKeysDesc() {
    final set = <String>{};
    for (final r in _resumenes) {
      final parts = r.fecha.split('-');
      if (parts.length >= 2) set.add('${parts[0]}-${parts[1]}');
    }
    final list = set.toList();
    list.sort((a, b) => b.compareTo(a));
    return list;
  }

  String _monthFullLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    final m = int.tryParse(parts[1]) ?? 0;
    final name = (m >= 1 && m <= 12) ? _monthNames[m - 1] : monthKey;
    return '$name ${parts[0]}';
  }

  String _monthAbbrev(int month1to12) {
    return _monthAbbrevs[(month1to12 - 1).clamp(0, 11)];
  }

  String _formatHhMm(int totalSeconds) {
    final d = Duration(seconds: totalSeconds);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// v62: render a UTC-epoch millis value as Argentina-local HH:mm.
  /// Persistence uses UTC millis to avoid timezone-shift bugs.
  String _formatClockFromMillis(int millis) {
    // Argentina is UTC-3 year-round (no DST). Matches the
    // `argentinaTime()` helper used elsewhere in the app.
    final utc = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    final local = utc.subtract(const Duration(hours: 3));
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int _unitsFromProductos(String productosJson) {
    if (productosJson.isEmpty) return 0;
    try {
      final list = jsonDecode(productosJson) as List;
      var sum = 0;
      for (final p in list) {
        if (p is Map) {
          sum += ((p['rec'] as num?)?.toInt() ?? 0);
        }
      }
      return sum;
    } catch (_) {
      return 0;
    }
  }

  // ignore: unused_element
  List<Resumene> get _filteredResumenes {
    var result = _resumenes;
    if (_filterDay != null) {
      result = result.where((r) => r.diaSemana == _filterDay).toList();
    }
    if (_filterDate != null) {
      final dateStr =
          '${_filterDate!.year}-${_filterDate!.month.toString().padLeft(2, '0')}-${_filterDate!.day.toString().padLeft(2, '0')}';
      result = result.where((r) => r.fecha == dateStr).toList();
    }
    return result;
  }

  /// Parse ISO week string "2026-W11" to Monday-Sunday date range
  // ignore: unused_element
  String _weekToDateRange(String weekStr) {
    // Parse year and week number
    final match = RegExp(r'(\d{4})-W(\d{2})').firstMatch(weekStr);
    if (match == null) return weekStr;
    final year = int.parse(match.group(1)!);
    final week = int.parse(match.group(2)!);

    // Jan 4 is always in week 1 (ISO 8601)
    final jan4 = DateTime(year, 1, 4);
    final monday = jan4
        .subtract(Duration(days: jan4.weekday - 1))
        .add(Duration(days: (week - 1) * 7));
    final sunday = monday.add(Duration(days: 6));

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return '${fmt(monday)} - ${fmt(sunday)}';
  }

  // ignore: unused_element
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: tokens.primaryBlue,
              surface: tokens.card,
            ),
            dialogTheme: DialogThemeData(backgroundColor: tokens.card),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _filterDate = picked);
    }
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatMoney(double amount) {
    final abs = amount.abs().round();
    final formatted = abs.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    if (amount < 0) return '- \$$formatted';
    return '\$$formatted';
  }

  String _formatDateLabel(String fecha) {
    // fecha is YYYY-MM-DD
    final parts = fecha.split('-');
    if (parts.length != 3) return fecha;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  // ignore: unused_element
  Widget _buildDayChip(String label, int? dayIndex) {
    final isSelected = _filterDay == dayIndex;
    return Padding(
      padding: EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _filterDay = dayIndex),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? tokens.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? tokens.primaryBlue : tokens.cardBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? tokens.text : tokens.textMuted,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  String _dayNameFromFecha(String fecha) {
    final date = DateTime.tryParse(fecha);
    if (date == null) return '?';
    // weekday: 1=Mon, 7=Sun → index 0–6
    return _dayNames[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final months = _monthKeysDesc();
    final selectedMonth = _selectedMonth;
    final monthItems =
        selectedMonth == null
              ? <Resumene>[]
              : _resumenes
                    .where((r) => r.fecha.startsWith('$selectedMonth-'))
                    .toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));

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
            'HISTORIAL',
            style: TextStyle(
              color: tokens.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          centerTitle: false,
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz, color: tokens.text),
              color: tokens.card,
              onSelected: (v) {
                if (v == 'export') _onExportar();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(
                        Icons.download_outlined,
                        size: 18,
                        color: tokens.text,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Exportar historial',
                        style: TextStyle(color: tokens.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
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
                  _buildHistorialHero(selectedMonth, monthItems),
                  SizedBox(height: 18),
                  if (months.isNotEmpty) ...[
                    _buildMonthPills(months),
                    SizedBox(height: 16),
                  ],
                  if (monthItems.isEmpty)
                    _buildHistorialEmpty()
                  else
                    for (final r in monthItems) _buildHistorialRow(r),
                  if (monthItems.isNotEmpty) ...[
                    SizedBox(height: 10),
                    _buildExportarButton(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorialHero(String? monthKey, List<Resumene> items) {
    final heroBg = tokens.isDark
        ? const Color(0xFF1F2E47)
        : const Color(0xFF0F1B2D);
    const heroInk = Colors.white;
    final heroInkSub = Colors.white.withValues(alpha: 0.60);
    final heroInkMuted = Colors.white.withValues(alpha: 0.45);
    final neto = items.fold<double>(
      0,
      (s, r) => s + (r.sueldoBruto - r.gastos),
    );
    final count = items.length;
    final promedio = count > 0 ? neto / count : 0.0;
    final mejor = items.fold<double>(0, (m, r) {
      final neto = r.sueldoBruto - r.gastos;
      return neto > m ? neto : m;
    });
    final monthLabel = monthKey != null
        ? _monthFullLabel(monthKey).toUpperCase()
        : 'SIN DATOS';

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
            monthLabel,
            style: TextStyle(
              color: heroInkMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          SizedBox(height: 10),
          Text(
            _formatMoney(neto),
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
            'Neto acumulado · $count jornada${count == 1 ? '' : 's'}',
            style: TextStyle(color: heroInkSub, fontSize: 13),
          ),
          SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _historialHeroMetric(
                  'PROMEDIO/DÍA',
                  _formatMoney(promedio),
                  heroInkMuted,
                  heroInk,
                ),
              ),
              Expanded(
                child: _historialHeroMetric(
                  'MEJOR JORNADA',
                  _formatMoney(mejor),
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

  Widget _historialHeroMetric(
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

  Widget _buildMonthPills(List<String> months) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < months.length; i++) ...[
            _buildMonthPill(months[i]),
            if (i < months.length - 1) SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthPill(String monthKey) {
    final isSelected = _selectedMonth == monthKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedMonth = monthKey),
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
          _monthFullLabel(monthKey),
          style: TextStyle(
            color: isSelected ? tokens.primaryBlue : tokens.text,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildHistorialEmpty() => Padding(
    padding: EdgeInsets.symmetric(vertical: 40),
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
            Icons.receipt_long_outlined,
            size: 28,
            color: tokens.textMuted,
          ),
        ),
        SizedBox(height: 14),
        Text(
          'No hay resúmenes guardados',
          style: TextStyle(
            color: tokens.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Cerrá una jornada para verla acá',
          style: TextStyle(color: tokens.textMuted, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _buildHistorialRow(Resumene r) {
    final parts = r.fecha.split('-');
    final dayNum = parts.length == 3
        ? parts[2].replaceFirst(RegExp(r'^0'), '')
        : '?';
    final monthIdx = parts.length == 3 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final monthAbbr = monthIdx >= 1 && monthIdx <= 12
        ? _monthAbbrev(monthIdx)
        : '';
    final dayName = _dayNameFromFecha(r.fecha);
    final units = _unitsFromProductos(r.productosJson);
    final duration = _formatHhMm(r.duracionSegundos);
    final neto = r.sueldoBruto - r.gastos;
    final dayMismatch =
        r.diaSemana >= 0 &&
        r.diaSemana < _dayNames.length &&
        _dayNames[r.diaSemana] != dayName;

    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(r.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          await _confirmDeleteResumen(r);
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: tokens.danger.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.delete_outline, color: tokens.danger, size: 24),
        ),
        child: Material(
          color: tokens.card,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _showDetail(r),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.card,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 8,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: tokens.surface2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayNum,
                          style: TextStyle(
                            color: tokens.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          monthAbbr,
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                dayName,
                                style: TextStyle(
                                  color: tokens.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (dayMismatch) ...[
                              SizedBox(width: 6),
                              Icon(
                                Icons.info_outline,
                                color: tokens.warn,
                                size: 12,
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          '$units unid. · $duration',
                          style: TextStyle(
                            color: tokens.textSub,
                            fontSize: 12,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
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
                        _formatMoney(neto),
                        style: TextStyle(
                          color: neto >= 0 ? tokens.text : tokens.danger,
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
                  SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: tokens.textMuted,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExportarButton() {
    return Material(
      color: tokens.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _onExportar,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 8,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.download_outlined, color: tokens.text, size: 18),
              SizedBox(width: 10),
              Text(
                'Exportar historial',
                style: TextStyle(
                  color: tokens.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onExportar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exportación próximamente'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmDeleteResumen(Resumene r) async {
    if (blockDemoAction(context)) return;
    final dayLabel = _dayNameFromFecha(r.fecha);
    final dateLabel = _formatDateLabel(r.fecha);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Eliminar resumen',
          style: TextStyle(
            color: tokens.text,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          '¿Eliminar el resumen de $dayLabel $dateLabel?\n\nLas entregas, pagos y carga del día se conservan en el historial — sólo se elimina la fila del resumen.',
          style: TextStyle(color: tokens.textSub, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: tokens.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: TextStyle(
                color: tokens.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // P3.2: only the resumen row is deleted. Entregas, pagos, and
      // carga_diaria for the day stay — historial is sacred. Soderos who
      // want to wipe a day's records must do it explicitly per cliente.
      final userId = AuthService.currentUserId;
      await _db.deleteResumen(r, userId: userId);
      await _loadData();
      widget.onResumenDeleted?.call();
    }
  }

  // ignore: unused_element
  Widget _buildResumenCard(Resumene r) {
    final dayLabel = _dayNameFromFecha(r.fecha);
    final dateLabel = _formatDateLabel(r.fecha);
    final neto = r.sueldoBruto - r.gastos;

    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(r.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          await _confirmDeleteResumen(r);
          return false; // we handle deletion ourselves
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: tokens.danger.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.delete_outline, color: tokens.danger, size: 28),
        ),
        child: GestureDetector(
          onTap: () => _showDetail(r),
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
                // Date + duration
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$dayLabel $dateLabel',
                        style: TextStyle(
                          color: tokens.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (r.diaSemana >= 0 &&
                        r.diaSemana < _dayNames.length &&
                        _dayNames[r.diaSemana] != dayLabel) ...[
                      SizedBox(width: 8),
                      Text(
                        '(${_dayNames[r.diaSemana]})',
                        style: TextStyle(
                          color: tokens.warn.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    Spacer(),
                    Icon(
                      Icons.timer_outlined,
                      color: tokens.textMuted,
                      size: 15,
                    ),
                    SizedBox(width: 4),
                    Text(
                      _formatDuration(r.duracionSegundos),
                      style: TextStyle(color: tokens.textMuted, fontSize: 13),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                // Money summary row
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniStat(
                        'Efectivo',
                        r.efectivo,
                        tokens.success,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniStat(
                        'Transfer.',
                        r.transferencia,
                        tokens.success,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniStat('Gastos', r.gastos, tokens.danger),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Neto',
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            _formatMoney(neto),
                            style: TextStyle(
                              color:
                                  (neto >= 0 ? tokens.success : tokens.danger)
                                      .withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: tokens.textMuted, fontSize: 10)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _formatMoney(value),
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showDetail(Resumene r) {
    final dayLabel = _dayNameFromFecha(r.fecha);
    final dateLabel = _formatDateLabel(r.fecha);

    List<dynamic> products = [];
    List<Map<String, dynamic>> gastosList = [];
    try {
      if (r.productosJson.isNotEmpty) {
        products = jsonDecode(r.productosJson) as List;
      }
      if (r.gastosJson.isNotEmpty) {
        gastosList = (jsonDecode(r.gastosJson) as List)
            .map((g) => Map<String, dynamic>.from(g as Map))
            .toList();
      }
    } catch (_) {}

    bool cargaExpanded = false;

    // Track current gastos total and neto/bruto for live updates in the sheet
    double currentGastos = r.gastos;
    double currentBruto = r.sueldoBruto;
    double currentNeto = r.sueldoBruto - r.gastos;

    // v62: recorrido start/end UTC-epoch millis (nullable for pre-v62
    // resumenes and shifts saved before the cierre captured them). Loaded
    // async; the sheet builds before the read returns, so the inline
    // INICIO/FIN block hides until both arrive.
    int? recorridoStartMillis;
    int? recorridoEndMillis;
    List<Map<String, dynamic>>? recorridoSessions;

    void recalc() {
      currentGastos = 0;
      for (final g in gastosList) {
        currentGastos += (g['monto'] as num?)?.toDouble() ?? 0;
      }
      final s = computeSueldo(
        efectivo: r.efectivo,
        transferencia: r.transferencia,
        cuentaCorriente: r.cuentaCorriente,
        gastos: currentGastos,
      );
      currentBruto = s.bruto;
      currentNeto = s.neto;
    }

    Future<void> saveGastos() async {
      if (blockDemoAction(context)) return;
      await _db.updateResumenGastos(
        r.id,
        currentGastos,
        jsonEncode(gastosList),
      );
      await _loadData();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Kick off the recorrido-times read once per sheet open.
            if (recorridoStartMillis == null && recorridoEndMillis == null) {
              AppDatabase.instance.getResumenRecorridoTimes(r.id).then((times) {
                if (times.startMillis == null && times.endMillis == null) {
                  return;
                }
                setSheetState(() {
                  recorridoStartMillis = times.startMillis;
                  recorridoEndMillis = times.endMillis;
                });
              });
            }
            if (recorridoSessions == null) {
              AppDatabase.instance.getResumenSessionsJson(r.id).then((raw) {
                final decoded = (raw.isNotEmpty && raw != '[]')
                    ? (jsonDecode(raw) as List)
                          .map((e) => Map<String, dynamic>.from(e as Map))
                          .toList()
                    : <Map<String, dynamic>>[];
                setSheetState(() {
                  recorridoSessions = decoded;
                });
              });
            }

            BoxDecoration whiteCardDeco() => BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 8,
                  offset: Offset(0, 1),
                ),
              ],
            );

            Widget heroMetric({
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
                  SizedBox(height: 8),
                  // FittedBox.scaleDown so long amounts ($1.234.567 or
                  // negative-prefixed) stay fully visible by shrinking
                  // instead of ellipsizing. Bottom-left alignment keeps
                  // the visual baseline stable across BRUTO/GASTOS/DURACIÓN.
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

            Widget recorridoSessionsBlock({
              required Color heroSurface2,
              required Color heroInkMuted,
              required Color heroInk,
            }) {
              final sessions = recorridoSessions ?? const [];
              final singleStart = sessions.length == 1
                  ? sessions.first['startMillis'] as int?
                  : recorridoStartMillis;
              final singleEnd = sessions.length == 1
                  ? sessions.first['endMillis'] as int?
                  : recorridoEndMillis;
              if (sessions.length <= 1) {
                if (singleStart == null || singleEnd == null) {
                  return SizedBox.shrink();
                }
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: heroSurface2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: heroMetric(
                          label: 'INICIO',
                          value: _formatClockFromMillis(singleStart),
                          inkMuted: heroInkMuted,
                          ink: heroInk,
                        ),
                      ),
                      Expanded(
                        child: heroMetric(
                          label: 'FIN',
                          value: _formatClockFromMillis(singleEnd),
                          inkMuted: heroInkMuted,
                          ink: heroInk,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < sessions.length; i++) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: heroSurface2,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'SESIÓN ${i + 1} — '
                        '${_formatClockFromMillis(sessions[i]['startMillis'] as int? ?? 0)} → '
                        '${_formatClockFromMillis(sessions[i]['endMillis'] as int? ?? 0)}',
                        style: TextStyle(
                          color: heroInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (i != sessions.length - 1) SizedBox(height: 8),
                  ],
                ],
              );
            }

            TextStyle tblHeader() => TextStyle(
              color: tokens.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            );

            Widget paymentRow({
              required IconData icon,
              required Color iconBg,
              required Color iconColor,
              required String label,
              required double amount,
            }) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: iconColor),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: tokens.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _formatMoney(amount),
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

            Widget productoRow(Map<String, dynamic> p) {
              final size = (p['pack_size'] as num?)?.toInt();
              int adjust(int qty) {
                if (size != null && size >= 2) return qty ~/ size;
                return qty;
              }

              final sal = adjust((p['sal'] as num?)?.toInt() ?? 0);
              final ret = adjust((p['ret'] as num?)?.toInt() ?? 0);
              final teor = sal - ret;
              final real = adjust((p['rec'] as num?)?.toInt() ?? 0);
              final dif = real - teor;
              final difColor = dif > 0
                  ? tokens.success
                  : (dif < 0 ? tokens.danger : tokens.textMuted);
              final difLabel = dif > 0 ? '+$dif' : '$dif';
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        p['nombre'] as String? ?? '',
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
                        '$sal',
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
                        '$ret',
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
                        '$teor',
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
                        '$real',
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

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (ctx, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                      Builder(
                        builder: (_) {
                          final heroBg = tokens.isDark
                              ? const Color(0xFF1F2E47)
                              : const Color(0xFF0F1B2D);
                          final heroSurface2 = tokens.isDark
                              ? const Color(0xFF2D3F60)
                              : const Color(0xFF1F2E47);
                          const heroInk = Colors.white;
                          final heroInkSub = Colors.white.withValues(
                            alpha: 0.70,
                          );
                          final heroInkMuted = Colors.white.withValues(
                            alpha: 0.45,
                          );
                          final configuredDayName =
                              r.diaSemana >= 0 && r.diaSemana < _dayNames.length
                              ? _dayNames[r.diaSemana]
                              : '';
                          final dayMismatch =
                              configuredDayName.isNotEmpty &&
                              configuredDayName != dayLabel;
                          final hours = r.duracionSegundos ~/ 3600;
                          final minutes = (r.duracionSegundos % 3600) ~/ 60;
                          final durationLabel =
                              '${hours.toString().padLeft(2, '0')} : ${minutes.toString().padLeft(2, '0')}';

                          return Container(
                            margin: EdgeInsets.fromLTRB(16, 12, 16, 12),
                            padding: EdgeInsets.fromLTRB(22, 22, 22, 22),
                            decoration: BoxDecoration(
                              color: heroBg,
                              borderRadius: BorderRadius.circular(16),
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
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: heroSurface2,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Jornada cerrada',
                                    style: TextStyle(
                                      color: heroInk,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 18),
                                Text(
                                  '$dayLabel $dateLabel',
                                  style: TextStyle(
                                    color: heroInk,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (dayMismatch) ...[
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Color(0xFFFBBF24),
                                        size: 13,
                                      ),
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
                                  _formatMoney(currentNeto),
                                  style: TextStyle(
                                    color: heroInk,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Sueldo neto del día',
                                  style: TextStyle(
                                    color: heroInkSub,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 22),
                                Row(
                                  children: [
                                    Expanded(
                                      child: heroMetric(
                                        label: 'BRUTO',
                                        value: _formatMoney(currentBruto),
                                        inkMuted: heroInkMuted,
                                        ink: heroInk,
                                      ),
                                    ),
                                    Expanded(
                                      child: heroMetric(
                                        label: 'GASTOS',
                                        value: currentGastos > 0
                                            ? '- ${_formatMoney(currentGastos)}'
                                            : _formatMoney(currentGastos),
                                        inkMuted: heroInkMuted,
                                        ink: heroInk,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 14),
                                heroMetric(
                                  label: 'DURACION',
                                  value: durationLabel,
                                  inkMuted: heroInkMuted,
                                  ink: heroInk,
                                ),
                                if ((recorridoStartMillis != null &&
                                        recorridoEndMillis != null) ||
                                    (recorridoSessions?.isNotEmpty ??
                                        false)) ...[
                                  SizedBox(height: 14),
                                  recorridoSessionsBlock(
                                    heroSurface2: heroSurface2,
                                    heroInkMuted: heroInkMuted,
                                    heroInk: heroInk,
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: whiteCardDeco(),
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
                              style: TextStyle(
                                color: tokens.textSub,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 12),
                            Divider(color: tokens.cardBorder, height: 1),
                            paymentRow(
                              icon: Icons.payments_outlined,
                              iconBg: tokens.success.withValues(alpha: 0.14),
                              iconColor: tokens.success,
                              label: 'Efectivo',
                              amount: r.efectivo,
                            ),
                            Divider(
                              color: tokens.cardBorder,
                              height: 1,
                              indent: 50,
                            ),
                            paymentRow(
                              icon: Icons.swap_horiz,
                              iconBg: tokens.primaryBlue.withValues(
                                alpha: 0.12,
                              ),
                              iconColor: tokens.primaryBlue,
                              label: 'Transferencia',
                              amount: r.transferencia,
                            ),
                            Divider(
                              color: tokens.cardBorder,
                              height: 1,
                              indent: 50,
                            ),
                            paymentRow(
                              icon: Icons.account_balance_wallet_outlined,
                              iconBg: tokens.warn.withValues(alpha: 0.14),
                              iconColor: tokens.warn,
                              label: 'Cuenta corriente',
                              amount: r.cuentaCorriente,
                            ),
                            SizedBox(height: 6),
                          ],
                        ),
                      ),
                      if (products.isNotEmpty)
                        Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: whiteCardDeco(),
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
                                style: TextStyle(
                                  color: tokens.textSub,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Text('PRODUCTO', style: tblHeader()),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'SAL.',
                                      textAlign: TextAlign.right,
                                      style: tblHeader(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'RET.',
                                      textAlign: TextAlign.right,
                                      style: tblHeader(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'TEÓR.',
                                      textAlign: TextAlign.right,
                                      style: tblHeader(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'REAL',
                                      textAlign: TextAlign.right,
                                      style: tblHeader(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'DIF.',
                                      textAlign: TextAlign.right,
                                      style: tblHeader(),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              for (var i = 0; i < products.length; i++) ...[
                                Divider(color: tokens.cardBorder, height: 1),
                                productoRow(
                                  Map<String, dynamic>.from(products[i] as Map),
                                ),
                              ],
                              if (products.isNotEmpty) ...[
                                SizedBox(height: 8),
                                _buildHistTotalsStrip(products),
                              ],
                            ],
                          ),
                        ),
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: whiteCardDeco(),
                        padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Builder(
                          builder: (_) {
                            final productGastos = gastosList
                                .where((g) => g['type'] == 'producto')
                                .toList();
                            final manualGastos = gastosList
                                .where(
                                  (g) =>
                                      g['type'] == 'manual' ||
                                      !g.containsKey('type'),
                                )
                                .toList();
                            final hasNoGastos =
                                manualGastos.isEmpty && productGastos.isEmpty;

                            return Column(
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
                                    TextButton(
                                      onPressed: () {
                                        _showAddGastoDialog(ctx, (
                                          descripcion,
                                          monto,
                                        ) {
                                          setSheetState(() {
                                            gastosList.add({
                                              'descripcion': descripcion,
                                              'monto': monto,
                                              'type': 'manual',
                                            });
                                            recalc();
                                          });
                                          saveGastos();
                                        });
                                      },
                                      child: Text(
                                        'Agregar',
                                        style: TextStyle(
                                          color: tokens.primaryBlue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                if (hasNoGastos)
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Text(
                                      'Sin gastos registrados',
                                      style: TextStyle(
                                        color: tokens.textSub,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                if (productGastos.isNotEmpty) ...[
                                  InkWell(
                                    onTap: () => setSheetState(
                                      () => cargaExpanded = !cargaExpanded,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            cargaExpanded
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                            color: tokens.textMuted,
                                            size: 18,
                                          ),
                                          SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Carga',
                                              style: TextStyle(
                                                color: tokens.text,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '- ${_formatMoney(productGastos.fold<double>(0, (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0)))}',
                                            style: TextStyle(
                                              color: tokens.danger,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              fontFeatures: [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (cargaExpanded)
                                    ...productGastos.map(
                                      (g) => Padding(
                                        padding: EdgeInsets.only(
                                          left: 24,
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                g['descripcion'] as String? ??
                                                    '',
                                                style: TextStyle(
                                                  color: tokens.textSub,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '- ${_formatMoney((g['monto'] as num?)?.toDouble() ?? 0)}',
                                              style: TextStyle(
                                                color: tokens.danger,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                fontFeatures: [
                                                  FontFeature.tabularFigures(),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                                ...manualGastos.map((g) {
                                  final i = gastosList.indexOf(g);
                                  return Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              _showEditGastoDialog(
                                                ctx,
                                                g['descripcion'] as String? ??
                                                    '',
                                                (g['monto'] as num?)
                                                        ?.toDouble() ??
                                                    0,
                                                (descripcion, monto) {
                                                  setSheetState(() {
                                                    gastosList[i] = {
                                                      'descripcion':
                                                          descripcion,
                                                      'monto': monto,
                                                      'type': 'manual',
                                                    };
                                                    recalc();
                                                  });
                                                  saveGastos();
                                                },
                                              );
                                            },
                                            child: Text(
                                              g['descripcion'] as String? ?? '',
                                              style: TextStyle(
                                                color: tokens.text,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '- ${_formatMoney((g['monto'] as num?)?.toDouble() ?? 0)}',
                                          style: TextStyle(
                                            color: tokens.danger,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            fontFeatures: [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        IconButton(
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: ctx,
                                              builder: (dCtx) => AlertDialog(
                                                backgroundColor: tokens.card,
                                                title: Text(
                                                  'Eliminar gasto',
                                                  style: TextStyle(
                                                    color: tokens.text,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                content: Text(
                                                  '¿Eliminar "${g['descripcion']}" (${_formatMoney((g['monto'] as num?)?.toDouble() ?? 0)})?',
                                                  style: TextStyle(
                                                    color: tokens.textSub,
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          dCtx,
                                                          false,
                                                        ),
                                                    child: Text(
                                                      'Cancelar',
                                                      style: TextStyle(
                                                        color: tokens.textSub,
                                                      ),
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          dCtx,
                                                          true,
                                                        ),
                                                    child: Text(
                                                      'Eliminar',
                                                      style: TextStyle(
                                                        color: tokens.danger,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              setSheetState(() {
                                                gastosList.removeAt(i);
                                                recalc();
                                              });
                                              saveGastos();
                                            }
                                          },
                                          icon: Icon(
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
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAddGastoDialog(
    BuildContext parentCtx,
    void Function(String, double) onSave,
  ) {
    final descCtrl = TextEditingController();
    final montoCtrl = TextEditingController();

    showDialog<void>(
      context: parentCtx,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: tokens.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Agregar gasto',
            style: TextStyle(
              color: tokens.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: tokens.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Descripción (ej: Combustible)',
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
              ),
              SizedBox(height: 12),
              TextField(
                controller: montoCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: tokens.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Monto',
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(color: tokens.textSub, fontSize: 14),
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
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: tokens.textSub)),
            ),
            TextButton(
              onPressed: () {
                final desc = descCtrl.text.trim();
                final monto =
                    double.tryParse(
                      montoCtrl.text.replaceAll(',', '.').trim(),
                    ) ??
                    0;
                if (desc.isEmpty || monto <= 0) return;
                Navigator.pop(ctx);
                onSave(desc, monto);
              },
              child: Text(
                'Agregar',
                style: TextStyle(
                  color: tokens.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        descCtrl.dispose();
        montoCtrl.dispose();
      });
    });
  }

  void _showEditGastoDialog(
    BuildContext parentCtx,
    String currentDesc,
    double currentMonto,
    void Function(String, double) onSave,
  ) {
    final descCtrl = TextEditingController(text: currentDesc);
    final montoCtrl = TextEditingController(
      text: currentMonto > 0 ? currentMonto.toStringAsFixed(0) : '',
    );

    showDialog<void>(
      context: parentCtx,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: tokens.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Editar gasto',
            style: TextStyle(
              color: tokens.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: tokens.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Descripción',
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
              ),
              SizedBox(height: 12),
              TextField(
                controller: montoCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: tokens.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Monto',
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(color: tokens.textSub, fontSize: 14),
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
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: tokens.textSub)),
            ),
            TextButton(
              onPressed: () {
                final desc = descCtrl.text.trim();
                final monto =
                    double.tryParse(
                      montoCtrl.text.replaceAll(',', '.').trim(),
                    ) ??
                    0;
                if (desc.isEmpty || monto <= 0) return;
                Navigator.pop(ctx);
                onSave(desc, monto);
              },
              child: Text(
                'Guardar',
                style: TextStyle(
                  color: tokens.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        descCtrl.dispose();
        montoCtrl.dispose();
      });
    });
  }

  // ignore: unused_element
  Widget _buildDetailRow(
    IconData icon,
    String label,
    double amount,
    bool positive,
  ) {
    return Row(
      children: [
        Icon(icon, color: tokens.textSub, size: 18),
        SizedBox(width: 8),
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _colHeader(String text) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: tokens.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _colValue(String text, Color color) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildHistTotalsStrip(List<dynamic> products) {
    int totalRet = 0;
    int totalVentReal = 0;
    for (final p in products) {
      final ret = (p['ret'] as num?)?.toInt() ?? 0;
      final rec = (p['rec'] as num?)?.toInt() ?? 0;
      final size = (p['pack_size'] as num?)?.toInt();
      if (size != null && size >= 2) {
        totalRet += ret ~/ size;
        totalVentReal += rec ~/ size;
      } else {
        totalRet += ret;
        totalVentReal += rec;
      }
    }
    final saldo = totalVentReal - totalRet;
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
              SizedBox(
                width: 90,
                child: Text(
                  'CONCEPTO',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _colHeader('VAC. REC.'),
              _colHeader('LLEN. ENT.'),
              _colHeader('SALDO'),
            ],
          ),
          SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  'Totales',
                  style: TextStyle(
                    color: tokens.textSub,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // VAC. REC. column gets the returns total (muted color); LLEN. ENT.
              // column gets the deliveries total (primary blue headline).
              _colValue('$totalRet', tokens.textSub),
              _colValue('$totalVentReal', tokens.primaryBlue),
              _colValue(
                '${saldo > 0 ? '+' : ''}$saldo',
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
}
