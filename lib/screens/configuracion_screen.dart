import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/app_database.dart';
import '../demo/demo_mode.dart';
import '../services/sync_service.dart';
import '../utils/app_tokens.dart';
import '../utils/theme_controller.dart';
import '../widgets/sync_indicator.dart';

class ConfiguracionScreen extends StatefulWidget {
  final int? repartoId;
  const ConfiguracionScreen({super.key, this.repartoId});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  AppTokens get tokens => AppTokens.of(context);

  static const List<String> _allDayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  final _db = AppDatabase.instance;
  Set<int> _workDays = {0, 1, 2, 3, 4, 5};
  bool _qrEnabled = true;
  bool _autoListoOnPago = false;
  bool _cargaGastosEnabled = true;
  bool _deudaNotifEnabled = true;
  int _deudaNotifWeeks = 3;
  bool _inactiveNotifEnabled = true;
  int _inactiveNotifWeeks = 4;
  bool _stockNotifMasterEnabled = true;
  bool _adminMessageBannerEnabled = true;
  List<_StockNotifRow> _stockNotifRows = [];
  List<_HabitualRow> _habitualRows = [];
  Set<String> _vistaRapidaFields = AppDatabase.defaultVistaRapidaFields.toSet();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final days = await _db.getWorkDays();
    final qr = await _db.getQrEnabled();
    final autoListoOnPago = await _db.getAutoListoOnPago();
    final cargaGastosEnabled = await _db.getCargaGastosEnabled();
    final deudaEnabled = await _db.getDeudaNotifEnabled();
    final deudaWeeks = await _db.getDeudaNotifWeeks();
    final inactiveEnabled = await _db.getInactiveNotifEnabled();
    final inactiveWeeks = await _db.getInactiveNotifWeeks();
    final stockMaster = await _db.getStockNotifMasterEnabled();
    final adminMessageBanner = await _db.getAdminMessageBannerEnabled();
    final vistaFields = await _db.getVistaRapidaFields();
    if (widget.repartoId != null) {
      await _db.ensureStockNotifSettingsExist(widget.repartoId!);
      await _db.ensureHabitualSettingsExist(widget.repartoId!);
    }
    final stockSettings = widget.repartoId != null
        ? await _db.getAllStockNotifSettings(widget.repartoId!)
        : <StockNotifSetting>[];
    final products = widget.repartoId != null
        ? await _db.getAllProducts(widget.repartoId!)
        : <Producto>[];
    final productNames = {for (final p in products) p.id: p.nombre};
    final stockRows = stockSettings
        .where((s) => productNames.containsKey(s.productoId))
        .map(
          (s) => _StockNotifRow(
            productoId: s.productoId,
            productName: productNames[s.productoId]!,
            enabled: s.enabled,
            threshold: s.threshold,
          ),
        )
        .toList();
    // Load habitual product settings
    final habitualSettings = widget.repartoId != null
        ? await _db.getHabitualSettings(widget.repartoId!)
        : <Map<String, dynamic>>[];
    final habitualRows = habitualSettings
        .map(
          (h) => _HabitualRow(
            productoId: h['producto_id'] as int,
            productName: h['product_name'] as String,
            enabled: h['enabled'] as bool,
          ),
        )
        .toList();

    if (mounted) {
      setState(() {
        _workDays = days.toSet();
        _qrEnabled = qr;
        _autoListoOnPago = autoListoOnPago;
        _cargaGastosEnabled = cargaGastosEnabled;
        _deudaNotifEnabled = deudaEnabled;
        _deudaNotifWeeks = deudaWeeks;
        _inactiveNotifEnabled = inactiveEnabled;
        _inactiveNotifWeeks = inactiveWeeks;
        _stockNotifMasterEnabled = stockMaster;
        _adminMessageBannerEnabled = adminMessageBanner;
        _stockNotifRows = stockRows;
        _habitualRows = habitualRows;
        _vistaRapidaFields = vistaFields;
        _loaded = true;
      });
    }
  }

  Future<void> _toggleDay(int day) async {
    if (blockDemoAction(context)) return;
    setState(() {
      if (_workDays.contains(day)) {
        if (_workDays.length > 1) {
          _workDays.remove(day);
        }
      } else {
        _workDays.add(day);
      }
    });
    await _db.setWorkDays(_workDays.toList()..sort());
  }

  Future<void> _toggleQr(bool value) async {
    if (blockDemoAction(context)) return;
    setState(() => _qrEnabled = value);
    await _db.setQrEnabled(value);
    SyncService.instance.scheduleSyncSoon();
  }

  Future<void> _toggleAutoListoOnPago(bool value) async {
    if (blockDemoAction(context)) return;
    setState(() => _autoListoOnPago = value);
    await _db.setAutoListoOnPago(value);
    SyncService.instance.scheduleSyncSoon();
  }

  Future<void> _toggleCargaGastos(bool value) async {
    if (blockDemoAction(context)) return;
    setState(() => _cargaGastosEnabled = value);
    await _db.setCargaGastosEnabled(value);
    SyncService.instance.scheduleSyncSoon();
  }

  Future<void> _toggleVistaRapidaField(String key, bool enabled) async {
    if (blockDemoAction(context)) return;
    setState(() {
      if (enabled) {
        _vistaRapidaFields.add(key);
      } else {
        _vistaRapidaFields.remove(key);
      }
    });
    await _db.setVistaRapidaFields(_vistaRapidaFields);
  }

  @override
  Widget build(BuildContext context) {
    final themeData = AppTheme.of(context);
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
              color: tokens.text,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
          title: Text(
            'CONFIGURACIÓN',
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
              child: !_loaded
                  ? SizedBox.shrink()
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        16 + MediaQuery.of(context).padding.bottom,
                      ),
                      children: [
                        // --- Apariencia ---
                        _buildSectionTitle('APARIENCIA'),
                        SizedBox(height: 10),
                        Container(
                          decoration: _whiteCardDeco(),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  themeData.brightness == Brightness.dark
                                      ? Icons.dark_mode
                                      : Icons.light_mode,
                                  color: tokens.textSub,
                                  size: 22,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Modo oscuro',
                                        style: TextStyle(
                                          color: tokens.text,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Cambia entre tema claro y oscuro',
                                        style: TextStyle(
                                          color: tokens.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value:
                                      themeData.brightness == Brightness.dark,
                                  onChanged: (value) =>
                                      themeData.controller.setMode(
                                        value
                                            ? Brightness.dark
                                            : Brightness.light,
                                      ),
                                  activeThumbColor: tokens.primaryBlue,
                                  activeTrackColor: tokens.primaryBlue
                                      .withValues(alpha: 0.3),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 22),

                        // --- Work Days ---
                        _buildSectionTitle('DÍAS DE TRABAJO'),
                        SizedBox(height: 10),
                        Container(
                          decoration: _whiteCardDeco(),
                          child: Column(
                            children: List.generate(_allDayNames.length, (i) {
                              final selected = _workDays.contains(i);
                              return Column(
                                children: [
                                  if (i > 0)
                                    Divider(
                                      color: tokens.cardBorder,
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16,
                                    ),
                                  InkWell(
                                    onTap: () => _toggleDay(i),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            _allDayNames[i],
                                            style: TextStyle(
                                              color: selected
                                                  ? tokens.text
                                                  : tokens.textMuted,
                                              fontSize: 15,
                                              fontWeight: selected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                          Spacer(),
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: selected
                                                  ? tokens.primaryBlue
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: selected
                                                    ? tokens.primaryBlue
                                                    : tokens.textMuted
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                width: 2,
                                              ),
                                            ),
                                            child: selected
                                                ? Icon(
                                                    Icons.check,
                                                    color: tokens.text,
                                                    size: 16,
                                                  )
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Solo los días seleccionados aparecerán en Carga, Configurar reparto y otros selectores de día.',
                            style: TextStyle(
                              color: tokens.textMuted.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),

                        SizedBox(height: 22),

                        // --- Feature Toggles ---
                        _buildSectionTitle('FUNCIONES'),
                        SizedBox(height: 10),
                        Container(
                          decoration: _whiteCardDeco(),
                          child: Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.qr_code,
                                      color: tokens.textSub,
                                      size: 22,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Cobrar con QR',
                                            style: TextStyle(
                                              color: tokens.text,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Muestra el botón de pago con QR de Mercado Pago en la ruta',
                                            style: TextStyle(
                                              color: tokens.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _qrEnabled,
                                      onChanged: _toggleQr,
                                      activeThumbColor: tokens.primaryBlue,
                                      activeTrackColor: tokens.primaryBlue
                                          .withValues(alpha: 0.3),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                color: tokens.cardBorder,
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      color: tokens.textSub,
                                      size: 22,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Carga como gasto',
                                            style: TextStyle(
                                              color: tokens.text,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Suma el costo mayorista de la carga en gastos y resumenes',
                                            style: TextStyle(
                                              color: tokens.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _cargaGastosEnabled,
                                      onChanged: _toggleCargaGastos,
                                      activeThumbColor: tokens.primaryBlue,
                                      activeTrackColor: tokens.primaryBlue
                                          .withValues(alpha: 0.3),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                color: tokens.cardBorder,
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: tokens.textSub,
                                      size: 22,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Marcar Listo al cobrar',
                                            style: TextStyle(
                                              color: tokens.text,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Al elegir un método de pago, marca al cliente como Listo y pasa al siguiente automáticamente',
                                            style: TextStyle(
                                              color: tokens.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _autoListoOnPago,
                                      onChanged: _toggleAutoListoOnPago,
                                      activeThumbColor: tokens.primaryBlue,
                                      activeTrackColor: tokens.primaryBlue
                                          .withValues(alpha: 0.3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 22),

                        // --- Vista rápida (Ruta cliente row) ---
                        _buildSectionTitle('VISTA RÁPIDA'),
                        SizedBox(height: 4),
                        Padding(
                          padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                          child: Text(
                            'Qué información mostrar de cada cliente en la lista de ruta. El nombre y la dirección siempre se muestran.',
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                        Container(
                          decoration: _whiteCardDeco(),
                          child: Column(
                            children: [
                              _buildVistaRapidaRow(
                                icon: Icons.account_balance_wallet_outlined,
                                title: 'Cuenta corriente',
                                subtitle:
                                    'Saldo del cliente al lado del nombre',
                                fieldKey: 'saldo',
                                isFirst: true,
                              ),
                              Divider(
                                color: tokens.cardBorder,
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                              _buildVistaRapidaRow(
                                icon: Icons.local_offer_outlined,
                                title: 'Etiquetas',
                                subtitle:
                                    'Etiquetas personalizadas del cliente',
                                fieldKey: 'etiquetas',
                              ),
                              Divider(
                                color: tokens.cardBorder,
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                              _buildVistaRapidaRow(
                                icon: Icons.sticky_note_2_outlined,
                                title: 'Notas',
                                subtitle:
                                    'Notas internas debajo de las etiquetas',
                                fieldKey: 'notas',
                                isLast: true,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 22),

                        // --- Notifications ---
                        _buildSectionTitle('NOTIFICACIONES'),
                        SizedBox(height: 10),
                        Container(
                          decoration: _whiteCardDeco(),
                          child: Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'MENSAJES',
                                    style: TextStyle(
                                      color: tokens.textMuted,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.forum_outlined,
                                      color: tokens.success,
                                      size: 22,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Mensajes del administrador',
                                            style: TextStyle(
                                              color: tokens.text,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Mostrar nuevos mensajes como notificación emergente',
                                            style: TextStyle(
                                              color: tokens.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _adminMessageBannerEnabled,
                                      onChanged: (v) async {
                                        if (blockDemoAction(context)) return;
                                        setState(
                                          () => _adminMessageBannerEnabled = v,
                                        );
                                        await _db.setAdminMessageBannerEnabled(
                                          v,
                                        );
                                      },
                                      activeThumbColor: tokens.primaryBlue,
                                      activeTrackColor: tokens.primaryBlue
                                          .withValues(alpha: 0.3),
                                      inactiveThumbColor: tokens.textMuted
                                          .withValues(alpha: 0.5),
                                      inactiveTrackColor: tokens.cardBorder,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          decoration: _whiteCardDeco(),
                          child: Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'DEUDA',
                                    style: TextStyle(
                                      color: tokens.textMuted,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: tokens.warn,
                                      size: 22,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Alerta de deuda prolongada',
                                            style: TextStyle(
                                              color: tokens.text,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Notifica cuando un cliente debe hace varias semanas',
                                            style: TextStyle(
                                              color: tokens.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _deudaNotifEnabled,
                                      onChanged: (v) async {
                                        if (blockDemoAction(context)) return;
                                        setState(() => _deudaNotifEnabled = v);
                                        await _db.setDeudaNotifEnabled(v);
                                      },
                                      activeThumbColor: tokens.primaryBlue,
                                      activeTrackColor: tokens.primaryBlue
                                          .withValues(alpha: 0.3),
                                      inactiveThumbColor: tokens.textMuted
                                          .withValues(alpha: 0.5),
                                      inactiveTrackColor: tokens.cardBorder,
                                    ),
                                  ],
                                ),
                              ),
                              if (_deudaNotifEnabled) ...[
                                Divider(
                                  color: tokens.cardBorder,
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Semanas de deuda',
                                          style: TextStyle(
                                            color: tokens.textSub,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          if (blockDemoAction(context)) return;
                                          if (_deudaNotifWeeks > 1) {
                                            setState(() => _deudaNotifWeeks--);
                                            _db.setDeudaNotifWeeks(
                                              _deudaNotifWeeks,
                                            );
                                          }
                                        },
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: tokens.primaryBlue
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: tokens.primaryBlue
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '-',
                                              style: TextStyle(
                                                color: tokens.primaryBlue,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 40,
                                        child: Center(
                                          child: Text(
                                            '$_deudaNotifWeeks',
                                            style: TextStyle(
                                              color: tokens.text,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          if (blockDemoAction(context)) return;
                                          setState(() => _deudaNotifWeeks++);
                                          _db.setDeudaNotifWeeks(
                                            _deudaNotifWeeks,
                                          );
                                        },
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: tokens.primaryBlue
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: tokens.primaryBlue
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '+',
                                              style: TextStyle(
                                                color: tokens.primaryBlue,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: 10),

                        // --- Inactive client notification ---
                        Container(
                          decoration: _whiteCardDeco(),
                          child: Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'INACTIVO',
                                    style: TextStyle(
                                      color: tokens.textMuted,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_off,
                                      color: tokens.textMuted,
                                      size: 22,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Cliente inactivo',
                                            style: TextStyle(
                                              color: tokens.text,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Notifica cuando un cliente no compra hace varias semanas',
                                            style: TextStyle(
                                              color: tokens.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _inactiveNotifEnabled,
                                      onChanged: (v) async {
                                        if (blockDemoAction(context)) return;
                                        setState(
                                          () => _inactiveNotifEnabled = v,
                                        );
                                        await _db.setInactiveNotifEnabled(v);
                                      },
                                      activeThumbColor: tokens.primaryBlue,
                                      activeTrackColor: tokens.primaryBlue
                                          .withValues(alpha: 0.3),
                                      inactiveThumbColor: tokens.textMuted
                                          .withValues(alpha: 0.5),
                                      inactiveTrackColor: tokens.cardBorder,
                                    ),
                                  ],
                                ),
                              ),
                              if (_inactiveNotifEnabled) ...[
                                Divider(
                                  color: tokens.cardBorder,
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Semanas sin comprar',
                                          style: TextStyle(
                                            color: tokens.textSub,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          if (blockDemoAction(context)) return;
                                          if (_inactiveNotifWeeks > 1) {
                                            setState(
                                              () => _inactiveNotifWeeks--,
                                            );
                                            _db.setInactiveNotifWeeks(
                                              _inactiveNotifWeeks,
                                            );
                                          }
                                        },
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: tokens.primaryBlue
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: tokens.primaryBlue
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '-',
                                              style: TextStyle(
                                                color: tokens.primaryBlue,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 40,
                                        child: Center(
                                          child: Text(
                                            '$_inactiveNotifWeeks',
                                            style: TextStyle(
                                              color: tokens.text,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          if (blockDemoAction(context)) return;
                                          setState(() => _inactiveNotifWeeks++);
                                          _db.setInactiveNotifWeeks(
                                            _inactiveNotifWeeks,
                                          );
                                        },
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: tokens.primaryBlue
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: tokens.primaryBlue
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '+',
                                              style: TextStyle(
                                                color: tokens.primaryBlue,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: 10),

                        // --- Stock low notification ---
                        Container(
                          decoration: _whiteCardDeco(),
                          child: Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'STOCK',
                                    style: TextStyle(
                                      color: tokens.textMuted,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.inventory_2,
                                      color: tokens.danger,
                                      size: 22,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Alerta de carga baja',
                                            style: TextStyle(
                                              color: tokens.text,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Notifica cuando te quedan pocas unidades de un producto durante el recorrido',
                                            style: TextStyle(
                                              color: tokens.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _stockNotifMasterEnabled,
                                      onChanged: (v) async {
                                        if (blockDemoAction(context)) return;
                                        setState(
                                          () => _stockNotifMasterEnabled = v,
                                        );
                                        await _db.setStockNotifMasterEnabled(v);
                                      },
                                      activeThumbColor: tokens.primaryBlue,
                                      activeTrackColor: tokens.primaryBlue
                                          .withValues(alpha: 0.3),
                                      inactiveThumbColor: tokens.textMuted
                                          .withValues(alpha: 0.5),
                                      inactiveTrackColor: tokens.cardBorder,
                                    ),
                                  ],
                                ),
                              ),
                              if (_stockNotifMasterEnabled &&
                                  _stockNotifRows.isNotEmpty) ...[
                                Divider(
                                  color: tokens.cardBorder,
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                                ...List.generate(_stockNotifRows.length, (i) {
                                  final row = _stockNotifRows[i];
                                  return Column(
                                    children: [
                                      if (i > 0)
                                        Divider(
                                          color: tokens.cardBorder,
                                          height: 1,
                                          indent: 40,
                                          endIndent: 16,
                                        ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () async {
                                                if (blockDemoAction(context)) {
                                                  return;
                                                }
                                                final newVal = !row.enabled;
                                                setState(
                                                  () => _stockNotifRows[i] = row
                                                      .copyWith(
                                                        enabled: newVal,
                                                      ),
                                                );
                                                await _db.setStockNotifEnabled(
                                                  row.productoId,
                                                  newVal,
                                                );
                                              },
                                              child: Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: row.enabled
                                                      ? tokens.primaryBlue
                                                      : Colors.transparent,
                                                  border: Border.all(
                                                    color: row.enabled
                                                        ? tokens.primaryBlue
                                                        : tokens.textMuted
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                    width: 2,
                                                  ),
                                                ),
                                                child: row.enabled
                                                    ? Icon(
                                                        Icons.check,
                                                        color: tokens.text,
                                                        size: 12,
                                                      )
                                                    : null,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                row.productName,
                                                style: TextStyle(
                                                  color: row.enabled
                                                      ? tokens.text
                                                      : tokens.textMuted,
                                                  fontSize: 14,
                                                  fontWeight: row.enabled
                                                      ? FontWeight.w500
                                                      : FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                            if (row.enabled) ...[
                                              GestureDetector(
                                                onTap: () async {
                                                  if (blockDemoAction(
                                                    context,
                                                  )) {
                                                    return;
                                                  }
                                                  if (row.threshold > 1) {
                                                    final newVal =
                                                        row.threshold - 1;
                                                    setState(
                                                      () => _stockNotifRows[i] =
                                                          row.copyWith(
                                                            threshold: newVal,
                                                          ),
                                                    );
                                                    await _db
                                                        .setStockNotifThreshold(
                                                          row.productoId,
                                                          newVal,
                                                        );
                                                  }
                                                },
                                                child: Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: tokens.primaryBlue
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: tokens.primaryBlue
                                                          .withValues(
                                                            alpha: 0.4,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '-',
                                                      style: TextStyle(
                                                        color:
                                                            tokens.primaryBlue,
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 40,
                                                child: Center(
                                                  child: Text(
                                                    '${row.threshold}',
                                                    style: TextStyle(
                                                      color: tokens.text,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () async {
                                                  if (blockDemoAction(
                                                    context,
                                                  )) {
                                                    return;
                                                  }
                                                  final newVal =
                                                      row.threshold + 1;
                                                  setState(
                                                    () => _stockNotifRows[i] =
                                                        row.copyWith(
                                                          threshold: newVal,
                                                        ),
                                                  );
                                                  await _db
                                                      .setStockNotifThreshold(
                                                        row.productoId,
                                                        newVal,
                                                      );
                                                },
                                                child: Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: tokens.primaryBlue
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: tokens.primaryBlue
                                                          .withValues(
                                                            alpha: 0.4,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '+',
                                                      style: TextStyle(
                                                        color:
                                                            tokens.primaryBlue,
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: 22),

                        // --- Habitual quick add products ---
                        _buildSectionTitle('PRODUCTOS HABITUALES'),
                        SizedBox(height: 10),
                        Container(
                          decoration: _whiteCardDeco(),
                          child: Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      color: tokens.warn.withValues(
                                        alpha: 0.85,
                                      ),
                                      size: 22,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Productos habituales',
                                            style: TextStyle(
                                              color: tokens.text,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Seleccioná qué productos pueden aparecer como sugerencia habitual',
                                            style: TextStyle(
                                              color: tokens.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_habitualRows.isNotEmpty) ...[
                                Divider(
                                  color: tokens.cardBorder,
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                                ...List.generate(_habitualRows.length, (i) {
                                  final row = _habitualRows[i];
                                  return Column(
                                    children: [
                                      if (i > 0)
                                        Divider(
                                          color: tokens.cardBorder,
                                          height: 1,
                                          indent: 40,
                                          endIndent: 16,
                                        ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () async {
                                                if (blockDemoAction(context)) {
                                                  return;
                                                }
                                                if (widget.repartoId == null) {
                                                  return;
                                                }
                                                final newVal = !row.enabled;
                                                setState(
                                                  () => _habitualRows[i] = row
                                                      .copyWith(
                                                        enabled: newVal,
                                                      ),
                                                );
                                                await _db.setHabitualEnabled(
                                                  widget.repartoId!,
                                                  row.productoId,
                                                  newVal,
                                                );
                                              },
                                              child: Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: row.enabled
                                                      ? tokens.primaryBlue
                                                      : Colors.transparent,
                                                  border: Border.all(
                                                    color: row.enabled
                                                        ? tokens.primaryBlue
                                                        : tokens.textMuted
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                    width: 2,
                                                  ),
                                                ),
                                                child: row.enabled
                                                    ? Icon(
                                                        Icons.check,
                                                        color: tokens.text,
                                                        size: 12,
                                                      )
                                                    : null,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                row.productName,
                                                style: TextStyle(
                                                  color: row.enabled
                                                      ? tokens.text
                                                      : tokens.textMuted,
                                                  fontSize: 14,
                                                  fontWeight: row.enabled
                                                      ? FontWeight.w500
                                                      : FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Solo los productos activados pueden aparecer como sugerencia rápida habitual al visitar un cliente.',
                            style: TextStyle(
                              color: tokens.textMuted.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: tokens.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  BoxDecoration _whiteCardDeco() => BoxDecoration(
    color: tokens.card,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 1)),
    ],
  );

  Widget _buildVistaRapidaRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String fieldKey,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final enabled = _vistaRapidaFields.contains(fieldKey);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: tokens.textSub, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (v) => _toggleVistaRapidaField(fieldKey, v),
            activeThumbColor: tokens.primaryBlue,
            activeTrackColor: tokens.primaryBlue.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _StockNotifRow {
  final int productoId;
  final String productName;
  final bool enabled;
  final int threshold;

  _StockNotifRow({
    required this.productoId,
    required this.productName,
    required this.enabled,
    required this.threshold,
  });

  _StockNotifRow copyWith({bool? enabled, int? threshold}) {
    return _StockNotifRow(
      productoId: productoId,
      productName: productName,
      enabled: enabled ?? this.enabled,
      threshold: threshold ?? this.threshold,
    );
  }
}

class _HabitualRow {
  final int productoId;
  final String productName;
  final bool enabled;

  _HabitualRow({
    required this.productoId,
    required this.productName,
    required this.enabled,
  });

  _HabitualRow copyWith({bool? enabled}) {
    return _HabitualRow(
      productoId: productoId,
      productName: productName,
      enabled: enabled ?? this.enabled,
    );
  }
}
