import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/mood_visual.dart';
import '../effects/motion.dart';
import '../effects/soft_hearts_background.dart';

/// The small things floating around the hero's illustration: hearts, a warm
/// glow, sparkles, kisses or soft drifting dots. Slow and faint by design.
/// With reduce-motion on they are drawn once, still. Decorative only.
class MoodParticlesLayer extends StatefulWidget {
  const MoodParticlesLayer({
    super.key,
    required this.style,
    required this.color,
  });

  final MoodParticles style;
  final Color color;

  @override
  State<MoodParticlesLayer> createState() => _MoodParticlesLayerState();
}

class _MoodParticlesLayerState extends State<MoodParticlesLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..addListener(_onTick);

  // The painter listens to this, not the controller: it is updated every
  // second tick, so these slow particles repaint at about 30 fps instead of
  // every frame (each repaint re-composites the hero).
  final _frame = ValueNotifier<double>(0.3);
  int _ticks = 0;

  void _onTick() {
    if ((_ticks++).isEven) _frame.value = _t.value;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionOff(context)) {
      _t.stop();
      _frame.value = 0.3; // a pleasant still frame
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.style == MoodParticles.none) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _ParticlesPainter(widget.style, widget.color, _frame),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  _ParticlesPainter(this.style, this.color, this.t) : super(repaint: t);

  final MoodParticles style;
  final Color color;
  final ValueListenable<double> t;

  // Built once: a unit heart and a unit sparkle, drawn scaled and moved.
  static final Path _unitHeart = heartPath(
    const Rect.fromLTWH(-0.5, -0.5, 1, 1),
  );
  static final Path _unitSparkle = Path()
    ..moveTo(0, -1)
    ..quadraticBezierTo(0, 0, 1, 0)
    ..quadraticBezierTo(0, 0, 0, 1)
    ..quadraticBezierTo(0, 0, -1, 0)
    ..quadraticBezierTo(0, 0, 0, -1)
    ..close();
  final Paint _paint = Paint();

  // Fixed seeds (x fraction, phase, size) so the layout is calm and stable.
  static const _seeds = [
    (0.58, 0.00, 1.0),
    (0.72, 0.35, 0.7),
    (0.86, 0.62, 0.9),
    (0.64, 0.80, 0.6),
    (0.93, 0.18, 0.75),
    (0.78, 0.50, 0.55),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final paint = _paint
      ..maskFilter = style == MoodParticles.glow
          ? const MaskFilter.blur(BlurStyle.normal, 3)
          : null;
    for (var i = 0; i < _seeds.length; i++) {
      final (fx, phase, scale) = _seeds[i];
      final p = (v + phase) % 1.0; // 0..1 lifetime of this particle
      // Fade in, hold, fade out.
      final alpha = (math.sin(p * math.pi)).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: 0.55 * alpha);
      final x = fx * size.width + math.sin((p + i) * 2 * math.pi) * 6;
      switch (style) {
        case MoodParticles.hearts:
        case MoodParticles.kisses:
          // Rise gently from the bottom right towards the top.
          final y = size.height * (0.92 - 0.8 * p);
          final s = (style == MoodParticles.kisses ? 10.0 : 13.0) * scale;
          _drawUnit(canvas, _unitHeart, Offset(x, y), s, paint);
        case MoodParticles.sparkles:
          final y = size.height * (0.15 + 0.7 * ((phase + i * 0.17) % 1.0));
          _drawUnit(
            canvas,
            _unitSparkle,
            Offset(x, y),
            7 * scale * (0.6 + 0.4 * alpha),
            paint,
          );
        case MoodParticles.glow:
          final y = size.height * (0.2 + 0.6 * ((phase + i * 0.21) % 1.0));
          canvas.drawCircle(Offset(x, y), 3 + 3 * scale * alpha, paint);
        case MoodParticles.drift:
          final y = size.height * (0.85 - 0.6 * p);
          canvas.drawCircle(Offset(x, y), 2.5 + 2 * scale, paint);
        case MoodParticles.none:
          break;
      }
    }
  }

  void _drawUnit(
    Canvas canvas,
    Path unit,
    Offset at,
    double size,
    Paint paint,
  ) {
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..scale(size)
      ..drawPath(unit, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) =>
      old.style != style || old.color != color || old.t != t;
}
