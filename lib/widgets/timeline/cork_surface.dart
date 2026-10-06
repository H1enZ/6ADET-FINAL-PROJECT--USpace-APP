import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/us_palette.dart';

/// The Timeline's corkboard: warm cocoa cork with a fine speckle and soft
/// tonal patches. Painted in board units, so it pans and zooms with the
/// memories on it, and anchored to saved board positions ([origin]), so
/// the grain never slides under a memory when the board grows.
///
/// The speckle is drawn once into a small tile image and repeated with an
/// image shader: the whole board is a handful of draw calls however big it
/// grows, and zooming only transforms it.
class CorkSurface extends StatefulWidget {
  const CorkSurface({super.key, this.origin = Offset.zero});

  /// Where the canvas's top-left sits in saved board units.
  final Offset origin;

  @override
  State<CorkSurface> createState() => _CorkSurfaceState();
}

class _CorkSurfaceState extends State<CorkSurface> {
  ui.Image? _tile = _CorkTile.ready;

  @override
  void initState() {
    super.initState();
    if (_tile == null) {
      _CorkTile.image.then((image) {
        if (mounted) setState(() => _tile = image);
      });
    }
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CorkPainter(tile: _tile, origin: widget.origin),
        ),
      ),
    ),
  );
}

/// One speckle tile for the whole app, made on first use and kept (it is
/// tiny, and every Timeline visit reuses it).
abstract final class _CorkTile {
  /// Board units per tile edge: small enough to look random, big enough
  /// that the repeat never reads as a pattern.
  static const size = 160;

  static ui.Image? ready;

  static final Future<ui.Image> image = _draw().then((i) => ready = i);

  static Future<ui.Image> _draw() async {
    final rnd = math.Random(7);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final light = Paint()..color = const Color(0x1AFFDCBE); // flecks
    final dark = Paint()..color = const Color(0x4D280F14); // pits
    final fibre = Paint()
      ..color = const Color(0x12FFE6C8)
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 520; i++) {
      final o = Offset(rnd.nextDouble() * size, rnd.nextDouble() * size);
      canvas.drawCircle(o, 0.35 + rnd.nextDouble() * 0.6, light);
    }
    for (var i = 0; i < 640; i++) {
      final o = Offset(rnd.nextDouble() * size, rnd.nextDouble() * size);
      canvas.drawCircle(o, 0.3 + rnd.nextDouble() * 0.8, dark);
    }
    // A few short fibres, so it reads as cork rather than noise.
    for (var i = 0; i < 40; i++) {
      final o = Offset(rnd.nextDouble() * size, rnd.nextDouble() * size);
      final a = rnd.nextDouble() * math.pi;
      final l = 1.5 + rnd.nextDouble() * 2.5;
      canvas.drawLine(o, o + Offset(math.cos(a) * l, math.sin(a) * l), fibre);
    }
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(size, size);
    } finally {
      picture.dispose();
    }
  }
}

class _CorkPainter extends CustomPainter {
  _CorkPainter({required this.tile, required this.origin});

  final ui.Image? tile;
  final Offset origin;

  /// Board units per tonal-patch cell.
  static const _cell = 520.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = UsPalette.cork);

    // Soft lighter and deeper patches on a fixed board grid (seeded per
    // cell), so the warmth is uneven like real cork and stays put.
    canvas.save();
    canvas.clipRect(rect);
    final board = rect.shift(origin);
    final c0 = (board.left / _cell).floor() - 1;
    final c1 = (board.right / _cell).ceil();
    final r0 = (board.top / _cell).floor() - 1;
    final r1 = (board.bottom / _cell).ceil();
    for (var cy = r0; cy <= r1; cy++) {
      for (var cx = c0; cx <= c1; cx++) {
        final rnd = math.Random((cx * 73856093) ^ (cy * 19349663));
        final centre =
            Offset(
              (cx + rnd.nextDouble()) * _cell,
              (cy + rnd.nextDouble()) * _cell,
            ) -
            origin;
        final radius = 200 + rnd.nextDouble() * 220;
        final lighter = rnd.nextBool();
        final color = lighter ? UsPalette.corkLight : UsPalette.corkDeep;
        canvas.drawCircle(
          centre,
          radius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                color.withValues(alpha: lighter ? 0.55 : 0.3),
                color.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: centre, radius: radius)),
        );
      }
    }
    canvas.restore();

    final image = tile;
    if (image != null) {
      // Shift the repeat by the origin so the grain is tied to the board.
      final shift = Matrix4.translationValues(-origin.dx, -origin.dy, 0);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ImageShader(
            image,
            TileMode.repeated,
            TileMode.repeated,
            shift.storage,
            // Smooth, not blocky, when zoomed in close.
            filterQuality: FilterQuality.medium,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_CorkPainter old) =>
      old.tile != tile || old.origin != origin;
}
