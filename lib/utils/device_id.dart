import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'uid_gen.dart';

/// Phase 15a — per-install device identifier for definitive self-push
/// detection on the realtime channel.
///
/// The previous self-push check (sync_service.dart `isSelfPush`) compared
/// `(newSync, selfSync) within 250ms`. The 250ms window was deliberate
/// because of network jitter, but it had a flip-side cost: a genuine
/// foreign push that happened to land within 250ms of our own would be
/// false-positive suppressed (Codex finding CB).
///
/// Including a per-install UUID in the sync_metadata payload removes the
/// ambiguity. The push includes `device_instance_id`; the realtime
/// callback compares it against this device's id:
///   • match  → definitely our own echo, suppress.
///   • differ → definitely a peer, pull.
///   • missing on either side → fall back to the 250ms heuristic
///     (backwards-compat with pre-15a builds that don't stamp the id).
class DeviceId {
  static const _kPrefKey = 'sync.device_instance_id';

  static String? _cached;

  /// Returns this install's device id. Generates a UUID v7 on first
  /// call, persists to SharedPreferences, and caches in-memory for
  /// fast subsequent reads. Idempotent across hot reload + cold start.
  ///
  /// On SharedPreferences failure (extremely rare), generates an
  /// in-memory only id — the device falls back to the 250ms timestamp
  /// heuristic for self-push detection.
  static Future<String> get() async {
    if (_cached != null) return _cached!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_kPrefKey);
      if (existing != null && existing.isNotEmpty) {
        _cached = existing;
        return existing;
      }
      final fresh = UidGen.next();
      await prefs.setString(_kPrefKey, fresh);
      _cached = fresh;
      return fresh;
    } catch (e) {
      debugPrint(
        '[DeviceId] SharedPreferences failure ($e) — using in-memory id only',
      );
      _cached ??= UidGen.next();
      return _cached!;
    }
  }

  /// Test seam: reset the in-memory cache. Combined with
  /// SharedPreferences.setMockInitialValues, lets tests inject a
  /// specific device id.
  @visibleForTesting
  static void resetForTest() {
    _cached = null;
  }

  /// Test seam: peek the cached value without forcing a SharedPreferences
  /// round-trip.
  @visibleForTesting
  static String? peekCached() => _cached;
}
