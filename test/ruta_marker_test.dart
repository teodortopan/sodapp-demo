import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression guard for Ruta's per-week cliente markers.
///
/// These tests intentionally inspect narrow source windows so the local-only
/// raw-SQL marker path cannot accidentally move into Drift schema generation,
/// sync, or the normal cliente expansion tap path.
void main() {
  group('ruta cliente marker regression guard', () {
    late String dbSrc;
    late String rutaSrc;

    setUpAll(() {
      dbSrc = File('lib/database/app_database.dart').readAsStringSync();
      rutaSrc = File('lib/screens/ruta_screen.dart').readAsStringSync();
    });

    String sourceWindow(
      String src, {
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

    test('migration adds marked_semana in onCreate and v60 upgrade', () {
      // Anchor-to-anchor (the whole onCreate body, bounded by onUpgrade)
      // instead of a fixed-size window — unrelated onCreate additions kept
      // pushing this assertion out of 4500- then 5000-char windows.
      final onCreateStart = dbSrc.indexOf('onCreate: (m) async {');
      final onUpgradeStart = dbSrc.indexOf('onUpgrade: (m, from, to) async {');
      expect(onCreateStart, isNot(-1));
      expect(onUpgradeStart, greaterThan(onCreateStart));
      final onCreateWindow = dbSrc.substring(onCreateStart, onUpgradeStart);
      expect(
        onCreateWindow,
        contains('ALTER TABLE clientes ADD COLUMN marked_semana TEXT'),
      );

      final upgradeWindow = sourceWindow(
        dbSrc,
        anchor: 'if (from < 60) {',
        before: 0,
        after: 300,
      );
      expect(
        upgradeWindow,
        contains('ALTER TABLE clientes ADD COLUMN marked_semana TEXT'),
      );
    });

    test('database marker helpers are defined', () {
      expect(dbSrc, contains('Future<Set<int>> getMarkedClientesForWeek'));
      expect(dbSrc, contains('Future<void> setClienteMarked'));
      expect(dbSrc, contains('Future<void> clearClienteMark'));
    });

    test('ruta marker state and toggle helper exist', () {
      expect(rutaSrc, contains('bool _markingMode = false;'));
      expect(rutaSrc, contains('Future<void> _toggleClienteMark'));
    });

    test('cliente card tap branches on marking mode before expansion', () {
      final cardTapWindow = sourceWindow(
        rutaSrc,
        anchor: 'Widget cardWidget = Padding',
        before: 0,
        after: 2200,
      );
      expect(cardTapWindow, contains('GestureDetector'));
      expect(cardTapWindow, contains('onTap: _editMode'));

      final markingIdx = cardTapWindow.indexOf('_markingMode');
      final expansionIdx = cardTapWindow.indexOf('_expandedClienteId');
      expect(markingIdx, isNot(-1));
      expect(expansionIdx, isNot(-1));
      expect(
        markingIdx,
        lessThan(expansionIdx),
        reason: 'marking mode must intercept card taps before expansion',
      );
    });
  });
}
