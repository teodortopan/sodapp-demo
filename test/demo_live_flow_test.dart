import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source guards for the demo "live delivery loop" (demo branch only).
///
/// In demo the sodero can run the FULL loop against the seeded example clients
/// — start/end a recorrido, load carga, mark entregas, take pagos, add gastos,
/// close the day — but CANNOT touch the client roster/config, products/prices,
/// invoicing, Mercado Pago, per-order price overrides, or past records.
///
/// These pins lock BOTH directions: the live-flow guards must be flag-gated
/// (`!kDemoAllowLiveFlow && blockDemoAction(...)`), and the locked actions must
/// keep their bare `blockDemoAction(...)` guard so we never over-relax.
void main() {
  String read(String p) => File(p).readAsStringSync();

  /// A window of [len] chars starting at the first occurrence of [marker].
  String windowAt(String src, String marker, {int len = 240}) {
    final i = src.indexOf(marker);
    expect(i, isNot(-1), reason: 'marker not found: $marker');
    return src.substring(i, (i + len).clamp(0, src.length));
  }

  test('demo_mode defines the live-flow policy flag', () {
    expect(
      read('lib/demo/demo_mode.dart'),
      contains('const bool kDemoAllowLiveFlow = true;'),
    );
  });

  group('ALLOWED — live-flow guards are flag-gated', () {
    test('home_screen: start/end recorrido + open cierre', () {
      final src = read('lib/screens/home_screen.dart');
      expect(
        windowAt(src, 'Future<void> _startRecorridoAsync() async {'),
        contains('!kDemoAllowLiveFlow && blockDemoAction'),
      );
      expect(
        windowAt(src, 'void _confirmEndRecorrido() {'),
        contains('!kDemoAllowLiveFlow && blockDemoAction'),
      );
      // Opening the cierre is allowed via the flag (was a hard `if (kDemoMode)`).
      expect(
        windowAt(src, 'void _showCierreSummary() async {', len: 320),
        contains('kDemoMode && !kDemoAllowLiveFlow'),
      );
    });

    test('ruta_screen: pago/entrega/status/mark are flag-gated', () {
      final src = read('lib/screens/ruta_screen.dart');
      for (final marker in [
        'Future<bool> _setPago(',
        'Future<void> _updateEntrega(',
        'Future<void> _persistStatusMarker(',
        'Future<void> _toggleClienteMark(Cliente cliente) async {',
      ]) {
        expect(
          windowAt(src, marker, len: 320),
          contains('!kDemoAllowLiveFlow && blockDemoAction'),
          reason: '$marker must be flag-gated',
        );
      }
    });

    test('ruta_screen: both delivery sheets become interactive in demo', () {
      final src = read('lib/screens/ruta_screen.dart');
      // The live inline card + the detail sheet both flip readOnly off.
      final flipped = 'final readOnly = kDemoMode && !kDemoAllowLiveFlow;'
          .allMatches(src)
          .length;
      expect(flipped, 2, reason: 'both readOnly sheets must be flag-gated');
      // No bare `readOnly = kDemoMode;` left behind.
      expect(src, isNot(contains('final readOnly = kDemoMode;')));
    });

    test(
      'carga/gastos/cierre: quantities, gastos, and cierre are flag-gated',
      () {
        expect(
          windowAt(
            read('lib/screens/carga_screen.dart'),
            'Future<void> _updateQuantity(int productId, int delta) async {',
          ),
          contains('!kDemoAllowLiveFlow && blockDemoAction'),
        );
        expect(
          windowAt(
            read('lib/screens/gastos_screen.dart'),
            'Future<void> _agregar() async {',
          ),
          contains('!kDemoAllowLiveFlow && blockDemoAction'),
        );
        expect(
          windowAt(
            read('lib/screens/cierre_screen.dart'),
            'Future<void> _saveResumen() async {',
          ),
          contains('!kDemoAllowLiveFlow && blockDemoAction'),
        );
      },
    );
  });

  group('STILL BLOCKED — locked actions keep their bare guard (no flag)', () {
    test('ruta_screen: factura / MP QR / price override / dar de baja', () {
      final src = read('lib/screens/ruta_screen.dart');
      for (final marker in [
        'Future<void> _generateFactura(Cliente cliente) async {',
        'void _showMpQrDialog(',
        'void _showPriceSelector(',
        'void _confirmDarDeBaja(Cliente cliente) {',
      ]) {
        final w = windowAt(src, marker, len: 220);
        expect(
          w,
          contains('blockDemoAction'),
          reason: '$marker must stay blocked',
        );
        expect(
          w,
          isNot(contains('kDemoAllowLiveFlow')),
          reason: '$marker must NOT be relaxed',
        );
      }
    });

    test(
      'carga_screen: adding a product / opening the price panel stay blocked',
      () {
        final src = read('lib/screens/carga_screen.dart');
        for (final marker in [
          'void _showAddProductDialog() {',
          'void _showPricePanel(Producto product) async {',
        ]) {
          final w = windowAt(src, marker, len: 200);
          expect(w, contains('blockDemoAction'));
          expect(w, isNot(contains('kDemoAllowLiveFlow')));
        }
      },
    );

    test('client + product + profile config never reference the live flag', () {
      // The whole point: the live flag must not leak into the config screens,
      // and they must still gate with blockDemoAction.
      for (final path in [
        'lib/screens/clientes_screen.dart',
        'lib/screens/configuracion_screen.dart',
        'lib/screens/profile_screen.dart',
      ]) {
        final src = read(path);
        expect(
          src,
          isNot(contains('kDemoAllowLiveFlow')),
          reason: '$path must stay fully locked (no live-flow flag)',
        );
        expect(
          src,
          contains('blockDemoAction'),
          reason: '$path must keep its demo guards',
        );
      }
    });
  });
}
