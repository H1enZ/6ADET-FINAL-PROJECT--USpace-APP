/// Tags a memory can have. The names match the database check.
enum MemoryTag {
  firstDate('first_date', 'First date', '💕'),
  anniversary('anniversary', 'Anniversary', '💍'),
  travel('travel', 'Travel', '✈️'),
  celebration('celebration', 'Celebration', '🎉'),
  everyday('everyday', 'Everyday moment', '☕'),
  special('special', 'Special moment', '✨');

  const MemoryTag(this.dbName, this.label, this.emoji);

  final String dbName;
  final String label;
  final String emoji;

  static MemoryTag? fromDb(String name) {
    for (final tag in MemoryTag.values) {
      if (tag.dbName == name) return tag;
    }
    return null;
  }
}

/// A stored photo and a short-lived link to show it.
class PhotoRef {
  const PhotoRef({required this.path, this.url});

  /// Where it is in the private bucket, e.g. `<couple_id>/123.jpg`.
  final String path;

  /// Signed link, valid for an hour. Null until signed or if signing failed.
  final String? url;

  PhotoRef withUrl(String? link) => PhotoRef(path: path, url: link);
}

/// One shared memory. Mirrors a row in `memories` plus its `memory_photos`.
/// `caption` is shown as the memory's title.
class Memory {
  const Memory({
    required this.id,
    required this.coupleId,
    required this.authorId,
    required this.caption,
    required this.memoryDate,
    this.description,
    this.location,
    this.tags = const [],
    this.photoPath,
    this.photos = const [],
    this.isFavorite = false,
  });

  final String id;
  final String coupleId;
  final String authorId;
  final String caption;
  final DateTime memoryDate;
  final String? description;
  final String? location;
  final List<MemoryTag> tags;

  /// The cover photo (the first one). Older memories only have this.
  final String? photoPath;

  /// All photos in order, cover first. For older memories this is just the
  /// cover, so screens never need to know the difference.
  final List<PhotoRef> photos;

  final bool isFavorite;

  String get title => caption;

  /// The cover photo's link, used by cards.
  String? get photoUrl => photos.isEmpty ? null : photos.first.url;

  factory Memory.fromMap(
    Map<String, dynamic> row, {
    List<String> photoPaths = const [],
  }) {
    final cover = row['photo_path'] as String?;
    final paths = photoPaths.isNotEmpty
        ? photoPaths
        : (cover == null ? const <String>[] : [cover]);
    final rawTags = (row['tags'] as List?)?.cast<String>() ?? const [];
    return Memory(
      id: row['id'] as String,
      coupleId: row['couple_id'] as String,
      authorId: row['author_id'] as String,
      caption: row['caption'] as String,
      memoryDate: DateTime.parse(row['memory_date'] as String),
      description: row['description'] as String?,
      location: row['location'] as String?,
      tags: rawTags.map(MemoryTag.fromDb).whereType<MemoryTag>().toList(),
      photoPath: cover,
      photos: [for (final p in paths) PhotoRef(path: p)],
      isFavorite: (row['is_favorite'] as bool?) ?? false,
    );
  }

  Memory copyWith({bool? isFavorite, List<PhotoRef>? photos}) {
    return Memory(
      id: id,
      coupleId: coupleId,
      authorId: authorId,
      caption: caption,
      memoryDate: memoryDate,
      description: description,
      location: location,
      tags: tags,
      photoPath: photoPath,
      photos: photos ?? this.photos,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
