import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodapp_demo/database/app_database.dart';

void main() {
  group('carga gastos preference - behavioral', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.customStatement(
        "INSERT INTO repartos (id, nombre, user_id) VALUES (1, 'R', 'u')",
      );
      await db.customStatement(
        "INSERT INTO productos (id, reparto_id, nombre, orden, precio, "
        "deleted) VALUES (1, 1, 'Soda', 0, 100.0, 0)",
      );
      await db.customStatement(
        'INSERT INTO carga_diaria '
        '(id, producto_id, reparto_id, dia_semana, semana, cantidad, '
        "remanente, fecha) VALUES (1, 1, 1, 0, '2026-W23', 10, 2, "
        "'2026-06-08')",
      );
      await db.customStatement(
        'INSERT INTO resumenes '
        '(id, reparto_id, fecha, semana, dia_semana, duracion_segundos, '
        'efectivo, transferencia, cuenta_corriente, gastos, sueldo_bruto, '
        'sueldo_neto, productos_json, gastos_json, created_at) VALUES '
        '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          1,
          1,
          '2026-06-08',
          '2026-W23',
          0,
          0,
          0,
          0,
          0,
          850,
          -850,
          -850,
          '[]',
          '[{"descripcion":"Soda (x8)","monto":800,"type":"producto","producto_id":1},{"descripcion":"Nafta","monto":50}]',
          '2026-06-08T10:00:00.000',
        ],
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<({double gastos, String gastosJson})> resumenGastos() async {
      final row =
          (await db
                  .customSelect('SELECT gastos, gastos_json FROM resumenes')
                  .get())
              .single;
      return (
        gastos: row.read<double>('gastos'),
        gastosJson: row.read<String>('gastos_json'),
      );
    }

    test(
      'toggle removes and restores product carga gastos in resumenes',
      () async {
        await db.setCargaGastosEnabled(false);
        final off = await resumenGastos();
        expect(off.gastos, 50);
        expect(off.gastosJson, isNot(contains('"type":"producto"')));
        expect(off.gastosJson, contains('Nafta'));

        await db.setCargaGastosEnabled(true);
        final on = await resumenGastos();
        expect(on.gastos, 850);
        expect(on.gastosJson, contains('"type":"producto"'));
        expect(on.gastosJson, contains('Soda (x8)'));
      },
    );
  });
}
