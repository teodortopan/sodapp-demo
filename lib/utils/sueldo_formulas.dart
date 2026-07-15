/// Single source of truth for the resumen-diario "Sueldo bruto" and
/// "Sueldo neto" calculations.
///
/// Definitions:
///
///   bruto = efectivo + transferencia
///     Cash actually collected today (efectivo + transferencia).
///     `cuentaCorriente` (unpaid deuda generated today) is intentionally
///     excluded - it's not yet received and is already shown as its own
///     line in cierre / historial.
///
///   neto = efectivo + transferencia - gastos
///     Take-home cash: collected minus the day's expenses.
({double bruto, double neto}) computeSueldo({
  required double efectivo,
  required double transferencia,
  // ignore: unused_element_parameter
  required double cuentaCorriente,
  required double gastos,
}) {
  final bruto = efectivo + transferencia;
  final neto = efectivo + transferencia - gastos;
  return (bruto: bruto, neto: neto);
}
