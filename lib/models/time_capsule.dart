/// Where a Time Capsule is in its life. Mirrors `time_capsules.status`.
enum CapsuleStatus {
  draft, // your one unsealed capsule
  editing, // sealed, then reopened during its ten minutes
  sealed,
  opened;

  static CapsuleStatus parse(String value) =>
      CapsuleStatus.values.firstWhere((s) => s.name == value);
}

/// A Time Capsule's envelope: who, to whom, when, and what state. Never the
/// title, letter or photo; those are in [CapsuleContents], which the
/// database only hands out at the right moments.
class TimeCapsule {
  const TimeCapsule({
    required this.id,
    required this.senderId,
    required this.status,
    required this.createdAt,
    this.receiverId,
    this.unlockAt,
    this.sealedAt,
    this.editableUntil,
    this.openedAt,
  });

  final String id;
  final String senderId;
  final String? receiverId;
  final CapsuleStatus status;
  final DateTime? unlockAt; // local time
  final DateTime? sealedAt;
  final DateTime? editableUntil;
  final DateTime? openedAt;
  final DateTime createdAt;

  static DateTime? _time(Object? v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();

  factory TimeCapsule.fromMap(Map<String, dynamic> row) => TimeCapsule(
    id: row['id'] as String,
    senderId: row['sender_id'] as String,
    receiverId: row['receiver_id'] as String?,
    status: CapsuleStatus.parse(row['status'] as String),
    unlockAt: _time(row['unlock_at']),
    sealedAt: _time(row['sealed_at']),
    editableUntil: _time(row['editable_until']),
    openedAt: _time(row['opened_at']),
    createdAt: _time(row['created_at'])!,
  );

  /// Sealed, and still within its ten minutes (only the sender sees these).
  bool inGrace(DateTime now) =>
      status == CapsuleStatus.sealed &&
      editableUntil != null &&
      now.isBefore(editableUntil!);

  /// Sealed for good and waiting for its moment.
  bool isWaiting(DateTime now) =>
      status == CapsuleStatus.sealed &&
      !inGrace(now) &&
      now.isBefore(unlockAt!);

  /// Its moment has come and the receiver hasn't opened it yet.
  bool isReady(DateTime now) =>
      status == CapsuleStatus.sealed &&
      !inGrace(now) &&
      !now.isBefore(unlockAt!);

  bool get isOpened => status == CapsuleStatus.opened;

  /// Waiting since: the later of its unlock time and the end of its grace.
  DateTime get readySince {
    final unlock = unlockAt!, grace = editableUntil!;
    return unlock.isAfter(grace) ? unlock : grace;
  }
}

/// The secret part: title, letter, photo and caption. The sender can read it
/// while it is a draft or still editable; after that nobody can until the
/// receiver opens it, and then both can.
class CapsuleContents {
  const CapsuleContents({
    required this.capsuleId,
    required this.letter,
    this.title,
    this.photoPath,
    this.photoCaption,
  });

  final String capsuleId;
  final String? title;
  final String letter;
  final String? photoPath;
  final String? photoCaption;

  factory CapsuleContents.fromMap(Map<String, dynamic> row) => CapsuleContents(
    capsuleId: row['capsule_id'] as String,
    title: row['title'] as String?,
    letter: (row['letter'] as String?) ?? '',
    photoPath: row['photo_path'] as String?,
    photoCaption: row['photo_caption'] as String?,
  );

  /// The first non-empty line of the letter, for the opened card.
  String get firstLine => letter
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
}

/// One reply on an opened capsule. Each partner has at most one.
class CapsuleReply {
  const CapsuleReply({
    required this.capsuleId,
    required this.authorId,
    required this.body,
    required this.createdAt,
  });

  final String capsuleId;
  final String authorId;
  final String body;
  final DateTime createdAt;

  factory CapsuleReply.fromMap(Map<String, dynamic> row) => CapsuleReply(
    capsuleId: row['capsule_id'] as String,
    authorId: row['author_id'] as String,
    body: row['body'] as String,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
  );
}
