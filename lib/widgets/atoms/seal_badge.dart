import 'dart:math' as math;

import 'package:flutter/material.dart';

enum SealState { sealed, broken }

/// The wax seal: the app's signature mark. Used on Splash now, and on
/// Time Capsules later (sealed until the unlock date, broken after).
/// Sizes from the design system: 22, 30, 46, plus larger on Splash.
class SealBadge extends StatelessWidget {
  const SealBadge({
    super.key,
    this.size = 46,
    this.state = SealState.sealed,
    this.color,
    this.letter = 'S',
  });

  final double size;
  final SealState state;
  final Color? color;
  final String letter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SealPainter(
          color: color ?? scheme.primary,
          ringColor: scheme.onPrimary,
          broken: state == SealState.broken,
        ),
        child: Center(
          child: Text(
            letter,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: size * 0.34,
              height: 1,
              color: scheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter({
    required this.color,
    required this.ringColor,
    required this.broken,
  });

  final Color color;
  final Color ringColor;
  final bool broken;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final inner = outer * 0.86;
    const points = 16;

    // Scalloped edge: alternate between the outer and inner radius.
    final edge = Path();
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = -math.pi / 2 + i * math.pi / points;
      final p = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        edge.moveTo(p.dx, p.dy);
      } else {
        edge.lineTo(p.dx, p.dy);
      }
    }
    edge.close();

    final bounds = Rect.fromCircle(center: center, radius: outer);
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, 0.18)!, color],
      ).createShader(bounds);
    canvas.drawPath(edge, fill);

    // The pressed ring inside the wax.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, outer * 0.07)
      ..color = ringColor.withValues(alpha: 0.9);
    canvas.drawCircle(center, outer * 0.62, ring);

    if (broken) {
      final crack = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, outer * 0.08)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = ringColor;
      final line = Path()
        ..moveTo(center.dx - outer * 0.10, center.dy - outer * 0.95)
        ..lineTo(center.dx + outer * 0.12, center.dy - outer * 0.30)
        ..lineTo(center.dx - outer * 0.10, center.dy + outer * 0.20)
        ..lineTo(center.dx + outer * 0.08, center.dy + outer * 0.95);
      canvas.drawPath(line, crack);
    }
  }

  @override
  bool shouldRepaint(covariant _SealPainter old) =>
      old.color != color || old.ringColor != ringColor || old.broken != broken;
}
