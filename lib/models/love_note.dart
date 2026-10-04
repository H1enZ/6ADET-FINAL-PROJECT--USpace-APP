/// The kind of love note, chosen when writing it. Older notes have none.
enum NoteCategory {
  justBecause('just_because', 'Just Because'),
  thankYou('thank_you', 'Thank You'),
  missingYou('missing_you', 'Missing You'),
  proudOfYou('proud_of_you', 'Proud of You'),
  love('love', 'Love');

  const NoteCategory(this.key, this.label);

  /// The value stored in `notes.category`.
  final String key;
  final String label;

  static NoteCategory? fromKey(String? key) {
    for (final c in values) {
      if (c.key == key) return c;
    }
    return null;
  }
}

/// A love note you can read: an ordinary note, or a Time Capsule that has
/// opened. Mirrors a row in `notes`.
class LoveNote {
  const LoveNote({
    required this.id,
    required this.authorId,
    required this.body,
    required this.sentAt,
    this.unlockAt,
    this.capsuleTitle,
    this.isFavorite = false,
    this.category,
    this.photoPath,
    this.photoUrl,
  });

  final String id;
  final String authorId;
  final String body;
  final DateTime sentAt; // local time
  final DateTime? unlockAt; // set for Time Capsules
  /// A capsule's teaser, or an ordinary note's title (same column).
  final String? capsuleTitle;
  final bool isFavorite;
  final NoteCategory? category;

  /// Where the photo is stored in the private memory-photos bucket.
  final String? photoPath;

  /// Signed link to show the photo. Not stored in the database.
  final String? photoUrl;

  bool get wasCapsule => unlockAt != null;
  String? get title => capsuleTitle;

  factory LoveNote.fromMap(Map<String, dynamic> row) {
    final unlock = row['unlock_at'] as String?;
    return LoveNote(
      id: row['id'] as String,
      authorId: row['author_id'] as String,
      body: row['body'] as String,
      sentAt: DateTime.parse(row['sent_at'] as String).toLocal(),
      unlockAt: unlock == null ? null : DateTime.parse(unlock).toLocal(),
      capsuleTitle: row['capsule_title'] as String?,
      isFavorite: (row['is_favorite'] as bool?) ?? false,
      category: NoteCategory.fromKey(row['category'] as String?),
      photoPath: row['photo_path'] as String?,
    );
  }

  LoveNote _copy({bool? isFavorite, String? photoUrl}) => LoveNote(
    id: id,
    authorId: authorId,
    body: body,
    sentAt: sentAt,
    unlockAt: unlockAt,
    capsuleTitle: capsuleTitle,
    isFavorite: isFavorite ?? this.isFavorite,
    category: category,
    photoPath: photoPath,
    photoUrl: photoUrl ?? this.photoUrl,
  );

  LoveNote withFavorite(bool value) => _copy(isFavorite: value);
  LoveNote withPhotoUrl(String? url) => _copy(photoUrl: url);
}

/// A Time Capsule that is still sealed: who sealed it, when, when it opens,
/// and its teaser. The database never sends the message itself.
class SealedNote {
  const SealedNote({
    required this.id,
    required this.authorId,
    required this.sentAt,
    required this.unlockAt,
    this.capsuleTitle,
  });

  final String id;
  final String authorId;
  final DateTime sentAt;
  final DateTime unlockAt;
  final String? capsuleTitle;

  factory SealedNote.fromMap(Map<String, dynamic> row) => SealedNote(
    id: row['id'] as String,
    authorId: row['author_id'] as String,
    sentAt: DateTime.parse(row['sent_at'] as String).toLocal(),
    unlockAt: DateTime.parse(row['unlock_at'] as String).toLocal(),
    capsuleTitle: row['capsule_title'] as String?,
  );

  bool isReady({DateTime? now}) => !unlockAt.isAfter(now ?? DateTime.now());

  /// 0.0 when sealed, 1.0 when it opens. Drives the unlock ring.
  double progress({DateTime? now}) {
    final total = unlockAt.difference(sentAt).inSeconds;
    if (total <= 0) return 1;
    final done = (now ?? DateTime.now()).difference(sentAt).inSeconds;
    return (done / total).clamp(0.0, 1.0).toDouble();
  }
}
