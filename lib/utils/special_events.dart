import 'anniversary.dart';

/// What kind of day a [SpecialEvent] is. The order is also the tie-break
/// when two events fall on the same date: the first one listed wins.
enum SpecialEventKind {
  anniversary,
  monthsary,
  partnerBirthday,
  myBirthday,
  valentines,
  custom,
}

/// One upcoming special day, worked out from data the app already has.
/// Pure Dart, so the maths can be unit tested (test/special_events_test.dart).
class SpecialEvent {
  const SpecialEvent({
    required this.kind,
    required this.date,
    required this.daysUntil,
    this.progress,
    this.count = 0,
    this.title = '',
    this.repeatsYearly = true,
  });

  final SpecialEventKind kind;

  /// The day it happens, as a whole UTC date.
  final DateTime date;

  /// 0 means today.
  final int daysUntil;

  /// How far through the wait we are: 0.0 just after the previous
  /// occurrence (or when it was planned), 1.0 on the day. Null when there is
  /// nothing meaningful to measure from.
  final double? progress;

  /// The 3 in "3rd anniversary", "3rd monthsary" or "turning 3".
  /// 0 when it does not apply.
  final int count;

  /// A custom event's own title.
  final String title;

  /// Only meaningful for custom events.
  final bool repeatsYearly;

  bool get isToday => daysUntil == 0;
}

/// A couple-created date (from `important_dates`), in the form the event
/// maths needs. [createdAt] is used to measure progress towards a one-off.
class CustomDate {
  const CustomDate({
    required this.title,
    required this.date,
    this.repeatsYearly = true,
    this.createdAt,
  });

  final String title;
  final DateTime date;
  final bool repeatsYearly;
  final DateTime? createdAt;
}

DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

bool _isLeap(int year) => (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

int _daysInMonth(int year, int month) => switch (month) {
  2 => _isLeap(year) ? 29 : 28,
  4 || 6 || 9 || 11 => 30,
  _ => 31,
};

/// The [k]th monthly occurrence of [start]: the same day of the month,
/// moved to the month's last day when that month is shorter (a 31 January
/// start falls on 28 or 29 February, then 31 March).
DateTime monthlyOccurrence(DateTime start, int k) {
  final months = start.month - 1 + k;
  final year = start.year + months ~/ 12;
  final month = months % 12 + 1;
  final day = start.day.clamp(1, _daysInMonth(year, month));
  return DateTime.utc(year, month, day);
}

/// The next anniversary of [start]. Null if they got together today or the
/// date is in the future (there is nothing to count to yet).
SpecialEvent? nextAnniversary(DateTime start, {required DateTime today}) {
  final t = _day(today);
  if (!_day(start).isBefore(t)) return null;
  final info = AnniversaryInfo.from(start, today: t);
  return SpecialEvent(
    kind: SpecialEventKind.anniversary,
    date: info.nextDate,
    daysUntil: info.daysUntilNext,
    progress: info.isToday ? 1 : info.yearProgress,
    count: info.yearsAtNext,
  );
}

/// The next monthsary of [start]. Every 12th month is an anniversary
/// instead, so it is skipped here.
SpecialEvent? nextMonthsary(DateTime start, {required DateTime today}) {
  final t = _day(today);
  final s = _day(start);
  if (!s.isBefore(t)) return null;
  var k = (t.year - s.year) * 12 + (t.month - s.month);
  if (k < 1) k = 1;
  while (k > 1 && !monthlyOccurrence(s, k - 1).isBefore(t)) {
    k--;
  }
  while (monthlyOccurrence(s, k).isBefore(t) || k % 12 == 0) {
    k++;
  }
  final next = monthlyOccurrence(s, k);
  final previous = monthlyOccurrence(s, k - 1);
  final span = next.difference(previous).inDays;
  final days = next.difference(t).inDays;
  return SpecialEvent(
    kind: SpecialEventKind.monthsary,
    date: next,
    daysUntil: days,
    progress: days == 0
        ? 1
        : span == 0
        ? 0
        : t.difference(previous).inDays / span,
    count: k,
  );
}

/// The next yearly occurrence of a date that repeats every year, measured
/// from the previous year's occurrence (29 February falls on the 28th in
/// other years).
SpecialEvent _yearly(
  SpecialEventKind kind,
  DateTime date, {
  required DateTime today,
  String title = '',
}) {
  final t = _day(today);
  DateTime onYear(int year) => DateTime.utc(
    year,
    date.month,
    date.day.clamp(1, _daysInMonth(year, date.month)),
  );
  var next = onYear(t.year);
  if (next.isBefore(t)) next = onYear(t.year + 1);
  final previous = onYear(next.year - 1);
  final days = next.difference(t).inDays;
  return SpecialEvent(
    kind: kind,
    date: next,
    daysUntil: days,
    progress: days == 0
        ? 1
        : t.difference(previous).inDays / next.difference(previous).inDays,
    count: next.year - date.year,
    title: title,
  );
}

/// The next birthday; [count] is the age they turn.
SpecialEvent nextBirthday(
  DateTime birthday, {
  required DateTime today,
  required bool isMe,
}) => _yearly(
  isMe ? SpecialEventKind.myBirthday : SpecialEventKind.partnerBirthday,
  birthday,
  today: today,
);

/// The next 14 February.
SpecialEvent nextValentines({required DateTime today}) => _yearly(
  SpecialEventKind.valentines,
  DateTime.utc(2000, 2, 14),
  today: today,
);

/// The next occurrence of a couple-created date. Null for a one-off that
/// has passed. A repeating date whose first occurrence is still ahead is
/// treated like a one-off until then.
SpecialEvent? nextCustom(CustomDate c, {required DateTime today}) {
  final t = _day(today);
  final first = _day(c.date);
  if (c.repeatsYearly && first.isBefore(t)) {
    return _yearly(SpecialEventKind.custom, first, today: t, title: c.title);
  }
  if (first.isBefore(t)) return null;
  final days = first.difference(t).inDays;
  double? progress;
  if (days == 0) {
    progress = 1;
  } else if (c.createdAt != null) {
    // From the day it was planned to the day itself.
    final planned = _day(c.createdAt!.toLocal());
    final span = first.difference(planned).inDays;
    if (span > 0 && !planned.isAfter(t)) {
      progress = t.difference(planned).inDays / span;
    }
  }
  return SpecialEvent(
    kind: SpecialEventKind.custom,
    date: first,
    daysUntil: days,
    progress: progress,
    title: c.title,
    repeatsYearly: c.repeatsYearly,
  );
}

/// Every upcoming special day, soonest first (ties in [SpecialEventKind]
/// order, then by title).
List<SpecialEvent> upcomingEvents({
  required DateTime today,
  DateTime? together,
  DateTime? myBirthday,
  DateTime? partnerBirthday,
  List<CustomDate> custom = const [],
}) {
  final events = <SpecialEvent>[
    if (together != null) ...[
      ?nextAnniversary(together, today: today),
      ?nextMonthsary(together, today: today),
    ],
    if (partnerBirthday != null)
      nextBirthday(partnerBirthday, today: today, isMe: false),
    if (myBirthday != null) nextBirthday(myBirthday, today: today, isMe: true),
    nextValentines(today: today),
    for (final c in custom) ?nextCustom(c, today: today),
  ];
  events.sort((a, b) {
    final byDays = a.daysUntil.compareTo(b.daysUntil);
    if (byDays != 0) return byDays;
    final byKind = a.kind.index.compareTo(b.kind.index);
    if (byKind != 0) return byKind;
    return a.title.compareTo(b.title);
  });
  return events;
}

/// The soonest special day. Valentine's Day is always a candidate, so there
/// is always one.
SpecialEvent nearestEvent({
  required DateTime today,
  DateTime? together,
  DateTime? myBirthday,
  DateTime? partnerBirthday,
  List<CustomDate> custom = const [],
}) => upcomingEvents(
  today: today,
  together: together,
  myBirthday: myBirthday,
  partnerBirthday: partnerBirthday,
  custom: custom,
).first;

const _fullMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// October 2, 2027
String fullDate(DateTime d) =>
    '${_fullMonths[d.month - 1]} ${d.day}, ${d.year}';

/// October 2
String monthDay(DateTime d) => '${_fullMonths[d.month - 1]} ${d.day}';
