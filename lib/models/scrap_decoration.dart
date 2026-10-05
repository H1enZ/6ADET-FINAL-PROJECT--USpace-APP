import 'dart:math' as math;
import 'dart:ui' show Color, Rect;

/// Decorations on the shared Timeline scrapbook (migration 019): sticky
/// notes, stickers, washi tape and doodles. Presentation only, like the
/// layout: they never touch a memory.

enum DecoKind {
  stickyNote('sticky_note'),
  sticker('sticker'),
  tape('tape'),
  doodle('doodle');

  const DecoKind(this.dbValue);

  final String dbValue;

  static DecoKind? fromDb(Object? v) {
    for (final k in values) {
      if (k.dbValue == v) return k;
    }
    return null;
  }

  /// How far each kind may turn: tape lies diagonally, notes stay gentle.
  double get maxTurn => switch (this) {
    DecoKind.tape => 45,
    DecoKind.sticker => 25,
    DecoKind.doodle => 30,
    DecoKind.stickyNote => 10,
  };

  /// Narrowest and widest, in board units.
  (double, double) get widthRange => switch (this) {
    DecoKind.stickyNote => (110, 260),
    DecoKind.sticker => (36, 160),
    DecoKind.tape => (50, 320),
    DecoKind.doodle => (40, 260),
  };

  /// Newly added: width and height.
  (double, double) get startSize => switch (this) {
    DecoKind.stickyNote => (150, 150),
    DecoKind.sticker => (72, 72),
    DecoKind.tape => (130, 30),
    DecoKind.doodle => (110, 110),
  };

  /// Tape keeps its thickness when made longer; the rest grow evenly.
  bool get keepsHeight => this == DecoKind.tape;

  /// Sticky notes may be a little taller than wide, the rest keep shape.
  double get maxNoteText => 200;
}

class ScrapDecoration {
  const ScrapDecoration({
    required this.id,
    required this.kind,
    required this.variant,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.color,
    this.body,
    this.rotation = 0,
    this.z = 0,
  });

  final String id;
  final DecoKind kind;

  /// Which sticker, tape pattern or doodle shape (see the catalogues in
  /// scrap_decorations.dart).
  final String variant;
  final Color? color;

  /// A sticky note's words.
  final String? body;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final int z;

  Rect get rect => Rect.fromLTWH(x, y, width, height);

  ScrapDecoration copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? z,
    Color? color,
    String? body,
    String? variant,
  }) => ScrapDecoration(
    id: id,
    kind: kind,
    variant: variant ?? this.variant,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    color: color ?? this.color,
    body: body ?? this.body,
    rotation: rotation ?? this.rotation,
    z: z ?? this.z,
  );

  /// A new decoration with a fresh id, centred on [center].
  static ScrapDecoration create({
    required DecoKind kind,
    required String variant,
    required ({double x, double y}) center,
    required int z,
    Color? color,
    String? body,
  }) {
    final (w, h) = kind.startSize;
    return ScrapDecoration(
      id: _uuid(),
      kind: kind,
      variant: variant,
      x: center.x - w / 2,
      y: center.y - h / 2,
      width: w,
      height: h,
      color: color,
      body: body,
      rotation: kind == DecoKind.tape ? -12 : 0,
      z: z,
    );
  }

  static ScrapDecoration? fromRow(Map<String, dynamic> r) {
    final kind = DecoKind.fromDb(r['kind']);
    if (kind == null) return null;
    final hex = r['color'] as String?;
    return ScrapDecoration(
      id: r['id'] as String,
      kind: kind,
      variant: r['variant'] as String,
      color: hex == null
          ? null
          : Color(0xFF000000 | int.parse(hex.substring(1), radix: 16)),
      body: r['body'] as String?,
      x: (r['x'] as num).toDouble(),
      y: (r['y'] as num).toDouble(),
      width: (r['width'] as num).toDouble(),
      height: (r['height'] as num).toDouble(),
      rotation: (r['rotation'] as num?)?.toDouble() ?? 0,
      z: (r['z_index'] as num?)?.toInt() ?? 0,
    );
  }

  /// The database row, kept inside the database's limits.
  Map<String, dynamic> toRow(String coupleId) {
    final c = color;
    return {
      'id': id,
      'couple_id': coupleId,
      'kind': kind.dbValue,
      'variant': variant,
      'color': c == null
          ? null
          : '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
      'body': kind == DecoKind.stickyNote ? (body ?? '').trim() : null,
      'x': x.clamp(-400.0, 800.0),
      'y': y.clamp(-2000.0, 200000.0),
      'width': width.clamp(24.0, 380.0),
      'height': height.clamp(12.0, 380.0),
      'rotation': rotation.clamp(-kind.maxTurn, kind.maxTurn),
      'z_index': z.clamp(-100000, 1000000),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ScrapDecoration &&
      other.id == id &&
      other.variant == variant &&
      other.color == color &&
      other.body == body &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height &&
      other.rotation == rotation &&
      other.z == z;

  @override
  int get hashCode =>
      Object.hash(id, variant, color, body, x, y, width, height, rotation, z);
}

final _random = math.Random.secure();

/// A random (version 4) UUID, so a decoration has its id before it is
/// saved and can be moved, undone or restored straight away.
String _uuid() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int from, int to) => b
      .sublist(from, to)
      .map((x) => x.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
