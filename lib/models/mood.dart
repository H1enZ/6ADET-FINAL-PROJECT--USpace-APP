/// The ten moods for Today's Mood. The names match the database check.
enum Mood {
  happy('Happy', '😊'),
  loved('Loved', '🥰'),
  excited('Excited', '🤩'),
  relaxed('Relaxed', '😌'),
  tired('Tired', '😴'),
  stressed('Stressed', '😣'),
  sad('Sad', '😔'),
  anxious('Anxious', '🥺'),
  lonely('Lonely', '🫂'),
  upset('Upset', '😞');

  const Mood(this.label, this.emoji);

  final String label;
  final String emoji;

  static Mood? fromName(String? name) {
    for (final mood in Mood.values) {
      if (mood.name == name) return mood;
    }
    return null;
  }
}

/// One mood check-in. Mirrors a row in the `moods` table.
class MoodEntry {
  const MoodEntry({
    required this.id,
    required this.userId,
    required this.mood,
    required this.createdAt,
    this.note,
    this.isShared = true,
  });

  final String id;
  final String userId;
  final Mood mood;
  final String? note;
  final bool isShared;
  final DateTime createdAt; // local time

  static MoodEntry? fromMap(Map<String, dynamic> row) {
    final mood = Mood.fromName(row['mood'] as String?);
    if (mood == null) return null;
    return MoodEntry(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      mood: mood,
      note: row['note'] as String?,
      isShared: (row['is_shared'] as bool?) ?? true,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}

/// The latest check-in for [userId] on the same local day as [day], or null.
MoodEntry? latestMoodOn(List<MoodEntry> entries, String userId, DateTime day) {
  MoodEntry? latest;
  for (final e in entries) {
    final sameDay = e.createdAt.year == day.year &&
        e.createdAt.month == day.month &&
        e.createdAt.day == day.day;
    if (e.userId != userId || !sameDay) continue;
    if (latest == null || e.createdAt.isAfter(latest.createdAt)) latest = e;
  }
  return latest;
}
