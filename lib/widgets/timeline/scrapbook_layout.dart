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
class ScrapMonth {
  const ScrapMonth({
    required this.year,
    required this.month,
    required this.top,
    required this.bottom,
    required this.headingRect,
    required this.count,
    this.yearRect,
  });

  final int year;
  final int month;
  final double top;
  final double bottom;
  final Rect headingRect;
  final int count;

  /// A year stamp above the heading, where a new year starts.
  final Rect? yearRect;
}

class ScrapbookLayout {
  const ScrapbookLayout({
    required this.width,
    required this.height,
    required this.pieces,
    required this.months,
    required this.originY,
    this.newStripRect,
  });

  final double width;
  final double height;

  /// Drawing order: lowest layer first.
  final List<ScrapPiece> pieces;
  final List<ScrapMonth> months;

  /// The saved y that is drawn at the canvas top (y - originY = drawn y).
  final double originY;

  /// The "New memories" label area, when there are new memories to place.
  final Rect? newStripRect;

  ScrapPiece? pieceOf(String memoryId) {
    for (final p in pieces) {
      if (p.memory.id == memoryId) return p;
    }
    return null;
  }

  /// The canvas is always laid out at this width, whatever the phone, so a
  /// memory sits in the same place on every device; the viewer scales it.
  static const canvasWidth = 400.0;

  static const _pad = 18.0;
  static const _gap = 14.0;
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
  static const maxWidth = 360.0;

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

  /// Arranges [memories] by date: newest month at the top, a year stamp
  /// where the year changes; inside a month, newest first, filling two
  /// staggered columns with a big feature photo now and then. Pure and
  /// deterministic: the same memories (and frames) always give the same
  /// arrangement. [frames] are kept: each memory is sized for its frame.
  static ({
    Map<String, LayoutItem> items,
    List<ScrapMonth> months,
    double height,
  })
  organize(
    List<Memory> memories, {
    Map<String, FrameStyle?> frames = const {},
  }) {
    const w = canvasWidth;
    const content = w - _pad * 2;
    const colW = (content - _gap) / 2;

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

    final items = <String, LayoutItem>{};
    final months = <ScrapMonth>[];
    var y = 24.0;
    var z = 0;
    int? lastYear;

    for (final entry in groups.entries) {
      final (year, month) = entry.key;
      final list = entry.value;
      final top = y;
      Rect? yearRect;
      if (year != lastYear) {
        yearRect = Rect.fromLTWH(_pad, y, 150, _yearHeight);
        y += _yearHeight + 6;
        lastYear = year;
      }
      final headingRect = Rect.fromLTWH(_pad - 4, y, 210, _headingHeight);
      y += _headingHeight + 18;

      // Column bottoms: left starts a little higher than right, which
      // gives the staggered, hand-placed look.
      final cols = [y, y + 22];
      var photoCount = 0;

      for (final m in list) {
        final seed = seedOf(m.id);
        final kind = contentKindOf(m);
        final frame = effectiveFrame(m, frames[m.id], seed);
        final turn = ((seed % 61) / 60) * 6 - 3; // -3 .. 3 degrees

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
          final fw = content * 0.9;
          final fh = frameHeight(frame, fw, m);
          final fy = math.max(cols[0], cols[1]);
          final fx = _pad + (seed.isEven ? 0 : content - fw);
          items[m.id] = LayoutItem(
            memoryId: m.id,
            x: fx,
            y: fy,
            width: fw,
            rotation: turn / 2,
            frame: frames[m.id],
            z: z++,
          );
          cols[0] = cols[1] = fy + fh + _gap;
          continue;
        }

        // Shortest column next, so pieces fill top to bottom.
        final c = cols[0] <= cols[1] ? 0 : 1;
        final colX = _pad + c * (colW + _gap);
        final pw = switch (kind) {
          ContentKind.photo => small ? colW * 0.84 : colW,
          ContentKind.event => colW * 0.92,
          ContentKind.text => colW * 0.96,
        };
        final ph = frameHeight(frame, pw, m);
        // Narrower pieces lean towards one side of their column.
        final px = colX + (seed % 3 == 0 ? 0 : colW - pw);
        items[m.id] = LayoutItem(
          memoryId: m.id,
          x: px,
          y: cols[c],
          width: pw,
          rotation: turn,
          frame: frames[m.id],
          z: z++,
        );
        cols[c] += ph + _gap;
      }

      y = math.max(cols[0], cols[1]) + 30;
      months.add(
        ScrapMonth(
          year: year,
          month: month,
          top: top,
          bottom: y,
          headingRect: headingRect,
          count: list.length,
          yearRect: yearRect,
        ),
      );
      y += 20;
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
    if (!customized) {
      final org = organize(memories);
      final pieces = [
        for (final m in memories)
          if (org.items[m.id] case final item?) _piece(m, item, 0),
      ]..sort((a, b) => a.item.z.compareTo(b.item.z));
      return ScrapbookLayout(
        width: canvasWidth,
        height: org.height,
        pieces: pieces,
        months: org.months,
        originY: 0,
      );
    }

    final placed = <Memory>[];
    final waiting = <Memory>[];
    for (final m in memories) {
      (saved.containsKey(m.id) ? placed : waiting).add(m);
    }

    // Headings above each month's highest memory.
    final groups = <(int, int), List<Rect>>{};
    for (final m in placed) {
      final seed = seedOf(m.id);
      final item = saved[m.id]!;
      final frame = effectiveFrame(m, item.frame, seed);
      groups
          .putIfAbsent((m.memoryDate.year, m.memoryDate.month), () => [])
          .add(rectOf(item, m, frame));
    }
    final keys = groups.keys.toList()
      ..sort(
        (a, b) => a.$1 != b.$1 ? b.$1.compareTo(a.$1) : b.$2.compareTo(a.$2),
      );
    final rawMonths = <ScrapMonth>[];
    int? lastYear;
    for (final key in keys) {
      final rects = groups[key]!;
      final top = rects.map((r) => r.top).reduce(math.min);
      final bottom = rects.map((r) => r.bottom).reduce(math.max);
      final headingTop = top - _headingHeight - 14;
      Rect? yearRect;
      if (key.$1 != lastYear) {
        yearRect = Rect.fromLTWH(
          _pad,
          headingTop - _yearHeight - 6,
          150,
          _yearHeight,
        );
        lastYear = key.$1;
      }
      rawMonths.add(
        ScrapMonth(
          year: key.$1,
          month: key.$2,
          top: (yearRect?.top ?? headingTop),
          bottom: bottom + 30,
          headingRect: Rect.fromLTWH(_pad - 4, headingTop, 210, _headingHeight),
          count: rects.length,
          yearRect: yearRect,
        ),
      );
    }

    // The New memories strip, above everything placed.
    final placedTop = [
      for (final m in rawMonths) m.top,
      for (final m in placed) saved[m.id]!.y,
    ].fold<double>(24, math.min);
    final waitingItems = <String, LayoutItem>{};
    Rect? stripRaw;
    if (waiting.isNotEmpty) {
      const cardW = 116.0;
      const perRow = 3;
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
      final stripTop = placedTop - 36 - total;
      stripRaw = Rect.fromLTWH(_pad, stripTop, canvasWidth - _pad * 2, 32);
      var rowY = stripTop + 40;
      for (var r = 0; r < rowHeights.length; r++) {
        final row = waiting.skip(r * perRow).take(perRow).toList();
        for (var i = 0; i < row.length; i++) {
          final m = row[i];
          final seed = seedOf(m.id);
          waitingItems[m.id] = LayoutItem(
            memoryId: m.id,
            x: _pad + i * (cardW + 13),
            y: rowY,
            width: cardW,
            rotation: ((seed % 41) / 40) * 4 - 2,
            z: 1000000 + i,
          );
        }
        rowY += rowHeights[r] + 18;
      }
    }

    final originY = (stripRaw?.top ?? placedTop) - 24;
    final pieces = <ScrapPiece>[
      for (final m in placed) _piece(m, saved[m.id]!, originY),
      for (final m in waiting)
        _piece(m, waitingItems[m.id]!, originY, isNew: true),
    ]..sort((a, b) => a.item.z.compareTo(b.item.z));

    final bottom = [
      for (final p in pieces) p.rect.bottom,
      for (final m in rawMonths) m.bottom - originY,
    ].fold<double>(0, math.max);

    Rect shift(Rect r) => r.translate(0, -originY);
    return ScrapbookLayout(
      width: canvasWidth,
      height: bottom + 60,
      pieces: pieces,
      originY: originY,
      newStripRect: stripRaw == null ? null : shift(stripRaw),
      months: [
        for (final m in rawMonths)
          ScrapMonth(
            year: m.year,
            month: m.month,
            top: m.top - originY,
            bottom: m.bottom - originY,
            headingRect: shift(m.headingRect),
            count: m.count,
            yearRect: m.yearRect == null ? null : shift(m.yearRect!),
          ),
      ],
    );
  }

  static ScrapPiece _piece(
    Memory m,
    LayoutItem item,
    double originY, {
    bool isNew = false,
  }) {
    final seed = seedOf(m.id);
    final frame = effectiveFrame(m, item.frame, seed);
    return ScrapPiece(
      memory: m,
      kind: contentKindOf(m),
      frame: frame,
      item: item,
      rect: rectOf(item, m, frame).translate(0, -originY),
      seed: seed,
      isNew: isNew,
    );
  }
}
