import 'package:flutter/widgets.dart';

/// One step of a coachmark walkthrough: a target widget to spotlight plus the
/// plain-language explanation shown beside it. Pure data — the overlay does all
/// measurement and rendering. Extending the tutorial later (more Inicio steps,
/// or steps on other pages once their keys exist) is just appending more of
/// these to a `List<CoachmarkStep>`.
class CoachmarkStep {
  /// Key attached (via `KeyedSubtree`) to the widget this step highlights. Null
  /// means a no-spotlight step (e.g. a closing message): the card is centered
  /// over a plain dim, with nothing highlighted.
  final GlobalKey? targetKey;
  final String title;
  final String body;

  /// Logical-pixel padding baked around the measured target so the spotlight
  /// hole breathes.
  final double spotlightPadding;

  /// Corner radius of the spotlight cutout (matches card radii by default).
  final double spotlightRadius;

  /// When non-null, this is an *action* step: the highlighted target becomes
  /// tappable, the explanatory card invites the user to tap it, and tapping it
  /// finishes the tutorial and runs this callback (e.g. the final "tap Carga"
  /// hand-off into a future Carga walkthrough).
  final VoidCallback? onTargetTap;

  const CoachmarkStep({
    this.targetKey,
    required this.title,
    required this.body,
    this.spotlightPadding = 8,
    this.spotlightRadius = 16,
    this.onTargetTap,
  });

  bool get isActionStep => onTargetTap != null;
}
