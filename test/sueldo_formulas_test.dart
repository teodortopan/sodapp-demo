import 'package:flutter_test/flutter_test.dart';
import 'package:sodapp_demo/utils/sueldo_formulas.dart';

/// Pins the user-confirmed bruto/neto formulas. If anyone tries to
/// re-fold cuentaCorriente into bruto/neto, these tests fail loudly.
void main() {
  test('typical day with cash, transfer, credit, and gastos', () {
    final s = computeSueldo(
      efectivo: 10000,
      transferencia: 5000,
      cuentaCorriente: 3000,
      gastos: 1000,
    );
    expect(s.bruto, 15000); // 10000 + 5000
    expect(s.neto, 14000); // 10000 + 5000 - 1000
  });

  test('all-cash day, no credit, no gastos', () {
    final s = computeSueldo(
      efectivo: 20000,
      transferencia: 0,
      cuentaCorriente: 0,
      gastos: 0,
    );
    expect(s.bruto, 20000);
    expect(s.neto, 20000);
  });

  test('full-credit day, nothing collected', () {
    final s = computeSueldo(
      efectivo: 0,
      transferencia: 0,
      cuentaCorriente: 15000,
      gastos: 0,
    );
    expect(s.bruto, 0);
    expect(s.neto, 0);
  });

  test('break-even cash vs credit', () {
    final s = computeSueldo(
      efectivo: 10000,
      transferencia: 0,
      cuentaCorriente: 10000,
      gastos: 0,
    );
    expect(s.bruto, 10000);
    expect(s.neto, 10000);
  });

  test('zero day', () {
    final s = computeSueldo(
      efectivo: 0,
      transferencia: 0,
      cuentaCorriente: 0,
      gastos: 0,
    );
    expect(s.bruto, 0);
    expect(s.neto, 0);
  });

  test('gastos-only day (no sales)', () {
    final s = computeSueldo(
      efectivo: 0,
      transferencia: 0,
      cuentaCorriente: 0,
      gastos: 500,
    );
    expect(s.bruto, 0);
    expect(s.neto, -500);
  });

  test('mixed payment methods', () {
    final s = computeSueldo(
      efectivo: 7500,
      transferencia: 12500,
      cuentaCorriente: 2000,
      gastos: 800,
    );
    expect(s.bruto, 20000); // 7500 + 12500
    expect(s.neto, 19200); // 7500 + 12500 - 800
  });

  test('decimals preserved', () {
    final s = computeSueldo(
      efectivo: 1234.56,
      transferencia: 789.01,
      cuentaCorriente: 100.00,
      gastos: 50.50,
    );
    expect(s.bruto, closeTo(2023.57, 0.001));
    expect(s.neto, closeTo(1973.07, 0.001));
  });
}
