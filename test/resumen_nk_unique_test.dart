import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sodapp_demo/database/app_database.dart';

/// P1-8 regression tests — one resumen per (reparto, fecha, dia_semana)
/// (pre-release audit #8, schema v81).
///
/// Nothing enforced this before (local + cloud only had id-based
/// uniqueness): a double-tap on cierre, two devices closing the same day,
/// or web's gasto-insert racing mobile's creation produced DUPLICATE
/// resumen rows — and web finanzas summed both (double-counted
/// gastos/sueldo). v81 dedupes (archiving losers), adds the UNIQUE index,
/// makes get-or-create atomic, and converts push/pull to NK convergence
/// like entregas/pagos.
void main() {
  group('resumen NK uniqueness — behavioral (in-memory AppDatabase)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> resumenCount() async {
      final rows = await db
          .customSelect('SELECT COUNT(*) AS c FROM resumenes')
          .get();
      return rows.first.read<int>('c');
    }

    test(
      'getOrCreateTodayResumen is idempotent (double-tap / re-entry)',
      () async {
        final a = await db.getOrCreateTodayResumen(
          repartoId: 1,
          fecha: '2026-06-08',
          semana: '2026-W24',
          diaSemana: 0,
        );
        final b = await db.getOrCreateTodayResumen(
          repartoId: 1,
          fecha: '2026-06-08',
          semana: '2026-W24',
          diaSemana: 0,
        );
        expect(b.id, a.id, reason: 'same day must return the SAME row');
        expect(
          await resumenCount(),
          1,
          reason: 'a second call must never create a duplicate',
        );
      },
    );

    test('the unique index hard-blocks raw duplicate inserts', () async {
      await db.customStatement(
        "INSERT INTO resumenes (reparto_id, fecha, semana, dia_semana, "
        "duracion_segundos) VALUES (1, '2026-06-08', '2026-W24', 0, 0)",
      );
      await expectLater(
        db.customStatement(
          "INSERT INTO resumenes (reparto_id, fecha, semana, dia_semana, "
          "duracion_segundos) VALUES (1, '2026-06-08', '2026-W24', 0, 0)",
        ),
        throwsA(anything),
        reason: 'resumenes_nk must reject a second row for the same day',
      );
    });

    test('dedupe keeps the newest duplicate and archives the losers', () async {
      // Recreate the pre-v81 world: no index, real duplicates.
      await db.customStatement('DROP INDEX IF EXISTS resumenes_nk');
      await db.customStatement(
        "INSERT INTO resumenes (id, reparto_id, fecha, semana, dia_semana, "
        "duracion_segundos, gastos, updated_at) "
        "VALUES (1, 1, '2026-06-08', '2026-W24', 0, 0, 500.0, 1000)",
      );
      await db.customStatement(
        "INSERT INTO resumenes (id, reparto_id, fecha, semana, dia_semana, "
        "duracion_segundos, gastos, updated_at) "
        "VALUES (2, 1, '2026-06-08', '2026-W24', 0, 0, 800.0, 2000)",
      );
      // Unrelated day must survive untouched.
      await db.customStatement(
        "INSERT INTO resumenes (id, reparto_id, fecha, semana, dia_semana, "
        "duracion_segundos, gastos, updated_at) "
        "VALUES (3, 1, '2026-06-09', '2026-W24', 1, 0, 100.0, 1500)",
      );

      await db.dedupeAndIndexResumenes();

      final survivors = await db
          .customSelect('SELECT id, gastos FROM resumenes ORDER BY id')
          .get();
      expect(survivors, hasLength(2));
      expect(
        survivors.first.read<int>('id'),
        2,
        reason: 'the NEWEST duplicate (updated_at=2000) must win',
      );
      expect(survivors.first.read<double>('gastos'), 800.0);
      expect(
        survivors.last.read<int>('id'),
        3,
        reason: 'unrelated day untouched',
      );

      final archived = await db
          .customSelect('SELECT id, archived_reason FROM resumenes_archive')
          .get();
      expect(archived, hasLength(1), reason: 'loser archived, not destroyed');
      expect(archived.first.read<int>('id'), 1);
      expect(archived.first.read<String>('archived_reason'), 'v81_nk_dedupe');

      // And the index is back.
      await expectLater(
        db.customStatement(
          "INSERT INTO resumenes (reparto_id, fecha, semana, dia_semana, "
          "duracion_segundos) VALUES (1, '2026-06-08', '2026-W24', 0, 0)",
        ),
        throwsA(anything),
      );
    });

    test(
      'restoreResumenFromCloud converges by NK even when ids differ',
      () async {
        // Local row created on THIS device with its own id.
        await db.customStatement(
          "INSERT INTO resumenes (id, reparto_id, fecha, semana, dia_semana, "
          "duracion_segundos, gastos, updated_at, dirty) "
          "VALUES (5, 1, '2026-06-08', '2026-W24', 0, 0, 500.0, 1000, 0)",
        );
        // Cloud row for the SAME day created on ANOTHER device (id 999).
        await db.restoreResumenFromCloud({
          'id': 999,
          'reparto_id': 1,
          'fecha': '2026-06-08',
          'semana': '2026-W24',
          'dia_semana': 0,
          'duracion_segundos': 60,
          'gastos': 800.0,
          'updated_at': '2026-06-08T20:00:00Z',
        });

        expect(
          await resumenCount(),
          1,
          reason: 'NK convergence — never a second row for the same day',
        );
        final row =
            (await db.customSelect('SELECT id, gastos FROM resumenes').get())
                .first;
        expect(row.read<int>('id'), 5, reason: 'local id preserved');
        expect(row.read<double>('gastos'), 800.0, reason: 'cloud values win');
      },
    );

    test(
      'restore survives a legacy id collision with a DIFFERENT day',
      () async {
        // Pre-v80 world: local id 7 belongs to one day…
        await db.customStatement(
          "INSERT INTO resumenes (id, reparto_id, fecha, semana, dia_semana, "
          "duracion_segundos, updated_at, dirty) "
          "VALUES (7, 1, '2026-06-08', '2026-W24', 0, 0, 1000, 0)",
        );
        // …and the cloud row for ANOTHER day arrives carrying id 7 too.
        await db.restoreResumenFromCloud({
          'id': 7,
          'reparto_id': 1,
          'fecha': '2026-06-09',
          'semana': '2026-W24',
          'dia_semana': 1,
          'duracion_segundos': 0,
          'updated_at': '2026-06-09T20:00:00Z',
        });

        expect(
          await resumenCount(),
          2,
          reason:
              'the PK collision must fall back to a fresh local id, '
              'not crash the pull',
        );
      },
    );

    test(
      'dirty-and-newer local resumen is preserved against the pull',
      () async {
        await db.customStatement(
          "INSERT INTO resumenes (id, reparto_id, fecha, semana, dia_semana, "
          "duracion_segundos, gastos, updated_at, dirty) "
          "VALUES (5, 1, '2026-06-08', '2026-W24', 0, 0, 500.0, 5000, 1)",
        );
        await db.restoreResumenFromCloud({
          'id': 999,
          'reparto_id': 1,
          'fecha': '2026-06-08',
          'semana': '2026-W24',
          'dia_semana': 0,
          'duracion_segundos': 60,
          'gastos': 800.0,
          // Cloud is OLDER (epoch ms 1000 << local 5000).
          'updated_at': '1970-01-01T00:00:01Z',
        });

        final row =
            (await db.customSelect('SELECT gastos, dirty FROM resumenes').get())
                .first;
        expect(
          row.read<double>('gastos'),
          500.0,
          reason: 'local unpushed edit must survive the pull',
        );
        expect(row.read<int>('dirty'), 1);
      },
    );
  });
}
