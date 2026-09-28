import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/utils/money.dart';

void main() {
  group('formatPeso', () {
    test('groups thousands and hides zero cents', () {
      expect(formatPeso(60000), '\u20B160,000');
      expect(formatPeso(1250.5), '\u20B11,250.50');
      expect(formatPeso(999), '\u20B1999');
      expect(formatPeso(1234567.89), '\u20B11,234,567.89');
      expect(formatPeso(0), '\u20B10');
    });
  });

  group('parsePeso', () {
    test('reads what people type', () {
      expect(parsePeso('60000'), 60000);
      expect(parsePeso('60,000'), 60000);
      expect(parsePeso('\u20B1 1,250.5'), 1250.5);
    });

    test('rejects anything that is not a positive amount', () {
      expect(parsePeso(''), isNull);
      expect(parsePeso('abc'), isNull);
      expect(parsePeso('0'), isNull);
      expect(parsePeso('-50'), isNull);
      expect(parsePeso('12.345'), isNull); // more than two decimals
    });
  });

  test('readAmount accepts numbers or text', () {
    expect(readAmount(500), 500.0);
    expect(readAmount('1250.50'), 1250.5);
    expect(readAmount(null), isNull);
  });
}
