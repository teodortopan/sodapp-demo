import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sodapp_demo/database/app_database.dart';

/// v85 «Instancias» — behavioral tests for the data layer: the
/// instances_json registry helpers, the soft-clear recorrido semantics,
/// and the atomic cloud-merge appliers, all against the REAL schema on
/// an in-memory database.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Run migrations + seed the singleton settings row.
    await db.customSelect('SELECT 1').get();
    await db.ensureUserSettingsRow();
  });

  tearDown(() async {
    await db.close();
  });

  Future<Map<String, Object?>> settingsRow() async {
    final rows = await db
        .customSelect(
          'SELECT instances_json, active_recorridos_json, '
          'settings_dirty_recorrido, sync_recorrido_enabled '
          'FROM user_settings WHERE id = 1',
        )
        .get();
    return rows.first.data;
  }

  group('v85 migration shape', () {
    test('fresh install: instances_json exists and defaults to []', () async {
      final row = await settingsRow();
      expect(row['instances_json'], '[]');
    });

    test('fresh install: recorrido sync is ON by default (v85)', () async {
      final row = await settingsRow();
      expect(
        row['sync_recorrido_enabled'],
        1,
        reason:
            '«Instancias» cross-device visibility depends on recorrido '
            'sync; v85 turns it on for everyone (merge made it safe)',
      );
    });
  });

  group('instances registry helpers', () {
    test('mutateInstancesAtomic round-trips and stamps the recorrido '
        'dirty section', () async {
      await db.mutateInstancesAtomic(
        (list) => list
          ..add({
            'id': 'uuid-1',
            'repartoId': 1,
            'nombre': 'Camión 2',
            'day': 4,
            'createdAtMs': 1000,
            'updatedAtMs': 1000,
          }),
      );
      final row = await settingsRow();
      final list = jsonDecode(row['instances_json']! as String) as List;
      expect(list, hasLength(1));
      expect((list.first as Map)['nombre'], 'Camión 2');
      expect(
        row['settings_dirty_recorrido'],
        greaterThanOrEqualTo(1),
        reason: 'the edit must ride the recorrido push section',
      );
    });

    test('purgeInstancesForReparto soft-deletes ONLY that reparto\'s '
        'instances and bumps their clock', () async {
      await db.mutateInstancesAtomic(
        (list) => list
          ..add({'id': 'a', 'repartoId': 1, 'nombre': 'R1-A', 'updatedAtMs': 5})
          ..add({
            'id': 'b',
            'repartoId': 2,
            'nombre': 'R2-B',
            'updatedAtMs': 5,
          }),
      );
      await db.purgeInstancesForReparto(1);
      final list = await db.getInstancesRaw();
      final a = list.firstWhere((e) => e['id'] == 'a');
      final b = list.firstWhere((e) => e['id'] == 'b');
      expect(a['deleted'], true);
      expect(
        (a['updatedAtMs'] as num).toInt(),
        greaterThan(5),
        reason: 'tombstone must out-arbitrate stale live copies on peers',
      );
      expect(b['deleted'], isNot(true), reason: 'other reparto untouched');
    });
  });

  group('soft-clear recorrido semantics', () {
    Future<void> seedRecorridos(List<Map<String, dynamic>> entries) =>
        db.saveActiveRecorridos(jsonEncode(entries));

    int nowMs() => DateTime.now().millisecondsSinceEpoch;

    test('clearRecorridoForRepartoAndDay clears ONE day; the sibling '
        'day\'s running recorrido survives', () async {
      await seedRecorridos([
        {'repartoId': 1, 'day': 3, 'startMillis': nowMs()},
        {'repartoId': 1, 'day': 4, 'startMillis': nowMs()},
      ]);
      await db.clearRecorridoForRepartoAndDay(1, 3);

      final visible = await db.getActiveRecorridos();
      expect(visible, hasLength(1));
      expect(
        visible.single['day'],
        4,
        reason:
            'midnight reset / cierre of one day must never wipe a '
            'sibling instance\'s recorrido — the pre-v85 bug',
      );

      // The cleared entry survives in storage as a merge tombstone.
      final raw =
          jsonDecode((await settingsRow())['active_recorridos_json']! as String)
              as List;
      expect(raw, hasLength(2));
      final cleared = raw.cast<Map>().firstWhere((e) => e['day'] == 3);
      expect(cleared['cleared'], true);
      expect(
        cleared['endMillis'],
        isNotNull,
        reason:
            'cleared entries must read as ENDED for pre-v85 builds '
            'so their prune can eventually drop them',
      );
      expect(
        cleared['lastTouchMs'],
        isNotNull,
        reason: 'the tombstone needs a fresh clock to win the merge',
      );
    });

    test('clearRecorridoForReparto soft-clears every day of that reparto '
        'but leaves other repartos alone', () async {
      await seedRecorridos([
        {'repartoId': 1, 'day': 3, 'startMillis': nowMs()},
        {'repartoId': 1, 'day': 4, 'startMillis': nowMs()},
        {'repartoId': 2, 'day': 3, 'startMillis': nowMs()},
      ]);
      await db.clearRecorridoForReparto(1);
      final visible = await db.getActiveRecorridos();
      expect(visible, hasLength(1));
      expect(visible.single['repartoId'], 2);
    });

    test('getActiveRecorridoForRepartoAndDay does not see cleared entries '
        '(a closed shift is not resumable)', () async {
      await seedRecorridos([
        {'repartoId': 1, 'day': 3, 'startMillis': nowMs()},
      ]);
      await db.clearRecorridoForRepartoAndDay(1, 3);
      expect(await db.getActiveRecorridoForRepartoAndDay(1, 3), isNull);
    });

    test('ended then cleared is invisible immediately, not resumable until '
        'tomorrow', () async {
      final start = nowMs();
      await seedRecorridos([
        {'repartoId': 1, 'day': 3, 'startMillis': start},
      ]);
      await db.markRecorridoSessionEnded(1, 3, start + 3600000);
      expect(
        await db.getActiveRecorridoForRepartoAndDay(1, 3),
        isNotNull,
        reason:
            'ended-only entries remain visible today for the old resume/'
            'finalize affordance',
      );

      await db.clearRecorridoForRepartoAndDay(1, 3);

      expect(await db.getActiveRecorridoForRepartoAndDay(1, 3), isNull);
      expect(await db.getActiveRecorridos(), isEmpty);
    });

    test('mutator stamps: statuses bump statusTouchMs, end/reactivate '
        'bump lastTouchMs', () async {
      await seedRecorridos([
        {'repartoId': 1, 'day': 3, 'startMillis': nowMs()},
      ]);
      await db.saveRecorridoClientStatuses(1, 3, '{"7":"completed"}');
      var entry = (await db.getActiveRecorridos()).single;
      expect(entry['statusTouchMs'], isNotNull);

      await db.markRecorridoSessionEnded(1, 3, nowMs());
      entry = (await db.getActiveRecorridos()).single;
      expect(entry['lastTouchMs'], isNotNull);

      await db.reactivateRecorridoSession(1, 3, nowMs());
      entry = (await db.getActiveRecorridos()).single;
      expect(entry['endMillis'], isNull);
    });
  });

  group('resumen per (fecha, día) — the two-days-in-one-date case', () {
    test('the SAME calendar date holds one resumen per configured día '
        '(jueves run + viernes run on the same Thursday)', () async {
      final jueves = await db.getOrCreateTodayResumen(
        repartoId: 1,
        fecha: '2026-06-11',
        semana: '2026-W24',
        diaSemana: 3,
      );
      final viernes = await db.getOrCreateTodayResumen(
        repartoId: 1,
        fecha: '2026-06-11',
        semana: '2026-W24',
        diaSemana: 4,
      );
      expect(
        viernes.id,
        isNot(jueves.id),
        reason:
            'two vistas closing different días on the same date '
            'must NOT collapse into one resumen',
      );
      // And re-asking for either day returns the SAME row (resume).
      final juevesAgain = await db.getOrCreateTodayResumen(
        repartoId: 1,
        fecha: '2026-06-11',
        semana: '2026-W24',
        diaSemana: 3,
      );
      expect(juevesAgain.id, jueves.id);
    });
  });

  group('cloud merge appliers', () {
    int nowMs() => DateTime.now().millisecondsSinceEpoch;

    test('mergeCloudActiveRecorridos: local day + cloud day → both, and '
        'the result reports local-ahead so a push gets scheduled', () async {
      await db.saveActiveRecorridos(
        jsonEncode([
          {'repartoId': 1, 'day': 3, 'startMillis': nowMs()},
        ]),
      );
      final cloudJson = jsonEncode([
        {'repartoId': 1, 'day': 4, 'startMillis': nowMs() - 1000},
      ]);
      final res = await db.mergeCloudActiveRecorridos(cloudJson);

      final visible = await db.getActiveRecorridos();
      expect(
        visible.map((e) => e['day']).toSet(),
        {3, 4},
        reason:
            'the sibling phone\'s running day must merge in, not '
            'overwrite ours',
      );
      expect(
        res.divergesFromCloud,
        isTrue,
        reason: 'local contributed day 3 — cloud needs our push',
      );
    });

    test('mergeCloudActiveRecorridos: pure adoption (cloud superset) '
        'does NOT report divergence — no push ping-pong', () async {
      final cloudJson = jsonEncode([
        {'repartoId': 1, 'day': 4, 'startMillis': nowMs() - 1000},
      ]);
      final res = await db.mergeCloudActiveRecorridos(cloudJson);
      expect(res.divergesFromCloud, isFalse);
      final visible = await db.getActiveRecorridos();
      expect(visible.single['day'], 4);
    });

    test('mergeCloudActiveRecorridos snapshots _prev when it rewrites '
        'local', () async {
      await db.saveActiveRecorridos(
        jsonEncode([
          {'repartoId': 1, 'day': 3, 'startMillis': nowMs()},
        ]),
      );
      final before = await db.getActiveRecorridosJsonRaw();
      await db.mergeCloudActiveRecorridos(
        jsonEncode([
          {'repartoId': 2, 'day': 0, 'startMillis': nowMs() - 500},
        ]),
      );
      expect(
        await db.getActiveRecorridosJsonPrev(),
        before,
        reason:
            'same atomic snapshot+apply contract as the pre-v85 '
            'whole-array apply',
      );
    });

    test('mergeCloudInstances: a peer\'s soft-delete lands locally; '
        'local-only instances report divergence', () async {
      // Real-clock timestamps: the merge GCs tombstones older than its
      // retention, so toy epoch values would (correctly) be pruned.
      final t = nowMs();
      await db.mutateInstancesAtomic(
        (list) => list
          ..add({
            'id': 'mine',
            'repartoId': 1,
            'nombre': 'Local',
            'updatedAtMs': t - 1000,
          })
          ..add({
            'id': 'shared',
            'repartoId': 1,
            'nombre': 'Compartida',
            'updatedAtMs': t - 1000,
          }),
      );
      final cloudJson = jsonEncode([
        {
          'id': 'shared',
          'repartoId': 1,
          'nombre': 'Compartida',
          'updatedAtMs': t - 500,
          'deleted': true,
        },
      ]);
      final res = await db.mergeCloudInstances(cloudJson);
      expect(
        res.divergesFromCloud,
        isTrue,
        reason: '"mine" exists only locally',
      );
      final list = await db.getInstancesRaw();
      final shared = list.firstWhere((e) => e['id'] == 'shared');
      expect(
        shared['deleted'],
        true,
        reason: 'the peer\'s deletion must not resurrect here',
      );
      expect(list.any((e) => e['id'] == 'mine'), isTrue);
    });
  });
}
