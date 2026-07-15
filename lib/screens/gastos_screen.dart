import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../demo/demo_mode.dart';
import '../utils/parse_number.dart';
import '../utils/app_tokens.dart';
import '../widgets/onboarding/tutorial_controller.dart';
import '../widgets/onboarding/guided_tutorial_overlay.dart';

class GastosScreen extends StatefulWidget {
  const GastosScreen({
    super.key,
    required this.todayGastos,
    required this.productGastos,
    required this.onTodayGastosChanged,
  });

  final List<Map<String, dynamic>> todayGastos;
  final List<Map<String, dynamic>> productGastos;
  final Future<void> Function(List<Map<String, dynamic>>) onTodayGastosChanged;

  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  late List<Map<String, dynamic>> _today;
  final _descCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  bool _saving = false;

  final GlobalKey _kGastoForm = GlobalKey();
  final GlobalKey _kBack = GlobalKey();

  AppTokens get tokens => AppTokens.of(context);

  @override
  void initState() {
    super.initState();
    _today = List<Map<String, dynamic>>.from(widget.todayGastos);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => TutorialController.instance.onGastosOpened(),
    );
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    if (!kDemoAllowLiveFlow && blockDemoAction(context)) return;
    final desc = _descCtrl.text.trim();
    final monto = parseArgNumber(_montoCtrl.text) ?? 0;
    if (desc.isEmpty || monto <= 0) return;
    setState(() {
      _today.add({'descripcion': desc, 'monto': monto});
      _descCtrl.clear();
      _montoCtrl.clear();
      _saving = true;
    });
    await widget.onTodayGastosChanged(_today);
    TutorialController.instance.onGastoSaved();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _eliminar(int i) async {
    if (!kDemoAllowLiveFlow && blockDemoAction(context)) return;
    setState(() => _today.removeAt(i));
    await widget.onTodayGastosChanged(_today);
  }

  String _fmt(double v) {
    final s = v
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '\$$s';
  }

  Widget _wrapGuided(Widget child) => Stack(
    children: [
      child,
      GuidedTutorialOverlay(screen: GuidedScreen.gastos, views: _guidedViews()),
    ],
  );

  Map<GuidedStep, GuidedStepView> _guidedViews() => {
    GuidedStep.registerGasto: GuidedStepView(
      targetKey: _kGastoForm,
      title: kDemoMode ? 'Gastos del día' : 'Registrá un gasto',
      body: kDemoMode
          ? 'En la app completa agregás gastos manuales como nafta, peajes o ayudantes.'
          : 'Poné una descripción y un monto (ej. Nafta — 5000) y tocá «Agregar gasto».',
    ),
    GuidedStep.gastosBack: GuidedStepView(
      targetKey: _kBack,
      title: '¡Perfecto!',
      body: 'Tocá la flecha para volver al inicio.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final total =
        _today.fold<double>(
          0,
          (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0),
        ) +
        widget.productGastos.fold<double>(
          0,
          (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0),
        );

    return _wrapGuided(
      Scaffold(
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
              key: _kBack,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: tokens.text,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'GASTOS',
              style: TextStyle(
                color: tokens.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            centerTitle: false,
            shape: Border(
              bottom: BorderSide(color: tokens.cardBorder, width: 1),
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _totalCard(total),
              SizedBox(height: 20),
              _sectionLabel('AGREGAR GASTO'),
              SizedBox(height: 8),
              KeyedSubtree(key: _kGastoForm, child: _addCard()),
              SizedBox(height: 24),
              if (_today.isNotEmpty) ...[
                _sectionLabel('GASTOS MANUALES'),
                SizedBox(height: 8),
                _manualList(),
                SizedBox(height: 20),
              ],
              if (widget.productGastos.isNotEmpty) ...[
                _sectionLabel('GASTOS DE CARGA'),
                SizedBox(height: 8),
                _productList(),
              ],
              if (_today.isEmpty && widget.productGastos.isEmpty) _emptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: EdgeInsets.only(left: 4),
    child: Text(
      text,
      style: TextStyle(
        color: tokens.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: tokens.card,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 1)),
    ],
  );

  Widget _totalCard(double total) => Container(
    padding: EdgeInsets.all(18),
    decoration: _cardDecoration(),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOTAL',
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Gastos del día',
              style: TextStyle(color: tokens.textSub, fontSize: 12),
            ),
          ],
        ),
        Text(
          _fmt(total),
          style: TextStyle(
            color: tokens.danger,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );

  InputDecoration _inputDecoration(String hint, {Widget? prefix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: tokens.textMuted, fontSize: 14),
        prefixIcon: prefix,
        prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: tokens.bg,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

  Widget _addCard() => Container(
    padding: EdgeInsets.all(14),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        TextField(
          controller: _descCtrl,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: tokens.text, fontSize: 14),
          decoration: _inputDecoration('Descripción (ej. Nafta)'),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _montoCtrl,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: tokens.text, fontSize: 14),
          decoration: _inputDecoration(
            'Monto',
            prefix: Padding(
              padding: EdgeInsets.only(left: 14, right: 6),
              child: Text(
                '\$',
                style: TextStyle(
                  color: tokens.textSub,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _saving ? null : _agregar,
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              disabledBackgroundColor: tokens.disabled,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _saving ? 'Guardando…' : 'Agregar gasto',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _manualList() => Container(
    decoration: _cardDecoration(),
    child: Column(
      children: List.generate(_today.length, (i) {
        final g = _today[i];
        final last = i == _today.length - 1;
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      (g['descripcion'] as String?) ?? '',
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    _fmt(((g['monto'] as num?)?.toDouble() ?? 0)),
                    style: TextStyle(
                      color: tokens.danger,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  SizedBox(width: 4),
                  InkWell(
                    onTap: () => _eliminar(i),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: tokens.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!last)
              Divider(
                color: tokens.cardBorder,
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
          ],
        );
      }),
    ),
  );

  Widget _productList() => Container(
    decoration: _cardDecoration(),
    child: Column(
      children: List.generate(widget.productGastos.length, (i) {
        final g = widget.productGastos[i];
        final last = i == widget.productGastos.length - 1;
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      (g['descripcion'] as String?) ?? '',
                      style: TextStyle(color: tokens.textSub, fontSize: 14),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    _fmt(((g['monto'] as num?)?.toDouble() ?? 0)),
                    style: TextStyle(
                      color: tokens.danger,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (!last)
              Divider(
                color: tokens.cardBorder,
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
          ],
        );
      }),
    ),
  );

  Widget _emptyState() => Padding(
    padding: EdgeInsets.all(32),
    child: Column(
      children: [
        Icon(Icons.receipt_long_outlined, size: 40, color: tokens.textMuted),
        SizedBox(height: 12),
        Text(
          'Sin gastos por ahora',
          style: TextStyle(
            color: tokens.textSub,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Agregá nafta, viáticos, reparaciones…',
          style: TextStyle(color: tokens.textMuted, fontSize: 12),
        ),
      ],
    ),
  );
}
