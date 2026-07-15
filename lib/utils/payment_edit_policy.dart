import 'parse_number.dart';

enum PaymentEditActionKind { none, save, remove, needsMethod }

class PaymentEditAction {
  final PaymentEditActionKind kind;
  final String? metodoPago;
  final double monto;

  const PaymentEditAction._(this.kind, {this.metodoPago, this.monto = 0});

  const PaymentEditAction.none() : this._(PaymentEditActionKind.none);

  const PaymentEditAction.needsMethod()
    : this._(PaymentEditActionKind.needsMethod);

  const PaymentEditAction.remove() : this._(PaymentEditActionKind.remove);

  const PaymentEditAction.save(String metodoPago, double monto)
    : this._(PaymentEditActionKind.save, metodoPago: metodoPago, monto: monto);
}

const Set<String> nonPaymentMethods = {
  'no_pago',
  'no_compro',
  'ausente',
  'saltado',
};

bool isRealPaymentMethod(String? metodoPago) {
  return metodoPago != null && !nonPaymentMethods.contains(metodoPago);
}

PaymentEditAction resolvePaymentEditAction({
  required String rawMonto,
  required String? currentMetodoPago,
  required String? rememberedMetodoPago,
  required bool commit,
  bool defaultPositiveToEfectivo = false,
}) {
  final monto = (parseArgNumber(rawMonto) ?? 0).toDouble();
  final currentIsPayment = isRealPaymentMethod(currentMetodoPago);
  final metodo = currentIsPayment
      ? currentMetodoPago
      : isRealPaymentMethod(rememberedMetodoPago)
      ? rememberedMetodoPago
      : null;

  if (monto > 0) {
    final metodoToSave =
        metodo ?? (defaultPositiveToEfectivo ? 'efectivo' : null);
    if (metodoToSave == null) return const PaymentEditAction.needsMethod();
    return PaymentEditAction.save(metodoToSave, monto);
  }

  if (!commit) return const PaymentEditAction.none();
  if (currentIsPayment) return const PaymentEditAction.remove();
  return const PaymentEditAction.none();
}
