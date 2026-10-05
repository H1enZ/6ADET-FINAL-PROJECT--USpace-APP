import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../atoms/fit_label.dart';
import '../effects/motion.dart';

/// Which drawing sits at the top of a quick-action card.
enum QuickActionArt {
  loveNote,
  memory,
  date,
  capsule,
  // Therabot next steps.
  comfort,
  talk,
  breather,
  reconnect,
}

/// One of the four big Home cards.
class QuickAction {
  const QuickAction({
    required this.title,
    required this.subtitle,
    required this.art,
    required this.onTap,
    this.disabledReason,
  });
  final String title;
  final String subtitle;
  final QuickActionArt art;
  final VoidCallback? onTap;

  /// Read by screen readers when [onTap] is null, so a dimmed card says why.
  final String? disabledReason;
}

/// A small shortcut in the row under the cards.
class MoreAction {
  const MoreAction(
    this.label,
    this.icon,
    this.onTap, {
    this.badge,
    this.disabledReason,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  /// A small dot on the icon, and this text read by screen readers
  /// (e.g. "your partner answered"). Null for no dot.
  final String? badge;
  final String? disabledReason;
}

/// Plum card colours, the same family as the special-event card.
class _Palette {
  static const cardTop = Color(0xFF3A1932);
  static const cardBottom = Color(0xFF241225);
  static const border = Color(0x40F6A9C1);
  static const borderPressed = Color(0x80F6A9C1);
  static const glow = Color(0x33EF6F98);
  static const cream = Color(0xFFFFF3EC);
  static const blush = Color(0xFFFFD6E1);
  static const pink = Color(0xFFF6A9C1);
  static const rose = Color(0xFFEF6F98);
  static const deepRose = Color(0xFFC23F66);
  static const plum = Color(0xFF6E2D61);
  static const subtitle = Color(0xFFD9BFCB);
}

/// The four big cards in a 2 x 2 grid, then an optional row of small
/// shortcuts.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.actions, this.more = const []});

  final List<QuickAction> actions;
  final List<MoreAction> more;

  static const _gap = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cardWidth = (box.maxWidth - _gap) / 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < actions.length; i += 2) ...[
              if (i > 0) const SizedBox(height: _gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _ActionCard(actions[i], width: cardWidth)),
                    const SizedBox(width: _gap),
                    Expanded(
                      child: i + 1 < actions.length
                          ? _ActionCard(actions[i + 1], width: cardWidth)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
            if (more.isNotEmpty) ...[
              const SizedBox(height: _gap),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [for (final m in more) _MorePill(m)],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ActionCard extends StatefulWidget {
  const _ActionCard(this.action, {required this.width});

  final QuickAction action;
  final double width;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;

  static const _radius = AppRadius.tile + 4;
  static const _chevron = 30.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.action;
    final enabled = a.onTap != null;
    final still = motionOff(context);
    // Narrow phones get a little less padding and a smaller drawing.
    final pad = widget.width < 150 ? AppSpacing.md : AppSpacing.lg;
    final inner = widget.width - pad * 2;
    final artHeight = (widget.width * 0.5).clamp(60.0, 92.0);
    const duration = Duration(milliseconds: 140);

    final card = AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Palette.cardTop, _Palette.cardBottom],
        ),
        border: Border.all(
          color: _pressed ? _Palette.borderPressed : _Palette.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _pressed ? _Palette.glow : _Palette.glow.withAlpha(0x14),
            blurRadius: _pressed ? 22 : 14,
            spreadRadius: _pressed ? 1 : 0,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: a.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          splashColor: _Palette.rose.withValues(alpha: 0.18),
          highlightColor: _Palette.pink.withValues(alpha: 0.08),
          child: Stack(
            children: [
              // A soft light from the top, behind the drawing.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_radius),
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.75),
                        radius: 0.9,
                        colors: [
                          _Palette.rose.withValues(alpha: 0.20),
                          _Palette.rose.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: artHeight,
                      width: double.infinity,
                      child: _CachedArt(a.art),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Spacer(),
                    FitLabel(
                      a.title,
                      maxWidth: inner,
                      maxLines: 1,
                      textAlign: TextAlign.start,
                      alignment: Alignment.centerLeft,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _Palette.cream,
                        fontSize: 16,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: FitLabel(
                            a.subtitle,
                            maxWidth: inner - _chevron - AppSpacing.sm,
                            textAlign: TextAlign.start,
                            alignment: Alignment.centerLeft,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _Palette.subtitle,
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _Chevron(size: _chevron, pressed: _pressed),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: '${a.title}. ${a.subtitle}',
      hint: enabled ? null : a.disabledReason,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: AnimatedScale(
          scale: _pressed && !still ? 0.965 : 1,
          duration: duration,
          curve: Curves.easeOut,
          child: card,
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.size, required this.pressed});

  final double size;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(_Palette.plum, _Palette.rose, pressed ? 0.45 : 0.15),
        border: Border.all(color: _Palette.pink.withValues(alpha: 0.35)),
      ),
      child: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: _Palette.cream,
      ),
    );
  }
}

class _MorePill extends StatelessWidget {
  const _MorePill(this.action);

  final MoreAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = action.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: action.label,
      value: action.badge,
      hint: enabled ? null : action.disabledReason,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: _Palette.cardBottom,
          shape: StadiumBorder(side: BorderSide(color: _Palette.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: action.onTap,
            splashColor: _Palette.rose.withValues(alpha: 0.18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.touchTarget - 4,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Badge(
                      isLabelVisible: action.badge != null,
                      backgroundColor: _Palette.rose,
                      smallSize: 8,
                      child: Icon(action.icon, size: 18, color: _Palette.pink),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      action.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _Palette.cream,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- drawings

/// One of the quick-action drawings on its own, e.g. on Love Notes.
class QuickActionArtView extends StatelessWidget {
  const QuickActionArtView(this.art, {super.key, this.size = 72});

  final QuickActionArt art;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(dimension: size, child: _CachedArt(art)),
  );
}

/// A drawing painted once into an image and reused. The drawings have
/// blurs and layers that are slow to paint, and on the web everything on
/// screen is painted again on every frame while scrolling.
class _CachedArt extends StatelessWidget {
  const _CachedArt(this.art);

  final QuickActionArt art;

  /// By drawing, size and pixel ratio. Only a handful ever exist.
  static final _images = <String, ui.Image>{};

  static ui.Image _image(QuickActionArt art, Size size, double ratio) {
    final key = '${art.name} ${size.width}x${size.height} @$ratio';
    final cached = _images[key];
    if (cached != null) return cached;
    // Never disposed here: one may still be on screen. A safety valve only.
    if (_images.length > 32) _images.clear();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(ratio);
    _ArtPainter(art).paint(canvas, size);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (size.width * ratio).ceil(),
      (size.height * ratio).ceil(),
    );
    picture.dispose();
    return _images[key] = image;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
        return RawImage(
          image: _image(art, size, ratio),
          width: size.width,
          height: size.height,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
        );
      },
    );
  }
}

/// The four card drawings, one family: soft cream / blush / rose objects
/// with a gloss highlight, a soft shadow under them and a few floating
/// hearts. Drawn in a 100 x 100 box, centred in the space given.
class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art);

  final QuickActionArt art;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);
    _floor(canvas);
    switch (art) {
      case QuickActionArt.loveNote:
        _loveNote(canvas);
      case QuickActionArt.memory:
        _memory(canvas);
      case QuickActionArt.date:
        _date(canvas);
      case QuickActionArt.capsule:
        _capsule(canvas);
      case QuickActionArt.comfort:
        _comfort(canvas);
      case QuickActionArt.talk:
        _talkBubbles(canvas);
      case QuickActionArt.breather:
        _breather(canvas);
      case QuickActionArt.reconnect:
        _reconnect(canvas);
    }
    canvas.restore();
  }

  // ---- shared pieces

  static Shader _vertical(Rect r, List<Color> colors) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: colors,
  ).createShader(r);

  /// The soft shadow the object sits on.
  void _floor(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 92), width: 70, height: 10),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  /// A drop shadow for a shape.
  void _shadow(Canvas canvas, Path p) {
    canvas.drawPath(
      p.shift(const Offset(0, 3)),
      Paint()
        ..color = const Color(0xFF12060E).withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  /// A glossy heart, [w] wide, centred on [c].
  void _heart(Canvas canvas, Offset c, double w, {bool shadow = true}) {
    final h = w * 0.9;
    final x = c.dx - w / 2, y = c.dy - h / 2;
    final p = Path()
      ..moveTo(x + w * 0.5, y + h * 0.95)
      ..cubicTo(
        x + w * 0.1,
        y + h * 0.66,
        x - w * 0.04,
        y + h * 0.32,
        x + w * 0.2,
        y + h * 0.1,
      )
      ..cubicTo(
        x + w * 0.34,
        y - h * 0.02,
        x + w * 0.48,
        y + h * 0.08,
        x + w * 0.5,
        y + h * 0.22,
      )
      ..cubicTo(
        x + w * 0.52,
        y + h * 0.08,
        x + w * 0.66,
        y - h * 0.02,
        x + w * 0.8,
        y + h * 0.1,
      )
      ..cubicTo(
        x + w * 1.04,
        y + h * 0.32,
        x + w * 0.9,
        y + h * 0.66,
        x + w * 0.5,
        y + h * 0.95,
      )
      ..close();
    if (shadow) _shadow(canvas, p);
    final r = Rect.fromLTWH(x, y, w, h);
    canvas.drawPath(
      p,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          radius: 0.9,
          colors: [Color(0xFFFF9DB8), _Palette.rose, _Palette.deepRose],
          stops: [0, 0.55, 1],
        ).createShader(r),
    );
    // Gloss.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x + w * 0.3, y + h * 0.28),
        width: w * 0.22,
        height: h * 0.14,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  /// A little faded heart floating beside the object.
  void _floating(Canvas canvas, Offset c, double w) {
    canvas.saveLayer(
      null,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    _heart(canvas, c, w, shadow: false);
    canvas.restore();
  }

  void _rotated(
    Canvas canvas,
    Offset pivot,
    double degrees,
    VoidCallback draw,
  ) {
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(degrees * math.pi / 180);
    canvas.translate(-pivot.dx, -pivot.dy);
    draw();
    canvas.restore();
  }

  /// A thin white line along the top edge of a shape, like light on it.
  void _rim(Canvas canvas, RRect r) {
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRRect(
      r.deflate(0.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.7),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.4],
        ).createShader(r.outerRect),
    );
    canvas.restore();
  }

  // ---- Love note: an open envelope with a heart letter rising out

  void _loveNote(Canvas canvas) {
    const body = Rect.fromLTRB(14, 42, 86, 86);
    final bodyR = RRect.fromRectAndRadius(body, const Radius.circular(7));
    _shadow(canvas, Path()..addRRect(bodyR));

    // Inside of the envelope and the open flap behind the letter.
    canvas.drawRRect(
      bodyR,
      Paint()
        ..shader = _vertical(body, const [
          Color(0xFFE290A9),
          Color(0xFFC86E8C),
        ]),
    );
    final flap = Path()
      ..moveTo(14, 46)
      ..lineTo(50, 20)
      ..lineTo(86, 46)
      ..close();
    canvas.drawPath(
      flap,
      Paint()
        ..shader = _vertical(const Rect.fromLTRB(14, 20, 86, 46), const [
          Color(0xFFF4BCCD),
          Color(0xFFE29AB0),
        ]),
    );

    // The letter, lifted out.
    _rotated(canvas, const Offset(50, 44), -4, () {
      final letter = RRect.fromRectAndRadius(
        const Rect.fromLTRB(26, 14, 74, 66),
        const Radius.circular(4),
      );
      _shadow(canvas, Path()..addRRect(letter));
      canvas.drawRRect(
        letter,
        Paint()
          ..shader = _vertical(letter.outerRect, const [
            _Palette.cream,
            Color(0xFFFBE1E6),
          ]),
      );
      _heart(canvas, const Offset(50, 36), 26);
    });

    // The front pocket over the letter.
    final pocket = Path()
      ..moveTo(14, 50)
      ..lineTo(50, 70)
      ..lineTo(86, 50)
      ..lineTo(86, 79)
      ..quadraticBezierTo(86, 86, 79, 86)
      ..lineTo(21, 86)
      ..quadraticBezierTo(14, 86, 14, 79)
      ..close();
    canvas.drawPath(
      pocket,
      Paint()..shader = _vertical(body, const [_Palette.blush, _Palette.pink]),
    );
    canvas.drawPath(
      Path()
        ..moveTo(15, 51)
        ..lineTo(50, 70)
        ..lineTo(85, 51),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.65),
    );

    _floating(canvas, const Offset(88, 22), 10);
    _floating(canvas, const Offset(11, 30), 7);
  }

  // ---- Add memory: two stacked instant photos and a heart

  void _polaroid(Canvas canvas, Rect frame, {required bool front}) {
    final r = RRect.fromRectAndRadius(frame, const Radius.circular(4));
    _shadow(canvas, Path()..addRRect(r));
    canvas.drawRRect(
      r,
      Paint()
        ..shader = _vertical(
          frame,
          front
              ? const [_Palette.cream, Color(0xFFF7DCE3)]
              : const [Color(0xFFF2D4DC), Color(0xFFDDB2C0)],
        ),
    );
    final photo = Rect.fromLTRB(
      frame.left + 5,
      frame.top + 5,
      frame.right - 5,
      frame.bottom - 14,
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(photo, const Radius.circular(2)));
    canvas.drawRect(
      photo,
      Paint()
        ..shader = _vertical(photo, const [
          Color(0xFFF7A1B4),
          Color(0xFFB4567E),
          _Palette.plum,
        ]),
    );
    if (front) {
      // A low sun over two hills.
      canvas.drawCircle(
        Offset(
          photo.left + photo.width * 0.62,
          photo.top + photo.height * 0.42,
        ),
        photo.width * 0.13,
        Paint()..color = const Color(0xFFFFE3D2),
      );
      canvas.drawPath(
        Path()
          ..moveTo(photo.left, photo.bottom)
          ..lineTo(photo.left, photo.top + photo.height * 0.72)
          ..lineTo(
            photo.left + photo.width * 0.32,
            photo.top + photo.height * 0.48,
          )
          ..lineTo(
            photo.left + photo.width * 0.6,
            photo.top + photo.height * 0.8,
          )
          ..lineTo(
            photo.left + photo.width * 0.78,
            photo.top + photo.height * 0.64,
          )
          ..lineTo(photo.right, photo.top + photo.height * 0.82)
          ..lineTo(photo.right, photo.bottom)
          ..close(),
        Paint()..color = const Color(0xFF4A1D42),
      );
    }
    canvas.restore();
    _rim(canvas, r);
  }

  void _memory(Canvas canvas) {
    _rotated(canvas, const Offset(40, 50), -12, () {
      _polaroid(canvas, const Rect.fromLTRB(16, 16, 62, 74), front: false);
    });
    _rotated(canvas, const Offset(58, 54), 7, () {
      _polaroid(canvas, const Rect.fromLTRB(34, 22, 82, 82), front: true);
    });
    _heart(canvas, const Offset(80, 74), 24);
    _floating(canvas, const Offset(12, 82), 8);
    _floating(canvas, const Offset(88, 18), 9);
  }

  // ---- Plan a date: a calendar card with a heart on it

  void _date(Canvas canvas) {
    const body = Rect.fromLTRB(18, 22, 82, 86);
    final bodyR = RRect.fromRectAndRadius(body, const Radius.circular(10));
    _shadow(canvas, Path()..addRRect(bodyR));
    canvas.drawRRect(
      bodyR,
      Paint()
        ..shader = _vertical(body, const [_Palette.cream, Color(0xFFF6D3DD)]),
    );
    // The coloured header band.
    canvas.save();
    canvas.clipRRect(bodyR);
    const band = Rect.fromLTRB(18, 22, 82, 41);
    canvas.drawRect(
      band,
      Paint()
        ..shader = _vertical(band, const [
          Color(0xFFF58FAD),
          _Palette.deepRose,
        ]),
    );
    canvas.restore();
    _rim(canvas, bodyR);

    // Day dots, faint, behind the heart.
    final dot = Paint()..color = const Color(0xFFE4B3C2);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 5; col++) {
        canvas.drawCircle(Offset(28 + col * 11.0, 52 + row * 11.0), 1.6, dot);
      }
    }

    // Binder rings.
    for (final x in [34.0, 66.0]) {
      final ring = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 3.5, 14, 7, 16),
        const Radius.circular(3.5),
      );
      _shadow(canvas, Path()..addRRect(ring));
      canvas.drawRRect(
        ring,
        Paint()
          ..shader = LinearGradient(
            colors: const [Color(0xFFFFE6EC), Color(0xFFC98AA0)],
          ).createShader(ring.outerRect),
      );
    }

    _heart(canvas, const Offset(50, 64), 30);
    _floating(canvas, const Offset(90, 30), 9);
    _floating(canvas, const Offset(10, 60), 7);
  }

  // ---- Time capsule: a sealed envelope with a heart wax seal

  void _capsule(Canvas canvas) {
    _rotated(canvas, const Offset(50, 56), -7, () {
      const body = Rect.fromLTRB(12, 30, 88, 82);
      final bodyR = RRect.fromRectAndRadius(body, const Radius.circular(7));
      _shadow(canvas, Path()..addRRect(bodyR));
      canvas.drawRRect(
        bodyR,
        Paint()
          ..shader = _vertical(body, const [_Palette.blush, _Palette.pink]),
      );
      canvas.save();
      canvas.clipRRect(bodyR);
      // Side and bottom folds.
      final fold = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFD58AA2);
      canvas.drawLine(const Offset(12, 82), const Offset(42, 58), fold);
      canvas.drawLine(const Offset(88, 82), const Offset(58, 58), fold);
      // The closed flap.
      final flap = Path()
        ..moveTo(12, 30)
        ..lineTo(50, 60)
        ..lineTo(88, 30)
        ..close();
      _shadow(canvas, flap);
      canvas.drawPath(
        flap,
        Paint()
          ..shader = _vertical(const Rect.fromLTRB(12, 30, 88, 60), const [
            _Palette.cream,
            Color(0xFFF8C9D6),
          ]),
      );
      canvas.restore();
      _rim(canvas, bodyR);

      // The wax seal: a lumpy rim, then the disc, then a pressed heart.
      const c = Offset(50, 59);
      final wax = Path();
      for (var i = 0; i < 10; i++) {
        final t = i * math.pi * 2 / 10;
        wax.addOval(
          Rect.fromCircle(
            center: c + Offset(math.cos(t), math.sin(t)) * 11.5,
            radius: 4,
          ),
        );
      }
      wax.addOval(Rect.fromCircle(center: c, radius: 12.5));
      _shadow(canvas, wax);
      final waxPaint = Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFE25A7E), Color(0xFFA42E52), Color(0xFF7C1F3E)],
          stops: [0, 0.65, 1],
        ).createShader(Rect.fromCircle(center: c, radius: 16));
      canvas.drawPath(wax, waxPaint);
      canvas.drawCircle(
        c,
        10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFF7C1F3E).withValues(alpha: 0.7),
      );
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
      _heart(canvas, c, 11, shadow: false);
      canvas.restore();
    });
    _floating(canvas, const Offset(88, 20), 9);
    _floating(canvas, const Offset(12, 22), 7);
  }

  // ---- Comfort each other: two soft figures leaning in, a heart above

  void _figure(
    Canvas canvas,
    Offset at,
    double scale,
    List<Color> colors, {
    required bool facingRight,
  }) {
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: at + Offset(0, 14 * scale),
        width: 30 * scale,
        height: 34 * scale,
      ),
      Radius.circular(15 * scale),
    );
    final head = Rect.fromCircle(
      center: at + Offset(0, -10 * scale),
      radius: 13 * scale,
    );
    final shape = Path()
      ..addRRect(body)
      ..addOval(head);
    _shadow(canvas, shape);
    canvas.drawPath(
      shape,
      Paint()..shader = _vertical(shape.getBounds(), colors),
    );
    // A sleepy, content face.
    final face = Paint()
      ..color = const Color(0xFF6B2A47)
      ..strokeWidth = 1.6 * scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final eye = facingRight ? 3.0 : -3.0;
    for (final dx in [-4.0, 4.0]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: at + Offset((dx + eye) * scale, -11 * scale),
          width: 4 * scale,
          height: 3 * scale,
        ),
        0,
        math.pi,
        false,
        face,
      );
    }
    canvas.drawCircle(
      at + Offset((eye - 6) * scale, -6 * scale),
      2.2 * scale,
      Paint()..color = const Color(0xFFF58FAD).withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      at + Offset((eye + 6) * scale, -6 * scale),
      2.2 * scale,
      Paint()..color = const Color(0xFFF58FAD).withValues(alpha: 0.7),
    );
  }

  void _comfort(Canvas canvas) {
    _rotated(canvas, const Offset(38, 60), -8, () {
      _figure(canvas, const Offset(38, 54), 1.0, const [
        Color(0xFFF7A1B8),
        Color(0xFFD95F86),
      ], facingRight: true);
    });
    _rotated(canvas, const Offset(62, 60), 8, () {
      _figure(canvas, const Offset(62, 54), 1.0, const [
        Color(0xFFFFF1F3),
        Color(0xFFE6C9D6),
      ], facingRight: false);
    });
    _heart(canvas, const Offset(50, 18), 18);
    _floating(canvas, const Offset(14, 30), 7);
    _floating(canvas, const Offset(88, 34), 6);
  }

  // ---- Talk it through: two speech bubbles, one with a heart

  void _bubble(
    Canvas canvas,
    Rect r,
    List<Color> colors, {
    required bool tailLeft,
  }) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(r.height * 0.32)));
    final tx = tailLeft ? r.left + r.width * 0.25 : r.right - r.width * 0.25;
    path.moveTo(tx - 5, r.bottom - 2);
    path.lineTo(tx + (tailLeft ? -6 : 6), r.bottom + 9);
    path.lineTo(tx + 6, r.bottom - 2);
    path.close();
    _shadow(canvas, path);
    canvas.drawPath(path, Paint()..shader = _vertical(r, colors));
  }

  void _talkBubbles(Canvas canvas) {
    _bubble(canvas, const Rect.fromLTRB(44, 40, 86, 72), const [
      Color(0xFFFFF4F1),
      Color(0xFFEBD3D8),
    ], tailLeft: false);
    final dots = Paint()..color = const Color(0xFFC79AAE);
    for (final x in [56.0, 65.0, 74.0]) {
      canvas.drawCircle(Offset(x, 56), 2.4, dots);
    }
    _bubble(canvas, const Rect.fromLTRB(12, 18, 58, 52), const [
      Color(0xFFF7A1B8),
      Color(0xFFDD6A90),
    ], tailLeft: true);
    canvas.save();
    canvas.drawPath(
      _heartPathAt(const Offset(35, 35), 16),
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    canvas.restore();
    _floating(canvas, const Offset(84, 22), 7);
  }

  Path _heartPathAt(Offset c, double w) {
    final h = w * 0.9;
    final x = c.dx - w / 2, y = c.dy - h / 2;
    return Path()
      ..moveTo(x + w * 0.5, y + h * 0.95)
      ..cubicTo(
        x + w * 0.1,
        y + h * 0.66,
        x - w * 0.04,
        y + h * 0.32,
        x + w * 0.2,
        y + h * 0.1,
      )
      ..cubicTo(
        x + w * 0.34,
        y - h * 0.02,
        x + w * 0.48,
        y + h * 0.08,
        x + w * 0.5,
        y + h * 0.22,
      )
      ..cubicTo(
        x + w * 0.52,
        y + h * 0.08,
        x + w * 0.66,
        y - h * 0.02,
        x + w * 0.8,
        y + h * 0.1,
      )
      ..cubicTo(
        x + w * 1.04,
        y + h * 0.32,
        x + w * 0.9,
        y + h * 0.66,
        x + w * 0.5,
        y + h * 0.95,
      )
      ..close();
  }

  // ---- Take a breather: a crescent moon and a few soft z's

  void _breather(Canvas canvas) {
    final moon = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: const Offset(42, 56), radius: 26));
    final bite = Path()
      ..addOval(Rect.fromCircle(center: const Offset(56, 46), radius: 22));
    final crescent = Path.combine(PathOperation.difference, moon, bite);
    _shadow(canvas, crescent);
    canvas.drawPath(
      crescent,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.2),
          colors: [Color(0xFFFFFBF2), Color(0xFFF0D9C9)],
        ).createShader(const Rect.fromLTRB(16, 30, 68, 82)),
    );
    for (final (x, y, size) in const [
      (62.0, 22.0, 15.0),
      (74.0, 34.0, 12.0),
      (82.0, 18.0, 10.0),
    ]) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'z',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFB98AD8),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x, y));
    }
    _floating(canvas, const Offset(14, 30), 6);
  }

  // ---- Reconnect gently: two hearts linked together

  void _reconnect(Canvas canvas) {
    final left = _heartPathAt(const Offset(40, 52), 44);
    final right = _heartPathAt(const Offset(60, 54), 44);
    for (final (path, colors) in [
      (left, const [Color(0xFFFFC3D3), Color(0xFFEF6F98)]),
      (right, const [Color(0xFFD8A6F0), Color(0xFFA35FC7)]),
    ]) {
      _shadow(canvas, path);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeJoin = StrokeJoin.round
          ..shader = _vertical(path.getBounds(), colors),
      );
    }
    // Gloss.
    canvas.drawArc(
      const Rect.fromLTRB(22, 34, 40, 50),
      math.pi,
      math.pi / 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.7),
    );
    _floating(canvas, const Offset(88, 26), 7);
    _floating(canvas, const Offset(12, 76), 6);
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.art != art;
}
