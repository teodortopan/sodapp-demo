/// «Instancias» (v85) — pure merge functions for the two user_settings
/// JSON registries that sync across devices:
///
///   • `instances_json`        — the per-reparto "vistas" registry
///     (entries keyed by `id`).
///   • `active_recorridos_json` — running/ended recorrido sessions
///     (entries keyed by `(repartoId, day)`).
///
/// Both columns used to sync whole-array LWW (last push wins). With
/// parallelism WITHIN a reparto — two phones running Thursday's and
/// Friday's route at the same time on the same account — whole-array
/// LWW silently drops the other phone's entry. These merges make every
/// push/pull a per-entry arbitration instead, so no device can clobber
/// a sibling's day.
///
/// Pure functions on decoded lists — no DB, no clocks, no I/O — so the
/// arbitration rules are exhaustively unit-testable. Callers supply
/// `nowMs` (retention pruning) and stamp the per-entry clocks
/// (`updatedAtMs` / `lastTouchMs` / `statusTouchMs`) with
/// `LogicalClock.nextMs()` at write time.
///
/// Old-version tolerance: entries written by pre-v85 builds carry none
/// of the new fields. Their freshness degrades to `startMillis` /
/// `endMillis`, their owner degrades to the reparto's default instance,
/// and an old build's whole-array push merges cleanly (its entries are
/// just one side of the per-entry arbitration).
library;

import 'dart:convert';

/// GC horizons (Codex review of the v85 diffs).
///
/// A tombstone may only be GC'd once it is implausible that any device
/// still holds the LIVE state it tombstones — otherwise a phone offline
/// longer than the horizon comes back, merges its stale live entry
/// against an array whose tombstone is gone, and resurrects it. Cleared
/// recorridos and deleted vistas therefore keep their tombstones for a
/// long horizon (an offline window beyond it means a retired device).
/// Both arrays stay bounded: recorrido entries are keyed (repartoId,
/// day) — a re-run REPLACES the key's tombstone — and deleted vistas
/// are a handful per account, GC'd at the same horizon.
///
/// ENDED (non-cleared) recorridos are different: they're the resume
/// affordance, invisible once stale, and a returning device's own merge
/// prunes its >7d ended entries before they can re-enter cloud — no
/// resurrection vector, so they keep the short horizon.
const Duration kRecorridoTombstoneRetention = Duration(days: 180);
const Duration kInstanceTombstoneRetention = Duration(days: 180);
const Duration kEndedRecorridoRetention = Duration(days: 7);

/// Tolerant decode for the JSON-array columns: null / '' / '[]' /
/// malformed / non-list / non-map elements all degrade to "no entries"
/// instead of throwing mid-sync.
List<Map<String, dynamic>> decodeJsonList(String? raw) {
  if (raw == null || raw.isEmpty || raw == '[]') return [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return [
      for (final e in decoded)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  } catch (_) {
    return [];
  }
}

/// Canonical encoding used for change detection (merged vs local vs
/// cloud). jsonEncode of the decoded list — key order follows parse
/// order, which is stable enough: a false mismatch costs one redundant
/// (idempotent) push, never a loss.
String encodeJsonList(List<Map<String, dynamic>> list) => jsonEncode(list);

int _asMs(Object? v) => v is num ? v.toInt() : 0;

/// Freshness of an entry's SCALAR fields (start/end/instanceId/fecha…).
/// `lastTouchMs` is stamped by v85+ mutators on every scalar mutation;
/// legacy entries degrade to their start/end timestamps.
int recorridoScalarFreshness(Map<String, dynamic> e) {
  final start = _asMs(e['startMillis']);
  final end = _asMs(e['endMillis']);
  final touch = _asMs(e['lastTouchMs']);
  var f = start;
  if (end > f) f = end;
  if (touch > f) f = touch;
  return f;
}

/// Freshness of an entry's `clientStatuses` blob. `statusTouchMs` is
/// stamped on every status write; folded with the scalar freshness so a
/// legacy device's scalar events (start / resume / end) still vouch for
/// the statuses it carried at that moment.
int recorridoStatusFreshness(Map<String, dynamic> e) {
  final status = _asMs(e['statusTouchMs']);
  final scalar = recorridoScalarFreshness(e);
  return status > scalar ? status : scalar;
}

bool _isEnded(Map<String, dynamic> e) => _asMs(e['endMillis']) != 0;

bool _isCleared(Map<String, dynamic> e) => e['cleared'] == true;

/// Merge two `active_recorridos_json` arrays per (repartoId, day) entry.
///
/// Arbitration rules:
///   • SCALAR fields: the entry with the higher [recorridoScalarFreshness]
///     wins wholesale; exact tie → [b] wins (callers pass `(cloud, local)`
///     so each device keeps its own copy on a tie).
///   • `clientStatuses`: arbitrated INDEPENDENTLY by
///     [recorridoStatusFreshness] — the phone actively marking clients
///     keeps its progress even when the other side won the scalars
///     (e.g. a cierre that ended the entry elsewhere).
///
///     Deliberately whole-blob, NO per-client union: a union could
///     resurrect an UN-marked client as falsely-completed and the sodero
///     would skip someone who was never served. Blob LWW only ever errs
///     toward falsely-pending (a redundant visit), and completed marks
///     self-heal from the pagos rows on the next ruta load anyway.
///   • Removal: entries are never physically removed by mutators —
///     cierre / midnight reset mark `cleared: true` (soft tombstone, the
///     UI filters them out). A cleared mark with fresher scalars beats a
///     stale live copy, so the clear propagates instead of resurrecting.
///   • Retention: ended entries older than [endedRetention] and cleared
///     tombstones older than [clearedRetention] are dropped from the
///     MERGED result — every push GCs the cloud array. The cleared
///     horizon is deliberately LONG (see [kRecorridoTombstoneRetention]):
///     a returning offline device's UNENDED entry is never age-pruned,
///     so only a surviving tombstone can out-arbitrate it. Live
///     (un-ended, un-cleared) entries are never age-pruned here; the
///     read-path prune owns that policy.
List<Map<String, dynamic>> mergeRecorridos(
  List<Map<String, dynamic>> a,
  List<Map<String, dynamic>> b, {
  required int nowMs,
  Duration endedRetention = kEndedRecorridoRetention,
  Duration clearedRetention = kRecorridoTombstoneRetention,
}) {
  final byKey = <String, Map<String, dynamic>>{};

  void fold(List<Map<String, dynamic>> list) {
    for (final raw in list) {
      final repartoId = raw['repartoId'];
      final day = raw['day'];
      if (repartoId is! num || day is! num) continue;
      final entry = Map<String, dynamic>.from(raw);
      final k = '${repartoId.toInt()}:${day.toInt()}';
      final existing = byKey[k];
      byKey[k] = existing == null
          ? entry
          : _pickFresherRecorrido(existing, entry);
    }
  }

  fold(a);
  fold(b);

  final endedCutoff = nowMs - endedRetention.inMilliseconds;
  final clearedCutoff = nowMs - clearedRetention.inMilliseconds;
  return byKey.values.where((e) {
    if (_isCleared(e)) return recorridoStatusFreshness(e) >= clearedCutoff;
    if (_isEnded(e)) return recorridoStatusFreshness(e) >= endedCutoff;
    return true;
  }).toList();
}

/// [y] wins exact scalar ties (fold order makes that "the later list").
Map<String, dynamic> _pickFresherRecorrido(
  Map<String, dynamic> x,
  Map<String, dynamic> y,
) {
  final yWins = recorridoScalarFreshness(y) >= recorridoScalarFreshness(x);
  final winner = yWins ? y : x;
  final loser = yWins ? x : y;
  final out = Map<String, dynamic>.from(winner);
  if (recorridoStatusFreshness(loser) > recorridoStatusFreshness(winner)) {
    if (loser.containsKey('clientStatuses')) {
      out['clientStatuses'] = loser['clientStatuses'];
    }
    if (loser.containsKey('statusTouchMs')) {
      out['statusTouchMs'] = loser['statusTouchMs'];
    }
  }
  return out;
}

/// Merge two `instances_json` arrays per entry `id`.
///
///   • Per-entry LWW on `updatedAtMs`; exact tie → [b] wins (callers pass
///     `(cloud, local)`).
///   • Deletion is SOFT (`deleted: true` with a bumped `updatedAtMs`) so
///     a deletion always out-arbitrates the stale live copy on other
///     devices — a hard removal would resurrect through the next merge.
///   • Soft-deleted entries older than [retention] are dropped from the
///     merged result (GC). The horizon is LONG (see
///     [kInstanceTombstoneRetention]): a device offline past a short
///     horizon would otherwise return holding the vista live, find the
///     tombstone GC'd, and resurrect a vista the user deleted.
///   • Entries without a usable String `id` are dropped (malformed /
///     foreign junk can't wedge the merge).
List<Map<String, dynamic>> mergeInstances(
  List<Map<String, dynamic>> a,
  List<Map<String, dynamic>> b, {
  required int nowMs,
  Duration retention = kInstanceTombstoneRetention,
}) {
  final byId = <String, Map<String, dynamic>>{};

  void fold(List<Map<String, dynamic>> list) {
    for (final raw in list) {
      final id = raw['id'];
      if (id is! String || id.isEmpty) continue;
      final entry = Map<String, dynamic>.from(raw);
      final existing = byId[id];
      if (existing == null ||
          _asMs(entry['updatedAtMs']) >= _asMs(existing['updatedAtMs'])) {
        byId[id] = entry;
      }
    }
  }

  fold(a);
  fold(b);

  final cutoff = nowMs - retention.inMilliseconds;
  return byId.values.where((e) {
    if (e['deleted'] != true) return true;
    return _asMs(e['updatedAtMs']) >= cutoff;
  }).toList();
}
