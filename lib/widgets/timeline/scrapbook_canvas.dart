import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/scrapbook.dart';
import '../../utils/anniversary.dart';
import '../notes/note_style.dart';
import 'scrap_frames.dart';
import 'scrapbook_layout.dart';

const _monthNames = [
  'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', //
  'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
];
const _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String monthLabel(int year, int month) => '${_monthNames[month - 1]} $year';
String shortMonthLabel(int year, int month) =>
    '${_shortMonths[month - 1].toUpperCase()} $year';

/// A memory being moved, resized or turned right now. Only that piece and
/// the connection lines follow it; nothing else rebuilds.
class ScrapLive {
  const ScrapLive(this.item, {this.guideX});

  final LayoutItem item;

  /// A snap guide to show (a canvas x), while it is snapped to one.
  final double? guideX;
}

/// What an editing gesture on the canvas reports, in canvas units.
enum ScrapGesture { move, resize, rotate }

/// The whole scrapbook at canvas size. Built when the layout, selection or
/// mode changes: the viewer only transforms it, so zooming never rebuilds it.
class ScrapbookCanvas extends StatefulWidget {
  const ScrapbookCanvas({
    super.key,
    required this.layout,
    required this.links,
    required this.photoScale,
    required this.lowRes,
    required this.onTapPiece,
    this.editing = false,
    this.selectedId,
    this.connectFromId,
    this.live,
    this.view,
    this.onTapEmpty,
    this.onTapLink,
    this.onGestureStart,
    this.onGestureUpdate,
    this.onGestureEnd,
  });

  final ScrapbookLayout layout;
  final List<ScrapConnection> links;

  /// Device pixels per canvas unit at the closest zoom, to size photos.
  final double photoScale;

  /// Zoomed far out: photos decoded small.
  final bool lowRes;

  final void Function(ScrapPiece piece) onTapPiece;
  final bool editing;
  final String? selectedId;

  /// Picking the second memory of a new connection.
  final String? connectFromId;
  final ValueNotifier<ScrapLive?>? live;

  /// The viewer's transform, so handles stay finger-sized at any zoom.
  final TransformationController? view;

  final VoidCallback? onTapEmpty;
  final void Function(ScrapConnection link)? onTapLink;
  final void Function(ScrapPiece piece, ScrapGesture kind, Offset canvas)?
  onGestureStart;
  final void Function(Offset canvas)? onGestureUpdate;
  final VoidCallback? onGestureEnd;

  @override
  State<ScrapbookCanvas> createState() => _ScrapbookCanvasState();

  static Offset? _midpoint(ScrapConnection link, Map<String, Rect> rects) {
    final a = rects[link.sourceId], b = rects[link.targetId];
    if (a == null || b == null) return null;
    return linkSegment(a, b)?.center;
  }
}

class _ScrapbookCanvasState extends State<ScrapbookCanvas> {
  /// The canvas itself, to turn screen positions into canvas units through
  /// the viewer's zoom. Kept for the canvas's whole life.
  final _canvasKey = GlobalKey();

  Offset _toCanvas(Offset global) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? global : box.globalToLocal(global);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final layout = w.layout,
        links = w.links,
        live = w.live,
        editing = w.editing;
    final canvasKey = _canvasKey;
    final toCanvas = _toCanvas;

    final rects = {for (final p in layout.pieces) p.memory.id: p.rect};
    return SizedBox(
      key: canvasKey,
      width: layout.width,
      height: layout.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (editing)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: w.onTapEmpty,
              ),
            ),
          for (final m in layout.months) ...[
            Positioned.fromRect(
              rect: Rect.fromLTWH(0, m.top, layout.width, m.bottom - m.top),
              child: _MonthDecor(month: m),
            ),
            if (m.yearRect != null)
              Positioned.fromRect(
                rect: m.yearRect!,
                child: _YearStamp(year: m.year),
              ),
            Positioned.fromRect(
              rect: m.headingRect,
              child: _MonthHeading(label: monthLabel(m.year, m.month)),
            ),
          ],
          if (layout.newStripRect != null)
            Positioned.fromRect(
              rect: layout.newStripRect!,
              child: const _NewStripLabel(),
            ),
          // Connections sit behind every memory.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _LinksPainter(
                  links: links,
                  rects: rects,
                  layout: layout,
                  live: live,
                ),
              ),
            ),
          ),
          for (final p in layout.pieces)
            _LivePiece(
              key: ValueKey('piece-${p.memory.id}'),
              piece: p,
              layout: layout,
              live: live,
              child: _PieceBody(
                piece: p,
                editing: editing,
                selected: p.memory.id == w.selectedId,
                connectTarget:
                    w.connectFromId != null && w.connectFromId != p.memory.id,
                decodeWidth:
                    (p.rect.width * w.photoScale * (w.lowRes ? 0.3 : 1))
                        .round()
                        .clamp(48, 1400),
                view: w.view,
                onTap: () => w.onTapPiece(p),
                onStart: (kind, global) =>
                    w.onGestureStart?.call(p, kind, toCanvas(global)),
                onUpdate: (global) => w.onGestureUpdate?.call(toCanvas(global)),
                onEnd: () => w.onGestureEnd?.call(),
              ),
            ),
          // The selected memory's handles, on top of every memory. Small
          // phones use the toolbar's Size and Turn instead.
          if (editing &&
              live != null &&
              w.view != null &&
              MediaQuery.sizeOf(context).width >= 340)
            if (w.selectedId case final id?)
              if (layout.pieceOf(id) case final piece?)
                _SelectionHandles(
                  piece: piece,
                  layout: layout,
                  live: live,
                  view: w.view!,
                  onStart: (kind, global) =>
                      w.onGestureStart?.call(piece, kind, toCanvas(global)),
                  onUpdate: (global) =>
                      w.onGestureUpdate?.call(toCanvas(global)),
                  onEnd: () => w.onGestureEnd?.call(),
                ),
          // A snap guide while a memory is lined up.
          if (live != null)
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<ScrapLive?>(
                  valueListenable: live,
                  builder: (context, l, _) => l?.guideX == null
                      ? const SizedBox.shrink()
                      : CustomPaint(painter: _GuidePainter(l!.guideX!)),
                ),
              ),
            ),
          // In edit mode, each connection's heart can be tapped to change it.
          if (editing)
            for (final link in links)
              if (ScrapbookCanvas._midpoint(link, rects) case final mid?)
                Positioned(
                  left: mid.dx - 16,
                  top: mid.dy - 16,
                  width: 32,
                  height: 32,
                  child: Semantics(
                    button: true,
                    label: 'Connection. Change or remove it',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => w.onTapLink?.call(link),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

/// Follows [live] when this piece is the one being edited.
///
/// The widget tree is exactly the same whether or not the piece is being
/// moved (only sizes, the lift and the shadow change), so the gesture that
/// is moving it is never interrupted by the piece being rebuilt.
class _LivePiece extends StatelessWidget {
  const _LivePiece({
    super.key,
    required this.piece,
    required this.layout,
    required this.live,
    required this.child,
  });

  final ScrapPiece piece;
  final ScrapbookLayout layout;
  final ValueNotifier<ScrapLive?>? live;
  final _PieceBody child;

  static const _lift = [
    BoxShadow(color: Color(0x73000000), blurRadius: 24, offset: Offset(0, 14)),
  ];

  Widget _at(Rect rect, double turn, {bool lifted = false}) =>
      Positioned.fromRect(
        rect: rect,
        child: Transform.rotate(
          angle: turn * math.pi / 180,
          child: Transform.scale(
            scale: lifted ? 1.04 : 1,
            child: DecoratedBox(
              decoration: BoxDecoration(boxShadow: lifted ? _lift : null),
              child: lifted ? child.resized(rect.size) : child,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final notifier = live;
    if (notifier == null) return _at(piece.rect, piece.turn);
    return ValueListenableBuilder<ScrapLive?>(
      valueListenable: notifier,
      // A Positioned must be a direct child of the Stack, so the builder
      // returns the whole positioned piece.
      builder: (context, l, _) {
        if (l == null || l.item.memoryId != piece.memory.id) {
          return _at(piece.rect, piece.turn);
        }
        final rect = ScrapbookLayout.rectOf(
          l.item,
          piece.memory,
          piece.frame,
        ).translate(0, -layout.originY);
        return _at(rect, l.item.rotation, lifted: true);
      },
    );
  }
}

class _PieceBody extends StatelessWidget {
  const _PieceBody({
    required this.piece,
    required this.editing,
    required this.selected,
    required this.connectTarget,
    required this.decodeWidth,
    required this.view,
    required this.onTap,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    this.size,
  });

  final ScrapPiece piece;
  final bool editing;
  final bool selected;
  final bool connectTarget;
  final int decodeWidth;
  final TransformationController? view;
  final VoidCallback onTap;
  final void Function(ScrapGesture kind, Offset global) onStart;
  final void Function(Offset global) onUpdate;
  final VoidCallback onEnd;

  /// Drawn at this size instead of the piece's own (while resizing).
  final Size? size;

  _PieceBody resized(Size s) => _PieceBody(
    piece: piece,
    editing: editing,
    selected: selected,
    connectTarget: connectTarget,
    decodeWidth: decodeWidth,
    view: view,
    onTap: onTap,
    onStart: onStart,
    onUpdate: onUpdate,
    onEnd: onEnd,
    size: s,
  );

  @override
  Widget build(BuildContext context) {
    final m = piece.memory;
    final s = size ?? piece.rect.size;
    final frame = RepaintBoundary(
      child: ScrapFrame(
        memory: m,
        frame: piece.frame,
        size: s,
        seed: piece.seed,
        decodeWidth: decodeWidth,
      ),
    );

    final semanticsLabel =
        '${m.title}, ${longDate(m.memoryDate)}${m.isFavorite ? ', favorite' : ''}'
        '${editing ? (selected ? '. Selected' : '. Tap to select') : ''}';

    if (!editing) {
      return Semantics(
        button: true,
        label: semanticsLabel,
        excludeSemantics: true,
        // A plain tap: a drag or pinch on top of it goes to the viewer
        // instead, so moving around never opens a memory.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: frame,
        ),
      );
    }

    // Edit mode: tap selects; a long press (or, once selected, a plain
    // drag) moves it. Nothing here ever opens the memory.
    final body = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPressStart: (d) => onStart(ScrapGesture.move, d.globalPosition),
      onLongPressMoveUpdate: (d) => onUpdate(d.globalPosition),
      onLongPressEnd: (_) => onEnd(),
      onLongPressCancel: onEnd,
      onPanStart: selected
          ? (d) => onStart(ScrapGesture.move, d.globalPosition)
          : null,
      onPanUpdate: selected ? (d) => onUpdate(d.globalPosition) : null,
      onPanEnd: selected ? (_) => onEnd() : null,
      onPanCancel: selected ? onEnd : null,
      child: frame,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: body),
          if (selected || connectTarget)
            Positioned(
              left: -5,
              top: -5,
              right: -5,
              bottom: -5,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected
                          ? NotePalette.rose
                          : NotePalette.pink.withValues(alpha: 0.5),
                      width: selected ? 2 : 1.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The selected memory's handles: resize (bottom right) and turn (above
/// the top). Drawn on their own layer over the canvas, in a box a little
/// bigger than the memory, so the whole handle can be grabbed even where it
/// sticks out past the memory's edge. Finger-sized at any zoom, and they
/// follow the memory while it moves, grows or turns.
class _SelectionHandles extends StatelessWidget {
  const _SelectionHandles({
    required this.piece,
    required this.layout,
    required this.live,
    required this.view,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final ScrapPiece piece;
  final ScrapbookLayout layout;
  final ValueNotifier<ScrapLive?> live;
  final TransformationController view;
  final void Function(ScrapGesture kind, Offset global) onStart;
  final void Function(Offset global) onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: view,
      builder: (context, _) => ValueListenableBuilder<ScrapLive?>(
        valueListenable: live,
        builder: (context, l, _) {
          final s = view.value.getMaxScaleOnAxis();
          final d = 34 / s; // about 34 screen pixels
          final m = d * 1.6; // room around the memory for the handles
          final mine = l != null && l.item.memoryId == piece.memory.id;
          final rect = mine
              ? ScrapbookLayout.rectOf(
                  l.item,
                  piece.memory,
                  piece.frame,
                ).translate(0, -layout.originY)
              : piece.rect;
          final turn = mine ? l.item.rotation : piece.turn;

          Widget handle(ScrapGesture kind, IconData icon, String label) =>
              Semantics(
                button: true,
                label: label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (e) => onStart(kind, e.globalPosition),
                  onPanUpdate: (e) => onUpdate(e.globalPosition),
                  onPanEnd: (_) => onEnd(),
                  onPanCancel: onEnd,
                  child: Center(
                    child: Container(
                      width: d * 0.72,
                      height: d * 0.72,
                      decoration: BoxDecoration(
                        color: NotePalette.rose,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2 / s),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 6 / s,
                          ),
                        ],
                      ),
                      child: Icon(icon, size: d * 0.42, color: Colors.white),
                    ),
                  ),
                ),
              );

          return Positioned.fromRect(
            rect: rect.inflate(m),
            child: Transform.rotate(
              angle: turn * math.pi / 180,
              child: Stack(
                children: [
                  Positioned(
                    left: m + rect.width - d / 2,
                    top: m + rect.height - d / 2,
                    width: d,
                    height: d,
                    child: handle(
                      ScrapGesture.resize,
                      Icons.open_in_full_rounded,
                      'Resize',
                    ),
                  ),
                  Positioned(
                    left: m + rect.width / 2 - d / 2,
                    top: m - d * 1.25 - d / 2,
                    width: d,
                    height: d,
                    child: handle(
                      ScrapGesture.rotate,
                      Icons.rotate_right_rounded,
                      'Turn',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------- connections

/// The visible part of a line between two memories: from the edge of one
/// to the edge of the other (never across either card).
({Offset start, Offset end, Offset center})? linkSegment(Rect a, Rect b) {
  final ca = a.center, cb = b.center;
  final d = cb - ca;
  if (d.distance < 1) return null;
  Offset edge(Rect r, Offset from, Offset dir) {
    // Where a ray from the centre leaves the rectangle.
    final tx = dir.dx == 0 ? double.infinity : (r.width / 2 + 6) / dir.dx.abs();
    final ty = dir.dy == 0
        ? double.infinity
        : (r.height / 2 + 6) / dir.dy.abs();
    return from + dir * math.min(tx, ty);
  }

  final start = edge(a, ca, d);
  final end = edge(b, cb, -d);
  // Overlapping cards: nothing worth drawing between them.
  if ((end - start).dx.sign != d.dx.sign &&
      (end - start).dy.sign != d.dy.sign) {
    return null;
  }
  return (start: start, end: end, center: (start + end) / 2);
}

class _LinksPainter extends CustomPainter {
  _LinksPainter({
    required this.links,
    required this.rects,
    required this.layout,
    required this.live,
  }) : super(repaint: live);

  final List<ScrapConnection> links;
  final Map<String, Rect> rects;
  final ScrapbookLayout layout;
  final ValueNotifier<ScrapLive?>? live;

  Rect? _rect(String id) {
    final l = live?.value;
    if (l != null && l.item.memoryId == id) {
      final p = layout.pieceOf(id);
      if (p != null) {
        return ScrapbookLayout.rectOf(
          l.item,
          p.memory,
          p.frame,
        ).translate(0, -layout.originY);
      }
    }
    return rects[id];
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in links) {
      final a = _rect(link.sourceId), b = _rect(link.targetId);
      if (a == null || b == null) continue;
      final seg = linkSegment(a, b);
      if (seg == null) continue;
      switch (link.style) {
        case ConnectionStyle.dotted:
          _dotted(canvas, seg.start, seg.end);
          _heart(canvas, seg.center, 9, filled: true);
        case ConnectionStyle.ribbon:
          _ribbon(canvas, seg.start, seg.end);
        case ConnectionStyle.hearts:
          _heartPath(canvas, seg.start, seg.end);
      }
    }
  }

  void _dotted(Canvas canvas, Offset a, Offset b) {
    final paint = Paint()
      ..color = NotePalette.rose.withValues(alpha: 0.7)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final len = (b - a).distance;
    final dir = (b - a) / len;
    for (var d = 0.0; d < len; d += 9) {
      if ((d - len / 2).abs() < 10) continue; // room for the heart
      canvas.drawLine(a + dir * d, a + dir * math.min(d + 3.5, len), paint);
    }
  }

  void _ribbon(Canvas canvas, Offset a, Offset b) {
    final mid = (a + b) / 2;
    final normal = Offset(-(b - a).dy, (b - a).dx) / (b - a).distance;
    final sag = mid + normal * math.min(26, (b - a).distance * 0.12);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(sag.dx, sag.dy, b.dx, b.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..color = NotePalette.deepRose.withValues(alpha: 0.55),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = NotePalette.pink.withValues(alpha: 0.7),
    );
    // The ribbon's middle, where the heart sits (on the curve).
    final heartAt = (a + b) / 4 + sag / 2;
    _heart(canvas, heartAt, 8, filled: false);
  }

  void _heartPath(Canvas canvas, Offset a, Offset b) {
    final len = (b - a).distance;
    final dir = (b - a) / len;
    final n = math.max(1, (len / 20).floor());
    for (var i = 0; i <= n; i++) {
      final at = a + dir * (len * i / n);
      final big = i == n ~/ 2;
      _heart(canvas, at, big ? 9 : 5, filled: true, alpha: big ? 0.9 : 0.6);
    }
  }

  void _heart(
    Canvas canvas,
    Offset c,
    double s, {
    required bool filled,
    double alpha = 0.9,
  }) {
    final r = Rect.fromCenter(center: c, width: s * 2, height: s * 2);
    final path = _heartShape(r);
    canvas.drawPath(
      path,
      Paint()
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = NotePalette.rose.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(_LinksPainter old) =>
      old.links != links || old.rects != rects || old.layout != layout;
}

Path _heartShape(Rect r) {
  final w = r.width, h = r.height, x = r.left, y = r.top;
  return Path()
    ..moveTo(x + w / 2, y + h * 0.92)
    ..cubicTo(
      x - w * 0.1,
      y + h * 0.52,
      x + w * 0.06,
      y - h * 0.06,
      x + w / 2,
      y + h * 0.24,
    )
    ..cubicTo(
      x + w * 0.94,
      y - h * 0.06,
      x + w * 1.1,
      y + h * 0.52,
      x + w / 2,
      y + h * 0.92,
    )
    ..close();
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(this.x);

  final double x;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = NotePalette.pink.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 12) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 6), p);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) => old.x != x;
}

// ------------------------------------------------------------- headings

class _YearStamp extends StatelessWidget {
  const _YearStamp({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Transform.rotate(
        angle: -0.04,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: NotePalette.rose.withValues(alpha: 0.8),
              width: 2,
            ),
          ),
          child: Text(
            '$year',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: NotePalette.rose,
            ),
          ),
        ),
      ),
    ),
  );
}

class _NewStripLabel extends StatelessWidget {
  const _NewStripLabel();

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Row(
      children: [
        const Icon(
          Icons.auto_awesome_rounded,
          size: 16,
          color: NotePalette.pink,
        ),
        const SizedBox(width: 6),
        Text(
          'NEW MEMORIES',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: NotePalette.cream,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Drag them into place, or organize by date',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: NotePalette.muted),
          ),
        ),
      ],
    ),
  );
}

/// "OCTOBER 2026" on a torn strip of paper with tape.
class _MonthHeading extends StatelessWidget {
  const _MonthHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Transform.rotate(
        angle: -0.03,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipPath(
              clipper: _TornEdge(),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF1DCCF), Color(0xFFE6C8BC)],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: NotePalette.ink,
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              left: -6,
              top: -6,
              child: ScrapTape(width: 42, turn: -0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _TornEdge extends CustomClipper<Path> {
  static const _teeth = [
    0.0,
    2.0,
    0.5,
    2.5,
    1.0,
    0.0,
    2.2,
    0.8,
    1.6,
    0.3,
    2.4,
    1.1,
  ];

  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final p = Path()..moveTo(0, _teeth[0]);
    for (var i = 1; i < _teeth.length; i++) {
      p.lineTo(w * i / (_teeth.length - 1), _teeth[i]);
    }
    for (var i = 0; i < 6; i++) {
      p.lineTo(w - (i.isEven ? 0 : 3), h * (i + 1) / 6);
    }
    for (var i = _teeth.length - 1; i >= 0; i--) {
      p.lineTo(
        w * i / (_teeth.length - 1),
        h - _teeth[(i + 3) % _teeth.length],
      );
    }
    for (var i = 6; i > 0; i--) {
      p.lineTo(i.isEven ? 0 : 3, h * (i - 1) / 6);
    }
    return p..close();
  }

  @override
  bool shouldReclip(_TornEdge old) => false;
}

/// A soft glow and a few outline hearts and a dashed doodle around each
/// month, so every chapter looks a little hand-made (fixed per month).
class _MonthDecor extends StatelessWidget {
  const _MonthDecor({required this.month});

  final ScrapMonth month;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: CustomPaint(
        painter: _DecorPainter(seed: month.year * 12 + month.month),
      ),
    ),
  );
}

class _DecorPainter extends CustomPainter {
  _DecorPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(rnd.nextBool() ? -0.6 : 0.6, -0.2),
          radius: 0.9,
          colors: [
            NotePalette.rose.withValues(alpha: 0.07),
            NotePalette.rose.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    final left = rnd.nextBool();
    final x = left ? 8.0 : size.width - 8;
    final path = Path()..moveTo(x, 60);
    path.cubicTo(
      x + (left ? 14 : -14),
      size.height * 0.35,
      x + (left ? -6 : 6),
      size.height * 0.65,
      x,
      size.height - 30,
    );
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = NotePalette.pink.withValues(alpha: 0.22);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), dash);
      }
    }
    final heart = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = NotePalette.pink.withValues(alpha: 0.35);
    for (var i = 0; i < 2; i++) {
      final hx = i == 0 ? size.width - 30.0 : 14.0 + rnd.nextDouble() * 10;
      final hy = 30 + rnd.nextDouble() * math.max(1, size.height - 80);
      final s = 12 + rnd.nextDouble() * 8;
      canvas.drawPath(_heartShape(Rect.fromLTWH(hx, hy, s, s)), heart);
    }
  }

  @override
  bool shouldRepaint(_DecorPainter old) => old.seed != seed;
}
