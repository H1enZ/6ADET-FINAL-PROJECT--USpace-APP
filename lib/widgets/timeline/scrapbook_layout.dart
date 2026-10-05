import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../models/memory.dart';
import '../../models/scrapbook.dart';

/// One memory on the canvas, ready to draw.
class ScrapPiece {
  const ScrapPiece({
    required this.memory,
    required this.kind,
    required this.frame,
    required this.item,
    required this.rect,
    required this.seed,
    this.isNew = false,
  });

  final Memory memory;
  final ContentKind kind;

  /// The frame it is drawn in (chosen, or automatic).
  final FrameStyle frame;

  /// Its placement in canvas units (what is saved).
  final LayoutItem item;

  /// Where it is drawn: [item]'s box, moved so the canvas starts at 0.
  final Rect rect;

  /// Stable per memory: picks tape position, paper tint and so on.
  final int seed;

  /// Added after the scrapbook was arranged by hand, waiting in the
  /// "New memories" strip to be placed.
  final bool isNew;

  /// Rotation in degrees.
  double get turn => item.rotation;
}

/// One month's chapter: its heading and the space its pieces use.
/// One month's chapter: its heading and the space its memories use.
class ScrapMonth {
  const ScrapMonth({
    required this.year,
    required this.month,
    required this.top,
    required this.bottom,
    required this.headingRect,
    required this.count,
    required this.area,
    this.yearRect,
  });

  final int year;
  final int month;
  final double top;
  final double bottom;
  final Rect headingRect;
  final int count;

  /// Everything the month covers (heading and memories), for the minimap
  /// and for zooming to a month.
  final Rect area;

  /// A year stamp above the heading, where a new year starts.
  final Rect? yearRect;

  ScrapMonth _shift(Offset by) => ScrapMonth(
    year: year,
    month: month,
    top: top + by.dy,
    bottom: bottom + by.dy,
    headingRect: headingRect.shift(by),
    count: count,
    area: area.shift(by),
    yearRect: yearRect?.shift(by),
  );
}

/// The scrapbook is a 2D board: newer months higher up, older ones lower
/// down (time runs down the board), and each month's memories spread out
/// sideways as a cluster. The board is wider than any phone: you pan it in
/// every direction and pinch to zoom.
///
/// Saved positions are board units. A memory's left edge (x) can be
/// anywhere from [minX] to [maxX], the range the database allows, so the
/// board is [boardWidth] units wide; its height follows the content.
class ScrapbookLayout {
  const ScrapbookLayout({
    required this.width,
    required this.height,
    required this.pieces,
    required this.months,
    required this.originX,
    required this.originY,
    required this.contentRect,
    this.newStripRect,
  });

  /// The drawn canvas: the whole board sideways, the content downwards.
  final double width;
  final double height;

  /// Drawing order: lowest layer first.
  final List<ScrapPiece> pieces;
  final List<ScrapMonth> months;

  /// The board position drawn at the canvas's top-left corner:
  /// drawn = saved - origin.
  final double originX;
  final double originY;

  /// Where the memories, headings and strip actually are (drawn units).
  /// Panning stays around this, so nobody gets lost in empty board.
  final Rect contentRect;

  /// The "New memories" label area, when there are new memories to place.
  final Rect? newStripRect;

  Offset get origin => Offset(originX, originY);

  /// A saved (board) rectangle, where it is drawn.
  Rect toCanvas(Rect board) => board.shift(-origin);

  ScrapPiece? pieceOf(String memoryId) {
    for (final p in pieces) {
      if (p.memory.id == memoryId) return p;
    }
    return null;
  }

  /// The board's sideways extent: the database keeps x in -400..800, and a
  /// memory is at most [maxWidth] wide.
  static const minX = -400.0;
  static const maxX = 800.0;
  static const boardWidth = maxX + maxWidth - minX; // 1580
  static const _boardMargin = 40.0;

  /// How much of the board fills a phone's width at the normal reading
  /// zoom: a memory is as big as it was on the old one-column page, and
  /// the rest of the board is a swipe sideways.
  static const readingWidth = 420.0;

  /// Organize lays clusters out between these (leaving the very edges of
  /// the board free for your own arranging).
  static const _areaLeft = -380.0;
  // A memory's left edge may go up to maxX, so the area ends one column
  // (less the wobble) past it.
  static const _areaRight = maxX + _colW - 12;

  static const _colW = 182.0;
  static const _colGap = 24.0;
  static const _headingHeight = 46.0;
  static const _yearHeight = 44.0;

  /// A small, stable number from a memory's id (FNV-1a), so the same
  /// memory always gets the same tilt, size and side.
  static int seedOf(String id) {
    var h = 0x811c9dc5;
    for (final c in id.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  // ------------------------------------------------------------- sizes

  /// Wide photos are drawn 4:3, narrower ones square.
  static double photoAspectFor(double w) => w >= 240 ? 4 / 3 : 1.0;

  /// Narrowest and widest a memory may be, so text stays readable.
  static double minWidth(ContentKind kind) =>
      kind == ContentKind.photo ? 110 : 130;
  static const maxWidth = 380.0;

  /// The Small / Medium / Large sizes.
  static List<double> presetWidths(ContentKind kind) =>
      kind == ContentKind.photo ? const [130, 178, 300] : const [140, 178, 260];

  /// How tall a memory is in [frame] at width [w]. Never stored: always
  /// worked out, so photos keep their shape whatever the size.
  static double frameHeight(FrameStyle frame, double w, Memory m) {
    final aspect = photoAspectFor(w);
    final hasStory = (m.description?.trim().isNotEmpty ?? false);
    switch (frame) {
      case FrameStyle.polaroid:
        final b = w * 0.06;
        return b + (w - b * 2) / aspect + 52;
      case FrameStyle.taped:
        final b = w * 0.035;
        return b * 2 + (w - b * 2) / aspect + 30;
      case FrameStyle.film:
        final band = math.max(14.0, w * 0.075);
        final side = w * 0.05;
        return band * 2 + (w - side * 2) / aspect + 36;
      case FrameStyle.postcard:
        return math.max(124.0, w * (m.photos.isEmpty ? 0.62 : 0.68));
      case FrameStyle.minimal:
        return m.photos.isEmpty ? (hasStory ? 134.0 : 106.0) : w / aspect + 46;
      case FrameStyle.paper:
        return (hasStory ? 150.0 : 118.0) + ((w - 170) * 0.12).clamp(0.0, 36.0);
      case FrameStyle.loveNote:
        return (hasStory ? 160.0 : 130.0) + ((w - 170) * 0.1).clamp(0.0, 30.0);
      case FrameStyle.ticket:
        return math.max(118.0, w * 0.5);
    }
  }

  static Rect rectOf(LayoutItem item, Memory m, FrameStyle frame) =>
      Rect.fromLTWH(
        item.x,
        item.y,
        item.width,
        frameHeight(frame, item.width, m),
      );

  // ------------------------------------------------------------- organize

  /// Arranges [memories] by date on the board. Months run down the board,
  /// newest at the top, with a year stamp where the year changes. Each
  /// month is a cluster spread sideways: a few staggered columns (more for
  /// busier months), a big feature photo now and then across two columns,
  /// a little hand-placed wobble, and the whole cluster set towards the
  /// left, middle or right of the board so the story zigzags as you go.
  ///
  /// Pure and deterministic: the same memories (and frames) always give the
  /// same arrangement. [frames] are kept: each memory is sized for its frame.
  static ({
    Map<String, LayoutItem> items,
    List<ScrapMonth> months,
    double height,
  })
  organize(
    List<Memory> memories, {
    Map<String, FrameStyle?> frames = const {},
  }) {
    final sorted = [...memories]
      ..sort((a, b) {
        final byDate = b.memoryDate.compareTo(a.memoryDate);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });

    // Group by month, keeping the newest-first order.
    final groups = <(int, int), List<Memory>>{};
    for (final m in sorted) {
      groups
          .putIfAbsent((m.memoryDate.year, m.memoryDate.month), () => [])
          .add(m);
    }

    // Where each month's cluster sits across the board, picked from the
    // month itself so it never changes when other months come and go.
    const zones = [0.5, 0.12, 0.88, 0.32, 0.7, 0.2, 0.8];
    // Column tops, staggered for a hand-placed look.
    const stagger = [0.0, 30.0, 12.0, 40.0, 4.0, 24.0, 16.0];

    final items = <String, LayoutItem>{};
    final months = <ScrapMonth>[];
    var y = 24.0;
    var z = 0;
    int? lastYear;

    for (final entry in groups.entries) {
      final (year, month) = entry.key;
      final list = entry.value;
      final n = list.length;
      final cols = (n / 2).ceil().clamp(2, 6);
      final clusterW = cols * _colW + (cols - 1) * _colGap;
      final room = (_areaRight - _areaLeft) - clusterW;
      final left = _areaLeft + room * zones[(year * 12 + month) % zones.length];

      final top = y;
      Rect? yearRect;
      if (year != lastYear) {
        yearRect = Rect.fromLTWH(left, y, 150, _yearHeight);
        y += _yearHeight + 6;
        lastYear = year;
      }
      final headingRect = Rect.fromLTWH(left - 4, y, 230, _headingHeight);
      y += _headingHeight + 22;

      final colY = [
        for (var c = 0; c < cols; c++) y + stagger[c % stagger.length],
      ];
      double colX(int c) => left + c * (_colW + _colGap);
      var photoCount = 0;
      var right = left + clusterW;

      for (final m in list) {
        final seed = seedOf(m.id);
        final kind = contentKindOf(m);
        final frame = effectiveFrame(m, frames[m.id], seed);
        final turn = ((seed % 61) / 60) * 6 - 3; // -3 .. 3 degrees
        // A little hand-placed wobble (stable per memory).
        final wobbleX = ((seed >> 3) % 17) - 8.0;
        final wobbleY = ((seed >> 7) % 11).toDouble();

        var feature = false;
        var small = false;
        if (kind == ContentKind.photo) {
          // The month's first photo is its feature; after that, every
          // fifth photo gets the big frame too.
          feature = photoCount == 0 || photoCount % 5 == 4;
          small = !feature && seed % 4 == 3;
          photoCount++;
        }

        if (feature) {
          // Across the two neighbouring columns that are free highest up.
          var best = 0;
          var bestY = double.infinity;
          for (var c = 0; c + 1 < cols; c++) {
            final top2 = math.max(colY[c], colY[c + 1]);
            if (top2 < bestY - 0.5) {
              bestY = top2;
              best = c;
            }
          }
          final fw = math.min(_colW * 2 + _colGap, maxWidth);
          final fh = frameHeight(frame, fw, m);
          final fx = colX(best) + (_colW * 2 + _colGap - fw) / 2 + wobbleX;
          final fy = bestY + wobbleY;
          items[m.id] = LayoutItem(
            memoryId: m.id,
            x: fx,
            y: fy,
            width: fw,
            rotation: turn / 2,
            frame: frames[m.id],
            z: z++,
          );
          colY[best] = colY[best + 1] = fy + fh + _colGap;
          right = math.max(right, fx + fw);
          continue;
        }

        // The column free highest up next, so newer memories sit higher.
        var c = 0;
        for (var i = 1; i < cols; i++) {
          if (colY[i] < colY[c] - 0.5) c = i;
        }
        final pw = switch (kind) {
          ContentKind.photo => small ? _colW * 0.84 : _colW,
          ContentKind.event => _colW * 0.92,
          ContentKind.text => _colW * 0.96,
        };
        final ph = frameHeight(frame, pw, m);
        final px = colX(c) + (_colW - pw) / 2 + wobbleX;
        final py = colY[c] + wobbleY;
        items[m.id] = LayoutItem(
          memoryId: m.id,
          x: px,
          y: py,
          width: pw,
          rotation: turn,
          frame: frames[m.id],
          z: z++,
        );
        colY[c] = py + ph + _colGap;
        right = math.max(right, px + pw);
      }

      final bottom = colY.reduce(math.max) + 30;
      months.add(
        ScrapMonth(
          year: year,
          month: month,
          top: top,
          bottom: bottom,
          headingRect: headingRect,
          count: n,
          yearRect: yearRect,
          area: Rect.fromLTRB(left - 16, top, right + 16, bottom),
        ),
      );
      y = bottom + 44;
    }
    return (items: items, months: months, height: y + 40);
  }

  // ------------------------------------------------------------- compose

  /// The scrapbook to draw.
  ///
  /// Not [customized] (nobody has arranged it by hand yet): exactly the
  /// automatic date layout. Customized: every memory with a saved place sits
  /// there; memories added since wait in a "New memories" strip above the
  /// newest month, so nobody's arrangement is ever reshuffled. Month and
  /// year headings sit above each month's highest memory.
  static ScrapbookLayout compose({
    required List<Memory> memories,
    required Map<String, LayoutItem> saved,
    required bool customized,
  }) {
    final placedItems = <String, LayoutItem>{};
    final waiting = <Memory>[];
    var rawMonths = <ScrapMonth>[];

    if (!customized) {
      final org = organize(memories);
      placedItems.addAll(org.items);
      rawMonths = org.months;
    } else {
      for (final m in memories) {
        if (saved[m.id] case final item?) {
          placedItems[m.id] = item;
        } else {
          waiting.add(m);
        }
      }
      rawMonths = _headingsFor(memories, placedItems);
    }

    final byId = {for (final m in memories) m.id: m};
    Rect boardRect(String id, LayoutItem item) {
      final m = byId[id]!;
      return rectOf(item, m, effectiveFrame(m, item.frame, seedOf(id)));
    }

    // The New memories strip, above everything placed.
    final placedRects = [
      for (final e in placedItems.entries) boardRect(e.key, e.value),
    ];
    final placedTop = [
      for (final m in rawMonths) m.top,
      for (final r in placedRects) r.top,
    ].fold<double>(24, math.min);
    final placedLeft = placedRects.isEmpty
        ? _areaLeft
        : placedRects.map((r) => r.left).reduce(math.min);
    final waitingItems = <String, LayoutItem>{};
    Rect? stripRaw;
    if (waiting.isNotEmpty) {
      const cardW = 140.0;
      const perRow = 4;
      final rowHeights = <double>[];
      for (var i = 0; i < waiting.length; i += perRow) {
        var h = 0.0;
        for (final m in waiting.skip(i).take(perRow)) {
          final frame = effectiveFrame(m, null, seedOf(m.id));
          h = math.max(h, frameHeight(frame, cardW, m));
        }
        rowHeights.add(h);
      }
      final total = 40 + rowHeights.fold<double>(0, (a, h) => a + h + 18);
      final stripTop = placedTop - 40 - total;
      final stripLeft = placedLeft.clamp(minX, maxX - (cardW + 16) * perRow);
      stripRaw = Rect.fromLTWH(stripLeft, stripTop, (cardW + 16) * perRow, 32);
      var rowY = stripTop + 40;
      for (var r = 0; r < rowHeights.length; r++) {
        final row = waiting.skip(r * perRow).take(perRow).toList();
        for (var i = 0; i < row.length; i++) {
          final m = row[i];
          final seed = seedOf(m.id);
          waitingItems[m.id] = LayoutItem(
            memoryId: m.id,
            x: stripLeft + i * (cardW + 16),
            y: rowY,
            width: cardW,
            rotation: ((seed % 41) / 40) * 4 - 2,
            z: 1000000 + i,
          );
        }
        rowY += rowHeights[r] + 18;
      }
    }

    // Everything that is actually there, on the board.
    final all = <Rect>[
      ...placedRects,
      for (final e in waitingItems.entries) boardRect(e.key, e.value),
      for (final m in rawMonths) m.area,
      ?stripRaw,
    ];
    final content = all.isEmpty
        ? const Rect.fromLTWH(0, 0, readingWidth, 400)
        : all.reduce((a, b) => a.expandToInclude(b));

    // The drawn canvas: the whole board sideways (so memories can be moved
    // anywhere the database allows), the content plus a margin downwards.
    final origin = Offset(minX - _boardMargin, content.top - 40);
    final width = boardWidth + _boardMargin * 2;
    final height = content.bottom - origin.dy + 60;

    final pieces = <ScrapPiece>[
      for (final e in placedItems.entries)
        _piece(byId[e.key]!, e.value, origin),
      for (final e in waitingItems.entries)
        _piece(byId[e.key]!, e.value, origin, isNew: true),
    ]..sort((a, b) => a.item.z.compareTo(b.item.z));

    return ScrapbookLayout(
      width: width,
      height: height,
      pieces: pieces,
      originX: origin.dx,
      originY: origin.dy,
      contentRect: content.shift(-origin),
      newStripRect: stripRaw?.shift(-origin),
      months: [for (final m in rawMonths) m._shift(-origin)],
    );
  }

  /// Month and year headings for a hand-arranged board: each above its
  /// month's highest memory, at that memory's left.
  static List<ScrapMonth> _headingsFor(
    List<Memory> memories,
    Map<String, LayoutItem> placed,
  ) {
    final groups = <(int, int), List<Rect>>{};
    for (final m in memories) {
      final item = placed[m.id];
      if (item == null) continue;
      final frame = effectiveFrame(m, item.frame, seedOf(m.id));
      groups
          .putIfAbsent((m.memoryDate.year, m.memoryDate.month), () => [])
          .add(rectOf(item, m, frame));
    }
    final keys = groups.keys.toList()
      ..sort(
        (a, b) => a.$1 != b.$1 ? b.$1.compareTo(a.$1) : b.$2.compareTo(a.$2),
      );
    final months = <ScrapMonth>[];
    int? lastYear;
    for (final key in keys) {
      final rects = groups[key]!;
      final bounds = rects.reduce((a, b) => a.expandToInclude(b));
      // Above the highest memory, lined up with it.
      final highest = rects.reduce((a, b) => a.top <= b.top ? a : b);
      final headingTop = bounds.top - _headingHeight - 14;
      final left = highest.left;
      Rect? yearRect;
      if (key.$1 != lastYear) {
        yearRect = Rect.fromLTWH(
          left,
          headingTop - _yearHeight - 6,
          150,
          _yearHeight,
        );
        lastYear = key.$1;
      }
      final top = yearRect?.top ?? headingTop;
      months.add(
        ScrapMonth(
          year: key.$1,
          month: key.$2,
          top: top,
          bottom: bounds.bottom + 30,
          headingRect: Rect.fromLTWH(left - 4, headingTop, 230, _headingHeight),
          count: rects.length,
          yearRect: yearRect,
          area: Rect.fromLTRB(
            math.min(bounds.left, left) - 16,
            top,
            math.max(bounds.right, left + 230) + 16,
            bounds.bottom + 30,
          ),
        ),
      );
    }
    return months;
  }

  static ScrapPiece _piece(
    Memory m,
    LayoutItem item,
    Offset origin, {
    bool isNew = false,
  }) {
    final seed = seedOf(m.id);
    final frame = effectiveFrame(m, item.frame, seed);
    return ScrapPiece(
      memory: m,
      kind: contentKindOf(m),
      frame: frame,
      item: item,
      rect: rectOf(item, m, frame).shift(-origin),
      seed: seed,
      isNew: isNew,
    );
  }
}
