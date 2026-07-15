import 'package:flutter_test/flutter_test.dart';
import 'package:sodapp_demo/utils/payment_edit_policy.dart';

void main() {
  group('resolvePaymentEditAction', () {
    test('does not remove a payment while a focused amount field is empty', () {
      final action = resolvePaymentEditAction(
        rawMonto: '',
        currentMetodoPago: 'efectivo',
        rememberedMetodoPago: null,
        commit: false,
      );

      expect(action.kind, PaymentEditActionKind.none);
    });

    test('saves a retyped amount with the remembered payment method', () {
      final action = resolvePaymentEditAction(
        rawMonto: '7000',
        currentMetodoPago: null,
        rememberedMetodoPago: 'transferencia',
        commit: false,
      );

      expect(action.kind, PaymentEditActionKind.save);
      expect(action.metodoPago, 'transferencia');
      expect(action.monto, 7000);
    });

    test(
      'requires a method for positive inline edits with no payment context',
      () {
        final action = resolvePaymentEditAction(
          rawMonto: '1200',
          currentMetodoPago: null,
          rememberedMetodoPago: null,
          commit: true,
        );

        expect(action.kind, PaymentEditActionKind.needsMethod);
      },
    );

    test('removes an existing real payment when empty amount is committed', () {
      final action = resolvePaymentEditAction(
        rawMonto: '',
        currentMetodoPago: 'efectivo',
        rememberedMetodoPago: 'efectivo',
        commit: true,
      );

      expect(action.kind, PaymentEditActionKind.remove);
    });

    test('does not remove no_pago when an empty amount is committed', () {
      final action = resolvePaymentEditAction(
        rawMonto: '',
        currentMetodoPago: 'no_pago',
        rememberedMetodoPago: 'efectivo',
        commit: true,
      );

      expect(action.kind, PaymentEditActionKind.none);
    });

    test('detail panel can default a positive amount to efectivo', () {
      final action = resolvePaymentEditAction(
        rawMonto: '1.500,75',
        currentMetodoPago: null,
        rememberedMetodoPago: null,
        commit: true,
        defaultPositiveToEfectivo: true,
      );

      expect(action.kind, PaymentEditActionKind.save);
      expect(action.metodoPago, 'efectivo');
      expect(action.monto, 1500.75);
    });
  });
}
