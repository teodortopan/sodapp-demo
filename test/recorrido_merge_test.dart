import 'package:flutter_test/flutter_test.dart';

import 'package:sodapp_demo/utils/recorrido_merge.dart';

/// v85 «Instancias» — unit tests for the pure per-entry merge that
/// replaced whole-array LWW on active_recorridos_json / instances_json.
///
/// The merge is THE data-safety core of running several days of the same
/// reparto on several phones at once: every rule here maps to a "two
/// soderos, same account" scenario that used to clobber one of them.
void main() {
  const day = Duration(days: 1);
  final now = DateTime.utc(2026, 6, 11, 12).millisecondsSinceEpoch;

  group('decodeJsonList', () {
    test('tolerates null / empty / [] / malformed input', () {
      expect(decodeJsonList(null), isEmpty);
      expect(decodeJsonList(''), isEmpty);
      expect(decodeJsonList('[]'), isEmpty);
      expect(decodeJsonList('not json at all'), isEmpty);
      expect(decodeJsonList('{"a":1}'), isEmpty, reason: 'non-list → []');
      expect(
        decodeJsonList('[1, "x", {"ok":true}]'),
        hasLength(1),
        reason: 'non-map elements dropped, map elements kept',
      );
    });
  });

  group('mergeRecorridos — the Instancias core', () {
    Map<String, dynamic> entry(
      int repartoId,
      int dayN, {
      int? start,
      int? end,
      int? lastTouch,
      int? statusTouch,
      String? statuses,
      bool? cleared,
      String? instanceId,
    }) => {
      'repartoId': repartoId,
      'day': dayN,
      if (start != null) 'startMillis': start,
      if (end != null) 'endMillis': end,
      if (lastTouch != null) 'lastTouchMs': lastTouch,
      if (statusTouch != null) 'statusTouchMs': statusTouch,
      if (statuses != null) 'clientStatuses': statuses,
      if (cleared != null) 'cleared': cleared,
      if (instanceId != null) 'instanceId': instanceId,
    };

    test('two phones running DIFFERENT days of the SAME reparto both '
        'survive — the original data-loss hazard', () {
      // Phone A runs Thursday (day 3); phone B runs Friday (day 4).
      final a = [entry(1, 3, start: now - 1000)];
      final b = [entry(1, 4, start: now - 900)];
      final merged = mergeRecorridos(a, b, nowMs: now);
      expect(
        merged,
        hasLength(2),
        reason: 'whole-array LWW used to drop one of these',
      );
      final days = merged.map((e) => e['day']).toSet();
      expect(days, {3, 4});
    });

    test('same (reparto, day): fresher scalars win wholesale', () {
      final stale = entry(1, 3, start: now - 10000, instanceId: 'old');
      final fresh = entry(
        1,
        3,
        start: now - 10000,
        lastTouch: now - 100,
        instanceId: 'new',
      );
      final merged = mergeRecorridos([stale], [fresh], nowMs: now);
      expect(merged.single['instanceId'], 'new');
      // And symmetric — fold order must not matter for a strict winner.
      final merged2 = mergeRecorridos([fresh], [stale], nowMs: now);
      expect(merged2.single['instanceId'], 'new');
    });

    test('exact scalar tie → the SECOND list wins (callers pass '
        '(cloud, local) so each device keeps its own copy)', () {
      final cloud = entry(1, 3, start: now - 1000, instanceId: 'cloud');
      final local = entry(1, 3, start: now - 1000, instanceId: 'local');
      final merged = mergeRecorridos([cloud], [local], nowMs: now);
      expect(merged.single['instanceId'], 'local');
    });

    test('clientStatuses arbitrate INDEPENDENTLY of the scalars — the '
        'actively-marking phone keeps its progress', () {
      // Phone A ended the recorrido (fresher scalars), but phone B kept
      // marking clients after A's stale status copy was taken.
      final aEnded = entry(
        1,
        3,
        start: now - 5000,
        end: now - 100,
        lastTouch: now - 100,
        statusTouch: now - 4000,
        statuses: '{"1":"completed"}',
      );
      final bMarking = entry(
        1,
        3,
        start: now - 5000,
        statusTouch: now - 50,
        statuses: '{"1":"completed","2":"completed"}',
      );
      final merged = mergeRecorridos([aEnded], [bMarking], nowMs: now);
      final m = merged.single;
      expect(
        m['endMillis'],
        now - 100,
        reason: 'A won the scalars — the recorrido reads as ended',
      );
      expect(
        m['clientStatuses'],
        '{"1":"completed","2":"completed"}',
        reason: 'B\'s fresher marking survives the scalar loss',
      );
      expect(m['statusTouchMs'], now - 50);
    });

    test('statuses adopt the WHOLE fresher blob — no per-client union '
        '(a union could resurrect an UN-marked client as falsely '
        'completed and the sodero would skip someone unserved)', () {
      final older = entry(
        1,
        3,
        start: now - 5000,
        statusTouch: now - 1000,
        statuses: '{"1":"completed","2":"completed"}',
      );
      final newer = entry(
        1,
        3,
        start: now - 5000,
        lastTouch: now - 100,
        statusTouch: now - 100,
        statuses: '{"1":"completed"}',
      );
      final merged = mergeRecorridos([older], [newer], nowMs: now);
      expect(
        merged.single['clientStatuses'],
        '{"1":"completed"}',
        reason:
            'client 2 was un-marked on the fresher side — must NOT '
            'come back through a union',
      );
    });

    test('a cleared mark with fresher scalars beats the stale live copy '
        '(cierre propagates instead of resurrecting)', () {
      final liveStale = entry(1, 3, start: now - 8000);
      final clearedFresh = entry(
        1,
        3,
        start: now - 8000,
        end: now - 200,
        lastTouch: now - 200,
        cleared: true,
      );
      final merged = mergeRecorridos([clearedFresh], [liveStale], nowMs: now);
      expect(
        merged.single['cleared'],
        true,
        reason:
            'physical removal would resurrect; the soft tombstone '
            'must win the arbitration',
      );
    });

    test('a NEW recorrido (fresh start) supersedes last week\'s cleared '
        'tombstone for the same (reparto, day)', () {
      final clearedOld = entry(
        1,
        3,
        start: now - 6 * day.inMilliseconds,
        end: now - 6 * day.inMilliseconds,
        lastTouch: now - 6 * day.inMilliseconds,
        cleared: true,
      );
      final freshStart = entry(1, 3, start: now - 50, instanceId: 'inst-2');
      final merged = mergeRecorridos([clearedOld], [freshStart], nowMs: now);
      final m = merged.single;
      expect(
        m['cleared'],
        isNot(true),
        reason: 'the fresh start must not inherit the tombstone',
      );
      expect(m['instanceId'], 'inst-2');
    });

    test('retention: ended entries GC at the SHORT horizon, cleared '
        'tombstones survive the LONG one, LIVE entries never age out', () {
      final clearedOld = entry(
        2,
        1,
        start: now - 9 * day.inMilliseconds,
        end: now - 9 * day.inMilliseconds,
        cleared: true,
      );
      final endedOld = entry(
        2,
        2,
        start: now - 9 * day.inMilliseconds,
        end: now - 9 * day.inMilliseconds,
      );
      final liveOld = entry(2, 3, start: now - 30 * day.inMilliseconds);
      final clearedAncient = entry(
        2,
        4,
        start: now - 200 * day.inMilliseconds,
        end: now - 200 * day.inMilliseconds,
        cleared: true,
      );
      final merged = mergeRecorridos(
        [clearedOld, endedOld, liveOld, clearedAncient],
        [],
        nowMs: now,
      );
      final days = merged.map((e) => e['day']).toSet();
      expect(
        days,
        {1, 3},
        reason:
            'ended@9d GC\'d (resume affordance, no resurrection '
            'vector); cleared@9d KEPT (the tombstone must outlive '
            'offline windows); live never age-pruned; cleared@200d '
            'GC\'d past kRecorridoTombstoneRetention',
      );
    });

    test('Codex review: a device returning from a LONG offline window '
        'cannot resurrect a cleared day', () {
      // Phone B went dark mid-route 100 days ago (UNENDED entry — never
      // age-pruned). The day was cierre-cleared meanwhile. With the old
      // 7-day tombstone GC the cleared mark would be long gone and B's
      // stale live copy would win by default; the long horizon keeps the
      // tombstone alive to out-arbitrate it.
      final staleLive = entry(1, 4, start: now - 100 * day.inMilliseconds);
      final clearedTomb = entry(
        1,
        4,
        start: now - 100 * day.inMilliseconds,
        end: now - 99 * day.inMilliseconds,
        lastTouch: now - 99 * day.inMilliseconds,
        cleared: true,
      );
      final merged = mergeRecorridos([clearedTomb], [staleLive], nowMs: now);
      expect(
        merged.single['cleared'],
        true,
        reason: 'the months-old running route must NOT come back',
      );
    });

    test('old-version entries (no v85 fields) merge cleanly: freshness '
        'degrades to start/end and they lose to actively-touched copies', () {
      final legacy = entry(
        1,
        3,
        start: now - 5000,
        statuses: '{"1":"completed"}',
      ); // no clocks
      final touched = entry(
        1,
        3,
        start: now - 5000,
        lastTouch: now - 100,
        statusTouch: now - 100,
        statuses: '{"1":"completed","2":"skipped"}',
      );
      final merged = mergeRecorridos([legacy], [touched], nowMs: now);
      expect(
        merged.single['clientStatuses'],
        '{"1":"completed","2":"skipped"}',
      );
      // And a legacy whole-array push that only has the legacy entry
      // cannot delete the other phone's different-day entry:
      final other = entry(1, 4, start: now - 200);
      final merged2 = mergeRecorridos([legacy], [other], nowMs: now);
      expect(merged2, hasLength(2));
    });

    test('malformed entries (missing repartoId/day) are dropped', () {
      final merged = mergeRecorridos(
        [
          {'repartoId': 1},
          {'day': 3},
          {'foo': 'bar'},
          entry(1, 3, start: now - 100),
        ],
        [],
        nowMs: now,
      );
      expect(merged, hasLength(1));
    });
  });

  group('mergeInstances — the vistas registry', () {
    Map<String, dynamic> inst(
      String id, {
      int repartoId = 1,
      String nombre = 'Vista',
      int? day,
      int? updatedAt,
      bool? deleted,
    }) => {
      'id': id,
      'repartoId': repartoId,
      'nombre': nombre,
      'day': day,
      'createdAtMs': updatedAt ?? 0,
      if (updatedAt != null) 'updatedAtMs': updatedAt,
      if (deleted != null) 'deleted': deleted,
    };

    test('instances created on different phones BOTH survive', () {
      final a = [inst('uuid-a', nombre: 'Camión 1', updatedAt: now - 100)];
      final b = [inst('uuid-b', nombre: 'Camión 2', updatedAt: now - 90)];
      final merged = mergeInstances(a, b, nowMs: now);
      expect(merged.map((e) => e['id']).toSet(), {'uuid-a', 'uuid-b'});
    });

    test('same id: newer updatedAtMs wins; exact tie → second list', () {
      final older = inst('x', nombre: 'Viejo', updatedAt: now - 500);
      final newer = inst('x', nombre: 'Nuevo', updatedAt: now - 100);
      expect(
        mergeInstances([older], [newer], nowMs: now).single['nombre'],
        'Nuevo',
      );
      expect(
        mergeInstances([newer], [older], nowMs: now).single['nombre'],
        'Nuevo',
      );
      final tieA = inst('x', nombre: 'A', updatedAt: now - 100);
      final tieB = inst('x', nombre: 'B', updatedAt: now - 100);
      expect(
        mergeInstances([tieA], [tieB], nowMs: now).single['nombre'],
        'B',
        reason: '(cloud, local) call order → local keeps its copy on tie',
      );
    });

    test('soft-delete does NOT resurrect: a newer tombstone beats the '
        'stale live copy in BOTH merge directions', () {
      final live = inst('x', updatedAt: now - 1000);
      final tomb = inst('x', updatedAt: now - 100, deleted: true);
      expect(
        mergeInstances([live], [tomb], nowMs: now).single['deleted'],
        true,
      );
      expect(
        mergeInstances([tomb], [live], nowMs: now).single['deleted'],
        true,
      );
    });

    test('a NEWER live copy un-deletes (rename-after-delete elsewhere '
        'follows normal LWW)', () {
      final tomb = inst('x', updatedAt: now - 1000, deleted: true);
      final reborn = inst('x', updatedAt: now - 100, nombre: 'Otra vez');
      final merged = mergeInstances([tomb], [reborn], nowMs: now);
      expect(merged.single['deleted'], isNot(true));
      expect(merged.single['nombre'], 'Otra vez');
    });

    test('retention: tombstones survive the LONG horizon and GC past '
        'it; live entries never age out', () {
      final keptTomb = inst(
        'a',
        updatedAt: now - 100 * day.inMilliseconds,
        deleted: true,
      );
      final ancientTomb = inst(
        'b',
        updatedAt: now - 200 * day.inMilliseconds,
        deleted: true,
      );
      final ancientLive = inst('c', updatedAt: now - 400 * day.inMilliseconds);
      final merged = mergeInstances(
        [keptTomb, ancientTomb, ancientLive],
        [],
        nowMs: now,
      );
      expect(
        merged.map((e) => e['id']).toSet(),
        {'a', 'c'},
        reason:
            'tombstone@100d kept (kInstanceTombstoneRetention), '
            '@200d GC\'d, live never age-pruned',
      );
    });

    test('Codex review: a device returning from a LONG offline window '
        'cannot resurrect a deleted vista', () {
      // The offline phone still holds the vista live (old updatedAtMs);
      // the deletion happened months ago. With a short tombstone GC the
      // live copy would re-enter unopposed; the long horizon keeps the
      // tombstone around to win LWW.
      final staleLive = inst('x', updatedAt: now - 100 * day.inMilliseconds);
      final tomb = inst(
        'x',
        updatedAt: now - 99 * day.inMilliseconds,
        deleted: true,
      );
      expect(
        mergeInstances([tomb], [staleLive], nowMs: now).single['deleted'],
        true,
      );
    });

    test('entries without a usable String id are dropped', () {
      final merged = mergeInstances(
        [
          {'repartoId': 1, 'nombre': 'sin id'},
          {'id': 42, 'nombre': 'id numérico'},
          {'id': '', 'nombre': 'id vacío'},
          inst('ok', updatedAt: now),
        ],
        [],
        nowMs: now,
      );
      expect(merged.single['id'], 'ok');
    });

    test('old-version push (no instances at all) cannot wipe the '
        'registry: empty ⊕ local = local', () {
      final local = [
        inst('a', updatedAt: now - 100),
        inst('b', updatedAt: now - 50, deleted: true),
      ];
      final merged = mergeInstances([], local, nowMs: now);
      expect(merged, hasLength(2));
    });
  });
}
