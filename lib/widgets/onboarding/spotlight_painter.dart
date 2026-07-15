import 'package:flutter/material.dart';

/// Paints a dim scrim with a rounded-rect "hole" (spotlight) cut out around a
/// target rect, plus an accent ring (and an optional pulse). Shared by the
/// Inicio coachmark and the guided cross-screen tutorial. Colors are passed in
/// because a [CustomPainter] has no [BuildContext].
class SpotlightPainter extends CustomPainter {
  const SpotlightPainter({
    required this.rect,
    required this.radius,
    required this.progress,
    required this.scrimBase,
    required this.ringColor,
    required this.pulse,
  });

  /// Target rect in the painter's coordinate space (null while measuring).
  final Rect? rect;
  final double radius;

  /// 0..1 scrim fade-in.
  final double progress;
  final Color scrimBase;
  final Color ringColor;

  /// 0..1; 0 means no pulse (non-action steps).
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final scrim = Paint()..color = scrimBase.withValues(alpha: 0.72 * progress);
    if (rect == null) {
      canvas.drawRect(full, scrim);
      return;
    }
    final hole = RRect.fromRectAndRadius(rect!, Radius.circular(radius));
    // Punch the spotlight hole with saveLayer + BlendMode.clear. The previous
    // Path.combine(PathOperation.difference) silently failed to subtract the
    // hole on Flutter web (CanvasKit) — the scrim covered the target and only
    // the ring showed. saveLayer + clear is the robust cross-renderer way:
    // fill the dim scrim into an offscreen layer, then clear the hole to
    // transparent before compositing it back.
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, scrim);
    canvas.drawRRect(hole, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // Solid accent ring on the hole edge.
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + pulse * 1.5
        ..color = ringColor.withValues(alpha: 0.9 * progress),
    );

    // Expanding faint pulse ring (action steps) to say "tap here".
    if (pulse > 0) {
      final grow = rect!.inflate(pulse * 10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(grow, Radius.circular(radius + pulse * 10)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = ringColor.withValues(alpha: (1 - pulse) * 0.5 * progress),
      );
    }
  }

  @override
  bool shouldRepaint(SpotlightPainter old) =>
      old.rect != rect ||
      old.radius != radius ||
      old.progress != progress ||
      old.scrimBase != scrimBase ||
      old.ringColor != ringColor ||
      old.pulse != pulse;
}
