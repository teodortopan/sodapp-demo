import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/ruta_screen.dart').readAsStringSync();

  test('_rutaFooterButton uses InkWell for visual tap feedback', () {
    final start = source.indexOf('Widget _rutaFooterButton({');
    expect(start, isNot(-1), reason: 'expected _rutaFooterButton');

    final end = source.indexOf(
      '/// Returns true if the client has a monto typed',
      start,
    );
    expect(end, isNot(-1), reason: 'expected end of _rutaFooterButton body');

    final body = source.substring(start, end);
    expect(
      body.contains('InkWell'),
      isTrue,
      reason: '_rutaFooterButton must use InkWell so footer taps are visible.',
    );
  });

  test('_showPaymentMethodWarning uses the sheet messenger when available', () {
    final start = source.indexOf('void _showPaymentMethodWarning()');
    expect(start, isNot(-1), reason: 'expected _showPaymentMethodWarning');

    final end = source.indexOf('void _showMontoWarning()', start);
    expect(
      end,
      isNot(-1),
      reason: 'expected end of _showPaymentMethodWarning body',
    );

    final body = source.substring(start, end);
    expect(
      body.contains('_sheetMessengerKey.currentState'),
      isTrue,
      reason:
          '_showPaymentMethodWarning must prefer the sheet messenger so the '
          'snackbar appears above the bottom sheet.',
    );
  });
}
