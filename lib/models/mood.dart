/// Every mood the database allows (migration 012). [dbValue] is what is
/// stored in moods.mood and must match the database check.
///
/// The first eight are the Home moods, in grid order, and are the only ones
/// anyone can pick. The rest come from the earlier mood list: they stay so
/// older check-ins still show in history and the activity feed.
///
/// Moods are shown with MoodVisual's artwork, never an emoji.
enum Mood {
  loved('loved', 'Loved'),
  happy('happy', 'Happy'),
  calm('calm', 'Calm'),
  emotional('emotional', 'Emotional'),
  needAHug('need_a_hug', 'Need a Hug'),
  flirty('flirty', 'Flirty'),
  romantic('romantic', 'Romantic'),
  excited('excited', 'Excited'),

  // History only: never offered for a new check-in.
  relaxed('relaxed', 'Relaxed', selectable: false),
  tired('tired', 'Tired', selectable: false),
  stressed('stressed', 'Stressed', selectable: false),
  sad('sad', 'Sad', selectable: false),
  anxious('anxious', 'Anxious', selectable: false),
  lonely('lonely', 'Lonely', selectable: false),
  upset('upset', 'Upset', selectable: false);

  const Mood(this.dbValue, this.label, {this.selectable = true});

  final String dbValue;
  final String label;

  /// False for the older moods kept only for history.
  final bool selectable;

  /// The eight Home moods, in grid order (two rows of four).
  static List<Mood> get selectableMoods => [
    for (final m in values)
      if (m.selectable) m,
  ];

  /// The mood stored as [value] (a moods.mood value), or null.
  static Mood? fromName(String? value) {
    for (final mood in Mood.values) {
      if (mood.dbValue == value) return mood;
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
    final sameDay =
        e.createdAt.year == day.year &&
        e.createdAt.month == day.month &&
        e.createdAt.day == day.day;
    if (e.userId != userId || !sameDay) continue;
    if (latest == null || e.createdAt.isAfter(latest.createdAt)) latest = e;
  }
  return latest;
}
