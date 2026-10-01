/// Countdown and time text for Time Capsules. Pure Dart, unit tested in
/// test/capsule_time_test.dart.

/// "in 42 days", "in 1 day 3h", "in 5h 20m", "in 12 min", "any moment now".
String opensIn(DateTime unlockAt, {DateTime? now}) {
  final left = unlockAt.difference(now ?? DateTime.now());
  if (left.inSeconds <= 0) return 'ready to open';
  if (left.inDays >= 2) return 'in ${left.inDays} days';
  if (left.inDays == 1) return 'in 1 day ${left.inHours - 24}h';
  if (left.inHours >= 1) return 'in ${left.inHours}h ${left.inMinutes % 60}m';
  if (left.inMinutes >= 1) return 'in ${left.inMinutes} min';
  return 'any moment now';
}

/// 8:05 AM, 12:00 PM, 11:30 PM
String clockTime(DateTime d) {
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// Ready-made unlock times, all at 8:00 AM so the capsule is waiting when
/// the day starts. [anniversary] adds "Our anniversary" when it is known.
Map<String, DateTime> capsulePresets(DateTime now, {DateTime? anniversary}) {
  DateTime morning(DateTime d) => DateTime(d.year, d.month, d.day, 8);
  final presets = <String, DateTime>{
    'Tomorrow morning': morning(now.add(const Duration(days: 1))),
    'In a week': morning(now.add(const Duration(days: 7))),
    'In a month': morning(DateTime(now.year, now.month + 1, now.day)),
    'In a year': morning(DateTime(now.year + 1, now.month, now.day)),
  };
  if (anniversary != null) {
    var next = DateTime(now.year, anniversary.month, anniversary.day, 8);
    if (!next.isAfter(now)) {
      next = DateTime(now.year + 1, anniversary.month, anniversary.day, 8);
    }
    presets['Our anniversary'] = next;
  }
  return presets;
}
