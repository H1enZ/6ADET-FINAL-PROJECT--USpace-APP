import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../models/scrap_decoration.dart';
import '../../models/scrapbook.dart';
import '../../theme/app_typography.dart';
import '../../theme/us_palette.dart';
import '../../utils/anniversary.dart';
import '../atoms/us_icon.dart';
import '../notes/note_style.dart';
import 'cork_surface.dart';
import 'scrap_decorations.dart';
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

/// "October 2026", as handwritten on a month tag.
String monthTitle(int year, int month) {
  final name = _monthNames[month - 1];
  return '${name[0]}${name.substring(1).toLowerCase()} $year';
}
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
    this.decorations = const [],
    this.decoLive,
    this.selectedDecoId,
    this.onTapDeco,
    this.onDecoGestureStart,
    this.showDates = true,
    this.tagOpacity,
  });

  /// The month tags on the board (hidden on request).
  final bool showDates;

  /// How visible the month tags on the board are (1 = fully). They fade out
  /// as the viewer zooms far out, where floating tags take over, so a month
  /// never shows twice. Only the tags repaint as it changes.
  final ValueListenable<double>? tagOpacity;

  final ScrapbookLayout layout;

  /// Sticky notes, stickers, tape and doodles (board positions).
  final List<ScrapDecoration> decorations;

  /// The decoration being moved, sized or turned right now.
  final ValueNotifier<ScrapDecoration?>? decoLive;
  final String? selectedDecoId;
  final void Function(ScrapDecoration deco)? onTapDeco;
  final void Function(ScrapDecoration deco, ScrapGesture kind, Offset canvas)?
  onDecoGestureStart;
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
          // The corkboard: framed, and only as big as what is on it.
          Positioned.fromRect(
            rect: boardRect(layout),
            child: BoardFrame(
              origin: layout.origin + corkRect(layout).topLeft,
            ),
          ),
          if (editing)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: w.onTapEmpty,
              ),
            ),
          if (w.showDates)
            for (final m in layout.months)
              Positioned.fromRect(
                rect: m.headingRect,
                child: _FadingTag(
                  opacity: w.tagOpacity,
                  child: MonthTag(
                    label: monthTitle(m.year, m.month),
                    turn: _tagTurn(m),
                  ),
                ),
              ),
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
          // Memories and decorations, lowest layer first (a piece of tape
          // can sit over a photo's corner).
          for (final (_, isDeco, index) in _order(layout, w.decorations))
            if (isDeco)
              _LiveDeco(
                key: ValueKey('deco-${w.decorations[index].id}'),
                deco: w.decorations[index],
                origin: layout.origin,
                live: w.decoLive,
                editing: editing,
                selected: w.decorations[index].id == w.selectedDecoId,
                onTap: () => w.onTapDeco?.call(w.decorations[index]),
                onStart: (kind, global) => w.onDecoGestureStart?.call(
                  w.decorations[index],
                  kind,
                  toCanvas(global),
                ),
                onUpdate: (global) => w.onGestureUpdate?.call(toCanvas(global)),
                onEnd: () => w.onGestureEnd?.call(),
              )
            else if (layout.pieces[index] case final p)
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
                  onUpdate: (global) =>
                      w.onGestureUpdate?.call(toCanvas(global)),
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
                  listenable: live,
                  resolve: () {
                    final l = live.value;
                    if (l == null || l.item.memoryId != piece.memory.id) {
                      return (rect: piece.rect, turn: piece.turn);
                    }
                    return (
                      rect: ScrapbookLayout.rectOf(
                        l.item,
                        piece.memory,
                        piece.frame,
                      ).shift(-layout.origin),
                      turn: l.item.rotation,
                    );
                  },
                  view: w.view!,
                  onStart: (kind, global) =>
                      w.onGestureStart?.call(piece, kind, toCanvas(global)),
                  onUpdate: (global) =>
                      w.onGestureUpdate?.call(toCanvas(global)),
                  onEnd: () => w.onGestureEnd?.call(),
                ),
          // The selected decoration's handles.
          if (editing &&
              w.decoLive != null &&
              w.view != null &&
              MediaQuery.sizeOf(context).width >= 340)
            if (w.selectedDecoId case final id?)
              if (w.decorations.where((d) => d.id == id).firstOrNull
                  case final deco?)
                _SelectionHandles(
                  listenable: w.decoLive!,
                  resolve: () {
                    final l = w.decoLive!.value;
                    final d = l != null && l.id == deco.id ? l : deco;
                    return (
                      rect: d.rect.shift(-layout.origin),
                      turn: d.rotation,
                    );
                  },
                  view: w.view!,
                  onStart: (kind, global) =>
                      w.onDecoGestureStart?.call(deco, kind, toCanvas(global)),
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

/// Drawing order of memories and decorations: (layer, is decoration,
/// index). On equal layers, memories go first.
List<(int, bool, int)> _order(
  ScrapbookLayout layout,
  List<ScrapDecoration> decorations,
) =>
    [
      for (var i = 0; i < layout.pieces.length; i++)
        (layout.pieces[i].item.z, false, i),
      for (var i = 0; i < decorations.length; i++) (decorations[i].z, true, i),
    ]..sort((a, b) {
      final byZ = a.$1.compareTo(b.$1);
      if (byZ != 0) return byZ;
      return (a.$2 ? 1 : 0).compareTo(b.$2 ? 1 : 0);
    });

/// A decoration on the board. In view mode it is just part of the picture
/// (taps go through to the memories under it); in edit mode it can be
/// selected and moved like a memory. Follows [live] while it is edited.
class _LiveDeco extends StatelessWidget {
  const _LiveDeco({
    super.key,
    required this.deco,
    required this.origin,
    required this.live,
    required this.editing,
    required this.selected,
    required this.onTap,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final ScrapDecoration deco;
  final Offset origin;
  final ValueNotifier<ScrapDecoration?>? live;
  final bool editing;
  final bool selected;
  final VoidCallback onTap;
  final void Function(ScrapGesture kind, Offset global) onStart;
  final void Function(Offset global) onUpdate;
  final VoidCallback onEnd;

  Widget _at(ScrapDecoration d, {bool lifted = false}) {
    final rect = d.rect.shift(-origin);
    Widget body = DecorationView(decoration: d, size: rect.size);
    if (!editing) {
      body = IgnorePointer(child: ExcludeSemantics(child: body));
    } else {
      body = Semantics(
        button: true,
        selected: selected,
        label: switch (d.kind) {
          DecoKind.stickyNote => 'Sticky note: ${d.body ?? ''}',
          DecoKind.sticker => 'Sticker',
          DecoKind.tape => 'Washi tape',
          DecoKind.doodle => 'Doodle',
        },
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPressStart: (e) => onStart(ScrapGesture.move, e.globalPosition),
          onLongPressMoveUpdate: (e) => onUpdate(e.globalPosition),
          onLongPressEnd: (_) => onEnd(),
          onLongPressCancel: onEnd,
          onPanStart: selected
              ? (e) => onStart(ScrapGesture.move, e.globalPosition)
              : null,
          onPanUpdate: selected ? (e) => onUpdate(e.globalPosition) : null,
          onPanEnd: selected ? (_) => onEnd() : null,
          onPanCancel: selected ? onEnd : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              body,
              if (selected)
                Positioned(
                  left: -5,
                  top: -5,
                  right: -5,
                  bottom: -5,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: NotePalette.rose, width: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Positioned.fromRect(
      rect: rect,
      child: Transform.rotate(
        angle: d.rotation * math.pi / 180,
        child: Transform.scale(scale: lifted ? 1.05 : 1, child: body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = live;
    if (notifier == null) return _at(deco);
    return ValueListenableBuilder<ScrapDecoration?>(
      valueListenable: notifier,
      builder: (context, l, _) =>
          l != null && l.id == deco.id ? _at(l, lifted: true) : _at(deco),
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
        ).shift(-layout.origin);
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
    required this.listenable,
    required this.resolve,
    required this.view,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  /// Changes while the selected thing is being moved, sized or turned.
  final Listenable listenable;

  /// Where the selected thing is drawn right now, and its turn.
  final ({Rect rect, double turn}) Function() resolve;
  final TransformationController view;
  final void Function(ScrapGesture kind, Offset global) onStart;
  final void Function(Offset global) onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([view, listenable]),
      builder: (context, _) {
        final s = view.value.getMaxScaleOnAxis();
        final d = 34 / s; // about 34 screen pixels
        final m = d * 1.6; // room around the item for the handles
        final (:rect, :turn) = resolve();

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
        ).shift(-layout.origin);
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

class _NewStripLabel extends StatelessWidget {
  const _NewStripLabel();

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    // On a soft dark band, so the words stay readable on the cork.
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: UsPalette.ink.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const UsIcon(UsIcons.sparkle, size: 16, color: NotePalette.pink),
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
    ),
  );
}

/// A small fixed tilt per month, so the tags look pinned by hand.
double _tagTurn(ScrapMonth m) => ((m.year * 12 + m.month) % 5 - 2) * 0.012;

/// A month tag on the board, faded by [opacity] while the viewer is far
/// out. Gestures always pass through it, and once it is mostly faded it
/// leaves the semantics tree (the floating tag speaks for the month then).
class _FadingTag extends StatelessWidget {
  const _FadingTag({required this.opacity, required this.child});

  final ValueListenable<double>? opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tag = IgnorePointer(child: RepaintBoundary(child: child));
    final o = opacity;
    if (o == null) return tag;
    return ValueListenableBuilder<double>(
      valueListenable: o,
      child: tag,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: ExcludeSemantics(excluding: value < 0.5, child: child),
      ),
    );
  }
}

/// A month's name handwritten on a cream paper tag, held to the cork by a
/// small rose pin, with a string hole at its square end. Used on the board
/// and, smaller, as the floating month buttons when zoomed out.
class MonthTag extends StatelessWidget {
  const MonthTag({
    super.key,
    required this.label,
    this.turn = 0,
    this.size = 22,
  });

  /// "October 2026".
  final String label;

  /// Tilt in radians.
  final double turn;

  /// Lettering size; the tag grows with it.
  final double size;

  @override
  Widget build(BuildContext context) {
    final hole = size * 0.26;
    final pin = size * 0.5;
    return Semantics(
      header: true,
      label: label,
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Transform.rotate(
          angle: turn,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  size * 1.05,
                  size * 0.12,
                  size * 0.75,
                  size * 0.08,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [NotePalette.paper, NotePalette.paperEdge],
                  ),
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(size * 0.14),
                    right: Radius.circular(size * 0.55),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: AppTypography.monthTag(
                    color: NotePalette.ink,
                    size: size,
                  ),
                ),
              ),
              // The string hole.
              Positioned(
                left: size * 0.38,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: hole,
                    height: hole,
                    decoration: const BoxDecoration(
                      color: UsPalette.corkDeep,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              // The pin, just right of the hole and over the top edge.
              Positioned(
                left: size * 0.62,
                top: -pin * 0.35,
                child: Container(
                  width: pin,
                  height: pin,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment(-0.35, -0.35),
                      colors: [UsPalette.blush, UsPalette.roseDeep],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x80000000),
                        blurRadius: 3,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- board

/// The framed board (canvas units): everything on it (memories, month
/// tags, the New strip, stickers) plus a cork margin and the frame. It grows
/// as soon as something is placed past it, and is never narrower than the
/// reading width, so at reading size it always fills the screen across.
/// Panning stops at its edges.
Rect boardRect(ScrapbookLayout layout) {
  final r = layout.contentRect.inflate(BoardFrame.margin + BoardFrame.width);
  const minWidth = ScrapbookLayout.readingWidth;
  if (r.width >= minWidth) return r;
  return Rect.fromCenter(center: r.center, width: minWidth, height: r.height);
}

/// The cork inside the frame.
Rect corkRect(ScrapbookLayout layout) =>
    boardRect(layout).deflate(BoardFrame.width);

/// A real pinboard: cocoa cork in a thin dark wooden frame with a soft
/// shadow, hanging on the app's plum. Gestures pass through it.
class BoardFrame extends StatelessWidget {
  const BoardFrame({super.key, required this.origin});

  /// Where the cork's top-left sits in saved board units (keeps the grain
  /// fixed to the board).
  final Offset origin;

  /// Cork between the outermost things on the board and the frame.
  static const margin = 76.0;

  /// The wooden frame's width.
  static const width = 14.0;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          // Dark wood: deeper than the cork, lighter than the wall, with a
          // faint bevel on its outer edge so it reads as a frame.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              UsPalette.corkDeep,
              Color.lerp(UsPalette.corkDeep, UsPalette.ink, 0.55)!,
              UsPalette.corkDeep,
            ],
            stops: const [0, 0.55, 1],
          ),
          border: Border.all(
            color: UsPalette.cream.withValues(alpha: 0.10),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x8C000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(width),
          child: DecoratedBox(
            // A thin dark line where the cork meets the wood.
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0x66140C14), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: CorkSurface(origin: origin),
            ),
          ),
        ),
      ),
    ),
  );
}

// ------------------------------------------------------- tag handoff

/// How far the viewer is into "zoomed out" (0 at normal size, 1 from 45%
/// of it), where the floating month tags take over from the board's own.
double farOutProgress(double scale, double defaultScale) =>
    ((defaultScale * 0.6 - scale) / (defaultScale * 0.15)).clamp(0.0, 1.0);

/// The board's month tags fade out over the first half of the handoff and
/// the floating ones fade in over the second, so a month is never shown
/// twice. With reduced motion they simply swap at the midpoint.
double boardTagOpacity(double progress, {bool still = false}) => still
    ? (progress < 0.5 ? 1 : 0)
    : (1 - 2 * progress).clamp(0.0, 1.0);

double floatingTagOpacity(double progress, {bool still = false}) => still
    ? (progress < 0.5 ? 0 : 1)
    : (2 * progress - 1).clamp(0.0, 1.0);

/// Floating month tags, kept from overlapping: taken top to bottom (then
/// left to right), each moves down just below any tag it would cover.
/// Same order in and out; a tag pushed past [maxBottom] is dropped (null),
/// so a crowded overview never stacks tags off screen.
List<Rect?> spreadTags(
  List<Rect> boxes, {
  required double maxBottom,
  double gap = 6,
}) {
  final order = List.generate(boxes.length, (i) => i)
    ..sort((a, b) {
      final byTop = boxes[a].top.compareTo(boxes[b].top);
      return byTop != 0 ? byTop : boxes[a].left.compareTo(boxes[b].left);
    });
  final placed = <Rect>[];
  final out = List<Rect?>.filled(boxes.length, null);
  for (final i in order) {
    var r = boxes[i];
    var moved = true;
    while (moved) {
      moved = false;
      for (final p in placed) {
        if (r.overlaps(p.inflate(gap / 2))) {
          r = r.translate(0, p.bottom + gap - r.top);
          moved = true;
        }
      }
    }
    if (r.bottom > maxBottom) continue;
    placed.add(r);
    out[i] = r;
  }
  return out;
}
