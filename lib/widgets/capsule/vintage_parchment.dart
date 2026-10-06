import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/us_palette.dart';

/// A sheet of aged parchment for Time Capsule letters: warm tan with a
/// mottled tone, small brown age freckles (foxing), fine fibres, slightly
/// rough edges, and darker scorched edges on the left, the bottom and the
/// top-right corner only.
///
/// The texture is decoration: it ignores taps, stays out of the semantics
/// tree, and is painted once per size on its own layer, so selecting text
/// never repaints it. The amount of detail grows with the sheet but is
/// capped, so a very long letter costs about the same as a short one.
class VintageParchment extends StatelessWidget {
  const VintageParchment({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(30, 34, 30, 30),
    this.seed = 11,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Picks the pattern of freckles and patches (fixed per letter).
  final int seed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipPath(
        clipper: _RoughEdge(seed),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _ParchmentPainter(seed)),
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Paper edges that are a little uneven, never straight-cut. Fixed per seed
/// so they don't change between frames.
class _RoughEdge extends CustomClipper<Path> {
  _RoughEdge(this.seed);

  final int seed;

  @override
  Path getClip(Size size) {
    final rnd = math.Random(seed);
    const step = 14.0;
    const depth = 1.8;
    double j() => rnd.nextDouble() * depth;
    final w = size.width, h = size.height;
    final p = Path()..moveTo(j(), j());
    for (var x = step; x < w; x += step) {
      p.lineTo(x, j());
    }
    p.lineTo(w - j(), j());
    for (var y = step; y < h; y += step) {
      p.lineTo(w - j(), y);
    }
    p.lineTo(w - j(), h - j());
    for (var x = w - step; x > 0; x -= step) {
      p.lineTo(x, h - j());
    }
    p.lineTo(j(), h - j());
    for (var y = h - step; y > 0; y -= step) {
      p.lineTo(j(), y);
    }
    return p..close();
  }

  @override
  bool shouldReclip(_RoughEdge old) => old.seed != seed;
}

/// Paints aged parchment into [size] at the canvas origin: tan base,
/// mottling, fibres, foxing and scorched edges (left, bottom, top-right).
/// [edge] scales the scorch widths, for small sheets such as a folded
/// letter or an envelope. Shared by every sheet of capsule paper, so the
/// ceremony and the opened letter are the same paper.
void paintParchment(
  Canvas canvas,
  Size size, {
  int seed = 11,
  double edge = 1,
}) {
  final rect = Offset.zero & size;
  final area = size.width * size.height;
  final rnd = math.Random(seed);

  // Warm tan base, lighter toward the top left.
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          UsPalette.parchmentLight,
          UsPalette.parchment,
          UsPalette.parchmentDeep,
        ],
        stops: [0, 0.55, 1],
      ).createShader(rect),
  );

  // Mottling: soft uneven patches of warmth.
  final patches = (area / 14000).clamp(6, 48).round();
  for (var i = 0; i < patches; i++) {
    final c = Offset(
      rnd.nextDouble() * size.width,
      rnd.nextDouble() * size.height,
    );
    final r = 40 + rnd.nextDouble() * 90;
    final light = rnd.nextDouble() < 0.4;
    final color = light ? UsPalette.parchmentLight : UsPalette.sepiaSoft;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: light ? 0.35 : 0.08),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  // Fibres: short faint strands.
  final fibre = Paint()
    ..color = UsPalette.sepiaSoft.withValues(alpha: 0.08)
    ..strokeWidth = 0.7
    ..strokeCap = StrokeCap.round;
  final fibres = (area / 1600).clamp(40, 420).round();
  for (var i = 0; i < fibres; i++) {
    final o = Offset(
      rnd.nextDouble() * size.width,
      rnd.nextDouble() * size.height,
    );
    final a = rnd.nextDouble() * math.pi;
    final l = 2 + rnd.nextDouble() * 6;
    canvas.drawLine(o, o + Offset(math.cos(a) * l, math.sin(a) * l), fibre);
  }

  // Foxing: small rust-brown age freckles, each a few uneven specks with
  // a faint warm stain around them (never a perfect dot).
  const rust = Color(0xFF8A5528);
  final spots = (area / 15000).clamp(5, 40).round();
  for (var i = 0; i < spots; i++) {
    final c = Offset(
      rnd.nextDouble() * size.width,
      rnd.nextDouble() * size.height,
    );
    final r = 0.6 + rnd.nextDouble() * 1.2;
    canvas.drawCircle(
      c,
      r * (3 + rnd.nextDouble() * 3),
      Paint()
        ..shader = RadialGradient(
          colors: [rust.withValues(alpha: 0.12), rust.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 6)),
    );
    final speck = Paint()..color = rust.withValues(alpha: 0.32);
    for (var k = 0; k < 3; k++) {
      final o = Offset(
        (rnd.nextDouble() - 0.5) * r * 2.2,
        (rnd.nextDouble() - 0.5) * r * 2.2,
      );
      canvas.drawCircle(c + o, r * (0.4 + rnd.nextDouble() * 0.6), speck);
    }
  }

  // Scorched edges on a few sides only: the left, the bottom and the
  // top-right corner. Fixed widths, so long letters age the same way.
  final scorch = UsPalette.sepia;
  final left = Rect.fromLTWH(
    0,
    0,
    math.min(28 * edge, size.width),
    size.height,
  );
  canvas.drawRect(
    left,
    Paint()
      ..shader = LinearGradient(
        colors: [scorch.withValues(alpha: 0.5), scorch.withValues(alpha: 0)],
      ).createShader(left),
  );
  final bottomH = math.min(44.0 * edge, size.height);
  final bottom = Rect.fromLTWH(0, size.height - bottomH, size.width, bottomH);
  canvas.drawRect(
    bottom,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [scorch.withValues(alpha: 0.5), scorch.withValues(alpha: 0)],
      ).createShader(bottom),
  );
  final corner = Offset(size.width, 0);
  final cornerR = 96.0 * edge;
  canvas.drawCircle(
    corner,
    cornerR,
    Paint()
      ..shader = RadialGradient(
        colors: [scorch.withValues(alpha: 0.45), scorch.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: corner, radius: cornerR)),
  );
}

class _ParchmentPainter extends CustomPainter {
  _ParchmentPainter(this.seed);

  final int seed;

  @override
  void paint(Canvas canvas, Size size) =>
      paintParchment(canvas, size, seed: seed);

  @override
  bool shouldRepaint(_ParchmentPainter old) => old.seed != seed;
}
