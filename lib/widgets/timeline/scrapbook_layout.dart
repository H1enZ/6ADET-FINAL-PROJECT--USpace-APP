import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../models/memory.dart';

/// How a memory is drawn on the scrapbook.
enum PieceKind {
  /// A big Polaroid across most of the page.
  feature,

  /// A Polaroid in one of the two columns.
  polaroid,

  /// A smaller taped photo.
  small,

  /// A lined paper note, for a memory without a photo.
  note,

  /// A date card, for a special memory without a photo.
  special,
}

/// One memory, placed on the canvas.
class ScrapPiece {
  const ScrapPiece({
    required this.memory,
    required this.kind,
    required this.rect,
    required this.turn,
    required this.seed,
  });

  final Memory memory;
  final PieceKind kind;

  /// Where it sits on the canvas, in canvas units.
  final Rect rect;

  /// Rotation in degrees, between -3 and 3.
  final double turn;

  /// Stable per memory: picks tape position, paper tint and so on.
  final int seed;
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
  });

  final int year;
  final int month;
  final double top;
  final double bottom;
  final Rect headingRect;
  final int count;
}

class ScrapbookLayout {
  const ScrapbookLayout({
    required this.width,
    required this.height,
    required this.pieces,
    required this.months,
  });

  final double width;
  final double height;
  final List<ScrapPiece> pieces;
  final List<ScrapMonth> months;

  /// The canvas is always laid out at this width, whatever the phone, so a
  /// memory sits in the same place on every device; the viewer scales it.
  static const canvasWidth = 400.0;

  static const _pad = 18.0;
  static const _gap = 14.0;
  static const _headingHeight = 46.0;

  /// Memories tagged like this, without a photo, become date cards.
  static const _specialTags = {
    'anniversary',
    'first_date',
    'celebration',
    'special',
  };

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

  /// Polaroid height for a frame [w] wide: border, photo, caption strip.
  static double polaroidHeight(double w, {required double photoAspect}) {
    final border = w * 0.06;
    final photo = (w - border * 2) / photoAspect;
    return border + photo + 52;
  }

  /// Lays out [memories] newest month first; inside a month, newest first,
  /// top to bottom (two columns fill in turn, so order stays readable).
  /// Pure and deterministic: the same memories give the same layout.
  static ScrapbookLayout build(List<Memory> memories) {
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

    final pieces = <ScrapPiece>[];
    final months = <ScrapMonth>[];
    var y = 24.0;

    for (final entry in groups.entries) {
      final (year, month) = entry.key;
      final list = entry.value;
      final top = y;
      final headingRect = Rect.fromLTWH(_pad - 4, y, 210, _headingHeight);
      y += _headingHeight + 18;

      // Column bottoms: left starts a little higher than right, which
      // gives the staggered, hand-placed look.
      final cols = [y, y + 22];
      var photoCount = 0;

      for (var i = 0; i < list.length; i++) {
        final m = list[i];
        final seed = seedOf(m.id);
        final hasPhoto = m.photos.isNotEmpty;
        final turn = ((seed % 61) / 60) * 6 - 3; // -3 .. 3 degrees

        final PieceKind kind;
        if (hasPhoto) {
          // The month's first photo is its feature; after that, every
          // fifth photo gets the big frame too.
          kind = photoCount == 0 || photoCount % 5 == 4
              ? PieceKind.feature
              : (seed % 4 == 3 ? PieceKind.small : PieceKind.polaroid);
          photoCount++;
        } else {
          kind = m.tags.any(_specialTags.contains)
              ? PieceKind.special
              : PieceKind.note;
        }

        if (kind == PieceKind.feature) {
          final fw = content * 0.9;
          final fh = polaroidHeight(fw, photoAspect: 4 / 3);
          final fy = math.max(cols[0], cols[1]);
          final fx = _pad + (seed.isEven ? 0 : content - fw);
          pieces.add(
            ScrapPiece(
              memory: m,
              kind: kind,
              rect: Rect.fromLTWH(fx, fy, fw, fh),
              turn: turn / 2,
              seed: seed,
            ),
          );
          cols[0] = cols[1] = fy + fh + _gap;
          continue;
        }

        // Shortest column next, so pieces fill top to bottom.
        final c = cols[0] <= cols[1] ? 0 : 1;
        final colX = _pad + c * (colW + _gap);
        final (pw, ph) = switch (kind) {
          PieceKind.polaroid => (colW, polaroidHeight(colW, photoAspect: 1)),
          PieceKind.small => (
            colW * 0.84,
            polaroidHeight(colW * 0.84, photoAspect: 1),
          ),
          PieceKind.special => (colW * 0.92, 132.0),
          _ => (
            colW * 0.96,
            (m.description?.isNotEmpty ?? false) ? 150.0 : 118.0,
          ),
        };
        // Narrower pieces lean towards one side of their column.
        final px = colX + (seed % 3 == 0 ? 0 : colW - pw);
        pieces.add(
          ScrapPiece(
            memory: m,
            kind: kind,
            rect: Rect.fromLTWH(px, cols[c], pw, ph),
            turn: turn,
            seed: seed,
          ),
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
        ),
      );
      y += 20;
    }

    return ScrapbookLayout(
      width: w,
      height: y + 40,
      pieces: pieces,
      months: months,
    );
  }
}
