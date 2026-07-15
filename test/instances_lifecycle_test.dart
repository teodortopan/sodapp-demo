import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sodapp_demo/database/app_database.dart';

/// v85 «Instancias» — phase 4 edge cases: resume keeps the original
/// fecha (no duplicate resumen), per-día gastos isolation on a shared
/// fecha (money path), cleared entries don't resurrect as resumable,
/// and the sync→memory reconciliation wiring.
void main() {
  group('behavioral (in-memory AppDatabase)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
      await db.ensureUserSettingsRow();
    });

    tearDown(() async {
      await db.close();
    });

    test('resume keeps the ORIGINAL fecha → one resumen, never two '
        '(the double-aggregation hazard)', () async {
      // Thursday: the sodero starts día 4 (Friday's route) early.
      final startMs = DateTime.now().millisecondsSinceEpoch;
      await db.saveActiveRecorridos(
        jsonEncode([
          {
            'repartoId': 1,
            'day': 4,
            'startMillis': startMs,
            'fecha': '2026-06-11', // jueves — the REAL calendar date
            'semana': '2026-W24',
          },
        ]),
      );
      final r1 = await db.getOrCreateTodayResumen(
        repartoId: 1,
        fecha: '2026-06-11',
        semana: '2026-W24',
        diaSemana: 4,
      );
      // Pause + resume LATER (even past midnight): the entry's fecha
      // must survive the reactivation untouched.
      await db.markRecorridoSessionEnded(1, 4, startMs + 3600000);
      await db.reactivateRecorridoSession(1, 4, startMs + 7200000);
      final entry = await db.getActiveRecorridoForRepartoAndDay(1, 4);
      expect(entry, isNotNull);
      expect(
        entry!['fecha'],
        '2026-06-11',
        reason:
            'reactivation must NOT re-stamp fecha — a new fecha would '
            'open a SECOND resumen aggregating the SAME entregas',
      );
      // Re-asking with the stored fecha returns the same row.
      final r2 = await db.getOrCreateTodayResumen(
        repartoId: 1,
        fecha: entry['fecha'] as String,
        semana: entry['semana'] as String,
        diaSemana: 4,
      );
      expect(r2.id, r1.id);
      final count = await db
          .customSelect('SELECT COUNT(*) AS c FROM resumenes')
          .get();
      expect(count.first.read<int>('c'), 1);
    });

    test('gastos are isolated per (fecha, día) resumen — two vistas '
        'closing the same date never bleed gastos into each other', () async {
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
      await db.updateResumenGastos(
        jueves.id,
        1500.0,
        '[{"descripcion":"Nafta","monto":1500}]',
      );

      final rows = await db
          .customSelect(
            'SELECT id, gastos, gastos_json FROM resumenes ORDER BY dia_semana',
          )
          .get();
      final jRow = rows.firstWhere((r) => r.read<int>('id') == jueves.id);
      final vRow = rows.firstWhere((r) => r.read<int>('id') == viernes.id);
      expect(jRow.read<double>('gastos'), 1500.0);
      expect(
        vRow.read<double>('gastos'),
        0.0,
        reason:
            'the sibling vista\'s day must stay untouched — gastos '
            'are per-resumen, never per-fecha',
      );
      expect(vRow.read<String>('gastos_json'), isEmpty);
    });

    test('WEEK-SLOT convergence: re-running the same día on a SECOND '
        'date in one week continues the existing resumen — never a '
        'double-counting twin', () async {
      // Thursday: día 4 (Friday's route) run early → resumen on Thursday.
      final early = await db.getOrCreateTodayResumen(
        repartoId: 1,
        fecha: '2026-06-11',
        semana: '2026-W24',
        diaSemana: 4,
      );
      // Friday: the sodero (or another vista/phone) touches día 4 again —
      // the recorrido entry from Thursday is gone (pruned/cleared), so the
      // caller passes TODAY's fecha. Pre-fix this created a SECOND resumen
      // that re-aggregated the SAME (semana, día)-keyed entregas: finanzas
      // then showed the day's pesos TWICE (500 real → 1000 displayed).
      final friday = await db.getOrCreateTodayResumen(
        repartoId: 1,
        fecha: '2026-06-12',
        semana: '2026-W24',
        diaSemana: 4,
      );
      expect(
        friday.id,
        early.id,
        reason:
            'one (reparto, semana, día) slot = ONE resumen, '
            'whatever date it gets touched on',
      );
      expect(
        friday.fecha,
        '2026-06-11',
        reason: 'the slot keeps its original fecha',
      );
      final count = await db
          .customSelect('SELECT COUNT(*) AS c FROM resumenes')
          .get();
      expect(count.first.read<int>('c'), 1);
      // A DIFFERENT week's día 4 is its own slot, untouched by this.
      final nextWeek = await db.getOrCreateTodayResumen(
        repartoId: 1,
        fecha: '2026-06-19',
        semana: '2026-W25',
        diaSemana: 4,
      );
      expect(nextWeek.id, isNot(early.id));
    });

    test('sign-out guard counts unpushed settings/recorrido edits', () async {
      expect(await db.totalDirtyRowCount(), 0);
      await db.customStatement(
        'UPDATE user_settings SET settings_dirty = 3 WHERE id = 1',
      );
      expect(
        await db.totalDirtyRowCount(),
        3,
        reason:
            'a failed force-push followed by sign-out must surface '
            'unpushed recorrido/vista/settings edits in the guard count '
            'instead of wiping them as "0 cambios"',
      );
    });

    test('a cleared day is NOT resumable — the start path sees null and '
        'goes fresh', () async {
      await db.saveActiveRecorridos(
        jsonEncode([
          {
            'repartoId': 1,
            'day': 3,
            'startMillis': DateTime.now().millisecondsSinceEpoch,
            'endMillis': DateTime.now().millisecondsSinceEpoch + 1000,
          },
        ]),
      );
      await db.clearRecorridoForRepartoAndDay(1, 3);
      expect(
        await db.getActiveRecorridoForRepartoAndDay(1, 3),
        isNull,
        reason: 'a closed shift must not offer Reanudar',
      );
    });
  });

  group('sync → memory reconciliation (source guards)', () {
    late String homeSrc;

    setUpAll(() {
      homeSrc = File('lib/screens/home_screen.dart').readAsStringSync();
    });

    test('the DB-change handler reconciles the chronometer map', () {
      expect(homeSrc, contains('_reconcileRecorridosFromDb();'));
      final idx = homeSrc.indexOf('void _handleDbDataChanged()');
      final body = homeSrc.substring(idx, idx + 1400);
      expect(
        body,
        contains('_reconcileRecorridosFromDb'),
        reason:
            'without this, a sibling phone ending/starting a day '
            'leaves this phone\'s chrono stale until an app restart',
      );
    });

    test('reconciliation drops closed-elsewhere and adopts '
        'running-elsewhere entries', () {
      final idx = homeSrc.indexOf('Future<void> _reconcileRecorridosFromDb()');
      expect(idx, isNot(-1));
      final body = homeSrc.substring(idx, idx + 5200);
      expect(body, contains('if (unendedByKey.containsKey(key)) continue;'));
      expect(body, contains('_activeRecorridos.remove(key)'));
      expect(
        body,
        contains('Adopt / refresh what runs elsewhere.'),
        reason:
            'adoption is the «see the Thursday chrono running» half '
            'of the feature',
      );
      expect(
        body,
        contains('_syncRecorridoNotificationOnEnd();'),
        reason:
            'a recorrido ended elsewhere must clear/refresh the '
            'lock-screen notification too',
      );
    });

    test('pointer healing keeps a RUNNING day context (mid-route vista '
        'deletion on a sibling phone must not strand the sodero)', () {
      final idx = homeSrc.indexOf('Future<void> _loadInstances()');
      final body = homeSrc.substring(idx, idx + 3000);
      expect(body, contains('final running ='));
      expect(
        body,
        contains('if (!running) {'),
        reason:
            'only an IDLE context drops to the default vista; a '
            'running route keeps its day',
      );
    });

    test('notification Terminar focuses the recorrido it mirrors', () {
      final idx = homeSrc.indexOf('void _onNotificationTerminar()');
      final body = homeSrc.substring(idx, idx + 1500);
      expect(body, contains('_notificationTargetRecorrido()'));
      expect(
        body,
        contains('_configSelectedDay = target.day'),
        reason:
            'ending from the notification while another vista is '
            'focused must act on the mirrored recorrido, not no-op',
      );
    });
  });
}
