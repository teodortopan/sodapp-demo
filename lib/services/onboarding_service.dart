import 'package:shared_preferences/shared_preferences.dart';

/// Per-user, device-local flag tracking whether the user has already seen (or
/// skipped) the Inicio onboarding tutorial. Stored in SharedPreferences with a
/// userId-namespaced key, mirroring the per-user key pattern in
/// `sync_service.dart`. Intentionally NOT a synced `user_settings` column —
/// re-onboarding on a new device is harmless for a tutorial, and this keeps the
/// feature free of any schema migration.
class OnboardingService {
  OnboardingService._();

  static String _kSeenKey(String userId) => 'onboarding_seen_$userId';

  /// True if this user already saw/skipped the Inicio tutorial. Returns `true`
  /// on an empty userId or a read error so a flaky read never re-triggers the
  /// auto-launch and nags the user.
  static Future<bool> hasSeenInicioTutorial(String userId) async {
    if (userId.isEmpty) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kSeenKey(userId)) ?? false;
    } catch (_) {
      return true;
    }
  }

  /// Marks the Inicio tutorial as seen for this user. Best-effort.
  static Future<void> markInicioTutorialSeen(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSeenKey(userId), true);
    } catch (_) {
      // best-effort; a failed write just means the tutorial may show again.
    }
  }
}
