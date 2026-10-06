import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Old oxblood sealing wax.
abstract final class OldWax {
  static const light = Color(0xFFC9483E);
  static const face = Color(0xFFA42B25);
  static const deep = Color(0xFF7A1A17);
  static const dark = Color(0xFF4A0E0C);
  static const lift = Color(0xFFF0907F);
}

/// "A" for "Ana": the first letter of the sender's name, for the seal.
String sealInitial(String name) {
  final t = name.trim();
  if (t.isEmpty) return '♥';
  return t.characters.first.toUpperCase();
}

/// A vintage wax seal with a monogram: oxblood wax with a soft, uneven
/// five-lobed rim and small runs, a mottled worn surface, a raised ring,
/// and the sender's initial embossed in a serif between two leafy sprigs.
///
/// [emboss] 0..1 fades in the stamped ring, letter and sprigs; [glow] warms
/// it before it opens; [crack] 0..1 runs a seam of light through it.
class MonogramSeal extends StatelessWidget {
  const MonogramSeal({
    super.key,
    required this.initial,
    this.size = 64,
    this.emboss = 1,
    this.glow = 0,
    this.crack = 0,
  });

  final String initial;
  final double size;
  final double emboss;
  final double glow;
  final double crack;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _MonogramPainter(
        initial: initial,
        emboss: emboss.clamp(0.0, 1.0),
        glow: glow.clamp(0.0, 1.0),
        crack: crack.clamp(0.0, 1.0),
      ),
    ),
  );
}

class _MonogramPainter extends CustomPainter {
  _MonogramPainter({
    required this.initial,
    required this.emboss,
    required this.glow,
    required this.crack,
  });

  final String initial;
  final double emboss;
  final double glow;
  final double crack;

  /// The rim: five soft lobes plus a little unevenness (fixed shape).
  static Path _rim(Offset c, double r) {
    final p = Path();
    const steps = 120;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * 2 * math.pi - math.pi / 2;
      final k =
          1 +
          0.055 * math.cos(5 * (t + math.pi / 2)) +
          0.022 * math.sin(3 * t + 0.7) +
          0.014 * math.cos(7 * t + 1.3);
      final o = c + Offset(math.cos(t), math.sin(t)) * r * k;
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  /// One leafy sprig (left side), in a 40 x 60 box, mirrored for the right.
  static Path _sprig() {
    final p = Path()
      ..moveTo(30, 56)
      ..cubicTo(18, 46, 14, 34, 18, 20)
      ..cubicTo(20, 12, 26, 6, 32, 4);
    return p;
  }

  static List<Path> _leaves() => [
    Path()
      ..moveTo(19, 30)
      ..cubicTo(10, 28, 6, 22, 8, 16)
      ..cubicTo(14, 18, 18, 22, 19, 30)
      ..close(),
    Path()
      ..moveTo(22, 18)
      ..cubicTo(16, 12, 16, 6, 20, 2)
      ..cubicTo(24, 6, 24, 12, 22, 18)
      ..close(),
    Path()
      ..moveTo(18, 42)
      ..cubicTo(8, 42, 4, 36, 4, 30)
      ..cubicTo(10, 32, 15, 36, 18, 42)
      ..close(),
    Path()
      ..moveTo(24, 50)
      ..cubicTo(26, 42, 32, 38, 36, 40)
      ..cubicTo(34, 46, 30, 50, 24, 50)
      ..close(),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final r = s * 0.44;
    final rim = _rim(c, r);

    // Shadow under the wax, and a few runs where it spilled past the rim.
    canvas.drawShadow(rim, Colors.black, s * 0.05, true);
    final run = Paint()..color = OldWax.deep;
    for (final (a, len, w) in const [
      (0.6, 0.12, 0.07),
      (2.4, 0.09, 0.06),
      (4.3, 0.1, 0.055),
    ]) {
      final o = c + Offset(math.cos(a), math.sin(a)) * r * 0.98;
      canvas.drawOval(
        Rect.fromCenter(
          center: o + Offset(math.cos(a), math.sin(a)) * s * len * 0.4,
          width: s * w * 1.4,
          height: s * len,
        ),
        run,
      );
    }

    // The wax body: oxblood, lit from the top left.
    canvas.drawPath(
      rim,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.42),
          radius: 1.05,
          colors: [
            Color.lerp(OldWax.light, const Color(0xFFFFB27A), glow * 0.5)!,
            OldWax.face,
            OldWax.deep,
            OldWax.dark,
          ],
          stops: const [0, 0.38, 0.78, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.1)),
    );
    // Rim lip: a dark line around the outside, light along the top left.
    canvas.drawPath(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012
        ..color = OldWax.dark.withValues(alpha: 0.55),
    );
    canvas.save();
    canvas.clipPath(rim);

    // Mottling and wear: darker streaks and pale specks, fixed per seal.
    final rnd = math.Random(initial.codeUnitAt(0));
    for (var i = 0; i < 26; i++) {
      final o =
          c +
          Offset(
            (rnd.nextDouble() - 0.5) * r * 1.8,
            (rnd.nextDouble() - 0.5) * r * 1.8,
          );
      final dark = rnd.nextBool();
      canvas.drawCircle(
        o,
        s * (0.006 + rnd.nextDouble() * 0.014),
        Paint()
          ..color = (dark ? OldWax.dark : OldWax.lift).withValues(
            alpha: dark ? 0.22 : 0.18,
          ),
      );
    }
    for (var i = 0; i < 3; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * (0.8 + rnd.nextDouble() * 0.15)),
        a,
        0.5 + rnd.nextDouble() * 0.6,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.01
          ..color = OldWax.dark.withValues(alpha: 0.25),
      );
    }

    final e = emboss;
    if (e > 0) {
      // Raised ring: shadow below right, light above left, then the face.
      final ringR = r * 0.74;
      void ring(Offset at, Color color, double width) => canvas.drawCircle(
        at,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color,
      );
      ring(
        c + Offset(s * 0.012, s * 0.014),
        OldWax.dark.withValues(alpha: 0.7 * e),
        s * 0.05,
      );
      ring(
        c - Offset(s * 0.008, s * 0.009),
        OldWax.lift.withValues(alpha: 0.55 * e),
        s * 0.03,
      );
      ring(c, OldWax.face.withValues(alpha: e), s * 0.03);

      // The recessed disc inside the ring.
      final inner = r * 0.66;
      canvas.drawCircle(
        c,
        inner,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.3, 0.35),
            colors: [
              OldWax.face.withValues(alpha: e),
              OldWax.deep.withValues(alpha: e),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: inner)),
      );
      // Pressed in: shade on the top-left inner edge, light on the bottom right.
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: inner - s * 0.01),
        math.pi * 0.9,
        math.pi * 0.9,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.02
          ..color = OldWax.dark.withValues(alpha: 0.45 * e),
      );
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: inner - s * 0.01),
        -math.pi * 0.1,
        math.pi * 0.9,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.014
          ..color = OldWax.lift.withValues(alpha: 0.3 * e),
      );

      // Sprigs on both sides of the letter, embossed the same way.
      void sprigs(Offset shift, Color color) {
        for (final mirror in [false, true]) {
          canvas.save();
          final box = Rect.fromLTWH(
            c.dx - r * 0.62,
            c.dy - r * 0.42,
            r * 0.34,
            r * 0.6,
          );
          if (mirror) {
            canvas.translate(c.dx * 2, 0);
            canvas.scale(-1, 1);
          }
          canvas.translate(box.left + shift.dx, box.top + shift.dy);
          canvas.scale(box.width / 40, box.height / 60);
          final stroke = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = color;
          canvas.drawPath(_sprig(), stroke);
          final fill = Paint()..color = color;
          for (final leaf in _leaves()) {
            canvas.drawPath(leaf, fill);
          }
          canvas.restore();
        }
      }

      sprigs(
        Offset(s * 0.01, s * 0.012),
        OldWax.dark.withValues(alpha: 0.7 * e),
      );
      sprigs(
        Offset(-s * 0.006, -s * 0.007),
        OldWax.lift.withValues(alpha: 0.6 * e),
      );
      sprigs(Offset.zero, OldWax.light.withValues(alpha: 0.85 * e));

      // The initial, in a serif, embossed.
      void letter(Offset shift, Color color) {
        final tp = TextPainter(
          text: TextSpan(
            text: initial,
            style: GoogleFonts.playfairDisplay(
              fontSize: r * 0.92,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          c - Offset(tp.width / 2, tp.height / 2) + shift + Offset(0, r * 0.02),
        );
        tp.dispose();
      }

      letter(
        Offset(s * 0.012, s * 0.014),
        OldWax.dark.withValues(alpha: 0.75 * e),
      );
      letter(
        Offset(-s * 0.008, -s * 0.009),
        OldWax.lift.withValues(alpha: 0.7 * e),
      );
      letter(Offset.zero, OldWax.face.withValues(alpha: e));
    }

    // Warm light from inside before it opens.
    if (glow > 0) {
      canvas.drawCircle(
        c,
        r * 1.1,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFC27A).withValues(alpha: 0.35 * glow),
              const Color(0xFFFFC27A).withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.1)),
      );
    }
    canvas.restore();

    // Gloss: a soft highlight and two tiny glints.
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-r * 0.42, -r * 0.55),
        width: r * 0.62,
        height: r * 0.24,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.26)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06),
    );
    canvas.drawCircle(
      c + Offset(-r * 0.62, -r * 0.2),
      s * 0.01,
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );

    // A seam of light, growing down through the seal.
    if (crack > 0) {
      final crackPath = Path()
        ..moveTo(c.dx - r * 0.08, c.dy - r * 1.02)
        ..lineTo(c.dx + r * 0.1, c.dy - r * 0.55)
        ..lineTo(c.dx - r * 0.12, c.dy - r * 0.1)
        ..lineTo(c.dx + r * 0.12, c.dy + r * 0.35)
        ..lineTo(c.dx - r * 0.04, c.dy + r * 1.02);
      final metric = crackPath.computeMetrics().first;
      final part = metric.extractPath(0, metric.length * crack);
      canvas.drawPath(
        part,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.06
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFFFD9A0).withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03),
      );
      canvas.drawPath(
        part,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.018
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFFFF4DE),
      );
    }
  }

  @override
  bool shouldRepaint(_MonogramPainter old) =>
      old.initial != initial ||
      old.emboss != emboss ||
      old.glow != glow ||
      old.crack != crack;
}
