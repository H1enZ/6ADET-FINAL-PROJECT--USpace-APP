import 'memory.dart';

/// The Timeline scrapbook's presentation data (migration 018). It only says
/// how a memory LOOKS on the scrapbook: where it sits, its size, tilt,
/// frame and layer. A memory's date, author and content live in `memories`
/// and are never changed by any of this.

/// What a memory is, for choosing which frames suit it.
enum ContentKind { photo, text, event }

/// Memories tagged like this, without a photo, read as an event or date.
const _eventTags = {'anniversary', 'first_date', 'celebration', 'special'};

ContentKind contentKindOf(Memory m) {
  if (m.photos.isNotEmpty) return ContentKind.photo;
  return m.tags.any(_eventTags.contains) ? ContentKind.event : ContentKind.text;
}

enum FrameStyle {
  polaroid('polaroid', 'Polaroid'),
  taped('taped', 'Taped'),
  film('film', 'Film'),
  paper('paper', 'Paper'),
  postcard('postcard', 'Postcard'),
  minimal('minimal', 'Minimal'),
  loveNote('love_note', 'Love Note'),
  ticket('ticket', 'Ticket'),
  sticky('sticky', 'Sticky note');

  const FrameStyle(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static FrameStyle? fromDb(Object? value) {
    for (final f in values) {
      if (f.dbValue == value) return f;
    }
    return null;
  }

  /// The frames that suit a memory: photo frames need a photo; sticky
  /// notes, paper and love notes are for words, tickets for events.
  static List<FrameStyle> forKind(ContentKind kind) => switch (kind) {
    ContentKind.photo => const [polaroid, taped, film, postcard, minimal],
    ContentKind.text => const [sticky, paper, loveNote, minimal],
    ContentKind.event => const [sticky, ticket, paper, postcard, minimal],
  };

  bool get showsPhoto =>
      this == polaroid ||
      this == taped ||
      this == film ||
      this == postcard ||
      this == minimal;
}

/// The look a memory has until someone chooses one: stable per memory, so
/// it never changes on its own. A memory without a photo is a sticky note.
FrameStyle autoFrameOf(Memory m, int seed) => switch (contentKindOf(m)) {
  ContentKind.photo => seed % 4 == 3 ? FrameStyle.taped : FrameStyle.polaroid,
  ContentKind.text || ContentKind.event => FrameStyle.sticky,
};

/// The frame a memory is drawn in: the chosen one if it suits the memory
/// (a photo may have been removed since), else its automatic one.
FrameStyle effectiveFrame(Memory m, FrameStyle? chosen, int seed) {
  if (chosen != null && FrameStyle.forKind(contentKindOf(m)).contains(chosen)) {
    return chosen;
  }
  return autoFrameOf(m, seed);
}

/// Where one memory sits on the scrapbook, in canvas units (the canvas is
/// 400 units wide on every phone). Height is never stored: it follows from
/// the frame and width, so photos always keep a sensible shape.
class LayoutItem {
  const LayoutItem({
    required this.memoryId,
    required this.x,
    required this.y,
    required this.width,
    this.rotation = 0,
    this.frame,
    this.z = 0,
  });

  final String memoryId;
  final double x;
  final double y;
  final double width;

  /// Degrees, -6 to 6.
  final double rotation;

  /// null: the memory's automatic look.
  final FrameStyle? frame;
  final int z;

  static const minRotation = -6.0;
  static const maxRotation = 6.0;

  LayoutItem copyWith({
    double? x,
    double? y,
    double? width,
    double? rotation,
    FrameStyle? frame,
    bool clearFrame = false,
    int? z,
  }) => LayoutItem(
    memoryId: memoryId,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    rotation: rotation ?? this.rotation,
    frame: clearFrame ? null : (frame ?? this.frame),
    z: z ?? this.z,
  );

  factory LayoutItem.fromRow(Map<String, dynamic> r) => LayoutItem(
    memoryId: r['memory_id'] as String,
    x: (r['x'] as num).toDouble(),
    y: (r['y'] as num).toDouble(),
    width: (r['width'] as num).toDouble(),
    rotation: (r['rotation'] as num?)?.toDouble() ?? 0,
    frame: FrameStyle.fromDb(r['frame_style']),
    z: (r['z_index'] as num?)?.toInt() ?? 0,
  );

  /// The database row. Values are kept inside the database's limits.
  Map<String, dynamic> toRow(String coupleId) => {
    'memory_id': memoryId,
    'couple_id': coupleId,
    'x': x.clamp(-400.0, 800.0),
    'y': y.clamp(-2000.0, 200000.0),
    'width': width.clamp(90.0, 380.0),
    'rotation': rotation.clamp(minRotation, maxRotation),
    'frame_style': frame?.dbValue,
    'z_index': z.clamp(-100000, 100000),
  };

  @override
  bool operator ==(Object other) =>
      other is LayoutItem &&
      other.memoryId == memoryId &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.rotation == rotation &&
      other.frame == frame &&
      other.z == z;

  @override
  int get hashCode => Object.hash(memoryId, x, y, width, rotation, frame, z);
}

enum ConnectionStyle {
  dotted('dotted', 'Dotted rose'),
  ribbon('ribbon', 'Ribbon'),
  hearts('hearts', 'Heart path');

  const ConnectionStyle(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static ConnectionStyle fromDb(Object? value) {
    for (final s in values) {
      if (s.dbValue == value) return s;
    }
    return dotted;
  }
}

/// A decorative line between two memories. Purely visual: it never changes
/// either memory or their order.
class ScrapConnection {
  const ScrapConnection({
    required this.id,
    required this.sourceId,
    required this.targetId,
    this.style = ConnectionStyle.dotted,
  });

  final String id;
  final String sourceId;
  final String targetId;
  final ConnectionStyle style;

  bool joins(String a, String b) =>
      (sourceId == a && targetId == b) || (sourceId == b && targetId == a);

  bool touches(String id) => sourceId == id || targetId == id;

  ScrapConnection copyWith({ConnectionStyle? style}) => ScrapConnection(
    id: id,
    sourceId: sourceId,
    targetId: targetId,
    style: style ?? this.style,
  );

  factory ScrapConnection.fromRow(Map<String, dynamic> r) => ScrapConnection(
    id: r['id'] as String,
    sourceId: r['source_id'] as String,
    targetId: r['target_id'] as String,
    style: ConnectionStyle.fromDb(r['style']),
  );
}
