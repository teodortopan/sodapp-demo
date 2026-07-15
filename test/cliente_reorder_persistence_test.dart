import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodapp_demo/database/app_database.dart';
import 'package:sodapp_demo/utils/logical_clock.dart';

/// Regression suite for the recurring "clients randomly change order on
/// load" bug. The read side was fixed earlier ((orden,id) tiebreakers,
/// MAX(orden)+1 inserts) — the surviving bug was WRITE-side: the per-row
/// reorder persist loop notified listeners after every row, the triggered
/// reloads swapped the screen's `_clientes` list mid-loop, and the
/// remaining writes persisted a half-applied permutation. These tests pin
/// the atomic batch writer, the screen-side coalescing/guards, and the
/// dirty-row field-merge on pull that kept losing unpushed reorders to
/// wall-clock skew.
void main() {
  group('updateClienteOrdenBatch — behavioral', () {
    late AppDatabase db;

    setUp(() async {
      LogicalClock.seedCounter(1); // deterministic; no prefs plugin in tests
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customStatement(
        "INSERT INTO repartos (id, nombre, user_id) VALUES (1, 'R', 'u')",
      );
      // 5 clientes, día 0, orden 0..4. Ids 10..14 — distinct from the orden
      // values so the assertions can tell id-order from orden-order apart.
      for (var i = 0; i < 5; i++) {
        await db.customStatement(
          'INSERT INTO clientes (id, reparto_id, dia_semana, nombre, orden, '
          "dirty, dirty_fields, updated_at) VALUES (?, 1, 0, ?, ?, 0, '', "
          '1000)',
          [10 + i, 'C$i', i],
        );
      }
    });

    tearDown(() async {
      await db.close();
      LogicalClock.resetForTest();
    });

    Future<List<Map<String, Object?>>> rows() async =>
        (await db
                .customSelect(
                  'SELECT id, orden, dirty, dirty_fields FROM clientes '
                  'ORDER BY orden, id',
                )
                .get())
            .map((r) => r.data)
            .toList();

    test(
      'applies a permutation atomically; stamps ONLY changed rows',
      () async {
        // Reverse the list: 14,13,12,11,10. Cliente 12 keeps orden 2 → its
        // persisted row must stay completely untouched (no dirty stamp).
        final changed = await db.updateClienteOrdenBatch({
          14: 0,
          13: 1,
          12: 2,
          11: 3,
          10: 4,
        });
        expect(changed, isTrue);
        final after = await rows();
        expect(after.map((r) => r['id']).toList(), [14, 13, 12, 11, 10]);
        for (final r in after) {
          final moved = r['id'] != 12;
          expect(r['dirty'], moved ? 1 : 0, reason: 'id ${r['id']}');
          expect(
            r['dirty_fields'],
            moved ? 'orden' : '',
            reason: 'a reorder must dirty exactly {orden} (id ${r['id']})',
          );
        }
      },
    );

    test('fires exactly ONE data notification per batch; none when the '
        'mapping matches the DB', () async {
      var ticks = 0;
      db.addDataListener(() => ticks++);
      await db.updateClienteOrdenBatch({14: 0, 13: 1, 12: 2, 11: 3, 10: 4});
      expect(
        ticks,
        1,
        reason:
            'one notify AFTER commit — the old per-row notify let '
            'reloads swap the caller\'s list mid-persist',
      );
      // Identity (already-persisted) mapping: DB-side diff finds nothing.
      final changed = await db.updateClienteOrdenBatch({
        14: 0,
        13: 1,
        12: 2,
        11: 3,
        10: 4,
      });
      expect(changed, isFalse);
      expect(ticks, 1);
    });

    test('nonexistent ids are skipped — no insert, no notify', () async {
      var ticks = 0;
      db.addDataListener(() => ticks++);
      final changed = await db.updateClienteOrdenBatch({999: 0});
      expect(changed, isFalse);
      expect(ticks, 0);
      final n =
          (await db.customSelect('SELECT COUNT(*) AS n FROM clientes').get())
              .single
              .read<int>('n');
      expect(n, 5);
    });
  });

  group('restoreClienteFromCloud — dirty rows field-merge', () {
    late AppDatabase db;

    Map<String, dynamic> cloudRow({
      required int orden,
      String direccion = 'Web 123',
      String updatedAt = '2030-01-01T00:00:00.000Z',
    }) => {
      'id': 10,
      'reparto_id': 1,
      'dia_semana': 0,
      'nombre': 'C0',
      'direccion': direccion,
      'telefono': '',
      'frecuencia': 'semanal',
      'etiqueta': '',
      'notas': '',
      'orden': orden,
      'cuenta_corriente': 0.0,
      'show_on_map': 1,
      'doc_tipo': 99,
      'doc_nro': '0',
      'marked_semana': null,
      'lat': null,
      'lng': null,
      'geocoded_direccion': null,
      'updated_at': updatedAt,
    };

    setUp(() async {
      LogicalClock.seedCounter(1);
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customStatement(
        "INSERT INTO repartos (id, nombre, user_id) VALUES (1, 'R', 'u')",
      );
      // Unpushed local reorder (dirty mask = orden) whose updated_at is FAR
      // older than the cloud row's — the pre-fix `localMs >= cloudMs` gate
      // dropped the whole local row (orden overwritten, dirty CLEARED) on
      // any later web edit or backward phone-clock skew.
      await db.customStatement(
        'INSERT INTO clientes (id, reparto_id, dia_semana, nombre, '
        'direccion, orden, dirty, dirty_fields, updated_at) '
        "VALUES (10, 1, 0, 'C0', 'Local 1', 7, 1, 'orden', 1000)",
      );
    });

    tearDown(() async {
      await db.close();
      LogicalClock.resetForTest();
    });

    test('dirty-but-OLDER local row keeps its orden, takes the cloud '
        'profile, and stays dirty for the next push', () async {
      await db.restoreClienteFromCloud(cloudRow(orden: 99));
      final r =
          (await db
                  .customSelect(
                    'SELECT orden, direccion, dirty, dirty_fields '
                    'FROM clientes WHERE id = 10',
                  )
                  .get())
              .single;
      expect(
        r.read<int>('orden'),
        7,
        reason: 'an unpushed reorder must survive a newer cloud row',
      );
      expect(
        r.read<String>('direccion'),
        'Web 123',
        reason: 'clean fields still come from cloud (field-level merge)',
      );
      expect(r.read<int>('dirty'), 1);
      expect(r.read<String>('dirty_fields'), contains('orden'));
    });

    test('dirty row whose orden already matches cloud converges: dirty '
        'cleared, cloud clock adopted', () async {
      await db.restoreClienteFromCloud(cloudRow(orden: 7));
      final r =
          (await db
                  .customSelect(
                    'SELECT orden, dirty, dirty_fields, updated_at '
                    'FROM clientes WHERE id = 10',
                  )
                  .get())
              .single;
      expect(r.read<int>('orden'), 7);
      expect(r.read<int>('dirty'), 0, reason: 'no residual stuck-dirty loop');
      expect(r.read<String>('dirty_fields'), '');
      expect(
        r.read<int>('updated_at'),
        DateTime.parse('2030-01-01T00:00:00.000Z').millisecondsSinceEpoch,
      );
    });
  });
}
