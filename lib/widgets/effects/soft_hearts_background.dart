import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';

/// A heart-shaped path filling [r]. Shared by the decorative backgrounds and
/// the mood particles, so every heart in the app has the same silhouette.
Path heartPath(Rect r) {
  final w = r.width, h = r.height, x = r.left, y = r.top;
  return Path()
    ..moveTo(x + w / 2, y + h * 0.92)
    ..cubicTo(
      x - w * 0.10,
      y + h * 0.52,
      x + w * 0.06,
      y - h * 0.06,
      x + w / 2,
      y + h * 0.24,
    )
    ..cubicTo(
      x + w * 0.94,
      y - h * 0.06,
      x + w * 1.10,
      y + h * 0.52,
      x + w / 2,
      y + h * 0.92,
    )
    ..close();
}

/// A soft wash with a few faint hearts, for Splash and Login/Signup.
/// The hearts drift very slowly; with reduce-motion on they stay still.
/// Decorative only: hidden from screen readers.
class SoftHeartsBackground extends StatefulWidget {
  const SoftHeartsBackground({
    super.key,
    required this.gradient,
    this.heartColor,
    this.child,
  });

  final Gradient gradient;

  /// Defaults to the theme's rose at very low opacity.
  final Color? heartColor;
  final Widget? child;

  @override
  State<SoftHeartsBackground> createState() => _SoftHeartsBackgroundState();
}

class _SoftHeartsBackgroundState extends State<SoftHeartsBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionOff(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.heartColor ??
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: widget.gradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: RepaintBoundary(
              // The painter repaints from the animation directly, so the
              // widget tree is not rebuilt on every frame.
              child: CustomPaint(
                painter: _HeartsPainter(color: color, drift: _drift),
              ),
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _HeartsPainter extends CustomPainter {
  _HeartsPainter({required this.color, required this.drift})
    : super(repaint: drift);

  final Color color;
  final Animation<double> drift; // 0..1, loops

  // Fixed layout (fractions of the canvas) so the composition is calm and
  // the same on every run: few hearts, mostly near the edges.
  static const _hearts = [
    (0.08, 0.10, 46.0, -0.25),
    (0.86, 0.07, 30.0, 0.20),
    (0.92, 0.38, 54.0, 0.30),
    (0.04, 0.55, 34.0, -0.15),
    (0.16, 0.88, 58.0, 0.18),
    (0.80, 0.84, 40.0, -0.28),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = drift.value;
    final paint = Paint()..color = color;
    for (var i = 0; i < _hearts.length; i++) {
      final (fx, fy, s, tilt) = _hearts[i];
      // A slow bob of a few pixels, each heart out of phase.
      final bob = math.sin((t + i / _hearts.length) * 2 * math.pi) * 6;
      final c = Offset(fx * size.width, fy * size.height + bob);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(tilt);
      canvas.drawPath(
        heartPath(Rect.fromCenter(center: Offset.zero, width: s, height: s)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HeartsPainter old) =>
      old.color != color || old.drift != drift;
}
