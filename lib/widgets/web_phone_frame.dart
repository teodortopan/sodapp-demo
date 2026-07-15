import 'package:flutter/material.dart';

/// Constrains the mobile UI to a phone-width column when the sodero app runs
/// in a desktop browser (the demo web build). Without this the layout would
/// stretch edge-to-edge across the window and look nothing like the phone app.
///
/// It also overrides `MediaQuery.size` (and the inset/padding fields) to the
/// phone box, so screens that branch on width compute a phone layout instead
/// of a desktop one. The clamped `textScaler` set by the outer MediaQuery is
/// preserved (we only copyWith the geometry).
///
/// Only mounted on web (see the `kIsWeb` guard in `main.dart`); on real
/// devices the app is full-screen as usual.
class WebPhoneFrame extends StatelessWidget {
  const WebPhoneFrame({super.key, required this.child});

  final Widget child;

  /// Logical width of a typical phone (Pixel-class). The UI was designed for
  /// this ballpark, so the demo reads like the real app.
  static const double phoneWidth = 412;

  /// Above this available height the frame floats as a rounded "device" with a
  /// backdrop + shadow; at or below it the frame fills the height edge-to-edge.
  static const double _maxDeviceHeight = 900;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return ColoredBox(
      color: const Color(0xFF0E1013),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final available = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : _maxDeviceHeight;
            final bool floating = available > _maxDeviceHeight;
            final double frameHeight = floating ? _maxDeviceHeight : available;
            final double frameWidth =
                constraints.maxWidth.isFinite &&
                    constraints.maxWidth < phoneWidth
                ? constraints.maxWidth
                : phoneWidth;

            final radius = BorderRadius.circular(floating ? 28 : 0);

            // Inner MediaQuery: the app inside the frame believes the screen
            // is exactly the phone box. Insets/padding are zeroed (no system
            // bars in a browser); textScaler is carried over from `mq`.
            final framed = MediaQuery(
              data: mq.copyWith(
                size: Size(frameWidth, frameHeight),
                padding: EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                systemGestureInsets: EdgeInsets.zero,
              ),
              child: SizedBox(
                width: frameWidth,
                height: frameHeight,
                child: child,
              ),
            );

            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: floating
                    ? const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
                border: floating
                    ? null
                    : const Border(
                        left: BorderSide(color: Color(0x14FFFFFF)),
                        right: BorderSide(color: Color(0x14FFFFFF)),
                      ),
              ),
              child: ClipRRect(borderRadius: radius, child: framed),
            );
          },
        ),
      ),
    );
  }
}
