import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/anniversary.dart';
import '../notes/note_style.dart';
import 'scrapbook_layout.dart';

const _monthNames = [
  'JANUARY',
  'FEBRUARY',
  'MARCH',
  'APRIL',
  'MAY',
  'JUNE',
  'JULY',
  'AUGUST',
  'SEPTEMBER',
  'OCTOBER',
  'NOVEMBER',
  'DECEMBER',
];
const _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String monthLabel(int year, int month) => '${_monthNames[month - 1]} $year';
String shortMonthLabel(int year, int month) =>
    '${_shortMonths[month - 1].toUpperCase()} $year';

/// Handwriting for captions and notes.
TextStyle _hand(double size, {Color color = NotePalette.ink}) =>
    GoogleFonts.caveat(
      fontSize: size,
      height: 1.1,
      color: color,
      fontWeight: FontWeight.w600,
    );

/// The whole scrapbook at canvas size. Built once per layout: the viewer
/// only transforms it, so zooming never rebuilds or moves a piece.
class ScrapbookCanvas extends StatelessWidget {
  const ScrapbookCanvas({
    super.key,
    required this.layout,
    required this.onTapPiece,
    required this.photoScale,
  });

  final ScrapbookLayout layout;
  final void Function(ScrapPiece piece) onTapPiece;

  /// Device pixels per canvas unit at the closest zoom, to size decoded
  /// photos (no full-size originals in memory).
  final double photoScale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: layout.width,
      height: layout.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final m in layout.months) ...[
            Positioned.fromRect(
              rect: Rect.fromLTWH(0, m.top, layout.width, m.bottom - m.top),
              child: _MonthDecor(month: m),
            ),
            Positioned.fromRect(
              rect: m.headingRect,
              child: _MonthHeading(label: monthLabel(m.year, m.month)),
            ),
          ],
          for (final p in layout.pieces)
            Positioned.fromRect(
              key: ValueKey('piece-${p.memory.id}'),
              rect: p.rect,
              child: Transform.rotate(
                angle: p.turn * math.pi / 180,
                child: _PieceButton(
                  piece: p,
                  onTap: () => onTapPiece(p),
                  child: switch (p.kind) {
                    PieceKind.feature ||
                    PieceKind.polaroid ||
                    PieceKind.small => _Polaroid(
                      piece: p,
                      photoScale: photoScale,
                    ),
                    PieceKind.note => _PaperNote(piece: p),
                    PieceKind.special => _DateCard(piece: p),
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PieceButton extends StatelessWidget {
  const _PieceButton({
    required this.piece,
    required this.onTap,
    required this.child,
  });

  final ScrapPiece piece;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final m = piece.memory;
    return Semantics(
      button: true,
      label:
          '${m.title}, ${longDate(m.memoryDate)}${m.isFavorite ? ', favorite' : ''}',
      excludeSemantics: true,
      // A plain tap: a drag or pinch on top of it goes to the viewer
      // instead, so moving around never opens a memory.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

/// A strip of washi tape.
class _Tape extends StatelessWidget {
  const _Tape({required this.width, this.turn = 0.05, this.tint = 0});

  final double width;
  final double turn;
  final int tint;

  static const _tints = [
    Color(0xB3F2C4CF),
    Color(0xB3E9D6C4),
    Color(0x99F6A9C1),
  ];

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: turn,
    child: Container(
      width: width,
      height: width * 0.28,
      decoration: BoxDecoration(
        color: _tints[tint % _tints.length],
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 2),
        ],
      ),
    ),
  );
}

BoxDecoration _paper(Color top, Color bottom) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [top, bottom],
  ),
  borderRadius: BorderRadius.circular(2.5),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.5),
      blurRadius: 10,
      offset: const Offset(0, 5),
    ),
  ],
);

class _Polaroid extends StatelessWidget {
  const _Polaroid({required this.piece, required this.photoScale});

  final ScrapPiece piece;
  final double photoScale;

  @override
  Widget build(BuildContext context) {
    final m = piece.memory;
    final r = piece.rect;
    final border = r.width * 0.06;
    final big = piece.kind == PieceKind.feature;
    final url = m.photoUrl;
    final decodeWidth = (r.width * photoScale).round().clamp(64, 1400);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: r.width,
          height: r.height,
          padding: EdgeInsets.fromLTRB(border, border, border, 0),
          decoration: _paper(const Color(0xFFFFF4EE), const Color(0xFFF1DCD9)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: url == null
                      ? const _NoPhoto()
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          cacheWidth: decodeWidth,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, _, _) => const _NoPhoto(),
                        ),
                ),
              ),
              SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              m.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _hand(big ? 24 : 19),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            m.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: big ? 16 : 13,
                            color: NotePalette.rose,
                          ),
                        ],
                      ),
                      Text(
                        longDate(m.memoryDate),
                        style: _hand(
                          big ? 15 : 13.5,
                          color: NotePalette.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -r.width * 0.05,
          left: r.width * (0.3 + (piece.seed % 3) * 0.08),
          child: _Tape(
            width: r.width * 0.32,
            tint: piece.seed,
            turn: (piece.seed % 5 - 2) * 0.03,
          ),
        ),
        if (m.photos.length > 1)
          Positioned(
            top: border + 6,
            right: border + 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    size: 11,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${m.photos.length}',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF4A1D42),
    alignment: Alignment.center,
    child: const Icon(Icons.image_outlined, color: NotePalette.pink),
  );
}

/// A lined pink note, handwritten.
class _PaperNote extends StatelessWidget {
  const _PaperNote({required this.piece});

  final ScrapPiece piece;

  @override
  Widget build(BuildContext context) {
    final m = piece.memory;
    final r = piece.rect;
    final description = m.description?.trim() ?? '';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: r.width,
          height: r.height,
          decoration: _paper(const Color(0xFFF9D3DE), const Color(0xFFF0BCCB)),
          child: CustomPaint(
            painter: _LinesPainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _hand(22),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _hand(16, color: NotePalette.inkSoft),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          longDate(m.memoryDate),
                          style: _hand(14, color: NotePalette.inkSoft),
                        ),
                      ),
                      Icon(
                        m.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 15,
                        color: NotePalette.deepRose,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -6,
          left: r.width * 0.36,
          child: _Tape(width: r.width * 0.3, tint: piece.seed + 1),
        ),
      ],
    );
  }
}

class _LinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFD98CA3).withValues(alpha: 0.45)
      ..strokeWidth = 0.8;
    for (var y = 40.0; y < size.height - 8; y += 20) {
      canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), line);
    }
    canvas.drawLine(
      const Offset(26, 6),
      Offset(26, size.height - 6),
      Paint()
        ..color = NotePalette.rose.withValues(alpha: 0.35)
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_LinesPainter old) => false;
}

/// A special date: a cream card with the day written large.
class _DateCard extends StatelessWidget {
  const _DateCard({required this.piece});

  final ScrapPiece piece;

  @override
  Widget build(BuildContext context) {
    final m = piece.memory;
    final r = piece.rect;
    final d = m.memoryDate;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: r.width,
          height: r.height,
          decoration: _paper(const Color(0xFFFBE4EA), const Color(0xFFF3C9D5)),
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_shortMonths[d.month - 1]} ${d.day}', style: _hand(34)),
              const SizedBox(height: 2),
              Text(
                m.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _hand(19, color: NotePalette.inkSoft),
              ),
              const Spacer(),
              const Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.celebration_outlined,
                  size: 20,
                  color: NotePalette.deepRose,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -6,
          right: r.width * 0.2,
          child: _Tape(
            width: r.width * 0.34,
            tint: piece.seed + 2,
            turn: -0.08,
          ),
        ),
      ],
    );
  }
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
              child: _Tape(width: 42, turn: -0.5),
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
    // A faint rose wash behind the chapter.
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
    // A dashed loop down one side.
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
    // Two outline hearts in the margins.
    final heart = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = NotePalette.pink.withValues(alpha: 0.35);
    for (var i = 0; i < 2; i++) {
      final hx = i == 0 ? size.width - 30.0 : 14.0 + rnd.nextDouble() * 10;
      final hy = 30 + rnd.nextDouble() * (size.height - 80);
      final s = 12 + rnd.nextDouble() * 8;
      canvas.drawPath(_heart(Rect.fromLTWH(hx, hy, s, s)), heart);
    }
  }

  static Path _heart(Rect r) {
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

  @override
  bool shouldRepaint(_DecorPainter old) => old.seed != seed;
}
