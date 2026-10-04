import 'package:final_project/utils/special_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

  group('monthsary', () {
    test('counts months from the start date', () {
      final e = nextMonthsary(d(2026, 7, 2), today: d(2026, 9, 20))!;
      expect(e.date, d(2026, 10, 2));
      expect(e.count, 3);
      expect(e.daysUntil, 12);
    });

    test('a 31st start falls on the last day of shorter months', () {
      expect(monthlyOccurrence(d(2027, 1, 31), 1), d(2027, 2, 28));
      expect(monthlyOccurrence(d(2028, 1, 31), 1), d(2028, 2, 29)); // leap
      expect(monthlyOccurrence(d(2027, 1, 31), 2), d(2027, 3, 31));
      expect(monthlyOccurrence(d(2027, 1, 31), 3), d(2027, 4, 30));
    });

    test('every 12th month is left to the anniversary', () {
      final e = nextMonthsary(d(2026, 1, 10), today: d(2026, 12, 20))!;
      expect(e.count, 13);
      expect(e.date, d(2027, 2, 10));
    });

    test('is today on the day', () {
      final e = nextMonthsary(d(2026, 7, 2), today: d(2026, 10, 2))!;
      expect(e.isToday, isTrue);
      expect(e.count, 3);
      expect(e.progress, 1);
    });

    test('progress runs from the previous monthsary', () {
      final e = nextMonthsary(d(2026, 7, 2), today: d(2026, 9, 17))!;
      // 2 Sep -> 2 Oct is 30 days; 15 have passed.
      expect(e.progress, closeTo(0.5, 1e-9));
    });
  });

  group('anniversary', () {
    test('numbers and progress', () {
      final e = nextAnniversary(d(2026, 10, 2), today: d(2026, 10, 4))!;
      expect(e.date, d(2027, 10, 2));
      expect(e.count, 1);
      expect(e.daysUntil, 363);
      expect(e.progress, closeTo(2 / 365, 1e-9));
    });

    test('nothing to count on the day they got together', () {
      expect(nextAnniversary(d(2026, 10, 4), today: d(2026, 10, 4)), isNull);
      expect(nextMonthsary(d(2026, 10, 4), today: d(2026, 10, 4)), isNull);
    });
  });

  group('yearly days', () {
    test('birthday counts the age they turn', () {
      final e = nextBirthday(
        d(2002, 11, 3),
        today: d(2026, 10, 4),
        isMe: false,
      );
      expect(e.kind, SpecialEventKind.partnerBirthday);
      expect(e.date, d(2026, 11, 3));
      expect(e.count, 24);
    });

    test('a 29 February birthday falls on the 28th in other years', () {
      final e = nextBirthday(d(2004, 2, 29), today: d(2027, 1, 1), isMe: true);
      expect(e.date, d(2027, 2, 28));
    });

    test("Valentine's progress runs from last 14 February", () {
      final e = nextValentines(today: d(2026, 10, 4));
      expect(e.date, d(2027, 2, 14));
      expect(e.progress, closeTo(232 / 365, 1e-9));
    });
  });

  group('custom dates', () {
    test('a one-off measures from when it was planned', () {
      final e = nextCustom(
        CustomDate(
          title: 'Beach Trip',
          date: d(2026, 10, 14),
          repeatsYearly: false,
          createdAt: DateTime(2026, 9, 24, 15),
        ),
        today: d(2026, 10, 4),
      )!;
      expect(e.daysUntil, 10);
      expect(e.progress, closeTo(0.5, 1e-9));
    });

    test('a one-off with nothing to measure from has no progress', () {
      final e = nextCustom(
        CustomDate(title: 'Trip', date: d(2026, 10, 14), repeatsYearly: false),
        today: d(2026, 10, 4),
      )!;
      expect(e.progress, isNull);
    });

    test('a past one-off is gone', () {
      expect(
        nextCustom(
          CustomDate(title: 'Trip', date: d(2026, 9, 1), repeatsYearly: false),
          today: d(2026, 10, 4),
        ),
        isNull,
      );
    });
  });

  group('nearest', () {
    test('picks the soonest event', () {
      final e = nearestEvent(
        today: d(2026, 10, 4),
        together: d(2026, 7, 2),
        partnerBirthday: d(2002, 10, 20),
        myBirthday: d(2001, 12, 1),
      );
      expect(e.kind, SpecialEventKind.partnerBirthday); // Oct 20 < Nov 2
    });

    test('ties go to the anniversary, then the monthsary, then birthdays', () {
      final e = nearestEvent(
        today: d(2026, 10, 1),
        together: d(2025, 10, 2),
        partnerBirthday: d(2000, 10, 2),
      );
      expect(e.kind, SpecialEventKind.anniversary);
      final m = nearestEvent(
        today: d(2026, 10, 1),
        together: d(2026, 8, 2),
        myBirthday: d(2000, 10, 2),
      );
      expect(m.kind, SpecialEventKind.monthsary);
    });

    test("falls back to Valentine's Day when nothing else is set", () {
      expect(
        nearestEvent(today: d(2026, 10, 4)).kind,
        SpecialEventKind.valentines,
      );
    });
  });

  test('full dates', () {
    expect(fullDate(d(2027, 10, 2)), 'October 2, 2027');
  });
}
