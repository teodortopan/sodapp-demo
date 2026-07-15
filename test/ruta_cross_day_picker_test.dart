import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the Ruta cross-day picker and cross-day search wiring.
///
/// These tests intentionally inspect source windows so they catch accidental
/// removal of the button, picker entry point, or other-day search query without
/// needing to boot the full Ruta widget and database stack.
void main() {
  group('ruta cross-day picker regression guard', () {
    late String src;

    setUpAll(() {
      src = File('lib/screens/ruta_screen.dart').readAsStringSync();
    });

    String sourceWindow({
      required String anchor,
      required int before,
      required int after,
    }) {
      final anchorIdx = src.indexOf(anchor);
      expect(anchorIdx, isNot(-1), reason: 'expected anchor: $anchor');

      final start = (anchorIdx - before).clamp(0, src.length);
      final end = (anchorIdx + after).clamp(0, src.length);
      return src.substring(start, end);
    }

    test('picker method exists and plus button opens it', () {
      expect(src.contains('void _showCrossDayPicker()'), isTrue);

      final plusButtonWindow = sourceWindow(
        anchor: 'Icons.add,',
        before: 1000,
        after: 200,
      );

      expect(plusButtonWindow, contains('widget.selectedDay'));
      expect(plusButtonWindow, contains('>= 0'));
      expect(plusButtonWindow, contains('onTap: _showCrossDayPicker'));
    });

    test('search loads clientes from days other than selected day', () {
      final applyFiltersWindow = sourceWindow(
        anchor: 'List<Cliente> _applyFilters',
        before: 0,
        after: 1800,
      );

      expect(applyFiltersWindow, contains('_loadCrossDaySearchMatches(query)'));
      expect(applyFiltersWindow, contains('query.isNotEmpty'));

      final crossDaySearchWindow = sourceWindow(
        anchor: 'Future<void> _loadCrossDaySearchMatches',
        before: 0,
        after: 2200,
      );

      expect(crossDaySearchWindow, contains('widget.selectedDay'));
      expect(crossDaySearchWindow, contains('day != selectedDay'));
      expect(
        crossDaySearchWindow,
        contains('getClientesForRepartoDay(repartoId, day)'),
      );
    });
  });
}
