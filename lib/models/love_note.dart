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
  });

  final String id;
  final String authorId;
  final String body;
  final DateTime sentAt; // local time
  final DateTime? unlockAt; // set for Time Capsules
  final String? capsuleTitle;
  final bool isFavorite;

  bool get wasCapsule => unlockAt != null;

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
    );
  }

  LoveNote withFavorite(bool value) => LoveNote(
        id: id,
        authorId: authorId,
        body: body,
        sentAt: sentAt,
        unlockAt: unlockAt,
        capsuleTitle: capsuleTitle,
        isFavorite: value,
      );
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
