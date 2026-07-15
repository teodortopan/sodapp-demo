import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/app_database.dart';
import '../demo/demo_mode.dart';
import '../utils/app_tokens.dart';
import '../widgets/onboarding/tutorial_controller.dart';
import '../widgets/onboarding/guided_tutorial_overlay.dart';

class MasMenuItem {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  final GlobalKey? guideKey;

  MasMenuItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
    this.destructive = false,
    this.guideKey,
  });
}

class MasSection {
  final String label;
  final List<MasMenuItem> items;
  MasSection({required this.label, required this.items});
}

class MasScreen extends StatefulWidget {
  const MasScreen({
    super.key,
    required this.userName,
    required this.userAvatar,
    required this.activeRepartoLabel,
    required this.onOpenProfile,
    required this.onOpenCarga,
    required this.onOpenGastos,
    required this.onOpenClientes,
    required this.onOpenEtiquetas,
    required this.onOpenResumenDiario,
    required this.onOpenResumenAnual,
    required this.onOpenConfiguracion,
    required this.onReplayTutorial,
    required this.onSignOut,
  });

  final String? userName;
  final Widget userAvatar;
  final String activeRepartoLabel;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenCarga;
  final VoidCallback onOpenGastos;
  final VoidCallback onOpenClientes;
  final VoidCallback onOpenEtiquetas;
  final VoidCallback onOpenResumenDiario;
  final VoidCallback onOpenResumenAnual;
  final VoidCallback onOpenConfiguracion;
  final VoidCallback onReplayTutorial;
  final VoidCallback onSignOut;

  @override
  State<MasScreen> createState() => _MasScreenState();
}

class _MasScreenState extends State<MasScreen> {
  bool? _subscriptionPaid;

  final GlobalKey _kProfileHeader = GlobalKey();
  final GlobalKey _kClientes = GlobalKey();
  final GlobalKey _kEtiquetas = GlobalKey();
  final GlobalKey _kResDiario = GlobalKey();
  final GlobalKey _kResAnual = GlobalKey();
  final GlobalKey _kConfig = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (!kDemoMode) {
      AppDatabase.instance.addDataListener(_onDbChanged);
      _loadSubscriptionPaid();
    }
  }

  @override
  void dispose() {
    if (!kDemoMode) {
      AppDatabase.instance.removeDataListener(_onDbChanged);
    }
    super.dispose();
  }

  Future<void> _loadSubscriptionPaid() async {
    final paid = await AppDatabase.instance.getSubscriptionPaid();
    if (!mounted) return;
    setState(() => _subscriptionPaid = paid);
  }

  void _onDbChanged() {
    _loadSubscriptionPaid();
  }

  List<MasSection> _sections(AppTokens tokens) => [
    MasSection(
      label: 'DÍA',
      items: [
        MasMenuItem(
          icon: Icons.local_shipping_outlined,
          iconBg: tokens.actionRowGastosTint,
          iconColor: tokens.danger,
          title: 'Registrar carga',
          subtitle: 'Botellones de 20L, 12L…',
          onTap: widget.onOpenCarga,
        ),
        MasMenuItem(
          icon: Icons.payments_outlined,
          iconBg: tokens.actionRowCargaTint,
          iconColor: tokens.primaryBlue,
          title: 'Registrar gastos',
          subtitle: 'Nafta, viáticos, reparación…',
          onTap: widget.onOpenGastos,
        ),
      ],
    ),
    MasSection(
      label: 'GESTIÓN',
      items: [
        MasMenuItem(
          icon: Icons.people_outline,
          iconBg: tokens.success.withValues(alpha: 0.12),
          iconColor: tokens.success,
          title: 'Clientes',
          guideKey: _kClientes,
          onTap: widget.onOpenClientes,
        ),
        MasMenuItem(
          icon: Icons.label_outline,
          iconBg: tokens.warn.withValues(alpha: 0.14),
          iconColor: tokens.warn,
          title: 'Etiquetas',
          guideKey: _kEtiquetas,
          onTap: widget.onOpenEtiquetas,
        ),
      ],
    ),
    MasSection(
      label: 'RESÚMENES',
      items: [
        MasMenuItem(
          icon: Icons.receipt_long_outlined,
          iconBg: tokens.primaryBlue.withValues(alpha: 0.10),
          iconColor: tokens.primaryBlue,
          title: 'Resumen diario',
          guideKey: _kResDiario,
          onTap: widget.onOpenResumenDiario,
        ),
        MasMenuItem(
          icon: Icons.bar_chart_outlined,
          iconBg: tokens.actionRowCargaTint,
          iconColor: tokens.primaryBlue,
          title: 'Resumen anual',
          guideKey: _kResAnual,
          onTap: widget.onOpenResumenAnual,
        ),
      ],
    ),
    MasSection(
      label: 'CUENTA',
      items: [
        MasMenuItem(
          icon: Icons.school_outlined,
          iconBg: tokens.primaryBlue.withValues(alpha: 0.10),
          iconColor: tokens.primaryBlue,
          title: 'Tutorial',
          subtitle: 'Aprendé a usar la app',
          onTap: widget.onReplayTutorial,
        ),
        MasMenuItem(
          icon: Icons.settings_outlined,
          iconBg: tokens.surface2,
          iconColor: tokens.textSub,
          title: 'Configuración',
          guideKey: _kConfig,
          onTap: widget.onOpenConfiguracion,
        ),
        MasMenuItem(
          icon: Icons.logout_rounded,
          iconBg: tokens.danger.withValues(alpha: 0.12),
          iconColor: tokens.danger,
          title: 'Cerrar sesión',
          onTap: widget.onSignOut,
          destructive: true,
        ),
      ],
    ),
  ];

  Widget _wrapGuided(Widget child) => Stack(
    children: [
      child,
      GuidedTutorialOverlay(
        screen: GuidedScreen.mas,
        views: {
          GuidedStep.openProfile: GuidedStepView(
            targetKey: _kProfileHeader,
            title: 'Tu perfil',
            body: kDemoMode
                ? 'Este perfil de ejemplo muestra dónde se configura la cuenta en la app completa.'
                : 'Tocá tu perfil para configurar tu cuenta y tu reparto.',
          ),
          GuidedStep.p2GotoClientes: GuidedStepView(
            targetKey: _kClientes,
            title: 'Tus clientes',
            body: kDemoMode
                ? 'Acá ves la agenda de clientes. En la app completa también los editás.'
                : 'Acá ves y editás tus clientes. Tocá para verlo.',
          ),
          GuidedStep.p2GotoEtiquetas: GuidedStepView(
            targetKey: _kEtiquetas,
            title: 'Etiquetas',
            body: 'Tocá para ver cómo organizás a tus clientes con etiquetas.',
          ),
          GuidedStep.p2GotoResDiario: GuidedStepView(
            targetKey: _kResDiario,
            title: 'Resumen diario',
            body: 'Tocá para ver el historial de tus días de trabajo.',
          ),
          GuidedStep.p2GotoResAnual: GuidedStepView(
            targetKey: _kResAnual,
            title: 'Resumen anual',
            body: 'Tocá para ver tus números de todo el año.',
          ),
          GuidedStep.p2GotoConfig: GuidedStepView(
            targetKey: _kConfig,
            title: 'Configuración',
            body: 'Tocá para ver los ajustes de la app.',
          ),
          GuidedStep.p2Clientes: GuidedStepView(
            title: 'Clientes',
            body:
                'Acá administrás tus clientes por día. Cuando termines, volvé atrás (←) para seguir.',
          ),
          GuidedStep.p2Etiquetas: GuidedStepView(
            title: 'Etiquetas',
            body:
                'Acá ves las etiquetas con las que agrupás clientes. Volvé atrás (←) para seguir.',
          ),
          GuidedStep.p2ResDiario: GuidedStepView(
            title: 'Resumen diario',
            body:
                'El historial de tus días: lo cobrado, gastos y duración. Volvé atrás (←) para seguir.',
          ),
          GuidedStep.p2ResAnual: GuidedStepView(
            title: 'Resumen anual',
            body:
                'Tus totales del año: ventas, gastos y ganancia. Volvé atrás (←) para seguir.',
          ),
          GuidedStep.p2Config: GuidedStepView(
            title: 'Configuración',
            body: kDemoMode
                ? 'Ajustes de la app: tema, días de trabajo, notificaciones y más. En el demo son de solo lectura.'
                : 'Ajustes: tema, días de trabajo, notificaciones y más. Volvé atrás (←) para seguir.',
          ),
          GuidedStep.tutorialDone: GuidedStepView(
            title: kDemoMode
                ? '¡Listo! Ya viste cómo funciona'
                : '¡Listo! Ya sabés usar la app',
            body: kDemoMode
                ? 'Cuando uses la app completa, estos mismos flujos quedan habilitados con tus datos reales.'
                : '¡A trabajar! Podés repetir este tutorial cuando quieras desde «Tutorial».',
          ),
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final sections = _sections(tokens);
    return _wrapGuided(
      AnnotatedRegion<SystemUiOverlayStyle>(
        value: tokens.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Container(
          color: tokens.bg,
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _header(tokens),
                SizedBox(height: 20),
                for (var i = 0; i < sections.length; i++) ...[
                  _sectionLabel(sections[i].label, tokens),
                  SizedBox(height: 8),
                  _sectionCard(sections[i].items, tokens),
                  if (i < sections.length - 1) SizedBox(height: 20),
                ],
                SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Profile card — stands out via size, padding and a slightly deeper
  // shadow rather than gradients or accent borders. Quieter than the
  // previous treatment.
  Widget _header(AppTokens tokens) => Material(
    color: tokens.card,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: _kProfileHeader,
            onTap: widget.onOpenProfile,
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 20, 18, 20),
              child: Row(
                children: [
                  SizedBox(width: 52, height: 52, child: widget.userAvatar),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Reparto is the primary line — soderos identify
                        // themselves by which route they're on first.
                        Text(
                          widget.activeRepartoLabel,
                          style: TextStyle(
                            color: tokens.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 3),
                        Text(
                          widget.userName ?? 'Mi cuenta',
                          style: TextStyle(color: tokens.textSub, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: tokens.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (!kDemoMode && _subscriptionPaid == false)
            _buildSubscriptionReminder(tokens),
        ],
      ),
    ),
  );

  Widget _buildSubscriptionReminder(AppTokens tokens) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Divider(color: tokens.cardBorder, height: 1, indent: 0, endIndent: 0),
      Padding(
        padding: EdgeInsets.fromLTRB(18, 14, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tokens.warn.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.payments_outlined,
                    color: tokens.warn,
                    size: 22,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      Text(
                        'Suscripción pendiente',
                        style: TextStyle(
                          color: tokens.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'PAGO MENSUAL',
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Padding(
              padding: EdgeInsets.only(left: 4, right: 16),
              child: Text(
                'Tu pago mensual está pendiente. Por favor, regularizá '
                'tu suscripción para seguir usando todas las funciones '
                'de la app.',
                style: TextStyle(
                  color: tokens.textSub,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _sectionLabel(String text, AppTokens tokens) => Padding(
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

  Widget _sectionCard(List<MasMenuItem> items, AppTokens tokens) => Container(
    decoration: BoxDecoration(
      color: tokens.card,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 8,
          offset: Offset(0, 1),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _itemRow(items[i], tokens),
          if (i < items.length - 1)
            Divider(
              color: tokens.cardBorder,
              height: 1,
              indent: 64,
              endIndent: 0,
            ),
        ],
      ],
    ),
  );

  Widget _itemRow(MasMenuItem item, AppTokens tokens) => Material(
    key: item.guideKey,
    color: Colors.transparent,
    child: InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 18, color: item.iconColor),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: item.destructive ? tokens.danger : tokens.text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                    SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: TextStyle(color: tokens.textMuted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: item.destructive ? tokens.danger : tokens.textMuted,
            ),
          ],
        ),
      ),
    ),
  );
}
