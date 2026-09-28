/// One shared memory. Mirrors a row in the `memories` table.
class Memory {
  const Memory({
    required this.id,
    required this.coupleId,
    required this.authorId,
    required this.caption,
    required this.memoryDate,
    this.photoPath,
    this.photoUrl,
    this.isFavorite = false,
  });

  final String id;
  final String coupleId;
  final String authorId;
  final String caption;
  final DateTime memoryDate;

  /// Where the photo is stored in the private bucket, e.g. "<couple_id>/123.jpg".
  final String? photoPath;

  /// A short-lived signed link to show the photo. Not stored in the database.
  final String? photoUrl;

  final bool isFavorite;

  factory Memory.fromMap(Map<String, dynamic> row) {
    return Memory(
      id: row['id'] as String,
      coupleId: row['couple_id'] as String,
      authorId: row['author_id'] as String,
      caption: row['caption'] as String,
      memoryDate: DateTime.parse(row['memory_date'] as String),
      photoPath: row['photo_path'] as String?,
      isFavorite: (row['is_favorite'] as bool?) ?? false,
    );
  }

  Memory copyWith({String? photoUrl, bool? isFavorite}) {
    return Memory(
      id: id,
      coupleId: coupleId,
      authorId: authorId,
      caption: caption,
      memoryDate: memoryDate,
      photoPath: photoPath,
      photoUrl: photoUrl ?? this.photoUrl,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
