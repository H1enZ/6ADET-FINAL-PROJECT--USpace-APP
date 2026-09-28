/// Countdown maths for the anniversary card. Pure Dart with no Flutter or
/// Supabase, so it can be unit tested (see test/anniversary_test.dart).
class AnniversaryInfo {
  const AnniversaryInfo({
    required this.daysTogether,
    required this.nextDate,
    required this.daysUntilNext,
    required this.yearsAtNext,
    required this.yearProgress,
  });

  final int daysTogether;
  final DateTime nextDate;
  final int daysUntilNext;

  /// 3 means the next anniversary is the 3rd. 0 means you got together today.
  final int yearsAtNext;

  /// 0.0 just after the last anniversary, 1.0 on the next one. Drives the ring.
  final double yearProgress;

  bool get isToday => daysUntilNext == 0;

  static AnniversaryInfo from(DateTime start, {DateTime? today}) {
    final now = today ?? DateTime.now();
    // Whole dates in UTC, so daylight saving and time of day never shift a
    // count by one.
    final t = DateTime.utc(now.year, now.month, now.day);
    final s = DateTime.utc(start.year, start.month, start.day);

    DateTime onYear(int year) {
      final isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
      if (s.month == 2 && s.day == 29 && !isLeap) {
        return DateTime.utc(year, 2, 28);
      }
      return DateTime.utc(year, s.month, s.day);
    }

    var next = onYear(t.year);
    if (next.isBefore(t)) next = onYear(t.year + 1);

    final previous = next.year - 1 >= s.year ? onYear(next.year - 1) : s;
    final span = next.difference(previous).inDays;
    final elapsed = t.difference(previous).inDays;

    return AnniversaryInfo(
      daysTogether: t.difference(s).inDays,
      nextDate: next,
      daysUntilNext: next.difference(t).inDays,
      yearsAtNext: next.year - s.year,
      yearProgress: span == 0 ? 0 : elapsed / span,
    );
  }
}

/// 1st, 2nd, 3rd, 4th, 11th, 12th, 13th, 21st...
String ordinal(int n) {
  final lastTwo = n % 100;
  if (lastTwo >= 11 && lastTwo <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// 14 Feb
String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// 14 Feb 2024
String longDate(DateTime d) => '${shortDate(d)} ${d.year}';

/// 2024-02-14, the format the database uses for dates.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// "Your birthday is in 42 days (turning 24)", "Ana's birthday is tomorrow
/// (turning 23)", or "Happy birthday! You're 24 today." Uses the same
/// next-occurrence maths as the anniversary, including 29 February.
String birthdayLine({
  required DateTime birthday,
  required bool isMe,
  required String name,
  DateTime? today,
}) {
  final info = AnniversaryInfo.from(birthday, today: today);
  final age = info.yearsAtNext;
  if (info.isToday) {
    return isMe
        ? 'Happy birthday! You\'re $age today.'
        : 'It\'s $name\'s birthday today! $age years old.';
  }
  final whose = isMe ? 'Your birthday' : '$name\'s birthday';
  final when = info.daysUntilNext == 1
      ? 'tomorrow'
      : 'in ${info.daysUntilNext} days';
  return '$whose is $when (turning $age)';
}
