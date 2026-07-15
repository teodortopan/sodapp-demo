import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sodapp_demo/database/app_database.dart';

/// Upgrade-regression guard for the NEXT release (schemaVersion 85).
///
/// Production phones run these builds today:
///   • v1.1.5+117 / v1.1.6+118 → schemaVersion 77
///   • v1.1.7+119              → schemaVersion 79
///
/// Installing the new AAB runs onUpgrade(from, 85) ONCE over a database
/// full of the sodero's money data. These tests execute those exact
/// ladders (77→85, 78→85, 79→85) against a database seeded like a real
/// install and assert: no migration throws, no business row is lost or
/// warped, and re-running a ladder (process-killed-mid-upgrade retry,
/// Drift re-entry) stays a no-op — every shipped gate is idempotent.
///
/// The ladder runs against the CURRENT schema shape (we cannot resurrect
/// a byte-exact v77 file in-memory), which is the right direction for
/// what this guards: gates that reference a missing column/table, throw
/// on re-entry, or UPDATE business rows unconditionally fail HERE first.
/// The per-migration behavior of each gate (id-range seeding, resumen
/// dedupe, price freeze) has its own dedicated behavioral test file.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get(); // run onCreate + ladder
    await db.ensureUserSettingsRow();
  });

  tearDown(() async {
    await db.close();
  });

  /// Seed the shape of a working sodero install: reparto, cliente,
  /// productos (one with a price tier), entregas (one with a frozen
  /// snapshot, one legacy zero-snapshot), pago, carga, resumen with
  /// gastos, active recorrido + vista, a pending deletion.
  Future<void> seedSoderoData() async {
    await db.customStatement(
      "INSERT INTO repartos (id, nombre, user_id, orden) "
      "VALUES (1, 'Reparto Norte', 'user-1', 0)",
    );
    await db.customStatement(
      "INSERT INTO productos (id, reparto_id, nombre, orden, precio, "
      "deleted, dirty, updated_at) VALUES (1, 1, 'Soda', 0, 900, 0, 0, 5000)",
    );
    await db.customStatement(
      'INSERT INTO producto_precios (id, producto_id, nombre, precio, '
      'orden, reparto_id) VALUES (1, 1, ' // tier the legacy row freezes to
      "'Lista', 1200, 0, 1)",
    );
    await db.customStatement(
      "INSERT INTO clientes (id, reparto_id, nombre, direccion, telefono, "
      "dia_semana, orden, cuenta_corriente, dirty, updated_at) "
      "VALUES (10, 1, 'Panadería X', 'Calle 1', '', 3, 0, -2400, 1, 6000)",
    );
    await db.customStatement(
      'INSERT INTO entregas (id, cliente_id, reparto_id, producto_id, '
      'semana, dia_semana, entregado, devuelto, precio_unitario, dirty, '
      "updated_at) VALUES (100, 10, 1, 1, '2026-W24', 3, 2, 0, 1200, 1, 6100)",
    );
    // Legacy zero-snapshot row — the v82 gate in the ladder must freeze
    // it to the tier price (1200), and must NOT touch the row above.
    await db.customStatement(
      'INSERT INTO entregas (id, cliente_id, reparto_id, producto_id, '
      'semana, dia_semana, entregado, devuelto, precio_unitario, dirty, '
      "updated_at) VALUES (101, 10, 1, 1, '2026-W23', 3, 3, 0, 0, 0, 4000)",
    );
    await db.customStatement(
      'INSERT INTO pagos (id, cliente_id, reparto_id, semana, dia_semana, '
      "metodo_pago, monto, dirty, updated_at) "
      "VALUES (200, 10, 1, '2026-W24', 3, 'efectivo', 2400, 1, 6200)",
    );
    await db.customStatement(
      'INSERT INTO carga_diaria (id, producto_id, reparto_id, dia_semana, '
      "semana, cantidad, remanente) VALUES (300, 1, 1, 3, '2026-W24', 12, 2)",
    );
    await db.customStatement(
      'INSERT INTO resumenes (id, reparto_id, fecha, semana, dia_semana, '
      'duracion_segundos, efectivo, transferencia, cuenta_corriente, '
      'gastos, gastos_json, dirty, updated_at) '
      "VALUES (400, 1, '2026-06-11', '2026-W24', 3, 3600, 2400, 0, 0, "
      "1500, '[{\"descripcion\":\"Nafta\",\"monto\":1500}]', 1, 6300)",
    );
    await db.saveActiveRecorridos(
      jsonEncode([
        {
          'repartoId': 1,
          'day': 3,
          'startMillis': DateTime.now().millisecondsSinceEpoch,
          'fecha': '2026-06-11',
          'semana': '2026-W24',
          'clientStatuses': '{"10":"completed"}',
        },
      ]),
    );
    await db.mutateInstancesAtomic(
      (list) => list
        ..add({
          'id': 'vista-1',
          'repartoId': 1,
          'nombre': 'Feriado',
          'day': 4,
          'createdAtMs': 1000,
          'updatedAtMs': 1000,
        }),
    );
    await db.markPendingDeletion('pagos', 999, 'user-1');
  }

  /// Money + state snapshot used to diff before/after a ladder run.
  Future<Map<String, Object?>> snapshot() async {
    final r = await db
        .customSelect(
          'SELECT '
          '(SELECT COUNT(*) FROM clientes) AS clientes, '
          '(SELECT COUNT(*) FROM entregas) AS entregas, '
          '(SELECT COUNT(*) FROM pagos) AS pagos, '
          '(SELECT COUNT(*) FROM resumenes) AS resumenes, '
          '(SELECT COUNT(*) FROM carga_diaria) AS carga, '
          '(SELECT COUNT(*) FROM pending_deletions) AS tombs, '
          '(SELECT cuenta_corriente FROM clientes WHERE id = 10) AS cc, '
          '(SELECT monto FROM pagos WHERE id = 200) AS pago_monto, '
          '(SELECT precio_unitario FROM entregas WHERE id = 100) AS precio_ok, '
          '(SELECT gastos FROM resumenes WHERE id = 400) AS gastos, '
          '(SELECT efectivo FROM resumenes WHERE id = 400) AS efectivo, '
          '(SELECT dirty FROM entregas WHERE id = 100) AS entrega_dirty, '
          '(SELECT cantidad FROM carga_diaria WHERE id = 300) AS carga_qty, '
          '(SELECT remanente FROM carga_diaria WHERE id = 300) AS carga_rem, '
          '(SELECT active_recorridos_json FROM user_settings WHERE id = 1) '
          'AS recorridos, '
          '(SELECT instances_json FROM user_settings WHERE id = 1) '
          'AS instances',
        )
        .get();
    return Map<String, Object?>.from(r.first.data);
  }

  for (final from in const [77, 78, 79]) {
    test('the $from→85 ladder (a real field build) runs clean and keeps '
        'every peso', () async {
      await seedSoderoData();
      final before = await snapshot();

      await db.rerunMigrationLadder(from); // must not throw

      final after = await snapshot();
      expect(
        after,
        equals(before),
        reason:
            'an upgrade must not create, drop, or warp business '
            'rows — the sodero opens the new build onto the exact '
            'same money state',
      );

      // The ladder's own work landed: v81 NK index + v85 flag/column.
      final idx = await db
          .customSelect(
            "SELECT COUNT(*) AS c FROM sqlite_master WHERE type = 'index' "
            "AND name = 'resumenes_nk'",
          )
          .get();
      expect(idx.first.read<int>('c'), 1);
      final flag = await db
          .customSelect(
            'SELECT sync_recorrido_enabled FROM user_settings WHERE id = 1',
          )
          .get();
      expect(flag.first.read<int>('sync_recorrido_enabled'), 1);
    });
  }

  test('the v82 gate inside the ladder freezes legacy zero-snapshot '
      'entregas at the price CC already used (and only those)', () async {
    await seedSoderoData();
    await db.rerunMigrationLadder(79);
    final rows = await db
        .customSelect(
          'SELECT id, precio_unitario, dirty FROM entregas ORDER BY id',
        )
        .get();
    expect(
      rows.first.read<double>('precio_unitario'),
      1200.0,
      reason: 'snapshot rows stay untouched',
    );
    expect(
      rows.last.read<double>('precio_unitario'),
      1200.0,
      reason:
          'the legacy zero-snapshot row freezes to the tier price '
          'the CC fallback was already valuing it at — CC unchanged',
    );
    expect(
      rows.last.read<int>('dirty'),
      0,
      reason:
          'the freeze must not trigger a mass push — cloud runs '
          'the same backfill',
    );
  });

  test('a ladder re-run (process killed mid-upgrade → Drift retries) is '
      'a complete no-op', () async {
    await seedSoderoData();
    await db.rerunMigrationLadder(77);
    final once = await snapshot();
    await db.rerunMigrationLadder(77);
    await db.rerunMigrationLadder(79);
    expect(
      await snapshot(),
      equals(once),
      reason:
          'every shipped gate must be idempotent — an interrupted '
          'upgrade retried on next launch cannot double-apply',
    );
  });

  test('the upgraded database still serves the core flows', () async {
    await seedSoderoData();
    await db.rerunMigrationLadder(77);
    // Recorrido state + vista registry survive and stay readable.
    final recorridos = await db.getActiveRecorridos();
    expect(recorridos, hasLength(1));
    expect(recorridos.single['clientStatuses'], '{"10":"completed"}');
    expect((await db.getInstancesRaw()).single['nombre'], 'Feriado');
    // Resumen resolution still converges on the existing row.
    final resumen = await db.getOrCreateTodayResumen(
      repartoId: 1,
      fecha: '2026-06-11',
      semana: '2026-W24',
      diaSemana: 3,
    );
    expect(resumen.id, 400);
    // And the day's aggregation math still reads the seeded entrega.
    final agg = await db.getEntregasAggregatedForDay(1, '2026-W24', 3);
    expect(agg[1]?.entregado, 2);
  });
}
