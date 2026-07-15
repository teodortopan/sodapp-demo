import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hybrid logical clock used as the authoritative source for every
/// `updated_at` timestamp on dirty rows in this device's local DB.
///
/// Why: the cloud `reject_stale_update` trigger compares client-stamped
/// `updated_at` values to arbitrate writes. If a phone's wall clock runs
/// backwards (NTP correction, daylight-savings transition, manual change)
/// the next dirty stamp produces a `updated_at` LOWER than the previous
/// one — causing the trigger to silently reject real edits or, worse,
/// letting stale data win. The hybrid clock ratchets the counter forward
/// monotonically per-device, surviving wall-clock skew.
///
/// Semantics: [nextMs] returns `max(wallclock_ms, counter + 1)` and
/// advances the in-memory counter. The counter is persisted to
/// SharedPreferences (fire-and-forget) so a process restart on a device
/// whose wall clock rolled back still emits strictly increasing
/// timestamps.
///
/// First-call bootstrap: [nextMs] is synchronous (callers in app_database
/// can't easily be made async). The first invocation kicks off an async
/// reconciliation against the persisted value. Between that first call
/// and the bootstrap completing, the returned value is just wall-clock —
/// which matches the pre-Phase-5 behaviour, so no regression. After
/// bootstrap completes, the counter is at least as large as any
/// previously-persisted value.
///
/// For deterministic startup, call [warmUp] from main.dart / splash
/// before any database mutation can fire.
class LogicalClock {
  LogicalClock._();

  static int _counter = 0;
  static bool _bootstrapped = false;
  static Future<void>? _bootstrap;

  static const String _prefKey = 'sync.logical_clock_counter';

  /// Synchronous next-timestamp. Returns the larger of wall-clock and
  /// (current counter + 1), advances the counter, and fires off a
  /// background persist so a future restart picks up where this one
  /// left off.
  static int nextMs() {
    final wall = DateTime.now().millisecondsSinceEpoch;
    final next = wall > _counter ? wall : _counter + 1;
    _counter = next;
    if (!_bootstrapped) {
      _bootstrap ??= _warmUpInternal();
    } else {
      // Cheap fire-and-forget persist; the only failure mode is "next
      // restart's counter is slightly stale" which the bootstrap on that
      // restart corrects against wall-clock.
      unawaited(_persist());
    }
    return next;
  }

  /// Optional explicit warm-up — call once from app bootstrap (main.dart
  /// or splash) before any DB mutation can fire. Idempotent.
  static Future<void> warmUp() async {
    if (_bootstrapped) return;
    _bootstrap ??= _warmUpInternal();
    return _bootstrap;
  }

  /// P1-7 (pre-release audit #7): how far the persisted counter may lead
  /// the wall clock before warmUp re-anchors it. The monotonic ratchet
  /// correctly survives BACKWARD wall jumps, but a transient FORWARD
  /// excursion (user sets the date to 2027, broken NTP) used to poison the
  /// counter permanently — every subsequent edit carried a far-future
  /// updated_at and won every LWW arbitration until real time caught up.
  /// Re-anchoring on restart bounds the damage to one session; the cloud
  /// side additionally clamps pushed timestamps to now()+10min (see the
  /// P1-7 reject_stale_update phase in supabase_schema.sql).
  static const int _maxLeadMs = 24 * 60 * 60 * 1000; // 24 h

  static Future<void> _warmUpInternal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var persisted = prefs.getInt(_prefKey) ?? 0;
      final wall = DateTime.now().millisecondsSinceEpoch;
      if (persisted > wall + _maxLeadMs) {
        debugPrint(
          '[LogicalClock] persisted counter leads wall clock by '
          '${persisted - wall}ms — re-anchoring to wall (P1-7 future-'
          'excursion heal)',
        );
        persisted = wall;
      }
      if (persisted > _counter) _counter = persisted;
    } catch (e) {
      debugPrint('[LogicalClock] warmUp read failed (non-fatal): $e');
    }
    _bootstrapped = true;
    unawaited(_persist());
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, _counter);
    } catch (e) {
      // Only the next restart cares about persistence; a transient prefs
      // failure isn't worth surfacing or retrying.
      debugPrint('[LogicalClock] persist failed (non-fatal): $e');
    }
  }

  /// Test-only: reset the in-memory state. Call between unit tests so each
  /// case starts from a clean slate.
  @visibleForTesting
  static void resetForTest() {
    _counter = 0;
    _bootstrapped = false;
    _bootstrap = null;
  }

  /// Test-only: peek the current counter without advancing it.
  @visibleForTesting
  static int peekCounter() => _counter;

  /// Test-only: seed the in-memory counter (simulates a prior session).
  @visibleForTesting
  static void seedCounter(int value) {
    _counter = value;
    _bootstrapped = true;
  }
}
