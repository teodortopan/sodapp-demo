import 'package:flutter_test/flutter_test.dart';
import 'package:sodapp_demo/utils/argentina_time.dart';

void main() {
  test('argentinaWeekString uses ISO 8601 boundary weeks', () {
    const vectors = {
      '2024-12-30': '2025-W01',
      '2025-01-01': '2025-W01',
      '2025-12-29': '2026-W01',
      '2026-12-28': '2026-W53',
      '2027-01-04': '2027-W01',
      '2026-03-15': '2026-W11',
    };

    for (final entry in vectors.entries) {
      expect(
        argentinaWeekString(at: DateTime.parse(entry.key)),
        entry.value,
        reason: entry.key,
      );
    }
  });
}
