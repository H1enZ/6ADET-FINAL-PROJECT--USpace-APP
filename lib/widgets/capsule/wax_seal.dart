import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wax colours for Time Capsules: burgundy into plum.
class WaxColors {
  WaxColors._();

  static const burgundy = Color(0xFF7A1F3D);
  static const plum = Color(0xFF4A1A3A);
  static const highlight = Color(0xFFA8466A);
}

/// The Time Capsule wax seal: a pressed burgundy-plum disc with a slightly
/// irregular rim and the USpace heart in the middle. [crack] from 0 (whole)
/// to 1 (split along a jagged line, halves drifting apart).
class WaxSeal extends StatelessWidget {
  const WaxSeal({super.key, this.size = 56, this.crack = 0});

  final double size;
  final double crack;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _WaxPainter(crack: crack)),
    );
  }
}

class _WaxPainter extends CustomPainter {
  _WaxPainter({required this.crack});

  final double crack;

  static Path _rim(Offset c, double r) {
    // A soft, uneven edge, like wax pressed by hand (fixed, not random).
    const bumps = [
      0.0,
      0.05,
      -0.02,
      0.04,
      0.01,
      -0.03,
      0.05,
      0.0,
      0.03,
      -0.02,
      0.04,
      0.02,
    ];
    final path = Path();
    const steps = 72;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * 2 * math.pi;
      final t = a / (2 * math.pi) * bumps.length;
      final k = t.floor() % bumps.length;
      final f = t - t.floor();
      final b = bumps[k] * (1 - f) + bumps[(k + 1) % bumps.length] * f;
      final p = c + Offset(math.cos(a), math.sin(a)) * r * (1 + b);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  static Path _heart(Offset c, double s) {
    return Path()
      ..moveTo(c.dx, c.dy + s * 0.55)
      ..cubicTo(
        c.dx - s * 1.1,
        c.dy - s * 0.15,
        c.dx - s * 0.55,
        c.dy - s * 0.95,
        c.dx,
        c.dy - s * 0.38,
      )
      ..cubicTo(
        c.dx + s * 0.55,
        c.dy - s * 0.95,
        c.dx + s * 1.1,
        c.dy - s * 0.15,
        c.dx,
        c.dy + s * 0.55,
      )
      ..close();
  }

  void _paintSeal(Canvas canvas, Offset c, double r) {
    final rim = _rim(c, r);
    canvas.drawShadow(rim, Colors.black, r * 0.12, true);
    canvas.drawPath(
      rim,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.0,
          colors: const [
            WaxColors.highlight,
            WaxColors.burgundy,
            WaxColors.plum,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // The pressed inner ring.
    canvas.drawCircle(
      c,
      r * 0.7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      c.translate(-r * 0.02, -r * 0.02),
      r * 0.7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = Colors.white.withValues(alpha: 0.18),
    );
    // Embossed heart: a dark press with a light edge.
    final heart = _heart(c.translate(0, r * 0.04), r * 0.42);
    canvas.drawPath(
      heart,
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
    canvas.drawPath(
      heart.shift(Offset(-r * 0.025, -r * 0.03)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04
        ..color = Colors.white.withValues(alpha: 0.28),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * 0.9;
    if (crack <= 0) {
      _paintSeal(canvas, c, r);
      return;
    }
    // The crack: a jagged line top to bottom; each half drifts and tilts.
    final crackLine = <Offset>[
      Offset(c.dx - r * 0.05, c.dy - r * 1.2),
      Offset(c.dx + r * 0.12, c.dy - r * 0.45),
      Offset(c.dx - r * 0.1, c.dy + r * 0.05),
      Offset(c.dx + r * 0.08, c.dy + r * 0.5),
      Offset(c.dx - r * 0.02, c.dy + r * 1.2),
    ];
    Path half(bool left) {
      final p = Path()..moveTo(crackLine.first.dx, crackLine.first.dy);
      for (final o in crackLine.skip(1)) {
        p.lineTo(o.dx, o.dy);
      }
      final x = left ? c.dx - r * 1.3 : c.dx + r * 1.3;
      p
        ..lineTo(x, c.dy + r * 1.2)
        ..lineTo(x, c.dy - r * 1.2)
        ..close();
      return p;
    }

    final apart = crack.clamp(0.0, 1.0) * r * 0.22;
    for (final left in [true, false]) {
      canvas.save();
      canvas.translate(left ? -apart : apart, apart * 0.3);
      canvas.translate(c.dx, c.dy);
      canvas.rotate((left ? -1 : 1) * crack * 0.12);
      canvas.translate(-c.dx, -c.dy);
      canvas.clipPath(half(left));
      _paintSeal(canvas, c, r);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _WaxPainter old) => old.crack != crack;
}
