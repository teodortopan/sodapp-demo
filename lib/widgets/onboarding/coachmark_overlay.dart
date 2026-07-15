import 'package:flutter/material.dart';

import '../../utils/app_tokens.dart';
import 'coachmark_step.dart';
import 'spotlight_painter.dart';

/// Drives a coachmark walkthrough as a single root-`Overlay` entry that floats
/// above the whole app (including the bottom nav). Owned by the host screen
/// (e.g. HomeScreen), which calls [start] / [dismiss].
class CoachmarkController {
  OverlayEntry? _entry;

  bool get isActive => _entry != null;

  /// Inserts the overlay. [onFinish] fires on natural completion (or a tapped
  /// action target); [onSkip] fires on the X button / Android back. Both run
  /// AFTER the overlay is removed, so the host can navigate safely.
  void start({
    required BuildContext context,
    required List<CoachmarkStep> steps,
    ScrollController? scrollController,
    required VoidCallback onFinish,
    required VoidCallback onSkip,
  }) {
    if (_entry != null || steps.isEmpty) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (_) => CoachmarkOverlay(
        steps: steps,
        scrollController: scrollController,
        onFinish: () {
          dismiss();
          onFinish();
        },
        onSkip: () {
          dismiss();
          onSkip();
        },
      ),
    );
    overlay.insert(_entry!);
  }

  /// Idempotent removal of the overlay entry.
  void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}

class CoachmarkOverlay extends StatefulWidget {
  const CoachmarkOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
    required this.onSkip,
    this.scrollController,
  });

  final List<CoachmarkStep> steps;
  final VoidCallback onFinish;
  final VoidCallback onSkip;
  final ScrollController? scrollController;

  @override
  State<CoachmarkOverlay> createState() => _CoachmarkOverlayState();
}

class _CoachmarkOverlayState extends State<CoachmarkOverlay>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _index = 0;
  Rect? _targetRect;

  late final AnimationController _scrimCtrl; // fades the scrim in once
  late final AnimationController _pulseCtrl; // pulses the ring on action steps

  CoachmarkStep get _step => widget.steps[_index];
  bool get _isLast => _index == widget.steps.length - 1;
  bool get _canGoBack => _index > 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _scrimCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareStep());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrimCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Rotation / resize / keyboard → re-measure the current target.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _remeasure();
    });
  }

  /// Scrolls the current target into view, then measures it on the next frame.
  Future<void> _prepareStep() async {
    final stepIndex = _index;
    final step = _step;
    if (step.targetKey == null) {
      // No-spotlight step (e.g. a closing message): just show the card.
      if (!mounted) return;
      setState(() => _targetRect = null);
      return;
    }
    final ctx = step.targetKey!.currentContext;
    if (ctx == null) {
      // Not laid out yet — retry once next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _index == stepIndex) _prepareStep();
      });
      return;
    }
    try {
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.5, // center the focused widget in the viewport
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      // Second settle pass: re-center after a lazily-built row finishes layout.
      final ctx2 = step.targetKey?.currentContext;
      if (mounted && _index == stepIndex && ctx2 != null) {
        await Scrollable.ensureVisible(
          ctx2,
          alignment: 0.5,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (_) {
      // Target may not be inside a Scrollable — measuring still works.
    }
    if (!mounted || _index != stepIndex) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _index != stepIndex) return;
      final rect = _measure(step);
      if (rect == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _index == stepIndex) _remeasure();
        });
        return;
      }
      setState(() => _targetRect = rect);
    });
  }

  void _remeasure() {
    final rect = _measure(_step);
    if (rect != null && mounted) setState(() => _targetRect = rect);
  }

  /// Measures the target rect in the overlay's own coordinate space (so it
  /// lines up with the spotlight painter and the positioned card).
  Rect? _measure(CoachmarkStep step) {
    if (step.targetKey == null) return null;
    final targetCtx = step.targetKey!.currentContext;
    if (targetCtx == null) return null;
    final box = targetCtx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final overlayBox = context.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    return (topLeft & box.size).inflate(step.spotlightPadding);
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _targetRect = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prepareStep();
    });
  }

  void _back() {
    if (!_canGoBack) return;
    setState(() {
      _index--;
      _targetRect = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prepareStep();
    });
  }

  void _finish() => widget.onFinish();

  void _skip() => widget.onSkip();

  void _onTargetTap() {
    final step = _step;
    widget.onFinish(); // removes overlay + marks seen
    step.onTargetTap?.call(); // host navigates (e.g. to Carga)
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final mq = MediaQuery.of(context);
    final step = _step;
    return Material(
      type: MaterialType.transparency,
      // NOTE: Android back is handled by the host screen's PopScope (this is a
      // bare OverlayEntry, not a route, and the app uses Navigator-based
      // MaterialApp — there is no Router for a BackButtonListener to attach to).
      child: Stack(
        children: [
          // Scrim + spotlight — absorbs taps so the app behind is inert.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // swallow; advance only via the card button
              child: AnimatedBuilder(
                animation: Listenable.merge([_scrimCtrl, _pulseCtrl]),
                builder: (_, _) => CustomPaint(
                  size: Size.infinite,
                  painter: SpotlightPainter(
                    rect: _targetRect,
                    radius: step.spotlightRadius,
                    progress: _scrimCtrl.value,
                    scrimBase: tokens.text,
                    ringColor: tokens.primaryBlue,
                    pulse: step.isActionStep ? _pulseCtrl.value : 0.0,
                  ),
                ),
              ),
            ),
          ),
          // Tappable hot-zone over the target (action steps only).
          if (step.isActionStep && _targetRect != null)
            Positioned(
              left: _targetRect!.left,
              top: _targetRect!.top,
              width: _targetRect!.width,
              height: _targetRect!.height,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onTargetTap,
              ),
            ),
          // Explanatory card (always shown for a no-spotlight step).
          if (_targetRect != null || step.targetKey == null)
            _buildCard(tokens, mq, step),
        ],
      ),
    );
  }

  Widget _buildCard(AppTokens tokens, MediaQueryData mq, CoachmarkStep step) {
    final size = mq.size;
    final rect = _targetRect;
    const cardEstimate = 190.0;
    const gap = 14.0;
    const margin = 16.0;

    final card = Container(
      key: const Key('coachmark_card'),
      constraints: BoxConstraints(maxWidth: size.width - 2 * margin),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    step.title,
                    style: TextStyle(
                      color: tokens.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              _skipBtn(tokens),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              step.body,
              style: TextStyle(
                color: tokens.textSub,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _navRow(tokens),
        ],
      ),
    );

    if (rect == null) {
      // No spotlight — center the card over the dim.
      return Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: margin),
          child: Center(child: card),
        ),
      );
    }

    final spaceBelow = size.height - rect.bottom - mq.padding.bottom;
    final placeBelow = spaceBelow >= cardEstimate + gap;
    return Positioned(
      left: margin,
      right: margin,
      top: placeBelow ? rect.bottom + gap : null,
      bottom: placeBelow ? null : (size.height - rect.top) + gap,
      child: card,
    );
  }

  Widget _navRow(AppTokens tokens) {
    return Row(
      children: [
        _navBtn(Icons.chevron_left_rounded, _canGoBack ? _back : null, tokens),
        const Spacer(),
        Text(
          '${_index + 1} de ${widget.steps.length}',
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        _navBtn(Icons.chevron_right_rounded, _next, tokens),
      ],
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

  Widget _skipBtn(AppTokens tokens) {
    return Material(
      key: const Key('coachmark_skip'),
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _skip,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.close_rounded, color: tokens.textSub, size: 22),
        ),
      ),
    );
  }
}
