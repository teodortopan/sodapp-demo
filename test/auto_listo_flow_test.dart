import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Auto-Listo (auto_listo_on_pago) + mensajes web→app: source guards on
/// the mobile wiring.
///
/// Design decisions pinned here on purpose:
///  • The método BUTTON is the auto-Listo trigger. Typing a monto
///    (auto-save onChanged) does NOT auto-complete — typing is
///    incremental, not intent.
///  • Toggling a método OFF (_removePago) does not un-complete.
void main() {
  late String rutaSrc;

  setUpAll(() {
    rutaSrc = File('lib/screens/ruta_screen.dart').readAsStringSync();
  });

  group('auto-Listo: marcar → cerrar panel → abrir el siguiente', () {
    test('every sheet pago pop is followed by opening the next pending '
        'panel', () {
      // El panel nuevo, setStatus y el cierre del flujo avanzado comparten
      // el mismo helper para continuar con el siguiente cliente pendiente.
      final pops = '_openNextPendingPanelAfter(cliente.id);'
          .allMatches(rutaSrc)
          .length;
      expect(
        pops,
        3,
        reason:
            'mark listo + close + open-next must fire from EVERY método '
            'button AND from setStatus (any status advances) in the sheet',
      );
    });

    test('the open-next helper scans forward to the next pending client '
        'and opens its sheet post-frame', () {
      final idx = rutaSrc.indexOf('void _openNextPendingPanelAfter(');
      expect(idx, isNot(-1));
      final body = rutaSrc.substring(idx, idx + 1400);
      expect(body, contains("_getClientStatus(candidate.id) == 'pending'"));
      expect(
        body,
        contains('addPostFrameCallback'),
        reason:
            'the current sheet\'s pop must land before pushing the '
            'next one',
      );
      expect(body, contains('_showClientDetail(candidate, idx);'));
    });

    test('inline chips await the auto-complete (were fire-and-forget)', () {
      final fireAndForget = RegExp(
        r'\.then\(\(ok\)\s*\{\s*if \(!ok\) return;\s*_maybeAutoCompleteOnPago\(',
      );
      expect(
        fireAndForget.hasMatch(rutaSrc),
        isFalse,
        reason: 'unawaited auto-complete raced UI updates',
      );
      expect(rutaSrc, contains('await _maybeAutoCompleteOnPago('));
    });

    test('the MP QR confirm awaits the pago + auto-complete before the '
        'snackbar', () {
      final idx = rutaSrc.indexOf('onPaymentConfirmed: () async {');
      expect(idx, isNot(-1), reason: 'QR callback must be async-awaited');
      final body = rutaSrc.substring(idx, idx + 900);
      expect(
        body,
        contains("final ok = await _setPago(clienteId, 'transferencia'"),
      );
      expect(body, contains('await _maybeAutoCompleteOnPago('));
    });
  });
}
