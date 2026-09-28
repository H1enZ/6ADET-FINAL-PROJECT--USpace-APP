// Unit tests for the countdown maths. Plain Dart, no widgets.

import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/utils/anniversary.dart';

void main() {
  test('next anniversary later this year', () {
    final info = AnniversaryInfo.from(DateTime(2024, 2, 14),
        today: DateTime(2026, 1, 1));
    expect(info.nextDate, DateTime.utc(2026, 2, 14));
    expect(info.daysUntilNext, 44);
    expect(info.yearsAtNext, 2);
  });

  test('already passed this year, so it rolls to next year', () {
    final info = AnniversaryInfo.from(DateTime(2024, 2, 14),
        today: DateTime(2026, 9, 28));
    expect(info.nextDate, DateTime.utc(2027, 2, 14));
    expect(info.yearsAtNext, 3);
    expect(info.daysTogether, 957);
  });

  test('on the day itself', () {
    final info = AnniversaryInfo.from(DateTime(2020, 9, 28),
        today: DateTime(2026, 9, 28));
    expect(info.isToday, isTrue);
    expect(info.yearsAtNext, 6);
  });

  test('29 February falls back to 28 February in non-leap years', () {
    final info = AnniversaryInfo.from(DateTime(2024, 2, 29),
        today: DateTime(2026, 1, 1));
    expect(info.nextDate, DateTime.utc(2026, 2, 28));
  });

  test('got together today', () {
    final info = AnniversaryInfo.from(DateTime(2026, 9, 28),
        today: DateTime(2026, 9, 28));
    expect(info.yearsAtNext, 0);
    expect(info.daysTogether, 0);
  });

  test('ring progress stays between 0 and 1', () {
    final info = AnniversaryInfo.from(DateTime(2024, 2, 14),
        today: DateTime(2026, 8, 14));
    expect(info.yearProgress, greaterThan(0.4));
    expect(info.yearProgress, lessThan(0.6));
  });

  test('ordinal suffixes', () {
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 101].map(ordinal).toList(),
        ['1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd', '101st']);
  });
}
