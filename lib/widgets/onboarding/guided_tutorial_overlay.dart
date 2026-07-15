import 'package:flutter/material.dart';

import '../../utils/app_tokens.dart';
import 'spotlight_painter.dart';
import 'tutorial_controller.dart';

/// View data for one guided step on a given screen. [targetKey] null means a
/// "top banner" step: no spotlight, just an instruction card pinned at the top
/// (rendered in the root overlay so it stays visible above bottom-sheets) —
/// used for hands-on-in-a-sheet steps and brief page explanations.
class GuidedStepView {
  const GuidedStepView({
    this.targetKey,
    required this.title,
    required this.body,
    this.bannerAtTop = false,
  });

  final GlobalKey? targetKey;
  final String title;
  final String body;

  /// For banner steps (no target): pin at the top (above bottom-sheets) instead
  /// of the bottom. Use top for hands-on-in-a-sheet steps; explanations default
  /// to the bottom so they don't cover the screen's header controls.
  final bool bannerAtTop;

  bool get isBanner => targetKey == null;
}

/// In-tree overlay a screen drops into a `Stack` over its Scaffold. It watches
/// [TutorialController]; when the current step belongs to THIS screen it either
/// spotlights the target (target-only pass-through: 4 barriers absorb taps
/// except the hole) or shows a top banner (no spotlight). The card carries a
/// `‹ n de N ›` control for re-reading explanations + an X to skip.
class GuidedTutorialOverlay extends StatefulWidget {
  const GuidedTutorialOverlay({
    super.key,
    required this.screen,
    required this.views,
  });

  final GuidedScreen screen;
  final Map<GuidedStep, GuidedStepView> views;

  @override
  State<GuidedTutorialOverlay> createState() => _GuidedTutorialOverlayState();
}

class _GuidedTutorialOverlayState extends State<GuidedTutorialOverlay>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TutorialController _c = TutorialController.instance;
  Rect? _rect;
  GuidedStep? _spotlightStep;
  GuidedStepView? _spotlightView;
  OverlayEntry? _bannerEntry;
  late final AnimationController _pulse;
  static const int _maxTargetRetries = 30;
  int _targetRetryCount = 0;
  bool _targetUnavailable = false;

  GuidedStep? get _step {
    final cur = _c.current;
    if (cur == null) return null;
    return widget.views.containsKey(cur) ? cur : null;
  }

  GuidedStepView? get _view {
    final s = _step;
    return s == null ? null : widget.views[s];
  }

  bool get _isSpotlight => _view != null && !_view!.isBanner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _c.addListener(_onController);
    _syncPulse();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncBanner();
      _prepare();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_onController);
    _bannerEntry?.remove();
    _bannerEntry = null;
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
  }

  void _onController() {
    if (!mounted) return;
    setState(() {
      _targetRetryCount = 0;
      _targetUnavailable = false;
      final nextStep = _step;
      if (!_isSpotlight || _spotlightStep != nextStep) {
        _rect = null;
        _spotlightStep = null;
        _spotlightView = null;
      }
    });
    _syncBanner();
    _syncPulse();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prepare();
    });
  }

  void _syncPulse() {
    final shouldRun = _isSpotlight && !_targetUnavailable;
    if (shouldRun && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!shouldRun && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  /// Manage the root-overlay top banner for null-target steps.
  void _syncBanner() {
    if (!mounted) return;
    final isBanner = _view?.isBanner ?? false;
    if (isBanner) {
      if (_bannerEntry == null) {
        final overlay = Overlay.of(context, rootOverlay: true);
        _bannerEntry = OverlayEntry(builder: _buildBanner);
        overlay.insert(_bannerEntry!);
      } else {
        _bannerEntry!.markNeedsBuild();
      }
    } else {
      _bannerEntry?.remove();
      _bannerEntry = null;
    }
  }

  Future<void> _prepare() async {
    if (!_isSpotlight || _targetUnavailable) return;
    final step = _step;
    final view = _view;
    if (step == null || view == null || view.isBanner) return;
    final ctx = view.targetKey!.currentContext;
    if (ctx == null) {
      if (_markTargetUnavailableAfterRetries()) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _c.current == step) _prepare();
      });
      return;
    }
    _targetRetryCount = 0;
    try {
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.5, // center the focused widget in the viewport
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      // Second settle pass: a conditionally-built/keyed row (e.g. the addQty
      // +/− controls) may only just have been laid out, so re-center it before
      // measuring — otherwise the spotlight can land half-off-screen.
      final ctx2 = view.targetKey!.currentContext;
      if (mounted && _c.current == step && ctx2 != null) {
        await Scrollable.ensureVisible(
          ctx2,
          alignment: 0.5,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (_) {}
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _c.current == step) _measure(step, view);
    });
  }

  void _measure([GuidedStep? expectedStep, GuidedStepView? expectedView]) {
    if (!_isSpotlight || _targetUnavailable) return;
    final step = expectedStep ?? _step;
    final view = expectedView ?? _view;
    if (step == null || view == null || view.isBanner || _c.current != step) {
      return;
    }
    final tctx = view.targetKey!.currentContext;
    final box = tctx?.findRenderObject() as RenderBox?;
    final selfBox = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || selfBox == null || !selfBox.attached) {
      if (_markTargetUnavailableAfterRetries()) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _c.current == step) _measure(step, view);
      });
      return;
    }
    _targetRetryCount = 0;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: selfBox);
    setState(() {
      _spotlightStep = step;
      _spotlightView = view;
      _rect = (topLeft & box.size).inflate(8);
    });
  }

  bool _markTargetUnavailableAfterRetries() {
    _targetRetryCount++;
    if (_targetRetryCount < _maxTargetRetries) return false;
    if (mounted) {
      setState(() => _targetUnavailable = true);
      _syncPulse();
    }
    return true;
  }

  // ─── In-tree spotlight rendering ───

  @override
  Widget build(BuildContext context) {
    if (!_isSpotlight) return const SizedBox.shrink();
    final tokens = AppTokens.of(context);
    final desiredView = _view!;
    if (_targetUnavailable) {
      return Positioned.fill(
        child: Stack(children: [_fallbackCard(tokens, desiredView)]),
      );
    }
    final rect = _rect;
    final view = _spotlightStep == _step ? desiredView : _spotlightView;
    if (rect == null || view == null) return _measuringScrim(tokens);
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, _) => CustomPaint(
                  size: Size.infinite,
                  painter: SpotlightPainter(
                    rect: rect,
                    radius: 14,
                    progress: 1.0,
                    scrimBase: tokens.text,
                    ringColor: tokens.primaryBlue,
                    pulse: _pulse.value,
                  ),
                ),
              ),
            ),
          ),
          ..._barriers(rect),
          _spotlightCard(tokens, view),
        ],
      ),
    );
  }

  Widget _measuringScrim(AppTokens tokens) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: CustomPaint(
          size: Size.infinite,
          painter: SpotlightPainter(
            rect: null,
            radius: 14,
            progress: 1.0,
            scrimBase: tokens.text,
            ringColor: tokens.primaryBlue,
            pulse: 0.0,
          ),
        ),
      ),
    );
  }

  List<Widget> _barriers(Rect? rect) {
    if (rect == null) {
      return [Positioned.fill(child: _absorb())];
    }
    final size = MediaQuery.of(context).size;
    final top = rect.top.clamp(0.0, size.height);
    final bottom = rect.bottom.clamp(0.0, size.height);
    final left = rect.left.clamp(0.0, size.width);
    final right = rect.right.clamp(0.0, size.width);
    return [
      Positioned(left: 0, top: 0, right: 0, height: top, child: _absorb()),
      Positioned(left: 0, top: bottom, right: 0, bottom: 0, child: _absorb()),
      Positioned(
        left: 0,
        top: top,
        width: left,
        height: (bottom - top).clamp(0.0, size.height),
        child: _absorb(),
      ),
      Positioned(
        left: right,
        top: top,
        right: 0,
        height: (bottom - top).clamp(0.0, size.height),
        child: _absorb(),
      ),
    ];
  }

  Widget _absorb() =>
      GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {});

  Widget _spotlightCard(AppTokens tokens, GuidedStepView view) {
    final mq = MediaQuery.of(context);
    final rect = _rect!;
    final atTop = rect.center.dy > mq.size.height * 0.55;
    return Positioned(
      left: 16,
      right: 16,
      top: atTop ? mq.padding.top + 12 : null,
      bottom: atTop ? null : mq.padding.bottom + 20,
      child: Material(
        type: MaterialType.transparency,
        child: _cardChrome(tokens, view),
      ),
    );
  }

  Widget _fallbackCard(AppTokens tokens, GuidedStepView view) {
    final mq = MediaQuery.of(context);
    return Positioned(
      left: 16,
      right: 16,
      top: mq.padding.top + 12,
      child: Material(
        type: MaterialType.transparency,
        child: _cardChrome(tokens, view),
      ),
    );
  }

  // ─── Root-overlay top banner rendering ───

  Widget _buildBanner(BuildContext ctx) {
    final view = _view;
    if (view == null || !view.isBanner) return const SizedBox.shrink();
    final tokens = AppTokens.of(ctx);
    final mq = MediaQuery.of(ctx);
    final atTop = view.bannerAtTop;
    return Positioned(
      top: atTop ? mq.padding.top + 10 : null,
      bottom: atTop ? null : mq.padding.bottom + 88,
      left: 16,
      right: 16,
      child: Material(
        type: MaterialType.transparency,
        child: _cardChrome(tokens, view),
      ),
    );
  }

  // ─── Shared card ───

  Widget _cardChrome(AppTokens tokens, GuidedStepView view) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        view.title,
                        style: TextStyle(
                          color: tokens.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        view.body,
                        style: TextStyle(
                          color: tokens.textSub,
                          fontSize: 13.5,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _skipBtn(tokens),
            ],
          ),
          _navRow(tokens),
        ],
      ),
    );
  }

  Widget _navRow(AppTokens tokens) {
    return Row(
      children: [
        _navBtn(
          Icons.chevron_left_rounded,
          _c.canGoBack ? _c.back : null,
          tokens,
        ),
        const Spacer(),
        Text(
          '${_c.stepNumber} de ${_c.totalSteps}',
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        _navBtn(
          Icons.chevron_right_rounded,
          _c.canGoForward ? _c.forwardManual : null,
          tokens,
        ),
      ],
    );
  }

  Widget _skipBtn(AppTokens tokens) {
    return Material(
      key: const Key('guided_skip'),
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _c.skip,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.close_rounded, color: tokens.textSub, size: 22),
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap, AppTokens tokens) {
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? tokens.primaryBlue.withValues(alpha: 0.12)
          : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 24,
            color: enabled
                ? tokens.primaryBlue
                : tokens.textMuted.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}
