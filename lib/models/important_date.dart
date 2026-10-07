import '../utils/anniversary.dart';

/// A date the couple wants to count down to. Mirrors `important_dates`.
class ImportantDate {
  const ImportantDate({
    required this.id,
    required this.title,
    required this.eventDate,
    this.repeatsYearly = true,
    this.createdAt,
  });

  final String id;
  final String title;
  final DateTime eventDate;
  final bool repeatsYearly;

  /// When it was added. Measures progress towards a one-off date.
  final DateTime? createdAt;

  factory ImportantDate.fromMap(Map<String, dynamic> row) => ImportantDate(
    id: row['id'] as String,
    title: row['title'] as String,
    eventDate: DateTime.parse(row['event_date'] as String),
    repeatsYearly: (row['repeats_yearly'] as bool?) ?? true,
    createdAt: row['created_at'] == null
        ? null
        : DateTime.tryParse(row['created_at'] as String)?.toLocal(),
  );

  /// When it next happens: this year's (or next year's) date if it repeats,
  /// otherwise the date itself. Null for a one-off date that has passed.
  DateTime? nextOccurrence({DateTime? today}) {
    final now = today ?? DateTime.now();
    final t = DateTime.utc(now.year, now.month, now.day);
    if (repeatsYearly) {
      return AnniversaryInfo.from(eventDate, today: now).nextDate;
    }
    final d = DateTime.utc(eventDate.year, eventDate.month, eventDate.day);
    return d.isBefore(t) ? null : d;
  }

  /// Days until the next occurrence, or null if it has passed.
  int? daysUntil({DateTime? today}) {
    final now = today ?? DateTime.now();
    final next = nextOccurrence(today: now);
    if (next == null) return null;
    return next.difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  }
}
