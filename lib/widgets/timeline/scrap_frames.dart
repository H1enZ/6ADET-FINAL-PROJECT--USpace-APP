import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/memory.dart';
import '../../models/scrapbook.dart';
import '../../utils/anniversary.dart';
import '../notes/note_style.dart';
import 'scrapbook_layout.dart';
import '../atoms/us_icon.dart';

const _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Handwriting for captions and notes.
TextStyle scrapHand(double size, {Color color = NotePalette.ink}) =>
    GoogleFonts.caveat(
      fontSize: size,
      height: 1.1,
      color: color,
      fontWeight: FontWeight.w600,
    );

/// One memory drawn in one of the scrapbook frames, filling [size] exactly
/// (the height comes from [ScrapbookLayout.frameHeight]). Used on the
/// canvas and, small, as the frame picker's previews.
class ScrapFrame extends StatelessWidget {
  const ScrapFrame({
    super.key,
    required this.memory,
    required this.frame,
    required this.size,
    required this.seed,
    this.decodeWidth,
  });

  final Memory memory;
  final FrameStyle frame;
  final Size size;
  final int seed;

  /// Device pixels to decode the photo at (never the full original).
  final int? decodeWidth;

  @override
  Widget build(BuildContext context) {
    final w = size.width;
    // Text grows a little with the frame, within readable limits.
    final f = (w / 175).clamp(0.8, 1.5);
    final child = switch (frame) {
      FrameStyle.polaroid => _Polaroid(this, f),
      FrameStyle.taped => _Taped(this, f),
      FrameStyle.film => _Film(this, f),
      FrameStyle.postcard => _Postcard(this, f),
      FrameStyle.minimal => _Minimal(this, f),
      FrameStyle.paper => _Paper(this, f),
      FrameStyle.loveNote => _LoveNote(this, f),
      FrameStyle.ticket => _Ticket(this, f),
      FrameStyle.sticky => _Sticky(this, f),
    };
    return SizedBox.fromSize(size: size, child: child);
  }
}

// ------------------------------------------------------------- shared bits

class ScrapTape extends StatelessWidget {
  const ScrapTape({
    super.key,
    required this.width,
    this.turn = 0.05,
    this.tint = 0,
  });

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

BoxDecoration _paper(Color top, Color bottom, {double radius = 2.5}) =>
    BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [top, bottom],
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );

class _Photo extends StatelessWidget {
  const _Photo(this.frame);

  final ScrapFrame frame;

  @override
  Widget build(BuildContext context) {
    final url = frame.memory.photoUrl;
    if (url == null) return const _NoPhoto();
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: frame.decodeWidth,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const _NoPhoto(),
    );
  }
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF4A1D42),
    alignment: Alignment.center,
    child: const UsIcon(UsIcons.image, color: NotePalette.pink),
  );
}

Widget _favourite(Memory m, double size, Color color) => Icon(
  m.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
  size: size,
  color: color,
);

Widget _title(Memory m, TextStyle style, {int lines = 1}) => Text(
  m.title,
  maxLines: lines,
  overflow: TextOverflow.ellipsis,
  style: style,
);

// ------------------------------------------------------------- 1 polaroid

class _Polaroid extends StatelessWidget {
  const _Polaroid(this.p, this.f);

  final ScrapFrame p;
  final double f;

  @override
  Widget build(BuildContext context) {
    final m = p.memory;
    final w = p.size.width;
    final border = w * 0.06;
    final big = w >= 240;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: w,
          height: p.size.height,
          padding: EdgeInsets.fromLTRB(border, border, border, 0),
          decoration: _paper(const Color(0xFFFFF4EE), const Color(0xFFF1DCD9)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Photo(p)),
              SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: _title(m, scrapHand(big ? 24 : 19))),
                          const SizedBox(width: 4),
                          _favourite(m, big ? 16 : 13, NotePalette.rose),
                        ],
                      ),
                      Text(
                        longDate(m.memoryDate),
                        maxLines: 1,
                        style: scrapHand(
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
          top: -w * 0.05,
          left: w * (0.3 + (p.seed % 3) * 0.08),
          child: ScrapTape(
            width: w * 0.32,
            tint: p.seed,
            turn: (p.seed % 5 - 2) * 0.03,
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

// ------------------------------------------------------------- 2 taped

class _Taped extends StatelessWidget {
  const _Taped(this.p, this.f);

  final ScrapFrame p;
  final double f;

  @override
  Widget build(BuildContext context) {
    final m = p.memory;
    final w = p.size.width;
    final b = w * 0.035;
    final photoH = (w - b * 2) / ScrapbookLayout.photoAspectFor(w);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: photoH + b * 2,
              padding: EdgeInsets.all(b),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF7),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: _Photo(p),
            ),
            // A small torn label under the photo.
            Align(
              alignment: p.seed.isEven
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Transform.rotate(
                angle: (p.seed % 3 - 1) * 0.03,
                child: Container(
                  height: 26,
                  constraints: BoxConstraints(maxWidth: w * 0.86),
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: _paper(
                    const Color(0xFFF6E3D6),
                    const Color(0xFFEACDBE),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: _title(m, scrapHand(15 * f.clamp(0.9, 1.2))),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_shortMonths[m.memoryDate.month - 1]} ${m.memoryDate.day}',
                        style: scrapHand(13, color: NotePalette.inkSoft),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: -w * 0.04,
          left: -w * 0.05,
          child: ScrapTape(width: w * 0.3, tint: p.seed, turn: -0.6),
        ),
        Positioned(
          top: -w * 0.04,
          right: -w * 0.05,
          child: ScrapTape(width: w * 0.3, tint: p.seed + 1, turn: 0.6),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- 3 film

class _Film extends StatelessWidget {
  const _Film(this.p, this.f);

  final ScrapFrame p;
  final double f;

  @override
  Widget build(BuildContext context) {
    final m = p.memory;
    final w = p.size.width;
    final band = math.max(14.0, w * 0.075);
    final side = w * 0.05;
    return Container(
      width: w,
      height: p.size.height,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1418),
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: band,
            child: CustomPaint(painter: _Sprockets(), size: Size(w, band)),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: side),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: _Photo(p),
              ),
            ),
          ),
          SizedBox(
            height: band,
            child: CustomPaint(painter: _Sprockets(), size: Size(w, band)),
          ),
          SizedBox(
            height: 36,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: side + 2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _title(
                          m,
                          scrapHand(
                            16 * f.clamp(0.9, 1.3),
                            color: NotePalette.cream,
                          ),
                        ),
                        Text(
                          longDate(m.memoryDate).toUpperCase(),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 8.5,
                            letterSpacing: 1.6,
                            color: const Color(
                              0xFFE7B36A,
                            ).withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _favourite(m, 12, NotePalette.pink),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sprockets extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final hole = Paint()
      ..color = const Color(0xFFEDE0D6).withValues(alpha: 0.85);
    final h = size.height * 0.42;
    final w = h * 1.3;
    for (var x = w * 0.6; x < size.width - w * 0.5; x += w * 2.1) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, w, h),
          Radius.circular(h * 0.25),
        ),
        hole,
      );
    }
  }

  @override
  bool shouldRepaint(_Sprockets old) => false;
}

// ------------------------------------------------------------- 4 postcard

class _Postcard extends StatelessWidget {
  const _Postcard(this.p, this.f);

  final ScrapFrame p;
  final double f;

  @override
  Widget build(BuildContext context) {
    final m = p.memory;
    final w = p.size.width;
    final hasPhoto = m.photos.isNotEmpty;
    final stamp = Container(
      width: 30 * f.clamp(0.8, 1.3),
      height: 36 * f.clamp(0.8, 1.3),
      decoration: BoxDecoration(
        color: const Color(0xFFF6D3DE),
        border: Border.all(
          color: NotePalette.deepRose.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: const Icon(
        Icons.favorite_rounded,
        size: 14,
        color: NotePalette.deepRose,
      ),
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(alignment: Alignment.topRight, child: stamp),
        const SizedBox(height: 4),
        _title(m, scrapHand(17 * f.clamp(0.85, 1.4)), lines: 2),
        const Spacer(),
        for (var i = 0; i < 2; i++)
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 7),
            color: NotePalette.inkSoft.withValues(alpha: 0.25),
          ),
        Text(
          longDate(m.memoryDate),
          maxLines: 1,
          style: scrapHand(13, color: NotePalette.inkSoft),
        ),
      ],
    );
    return Container(
      width: w,
      height: p.size.height,
      padding: const EdgeInsets.all(7),
      decoration: _paper(
        const Color(0xFFFFF6EC),
        const Color(0xFFF1E0CF),
        radius: 3,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: NotePalette.rose.withValues(alpha: 0.35)),
        ),
        padding: const EdgeInsets.all(6),
        child: hasPhoto
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 11, child: _Photo(p)),
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    color: NotePalette.inkSoft.withValues(alpha: 0.25),
                  ),
                  Expanded(flex: 8, child: words),
                ],
              )
            : words,
      ),
    );
  }
}

// ------------------------------------------------------------- 5 minimal

class _Minimal extends StatelessWidget {
  const _Minimal(this.p, this.f);

  final ScrapFrame p;
  final double f;

  @override
  Widget build(BuildContext context) {
    final m = p.memory;
    final caption = [
      _title(
        m,
        TextStyle(
          fontSize: 13 * f.clamp(0.9, 1.3),
          fontWeight: FontWeight.w600,
          color: NotePalette.cream,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        longDate(m.memoryDate),
        maxLines: 1,
        style: TextStyle(
          fontSize: 11,
          color: NotePalette.muted.withValues(alpha: 0.9),
        ),
      ),
    ];
    if (m.photos.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _Photo(p),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...caption,
        ],
      );
    }
    final story = m.description?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1426),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NotePalette.pink.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(m, NotePalette.display(16 * f.clamp(0.9, 1.3)), lines: 2),
          if (story.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              story,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: NotePalette.muted,
                height: 1.3,
              ),
            ),
          ],
          const Spacer(),
          Text(
            longDate(m.memoryDate),
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              color: NotePalette.muted.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- 6 paper scrap

class _Paper extends StatelessWidget {
  const _Paper(this.p, this.f);

  final ScrapFrame p;
  final double f;

  @override
  Widget build(BuildContext context) {
    final m = p.memory;
    final w = p.size.width;
    final story = m.description?.trim() ?? '';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: w,
          height: p.size.height,
          decoration: _paper(const Color(0xFFF9D3DE), const Color(0xFFF0BCCB)),
          child: CustomPaint(
            painter: _LinesPainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(m, scrapHand(22 * f.clamp(0.85, 1.3)), lines: 2),
                  if (story.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      story,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: scrapHand(16, color: NotePalette.inkSoft),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          longDate(m.memoryDate),
                          maxLines: 1,
                          style: scrapHand(14, color: NotePalette.inkSoft),
                        ),
                      ),
                      _favourite(m, 15, NotePalette.deepRose),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -6,
          left: w * 0.36,
          child: ScrapTape(width: w * 0.3, tint: p.seed + 1),
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

// ------------------------------------------------------------- 7 love note

class _LoveNote extends StatelessWidget {
  const _LoveNote(this.p, this.f);

  final ScrapFrame p;
  final double f;

  @override
  Widget build(BuildContext context) {
    final m = p.memory;
    final story = m.description?.trim() ?? '';
    return Container(
      width: p.size.width,
      height: p.size.height,
      decoration: _paper(
        const Color(0xFFF9CFDB),
        const Color(0xFFEFA9BF),
        radius: 6,
      ),
      child: Stack(
        children: [
          // The envelope's flap, as two soft lines meeting in the middle.
          Positioned.fill(child: CustomPaint(painter: _FlapLines())),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NotePalette.deepRose,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 13,
                    color: Color(0xFFFCE4EC),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  m.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: scrapHand(20 * f.clamp(0.85, 1.3)),
                ),
                if (story.isNotEmpty)
                  Text(
                    story,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: scrapHand(15, color: NotePalette.inkSoft),
                  ),
                const Spacer(),
                Text(
                  longDate(m.memoryDate),
                  maxLines: 1,
                  style: scrapHand(13.5, color: NotePalette.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlapLines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.45);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height * 0.32)
        ..lineTo(size.width, 0),
      p,
    );
  }

  @override
  bool shouldRepaint(_FlapLines old) => false;
}

// ------------------------------------------------------------- 9 sticky

/// The note colours, shared with sticky-note decorations.
const stickyColors = [
  Color(0xFFF9D3DE), // pink
  Color(0xFFFCEFA8), // butter yellow
  Color(0xFFDCCFF5), // lavender
  Color(0xFFCFEFDD), // mint
  Color(0xFFFAD9C1), // peach
];

/// A square sticky note, handwritten, with no date: the look of a memory
/// without a photo.
class _Sticky extends StatelessWidget {
  const _Sticky(this.p, this.f);

  final ScrapFrame p;
  final double f;

  @override
  Widget build(BuildContext context) {
    final m = p.memory;
    final story = m.description?.trim() ?? '';
    return StickyPaper(
      color: stickyColors[p.seed % stickyColors.length],
      size: p.size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.title,
            maxLines: story.isEmpty ? 4 : 2,
            overflow: TextOverflow.ellipsis,
            style: scrapHand(22 * f.clamp(0.85, 1.35)),
          ),
          if (story.isNotEmpty) ...[
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                story,
                overflow: TextOverflow.fade,
                style: scrapHand(
                  16 * f.clamp(0.9, 1.25),
                  color: NotePalette.inkSoft,
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (m.isFavorite)
            const Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                Icons.favorite_rounded,
                size: 14,
                color: NotePalette.deepRose,
              ),
            ),
        ],
      ),
    );
  }
}

/// The paper of a sticky note: a soft colour, a slightly darker glue strip
/// at the top and a lifted bottom corner.
class StickyPaper extends StatelessWidget {
  const StickyPaper({
    super.key,
    required this.color,
    required this.size,
    required this.child,
  });

  final Color color;
  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glue = Color.lerp(color, Colors.black, 0.06)!;
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [glue, color, color, Color.lerp(color, Colors.white, 0.18)!],
          stops: const [0, 0.14, 0.7, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(2, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          // The lifted corner.
          Positioned(
            right: 0,
            bottom: 0,
            child: CustomPaint(
              size: Size.square(math.min(26, size.width * 0.16)),
              painter: _CornerCurl(color),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, size.height * 0.16, 12, 10),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _CornerCurl extends CustomPainter {
  _CornerCurl(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final fold = Path()
      ..moveTo(w, 0)
      ..lineTo(0, w)
      ..lineTo(w * 0.15, w * 0.15)
      ..close();
    canvas.drawPath(
      Path()
        ..moveTo(w, 0)
        ..lineTo(w, w)
        ..lineTo(0, w)
        ..close(),
      Paint()..color = const Color(0xFF1C0F1A),
    );
    canvas.drawPath(
      fold,
      Paint()..color = Color.lerp(color, Colors.black, 0.12)!,
    );
  }

  @override
  bool shouldRepaint(_CornerCurl old) => old.color != color;
}

// ------------------------------------------------------------- 8 ticket

class _Ticket extends StatelessWidget {
  const _Ticket(this.p, this.f);

  final ScrapFrame p;
  final double f;

  @override
  Widget build(BuildContext context) {
    final m = p.memory;
    final d = m.memoryDate;
    final w = p.size.width;
    final stub = w * 0.3;
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipPath(
        clipper: _TicketClip(stub),
        child: Container(
          width: w,
          height: p.size.height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFBE4EA), Color(0xFFF3C9D5)],
            ),
          ),
          child: CustomPaint(
            painter: _Perforation(stub),
            child: Row(
              children: [
                SizedBox(
                  width: stub,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${d.day}',
                        style: scrapHand(30 * f.clamp(0.8, 1.3)),
                      ),
                      Text(
                        _shortMonths[d.month - 1].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                          color: NotePalette.deepRose,
                        ),
                      ),
                      Text(
                        '${d.year}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: NotePalette.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ADMIT TWO',
                          style: TextStyle(
                            fontSize: 8.5,
                            letterSpacing: 2.2,
                            fontWeight: FontWeight.w700,
                            color: NotePalette.deepRose,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _title(m, scrapHand(19 * f.clamp(0.85, 1.3)), lines: 2),
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: _favourite(m, 15, NotePalette.deepRose),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded notches top and bottom where the stub tears off.
class _TicketClip extends CustomClipper<Path> {
  _TicketClip(this.stub);

  final double stub;

  @override
  Path getClip(Size size) {
    const r = 7.0;
    final card = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5)),
      );
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(stub, 0), radius: r))
      ..addOval(Rect.fromCircle(center: Offset(stub, size.height), radius: r));
    return Path.combine(PathOperation.difference, card, notches);
  }

  @override
  bool shouldReclip(_TicketClip old) => old.stub != stub;
}

class _Perforation extends CustomPainter {
  _Perforation(this.stub);

  final double stub;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = NotePalette.deepRose.withValues(alpha: 0.45)
      ..strokeWidth = 1.2;
    for (var y = 10.0; y < size.height - 10; y += 7) {
      canvas.drawLine(Offset(stub, y), Offset(stub, y + 3.5), p);
    }
  }

  @override
  bool shouldRepaint(_Perforation old) => old.stub != stub;
}
