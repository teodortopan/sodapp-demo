import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sodapp_demo/database/app_database.dart';

/// P1-9 regression tests — freeze legacy zero-snapshot entregas (audit #9,
/// schema v82).
///
/// Zero-snapshot rows were valued through a CURRENT-price fallback chain
/// at every cuenta-corriente recompute, so a price edit today retro-warped
/// historical balances. The backfill stamps those rows with exactly the
/// value the chain produces — CC must be UNCHANGED by construction — and
/// from then on history is frozen.
void main() {
  group('zero-snapshot backfill — behavioral (in-memory AppDatabase)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      // Producto 1: tiered prices + a cliente-assigned tier.
      await db.customStatement(
        "INSERT INTO repartos (id, nombre, user_id) VALUES (1, 'R', 'u')",
      );
      await db.customStatement(
        "INSERT INTO productos (id, reparto_id, nombre, orden, precio, "
        "deleted) VALUES (1, 1, 'Soda', 0, 150.0, 0)",
      );
      await db.customStatement(
        'INSERT INTO producto_precios (id, reparto_id, producto_id, nombre, '
        "precio, orden) VALUES (10, 1, 1, 'Base', 120.0, 0)",
      );
      await db.customStatement(
        'INSERT INTO producto_precios (id, reparto_id, producto_id, nombre, '
        "precio, orden) VALUES (11, 1, 1, 'Especial', 100.0, 1)",
      );
      // Producto 2: no tiers — chain falls through to productos.precio.
      await db.customStatement(
        "INSERT INTO productos (id, reparto_id, nombre, orden, precio, "
        "deleted) VALUES (2, 1, 'Bidón', 1, 90.0, 0)",
      );
      // Producto 3: priceless everywhere.
      await db.customStatement(
        "INSERT INTO productos (id, reparto_id, nombre, orden, precio, "
        "deleted) VALUES (3, 1, 'Sin precio', 2, 0.0, 0)",
      );
      // Cliente 1 has the 'Especial' (100) tier assigned for producto 1.
      await db.customStatement(
        "INSERT INTO clientes (id, reparto_id, dia_semana, nombre) "
        "VALUES (1, 1, 0, 'Juan')",
      );
      await db.customStatement(
        'INSERT INTO cliente_productos (id, cliente_id, producto_id, '
        'cantidad_habitual, precio_tipo_id) VALUES (1, 1, 1, 1, 11)',
      );
      // Cliente 2 has no assignment.
      await db.customStatement(
        "INSERT INTO clientes (id, reparto_id, dia_semana, nombre) "
        "VALUES (2, 1, 0, 'Ana')",
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> seedEntrega({
      required int id,
      required int clienteId,
      required int productoId,
      int entregado = 2,
      double precio = 0.0,
    }) {
      return db.customStatement(
        'INSERT INTO entregas (id, cliente_id, reparto_id, producto_id, '
        'semana, dia_semana, entregado, devuelto, precio_unitario, fecha, '
        "updated_at, dirty) VALUES (?, ?, 1, ?, '2026-W20', 0, ?, 0, ?, "
        "'2026-05-11', 7777, 0)",
        [id, clienteId, productoId, entregado, precio],
      );
    }

    Future<Map<String, Object?>> entrega(int id) async {
      final rows = await db
          .customSelect(
            'SELECT precio_unitario, updated_at, dirty FROM entregas '
            'WHERE id = $id',
          )
          .get();
      return rows.first.data;
    }

    test(
      'chain order: assigned tier → first tier → productos.precio',
      () async {
        await seedEntrega(id: 1, clienteId: 1, productoId: 1); // assigned: 100
        await seedEntrega(id: 2, clienteId: 2, productoId: 1); // tier0: 120
        await seedEntrega(id: 3, clienteId: 2, productoId: 2); // precio: 90

        final stamped = await db.backfillZeroSnapshotPrecios();
        expect(stamped, 3);

        expect(
          (await entrega(1))['precio_unitario'],
          100.0,
          reason: 'cliente-assigned tier wins',
        );
        expect(
          (await entrega(2))['precio_unitario'],
          120.0,
          reason: 'lowest-orden tier is the fallback',
        );
        expect(
          (await entrega(3))['precio_unitario'],
          90.0,
          reason: 'productos.precio is the last resort',
        );
      },
    );

    test('untouchable rows stay untouched', () async {
      await seedEntrega(id: 1, clienteId: 1, productoId: 3); // priceless
      await seedEntrega(
        id: 2,
        clienteId: 1,
        productoId: 1,
        precio: 55.0, // already snapshotted
      );
      // Different cliente so the NK (cliente, reparto, producto, semana,
      // dia) doesn't collide with row 2.
      await seedEntrega(
        id: 3,
        clienteId: 2,
        productoId: 1,
        entregado: 0, // nothing delivered
      );

      final stamped = await db.backfillZeroSnapshotPrecios();
      expect(stamped, 0);

      expect(
        (await entrega(1))['precio_unitario'],
        0.0,
        reason:
            'a row the chain cannot price must stay 0 (the CC '
            'fallback chain still covers it at read time)',
      );
      expect(
        (await entrega(2))['precio_unitario'],
        55.0,
        reason: 'existing snapshots are history — never rewritten',
      );
      expect((await entrega(3))['precio_unitario'], 0.0);
    });

    test('backfill does not bump updated_at or dirty (no mass push)', () async {
      await seedEntrega(id: 1, clienteId: 1, productoId: 1);
      await db.backfillZeroSnapshotPrecios();
      final row = await entrega(1);
      expect(
        row['updated_at'],
        7777,
        reason:
            'cloud-side backfill owns convergence; a local mass push '
            'would re-arbitrate every legacy row',
      );
      expect(row['dirty'], 0);
    });

    test('CC is unchanged by construction — the freeze re-states what the '
        'fallback already computed', () async {
      await seedEntrega(id: 1, clienteId: 1, productoId: 1, entregado: 3);
      await seedEntrega(id: 2, clienteId: 1, productoId: 2, entregado: 2);

      Future<double> cc() async {
        await db.recalcCuentaCorrienteForCliente(1);
        final rows = await db
            .customSelect('SELECT cuenta_corriente FROM clientes WHERE id = 1')
            .get();
        return rows.first.read<double>('cuenta_corriente');
      }

      final before = await cc();
      final stamped = await db.backfillZeroSnapshotPrecios();
      expect(stamped, 2);
      final after = await cc();

      expect(
        after,
        before,
        reason:
            'freezing history must not move a single peso — and from '
            'now on price edits cannot re-value these rows',
      );

      // THE point of the fix: a price edit no longer warps history.
      await db.customStatement(
        'UPDATE producto_precios SET precio = 999.0 WHERE id = 11',
      );
      await db.customStatement(
        'UPDATE productos SET precio = 999.0 WHERE id = 2',
      );
      final afterPriceEdit = await cc();
      expect(
        afterPriceEdit,
        before,
        reason:
            'pre-fix, this assertion fails: the zero-snapshot rows '
            'would re-value at 999 and rewrite the historical balance',
      );
    });
  });
}
