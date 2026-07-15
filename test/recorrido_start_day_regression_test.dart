import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('overnight recorrido start-day guards', () {
    final homeSrc = File('lib/screens/home_screen.dart').readAsStringSync();
    final rutaSrc = File('lib/screens/ruta_screen.dart').readAsStringSync();
    final dbSrc = File('lib/database/app_database.dart').readAsStringSync();

    test('active recorrido state persists its start fecha and semana', () {
      expect(homeSrc, contains('final String fecha;'));
      expect(homeSrc, contains('final String semana;'));
      // v85: _persistRecorridoState binds the entry from `s` (the
      // in-memory _RecorridoState) — same invariant, new spelling.
      expect(homeSrc, contains("'fecha': s.fecha"));
      expect(homeSrc, contains("'semana': s.semana"));
      expect(homeSrc, contains("(saved['fecha'] as String?) ?? argFecha"));
      expect(
        homeSrc,
        contains("(saved['semana'] as String?) ?? argentinaWeekString"),
      );
    });

    test(
      'cierre summary uses the recorrido start key, not close-day clock',
      () {
        final start = homeSrc.indexOf('void _showCierreSummary() async');
        final end = homeSrc.indexOf(
          'Future<void> _ensureTodayResumen()',
          start,
        );
        expect(start, isNot(-1));
        expect(end, isNot(-1));
        final body = homeSrc.substring(start, end);

        expect(body, contains('final semana = recorridoState.semana;'));
        expect(body, contains('final fecha = recorridoState.fecha;'));
        expect(body, isNot(contains('final now = argentinaTime();')));
      },
    );

    test('live resumen recalculation targets the active start day', () {
      final start = dbSrc.indexOf('Future<void> _recalcAndSaveResumenLiveNow');
      final end = dbSrc.indexOf('/// Update an existing resumen', start);
      expect(start, isNot(-1));
      expect(end, isNot(-1));
      final body = dbSrc.substring(start, end);

      expect(body, contains("(active['fecha'] as String?) ?? argFecha"));
      expect(
        body,
        contains("(active['semana'] as String?) ?? argentinaWeekString"),
      );
      expect(
        body,
        isNot(contains('final todaySemana = argentinaWeekString();')),
      );
    });

    test('stale pruning keeps unended overnight recorridos', () {
      final start = dbSrc.indexOf(
        'Future<List<Map<String, dynamic>>> getActiveRecorridos()',
      );
      final end = dbSrc.indexOf('bool _isEndedActiveRecorridoEntry', start);
      expect(start, isNot(-1));
      expect(end, isNot(-1));
      final body = dbSrc.substring(start, end);

      expect(
        body,
        contains('if (!_isEndedActiveRecorridoEntry(entry)) return false;'),
      );
      expect(
        dbSrc,
        contains(
          'midnight so an overnight recorrido can still be finalized on its start day',
        ),
      );
    });

    test('ruta reads and writes use the active recorrido week', () {
      expect(rutaSrc, contains('final String? activeSemana;'));
      expect(
        rutaSrc,
        contains(
          'String get _currentSemana => widget.activeSemana ?? argentinaWeekString();',
        ),
      );
      expect(rutaSrc, isNot(contains('final semana = argentinaWeekString();')));
      expect(
        rutaSrc,
        isNot(contains('getMarkedClientesForWeek(argentinaWeekString())')),
      );
    });
  });
}
