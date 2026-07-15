import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rutaSrc;
  late String demoSeedSrc;

  setUpAll(() {
    rutaSrc = File('lib/screens/ruta_screen.dart').readAsStringSync();
    demoSeedSrc = File('lib/demo/demo_data_seed.dart').readAsStringSync();
  });

  String methodBody(String source, String name) {
    final start = source.indexOf(name);
    expect(start, isNot(-1), reason: 'Expected to find $name');
    final brace = source.indexOf('{', start);
    expect(brace, isNot(-1), reason: 'Expected $name to have a body');

    var depth = 0;
    for (var i = brace; i < source.length; i++) {
      final char = source[i];
      if (char == '{') depth++;
      if (char == '}') depth--;
      if (depth == 0) return source.substring(brace, i + 1);
    }
    fail('Could not find end of $name');
  }

  test('expanded ruta map does not require simulator GPS to render', () {
    final body = methodBody(rutaSrc, 'Widget _buildExpandedMap');

    expect(body, contains('GoogleMap('));
    expect(body, contains('target: _mapInitialTarget()'));
    expect(body, contains('zoom: _mapInitialZoom()'));
    expect(body, contains('myLocationEnabled: _currentLocation != null'));
    expect(
      body,
      isNot(contains('if (_currentLocation != null)\n          GoogleMap(')),
      reason:
          'The iPhone simulator can fail to return GPS, but the map '
          'should still render using client markers or a neutral fallback.',
    );
  });

  test('fallback camera prefers route/client anchors before default city', () {
    final targetBody = methodBody(rutaSrc, 'LatLng _mapInitialTarget');
    final focusBody = methodBody(rutaSrc, 'void _focusMapOnFallbackIfNeeded');

    expect(targetBody, contains('if (_currentLocation != null)'));
    expect(targetBody, contains('_miniCardClienteId ?? _activeClienteId'));
    expect(targetBody, contains('_geocodedLocations.values.first'));
    expect(targetBody, contains('const LatLng(-34.6037, -58.3816)'));
    expect(focusBody, contains('_mapFallbackCameraApplied'));
    expect(focusBody, contains('CameraUpdate.newLatLngZoom'));
  });

  test('manual list/map choice is not overridden by tutorial state', () {
    final body = methodBody(rutaSrc, 'Widget _buildRutaBody');

    expect(rutaSrc, isNot(contains('_tutorialForcesList')));
    expect(rutaSrc, isNot(contains('_tutorialWasForcingList')));
    expect(body, contains('if (_mapExpanded) return _buildExpandedMap();'));
    expect(body, isNot(contains('TutorialController.instance')));
  });

  test('demo ruta starts in list view until mapa is chosen manually', () {
    expect(demoSeedSrc, contains('"map_enabled = 0, "'));
    expect(demoSeedSrc, isNot(contains('"map_enabled = 1, "')));
  });
}
