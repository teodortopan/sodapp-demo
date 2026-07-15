import 'package:flutter_test/flutter_test.dart';
import 'package:sodapp_demo/utils/pack_format.dart';

void main() {
  test('formats pack quantities', () {
    expect(formatPackQty(5, null), '5');
    expect(formatPackQty(5, 1), '5');
    expect(formatPackQty(12, 6), '(2)');
    expect(formatPackQty(14, 6), '(2) +2');
    expect(formatPackQty(0, 6), '0');
    expect(formatPackQty(6, 6), '(1)');
    expect(formatPackQty(-3, 6), '-3');
  });
}
