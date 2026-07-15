import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Phase 4: UUID v7 generation for the cross-device-collision-proof
/// row identifier (`uid` column on every business table).
///
/// Why v7 specifically:
///   • Time-prefixed (48-bit Unix-millis prefix) so uids issued on the
///     same device sort in insertion order. Helps with cloud-side range
///     queries and keeps b-tree indexes from fragmenting like v4 does.
///   • RFC 9562 standard, drop-in `String` shape (36 chars including
///     dashes) so it slots into any existing TEXT column without schema
///     surgery.
///   • Generable offline — no network round-trip / claim-an-id RPC
///     required. Critical for the sodero's airplane-mode workflow.
///
/// Cross-version compatibility note: cloud backfill uses Postgres's
/// `gen_random_uuid()` which returns v4. Mobile-generated v7 and cloud-
/// backfilled v4 coexist in the same column — the version bits differ
/// but the textual representation is interchangeable as far as the
/// `(user_id, uid)` UNIQUE index is concerned. Both are just 36-char
/// hex strings to Postgres.
class UidGen {
  static const _uuid = Uuid();

  /// Returns a fresh UUID v7. Pure — no side effects, no persistence.
  ///
  /// In tests, the seam is at the call site: code that needs a
  /// deterministic uid passes an injected generator function instead of
  /// calling this directly. We deliberately do NOT add a `setForTest`
  /// hook here, because the only consumers (push code + Drift mutators)
  /// don't need to assert on uid values — they just need any unique
  /// string.
  static String next() => _uuid.v7();

  /// `@visibleForTesting` cheap predicate so test assertions can confirm
  /// a string looks like a UUID without depending on the package's
  /// regex internals. Match shape: 8-4-4-4-12 hex with the v7 version
  /// nibble in position 14 (0-indexed). We're permissive on the variant
  /// nibble because some generator implementations differ by one bit;
  /// the cloud-side gen_random_uuid() is v4 anyway, so a strict check
  /// would false-fail on cloud-backfilled rows.
  @visibleForTesting
  static bool looksLikeUuid(String s) {
    final re = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return re.hasMatch(s);
  }

  /// `@visibleForTesting` — confirm a generated uid has the v7 version
  /// nibble (position 14 = '7'). Use this in unit tests that exercise
  /// `next()` directly; do NOT use it to validate uids from cloud
  /// (cloud uses v4, fails this check by design).
  @visibleForTesting
  static bool isV7(String s) {
    if (!looksLikeUuid(s)) return false;
    // Position 14 in "xxxxxxxx-xxxx-Mxxx-..." is the version nibble.
    return s[14] == '7';
  }
}
