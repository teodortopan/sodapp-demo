import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sodapp_demo/utils/factura_guards.dart';

/// P0-5 regression tests — never bill a $0 line to AFIP (pre-release audit
/// fix #5, extended per Codex review to cover EVERY invoice entry point).
///
/// Invoice builders price each line from the entrega snapshot with a
/// getEffectivePrice fallback. When BOTH are zero (producto without a
/// configured price, legacy row), the old code silently issued the factura
/// with a $0 line — an understated importeTotal reported to AFIP and stored
/// forever in facturas. Both invoice paths (Ruta AND Clientes) must block
/// before their confirmation dialogs, naming the unpriced productos.
void main() {
  group('unpricedFacturaItems (shared guard logic)', () {
    test('collects only items priced at zero or less', () {
      final items = <Map<String, dynamic>>[
        {'nombre': 'Soda', 'cantidad': 2, 'precioUnit': 100.0},
        {'nombre': 'Bidón', 'cantidad': 1, 'precioUnit': 0.0},
        {'nombre': 'Pack', 'cantidad': 3, 'precioUnit': -1.0},
      ];
      expect(unpricedFacturaItems(items), ['Bidón', 'Pack']);
    });

    test('treats a missing/null price as unpriced (never bill it)', () {
      expect(
        unpricedFacturaItems([
          {'nombre': 'Sifón', 'cantidad': 1},
        ]),
        ['Sifón'],
      );
    });

    test('returns empty for a fully priced invoice', () {
      expect(
        unpricedFacturaItems([
          {'nombre': 'Soda', 'precioUnit': 100.0},
          {'nombre': 'Bidón', 'precioUnit': 0.01},
        ]),
        isEmpty,
      );
    });
  });

  group('invoice entry points use the guard', () {
    for (final entry in const {
      'lib/screens/ruta_screen.dart': '// 3. Show confirmation dialog',
      'lib/screens/clientes_screen.dart': '// 3. Confirm',
    }.entries) {
      test('${entry.key} blocks unpriced lines before its confirmation '
          'dialog', () {
        final src = File(entry.key).readAsStringSync();
        expect(
          src,
          contains("import '../utils/factura_guards.dart';"),
          reason: 'every invoice path shares ONE guard implementation',
        );
        final guardIdx = src.indexOf(
          'final sinPrecio = unpricedFacturaItems(items);',
        );
        expect(
          guardIdx,
          isNot(-1),
          reason: '${entry.key} must collect unpriced lines',
        );
        final confirmIdx = src.indexOf(entry.value, guardIdx);
        expect(
          confirmIdx,
          greaterThan(guardIdx),
          reason:
              'the block must run BEFORE the user can confirm — a \$0 '
              'line must never reach AFIP from ${entry.key}',
        );
        final guardBlock = src.substring(guardIdx, confirmIdx);
        expect(
          guardBlock,
          contains('sin precio '),
          reason: 'snackbar names the unpriced productos',
        );
        expect(
          guardBlock,
          contains('return;'),
          reason: 'an unpriced invoice must abort, not continue',
        );
      });
    }
  });
}
