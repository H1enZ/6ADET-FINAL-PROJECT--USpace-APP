import '../theme/us_icons.dart';

/// Built-in tags, offered as one-tap chips. Couples can also type their
/// own (1 to 30 characters, up to 10 per memory; see migration 009).
enum MemoryTag {
  firstDate('first_date', 'First date', UsIcons.tagFirstDate),
  anniversary('anniversary', 'Anniversary', UsIcons.tagAnniversary),
  outing('outing', 'Outing', UsIcons.tagOuting),
  travel('travel', 'Travel', UsIcons.tagTravel),
  celebration('celebration', 'Celebration', UsIcons.tagCelebration),
  everyday('everyday', 'Everyday moment', UsIcons.tagEveryday),
  special('special', 'Special moment', UsIcons.tagSpecial);

  const MemoryTag(this.dbName, this.label, this.icon);

  final String dbName;
  final String label;

  /// Shown beside the label on tag chips (an icon, never an emoji).
  final UsIconData icon;

  static MemoryTag? fromDb(String name) {
    for (final tag in MemoryTag.values) {
      if (tag.dbName == name) return tag;
    }
    return null;
  }
}

const maxTags = 10;
const maxTagLength = 30;

/// How a stored tag is named: "Anniversary" for built-ins, the typed text
/// ("Special date") for your own.
String tagLabel(String tag) => MemoryTag.fromDb(tag)?.label ?? tag;

/// The icon shown with a stored tag; your own tags get a plain tag icon.
UsIconData tagIcon(String tag) =>
    MemoryTag.fromDb(tag)?.icon ?? UsIcons.tag;

/// Cleans up a typed tag: trims, squeezes spaces, caps the length, and
/// turns a built-in's name ("outing", "First Date") into its stored name.
/// Returns null when nothing usable is left.
String? normalizeTag(String input) {
  var t = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.startsWith('#')) t = t.substring(1).trim();
  if (t.isEmpty) return null;
  if (t.length > maxTagLength) t = t.substring(0, maxTagLength).trim();
  for (final tag in MemoryTag.values) {
    if (tag.label.toLowerCase() == t.toLowerCase() ||
        tag.dbName.toLowerCase() == t.toLowerCase()) {
      return tag.dbName;
    }
  }
  return t;
}

/// Adds [tag] unless the same tag (ignoring capital letters) is already in.
List<String> withTag(List<String> tags, String tag) =>
    tags.any((t) => t.toLowerCase() == tag.toLowerCase()) ? tags : [...tags, tag];

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
  /// Stored tag names: built-ins by their stored name, your own as typed.
  final List<String> tags;

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
      tags: rawTags,
      photoPath: cover,
      photos: [for (final p in paths) PhotoRef(path: p)],
      isFavorite: (row['is_favorite'] as bool?) ?? false,
    );
  }

  Memory copyWith({bool? isFavorite, List<PhotoRef>? photos, List<String>? tags}) {
    return Memory(
      id: id,
      coupleId: coupleId,
      authorId: authorId,
      caption: caption,
      memoryDate: memoryDate,
      description: description,
      location: location,
      tags: tags ?? this.tags,
      photoPath: photoPath,
      photos: photos ?? this.photos,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
