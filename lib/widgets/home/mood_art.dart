import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/mood.dart';
import '../../models/mood_visual.dart';
import '../effects/soft_hearts_background.dart';

/// A mood's illustration: the final artwork from assets/moods/ when it has
/// been added, otherwise a soft placeholder drawn in code (never an emoji).
/// Dropping the PNG into assets/moods/ is enough; no code change needed.
class MoodArt extends StatelessWidget {
  const MoodArt({
    super.key,
    required this.visual,
    required this.size,
    this.semantic = true,
  });

  final MoodVisual visual;
  final double size;

  /// False where a label next to it already names the mood (the grid).
  final bool semantic;

  // Read the asset manifest once per app run.
  static Future<Set<String>>? _assets;

  // The finished result, handed to FutureBuilder as initialData so a newly
  // built MoodArt shows the real image on its first frame (no placeholder
  // flash) once the manifest has been read.
  static Set<String>? _loaded;

  static Future<Set<String>> _available() =>
      _assets ??= AssetManifest.loadFromAssetBundle(rootBundle)
          .then((m) => _loaded = m.listAssets().toSet())
          .catchError((Object _) => _loaded = <String>{});

  @override
  Widget build(BuildContext context) {
    final art = FutureBuilder<Set<String>>(
      future: _available(),
      initialData: _loaded,
      builder: (context, snap) {
        final hasArt = snap.data?.contains(visual.assetPath) ?? false;
        if (hasArt) {
          return Image.asset(
            visual.assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            // Decode at display size, not the full 1024 px.
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
            errorBuilder: (context, _, _) =>
                _Placeholder(visual: visual, size: size),
          );
        }
        return _Placeholder(visual: visual, size: size);
      },
    );
    return semantic
        ? Semantics(
            image: true,
            label: visual.artDescription,
            child: ExcludeSemantics(child: art),
          )
        : ExcludeSemantics(child: art);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.visual, required this.size});

  final MoodVisual visual;
  final double size;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.square(size),
      painter: _ArtPainter(
        visual.mood,
        visual.colors.particle,
        visual.colors.accent,
      ),
    ),
  );
}

/// Placeholder art: glossy "soft 3D" shapes (radial shading plus a
/// highlight) with simple faces. Only for layout until the final artwork.
class _ArtPainter extends CustomPainter {
  _ArtPainter(this.mood, this.base, this.deep);

  final Mood mood;
  final Color base;
  final Color deep;

  static const _ink = Color(0xFF4A2545); // plum facial features
  static const _blush = Color(0x66F2708F);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.save();
    canvas.scale(s / 100); // draw on a 100×100 grid
    switch (mood) {
      case Mood.loved:
        _heart(canvas, const Rect.fromLTWH(14, 14, 72, 70), base, deep);
        // Two little arms wrapped across the front: the hug.
        final arm = Paint()..color = Color.lerp(base, Colors.white, 0.25)!;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(24, 54, 30, 11),
            const Radius.circular(6),
          ),
          arm,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(46, 54, 30, 11),
            const Radius.circular(6),
          ),
          arm,
        );
        _closedEyes(canvas, const Offset(40, 40), const Offset(60, 40));
        _blushes(canvas, const Offset(34, 48), const Offset(66, 48));
      case Mood.happy:
        final rays = Paint()..color = Color.lerp(base, deep, 0.25)!;
        for (var i = 0; i < 10; i++) {
          canvas.save();
          canvas.translate(50, 50);
          canvas.rotate(i * math.pi / 5);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-4, -47, 8, 14),
              const Radius.circular(4),
            ),
            rays,
          );
          canvas.restore();
        }
        _ball(canvas, const Offset(50, 50), 30, base, deep);
        _dotEyes(canvas, const Offset(41, 45), const Offset(59, 45));
        _smile(canvas, const Offset(50, 54), 10);
        _blushes(canvas, const Offset(36, 56), const Offset(64, 56));
      case Mood.calm:
        _cloud(canvas, base, deep);
        _closedEyes(
          canvas,
          const Offset(40, 56),
          const Offset(60, 56),
          sleepy: true,
        );
        _z(canvas, const Offset(74, 22), 7);
        _z(canvas, const Offset(84, 12), 5);
      case Mood.emotional:
        _cloud(canvas, base, deep);
        _closedEyes(
          canvas,
          const Offset(40, 56),
          const Offset(60, 56),
          sad: true,
        );
        _tear(canvas, const Offset(37, 64));
        _blushes(canvas, const Offset(32, 64), const Offset(68, 64));
      case Mood.needAHug:
        for (final ear in const [Offset(28, 28), Offset(72, 28)]) {
          _ball(canvas, ear, 12, base, deep);
          canvas.drawCircle(
            ear,
            6,
            Paint()..color = Color.lerp(base, Colors.white, 0.45)!,
          );
        }
        _ball(canvas, const Offset(50, 54), 32, base, deep);
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(50, 64), width: 30, height: 22),
          Paint()..color = Color.lerp(base, Colors.white, 0.55)!,
        );
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(50, 59), width: 10, height: 7),
          Paint()..color = _ink,
        );
        _dotEyes(canvas, const Offset(40, 48), const Offset(60, 48));
        _smile(canvas, const Offset(50, 64), 5);
      case Mood.flirty:
        _ball(canvas, const Offset(50, 52), 34, base, deep);
        _dotEyes(canvas, const Offset(40, 46), null);
        _wink(canvas, const Offset(60, 46));
        _kissLips(canvas, const Offset(52, 62));
        _blushes(canvas, const Offset(34, 58), const Offset(68, 56));
        _heart(canvas, const Rect.fromLTWH(78, 18, 14, 13), deep, deep);
      case Mood.romantic:
        canvas.save();
        canvas.translate(38, 54);
        canvas.rotate(-0.25);
        _heart(canvas, const Rect.fromLTWH(-26, -26, 52, 50), base, deep);
        canvas.restore();
        canvas.save();
        canvas.translate(68, 34);
        canvas.rotate(0.25);
        _heart(
          canvas,
          const Rect.fromLTWH(-18, -18, 36, 35),
          Color.lerp(base, deep, 0.35)!,
          deep,
        );
        canvas.restore();
      case Mood.excited:
        _ball(canvas, const Offset(50, 52), 34, base, deep);
        _star(canvas, const Offset(39, 46), 8);
        _star(canvas, const Offset(61, 46), 8);
        final mouth = Path()
          ..moveTo(40, 58)
          ..quadraticBezierTo(50, 74, 60, 58)
          ..close();
        canvas.drawPath(mouth, Paint()..color = _ink);
        _blushes(canvas, const Offset(32, 60), const Offset(68, 60));
      default:
        _ball(canvas, const Offset(50, 50), 30, base, deep);
    }
    canvas.restore();
  }

  // ---- glossy primitives

  Shader _gloss(Rect r, Color c, Color edge) => RadialGradient(
    center: const Alignment(-0.35, -0.45),
    radius: 0.95,
    colors: [Color.lerp(c, Colors.white, 0.45)!, c, Color.lerp(c, edge, 0.45)!],
    stops: const [0, 0.55, 1],
  ).createShader(r);

  void _highlight(Canvas canvas, Rect r) => canvas.drawOval(
    Rect.fromLTWH(
      r.left + r.width * 0.2,
      r.top + r.height * 0.12,
      r.width * 0.3,
      r.height * 0.16,
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );

  void _ball(Canvas canvas, Offset c, double r, Color color, Color edge) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c + const Offset(0, 3),
      r,
      Paint()..color = edge.withValues(alpha: 0.12),
    );
    canvas.drawCircle(c, r, Paint()..shader = _gloss(rect, color, edge));
    _highlight(canvas, rect);
  }

  void _heart(Canvas canvas, Rect r, Color color, Color edge) {
    canvas.drawPath(
      heartPath(r.shift(const Offset(0, 3))),
      Paint()..color = edge.withValues(alpha: 0.12),
    );
    canvas.drawPath(heartPath(r), Paint()..shader = _gloss(r, color, edge));
    _highlight(canvas, r);
  }

  void _cloud(Canvas canvas, Color color, Color edge) {
    final path = Path()
      ..addOval(Rect.fromCircle(center: const Offset(36, 56), radius: 20))
      ..addOval(Rect.fromCircle(center: const Offset(54, 44), radius: 24))
      ..addOval(Rect.fromCircle(center: const Offset(70, 58), radius: 18))
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(20, 52, 66, 24),
          const Radius.circular(12),
        ),
      );
    const bounds = Rect.fromLTWH(16, 20, 74, 58);
    canvas.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()..color = edge.withValues(alpha: 0.12),
    );
    canvas.drawPath(path, Paint()..shader = _gloss(bounds, color, edge));
    _highlight(canvas, bounds);
  }

  // ---- faces

  Paint get _line => Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round;

  void _dotEyes(Canvas canvas, Offset a, Offset? b) {
    final p = Paint()..color = _ink;
    canvas.drawCircle(a, 3.4, p);
    if (b != null) canvas.drawCircle(b, 3.4, p);
  }

  void _closedEyes(
    Canvas canvas,
    Offset a,
    Offset b, {
    bool sleepy = false,
    bool sad = false,
  }) {
    for (final c in [a, b]) {
      final r = Rect.fromCenter(center: c, width: 9, height: 7);
      // Happy/sleepy: a downward arc. Sad: an upward one.
      canvas.drawArc(r, sad ? math.pi : 0, math.pi, false, _line);
      if (sleepy) {
        canvas.drawLine(
          c + const Offset(-5, -1),
          c + const Offset(-7, -3),
          _line..strokeWidth = 1.6,
        );
      }
    }
  }

  void _wink(Canvas canvas, Offset c) => canvas.drawArc(
    Rect.fromCenter(center: c, width: 9, height: 7),
    math.pi,
    math.pi,
    false,
    _line,
  );

  void _smile(Canvas canvas, Offset c, double w) => canvas.drawArc(
    Rect.fromCenter(center: c, width: w, height: w * 0.7),
    0.2,
    math.pi - 0.4,
    false,
    _line,
  );

  void _blushes(Canvas canvas, Offset a, Offset b) {
    final p = Paint()..color = _blush;
    canvas.drawOval(Rect.fromCenter(center: a, width: 9, height: 5), p);
    canvas.drawOval(Rect.fromCenter(center: b, width: 9, height: 5), p);
  }

  void _kissLips(Canvas canvas, Offset c) {
    final p = Paint()..color = const Color(0xFFD52F47);
    canvas.drawOval(
      Rect.fromCenter(center: c + const Offset(-2.5, 0), width: 6, height: 5),
      p,
    );
    canvas.drawOval(
      Rect.fromCenter(center: c + const Offset(2.5, 0), width: 6, height: 5),
      p,
    );
  }

  void _tear(Canvas canvas, Offset c) {
    final path = Path()
      ..moveTo(c.dx, c.dy - 5)
      ..quadraticBezierTo(c.dx + 4, c.dy + 1, c.dx, c.dy + 4)
      ..quadraticBezierTo(c.dx - 4, c.dy + 1, c.dx, c.dy - 5);
    canvas.drawPath(path, Paint()..color = const Color(0xFF8FC3F2));
  }

  void _star(Canvas canvas, Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFF2B33D));
  }

  void _z(Canvas canvas, Offset o, double s) {
    final path = Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + s, o.dy)
      ..lineTo(o.dx, o.dy + s)
      ..lineTo(o.dx + s, o.dy + s);
    canvas.drawPath(path, _line..strokeWidth = 1.8);
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.mood != mood || old.base != base || old.deep != deep;
}
