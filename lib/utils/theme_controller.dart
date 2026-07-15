import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_tokens.dart';

const String kMobileThemeModePrefsKey = 'mobile_theme_mode';

class MobileThemeController extends ChangeNotifier {
  Brightness _brightness;

  MobileThemeController(this._brightness);

  Brightness get brightness => _brightness;

  Future<void> setMode(Brightness b) async {
    if (b == _brightness) return;
    _brightness = b;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kMobileThemeModePrefsKey,
        b == Brightness.dark ? 'dark' : 'light',
      );
    } catch (_) {
      // Persistence is best-effort; runtime state is already updated.
    }
  }

  Future<void> toggle() => setMode(
    _brightness == Brightness.dark ? Brightness.light : Brightness.dark,
  );

  static Future<MobileThemeController> bootstrap() async {
    Brightness initial = Brightness.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(kMobileThemeModePrefsKey);
      if (saved == 'dark') initial = Brightness.dark;
    } catch (_) {
      // SharedPreferences not ready, so keep the Phase 1 light default.
    }
    return MobileThemeController(initial);
  }
}

@immutable
class AppThemeData {
  final MobileThemeController controller;
  final AppTokens tokens;
  final Brightness brightness;

  const AppThemeData({
    required this.controller,
    required this.tokens,
    required this.brightness,
  });
}

class AppTheme extends InheritedNotifier<MobileThemeController> {
  const AppTheme({
    super.key,
    required MobileThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<AppTheme>();
    assert(
      theme != null,
      'AppTheme not found in widget tree. Wrap the mobile entry with AppTheme.',
    );
    final controller = theme!.notifier!;
    final brightness = controller.brightness;
    final tokens = brightness == Brightness.dark
        ? AppTokens.dark()
        : AppTokens.light();
    return AppThemeData(
      controller: controller,
      tokens: tokens,
      brightness: brightness,
    );
  }
}
