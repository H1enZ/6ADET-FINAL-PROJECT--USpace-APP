import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/app_typography.dart';
import '../../theme/us_palette.dart';
import '../atoms/us_icon.dart';
import '../effects/motion.dart';
import 'monogram_seal.dart';
import 'vintage_parchment.dart';

// The Time Capsule ceremony.
//
// Sealing: the parchment letter folds into thirds, a rose ribbon is tied
// around it, it slides into an aged envelope and the flap closes; a lit
// candle drips three drops of wax onto the flap and a brass stamp presses
// the sender's monogram into it.
//
// Opening: warm light swells, a seam of light splits the seal, the flap
// opens, the photo rises out first, then the letter comes out still folded,
// the ribbon slips off and it unfolds.
//
// Nothing shakes or bounces. With reduced motion each starts at its end.

/// Where a value is between [from] and [to] of the timeline, eased.
double _span(
  double t,
  double from,
  double to, [
  Curve curve = Curves.easeInOutCubic,
]) => curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

/// Everything the scene shows at one moment of a ceremony.
class _Frame {
  const _Frame({
    this.fold1 = 0,
    this.fold3 = 0,
    this.ribbon = 0,
    this.ribbonOff = 0,
    this.letterIn = 0,
    this.envelope = 1,
    this.envelopeDrop = 0,
    this.flapClosed = 1,
    this.candle = 0,
    this.drops = const [0, 0, 0],
    this.pool = 1,
    this.seal = 1,
    this.emboss = 1,
    this.stamp = 0,
    this.glow = 0,
    this.sealGlow = 0,
    this.crack = 0,
    this.photo = 0,
    this.letterOut = 0,
  });

  /// Top and bottom thirds folded over the middle (0 flat, 1 folded).
  final double fold1, fold3;

  /// Ribbon tied (0..1) and slipping off (0..1).
  final double ribbon, ribbonOff;

  /// Folded letter sliding into the envelope (0 above it, 1 inside).
  final double letterIn;

  /// Envelope shown (0..1) and sinking away at the end of an opening.
  final double envelope, envelopeDrop;

  /// Flap: 0 open (pointing up), 1 closed.
  final double flapClosed;

  /// Candle on screen (0..1, in then out).
  final double candle;

  /// Each wax drop's fall (0 at the wick, 1 landed; 0 also = hidden).
  final List<double> drops;

  /// Wax pool spreading (0..1), seal shown (0..1), impression (0..1).
  final double pool, seal, emboss;

  /// Brass stamp: 0 hidden above, 1 pressed into the wax.
  final double stamp;

  /// Candle glow around the seal, warmth inside it, seam of light.
  final double glow, sealGlow, crack;

  /// Photo rising out (0..1) and the folded letter rising out (0..1).
  final double photo, letterOut;
}

_Frame _sealingAt(double t) {
  final stampDown = _span(t, 0.84, 0.89, Curves.easeInCubic);
  final stampUp = _span(t, 0.92, 0.98, Curves.easeOutCubic);
  return _Frame(
    fold3: _span(t, 0.06, 0.16),
    fold1: _span(t, 0.16, 0.26),
    ribbon: _span(t, 0.26, 0.36, Curves.easeOutCubic),
    envelope: _span(t, 0.34, 0.42, Curves.easeOutCubic),
    letterIn: _span(t, 0.40, 0.52),
    flapClosed: _span(t, 0.52, 0.60),
    candle: t < 0.6
        ? 0
        : (t < 0.78 ? _span(t, 0.6, 0.66) : 1 - _span(t, 0.78, 0.84)),
    drops: [
      t >= 0.67 && t < 0.712 ? _span(t, 0.67, 0.71, Curves.easeInQuad) : 0,
      t >= 0.71 && t < 0.752 ? _span(t, 0.71, 0.75, Curves.easeInQuad) : 0,
      t >= 0.75 && t < 0.792 ? _span(t, 0.75, 0.79, Curves.easeInQuad) : 0,
    ],
    pool: 0.45 + 0.43 * _span(t, 0.70, 0.80) + 0.12 * _span(t, 0.89, 0.94),
    seal: t < 0.70 ? 0 : 1,
    emboss: _span(t, 0.89, 0.93),
    stamp: t < 0.82 ? 0 : (t < 0.92 ? stampDown : 1 - stampUp),
    glow: t < 0.62
        ? 0
        : (t < 0.70 ? _span(t, 0.62, 0.70) : 1 - 0.7 * _span(t, 0.84, 1.0)),
  );
}

_Frame _openingAt(double t) => _Frame(
  fold1: 1 - _span(t, 0.74, 0.86),
  fold3: 1 - _span(t, 0.82, 0.94),
  ribbon: 1,
  ribbonOff: _span(t, 0.66, 0.74),
  letterIn: 1,
  letterOut: _span(t, 0.54, 0.66, Curves.easeOutCubic),
  envelope: 1 - _span(t, 0.70, 0.92),
  envelopeDrop: _span(t, 0.66, 0.92),
  flapClosed: 1 - _span(t, 0.28, 0.38),
  glow: t < 0.12 ? 0.3 + 0.7 * _span(t, 0, 0.12) : 1 - _span(t, 0.24, 0.36),
  sealGlow: _span(t, 0.0, 0.14),
  crack: _span(t, 0.12, 0.22, Curves.easeOutCubic),
  seal: 1 - _span(t, 0.22, 0.30),
  photo: _span(t, 0.38, 0.54, Curves.easeOutCubic),
);

/// The sealing ceremony. Shows "Sealed" and a Done button at the end, which
/// calls [onDone].
class CapsuleSealingCeremony extends StatefulWidget {
  const CapsuleSealingCeremony({
    super.key,
    required this.width,
    required this.initial,
    required this.letter,
    required this.onDone,
    this.title,
    this.caption,
  });

  final double width;

  /// The sender's initial for the monogram (see [sealInitial]).
  final String initial;
  final String letter;
  final String? title;

  /// Under "Sealed", e.g. "Opens 4 Nov at 8:00 AM".
  final String? caption;
  final VoidCallback onDone;

  @override
  State<CapsuleSealingCeremony> createState() => _CapsuleSealingCeremonyState();
}

class _CapsuleSealingCeremonyState extends State<CapsuleSealingCeremony>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7000),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (motionOff(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final end = _span(t, 0.94, 1.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Scene(
              width: widget.width,
              frame: _sealingAt(t),
              time: t,
              initial: widget.initial,
              letter: widget.letter,
              title: widget.title,
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: end,
              child: Column(
                children: [
                  Text(
                    'Sealed',
                    style: AppTypography.display(26, color: UsPalette.cream),
                  ),
                  if (widget.caption != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.caption!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: UsPalette.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: end > 0.5 ? widget.onDone : null,
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The opening ceremony. When it has finished, tapping the letter (or the
/// button under it) calls [onReveal].
class CapsuleOpeningCeremony extends StatefulWidget {
  const CapsuleOpeningCeremony({
    super.key,
    required this.width,
    required this.initial,
    required this.letter,
    required this.onReveal,
    this.title,
    this.photo,
  });

  final double width;
  final String initial;
  final String letter;
  final String? title;
  final Uint8List? photo;
  final VoidCallback onReveal;

  @override
  State<CapsuleOpeningCeremony> createState() => _CapsuleOpeningCeremonyState();
}

class _CapsuleOpeningCeremonyState extends State<CapsuleOpeningCeremony>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6400),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (motionOff(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final done = _c.isCompleted;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Scene(
              width: widget.width,
              frame: _openingAt(t),
              time: t,
              opening: true,
              initial: widget.initial,
              letter: widget.letter,
              title: widget.title,
              photo: widget.photo,
              onLetterTap: done ? widget.onReveal : null,
            ),
            const SizedBox(height: 8),
            AnimatedOpacity(
              opacity: done ? 1 : 0,
              duration: motionOff(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 400),
              child: TextButton.icon(
                onPressed: done ? widget.onReveal : null,
                icon: const UsIcon(UsIcons.loveNotes, size: 20),
                label: Text(
                  'Tap the letter to read it',
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The stage: envelope, folded letter, ribbon, candle, wax, stamp, seal and
/// photo, placed from one [frame].
class _Scene extends StatelessWidget {
  const _Scene({
    required this.width,
    required this.frame,
    required this.time,
    required this.initial,
    required this.letter,
    this.title,
    this.photo,
    this.opening = false,
    this.onLetterTap,
  });

  final double width;
  final _Frame frame;

  /// The timeline position, for the flame's flicker.
  final double time;
  final String initial;
  final String letter;
  final String? title;
  final Uint8List? photo;
  final bool opening;
  final VoidCallback? onLetterTap;

  @override
  Widget build(BuildContext context) {
    final f = frame;
    final w = width;
    final h = w * 1.42;

    // The envelope near the bottom; it sinks away at the end of an opening.
    final ew = w * 0.8, eh = ew * 0.62;
    final envLeft = (w - ew) / 2;
    final envTop =
        h -
        eh -
        w * 0.08 +
        (1 - f.envelope) * w * 0.1 * (opening ? 0 : 1) +
        f.envelopeDrop * w * 0.25;
    final apex = eh * 0.56;
    final sealSpot = Offset(w / 2, envTop + apex);

    // The letter: three panels of parchment.
    final lw = ew * 0.86, ph = lw * 0.36;
    final sheetLeft = (w - lw) / 2;
    final aboveTop = w * 0.12; // where it is written and folded
    final insideTop = envTop + eh * 0.18 - ph; // middle panel inside
    final outTop = w * 0.56; // above the photo-cleared space, when opened
    final double sheetTop;
    final double letterScale;
    if (opening) {
      final from = insideTop, to = outTop;
      sheetTop = from + (to - from) * f.letterOut;
      letterScale = 0.9 + 0.1 * f.letterOut;
    } else {
      sheetTop = aboveTop + (insideTop - aboveTop) * f.letterIn;
      letterScale = 1 - 0.1 * f.letterIn;
    }
    final letterInside = opening ? f.letterOut < 0.02 : f.letterIn > 0.98;

    // Flap depth: closed points down over the pocket, open points up.
    final flapDepth = apex * math.cos(math.pi * (1 - f.flapClosed));

    final sealSize = w * 0.22;
    final photoSize = w * 0.44;
    final photoStart = envTop + eh * 0.1;
    final photoTop = photoStart + (w * 0.04 - photoStart) * f.photo;

    final children = <Widget>[
      // Envelope back, and the flap while it is open (behind the letter).
      if (f.envelope > 0)
        Positioned(
          left: envLeft,
          top: envTop,
          width: ew,
          height: eh,
          child: Opacity(
            opacity: f.envelope,
            child: CustomPaint(
              painter: _EnvelopeBackPainter(
                flapDepth: flapDepth < 0 ? flapDepth : null,
              ),
            ),
          ),
        ),
      if (photo != null && f.photo > 0)
        Positioned(
          left: (w - photoSize) / 2,
          top: photoTop,
          width: photoSize,
          child: Transform.rotate(
            angle: -0.04 * f.photo,
            child: _Polaroid(bytes: photo!),
          ),
        ),
      if (!(letterInside && f.envelope >= 1 && f.flapClosed >= 1))
        Positioned(
          left: sheetLeft,
          top: sheetTop,
          width: lw,
          height: ph * 3,
          child: Transform.scale(
            scale: letterScale,
            child: GestureDetector(
              onTap: onLetterTap,
              child: Semantics(
                button: onLetterTap != null,
                label: onLetterTap != null ? 'Read the letter' : null,
                child: _FoldedLetter(
                  width: lw,
                  panel: ph,
                  fold1: f.fold1,
                  fold3: f.fold3,
                  ribbon: f.ribbon,
                  ribbonOff: f.ribbonOff,
                  letter: letter,
                  title: title,
                ),
              ),
            ),
          ),
        ),
      // Envelope front pocket, and the flap once it covers the pocket.
      if (f.envelope > 0)
        Positioned(
          left: envLeft,
          top: envTop,
          width: ew,
          height: eh,
          child: IgnorePointer(
            child: Opacity(
              opacity: f.envelope,
              child: CustomPaint(
                painter: _EnvelopeFrontPainter(
                  flapDepth: flapDepth >= 0 ? flapDepth : null,
                ),
              ),
            ),
          ),
        ),
      if (f.glow > 0)
        Positioned(
          left: sealSpot.dx - w * 0.4,
          top: sealSpot.dy - w * 0.4,
          width: w * 0.8,
          height: w * 0.8,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFBE82).withValues(alpha: 0.38 * f.glow),
                    const Color(0xFFFFA05A).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      if (f.seal > 0 && f.envelope > 0)
        Positioned(
          left: sealSpot.dx - sealSize / 2,
          top:
              sealSpot.dy -
              sealSize / 2 +
              (opening ? (1 - f.seal) * w * 0.04 : 0),
          width: sealSize,
          height: sealSize,
          child: Opacity(
            opacity: f.seal * f.envelope,
            child: Transform.scale(
              scaleX: opening ? 1 : f.pool,
              scaleY: opening ? 1 - (1 - f.seal) * 0.3 : f.pool,
              child: MonogramSeal(
                initial: initial,
                size: sealSize,
                emboss: f.emboss,
                glow: f.sealGlow,
                crack: f.crack,
              ),
            ),
          ),
        ),
      for (var i = 0; i < 3; i++)
        if (f.drops[i] > 0)
          Positioned(
            left: sealSpot.dx - w * 0.02 + (i - 1) * w * 0.012,
            top:
                _lip(w, sealSpot).dy +
                (sealSpot.dy - _lip(w, sealSpot).dy) * f.drops[i] -
                w * 0.03,
            width: w * 0.04,
            height: w * 0.06,
            child: const CustomPaint(painter: _DropPainter()),
          ),
      if (f.candle > 0)
        Positioned(
          left: sealSpot.dx - w * 0.05 + (1 - f.candle) * w * 0.25,
          top: _lip(w, sealSpot).dy - w * 0.08 - (1 - f.candle) * w * 0.2,
          width: w * 0.42,
          height: w * 0.5,
          child: IgnorePointer(
            child: Opacity(
              opacity: f.candle,
              child: CustomPaint(painter: _CandlePainter(flicker: time)),
            ),
          ),
        ),
      if (f.stamp > 0)
        Positioned(
          left: sealSpot.dx - w * 0.09,
          top: -w * 0.1 + (sealSpot.dy - w * 0.3 + w * 0.1) * f.stamp,
          width: w * 0.18,
          height: w * 0.32,
          child: Opacity(
            opacity: f.stamp.clamp(0.0, 1.0) > 0.05 ? 1 : f.stamp * 20,
            child: const CustomPaint(painter: _StampPainter()),
          ),
        ),
    ];

    return ExcludeSemantics(
      excluding: onLetterTap == null,
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(clipBehavior: Clip.none, children: children),
      ),
    );
  }

  /// The candle's lip, where the wax drips from: above the seal spot.
  static Offset _lip(double w, Offset sealSpot) =>
      Offset(sealSpot.dx, sealSpot.dy - w * 0.46);
}

/// The letter as three panels of parchment. The top and bottom thirds fold
/// over the middle (showing the paper's back), a ribbon ties the folded
/// letter, and it can slip off again.
class _FoldedLetter extends StatelessWidget {
  const _FoldedLetter({
    required this.width,
    required this.panel,
    required this.fold1,
    required this.fold3,
    required this.ribbon,
    required this.ribbonOff,
    required this.letter,
    this.title,
  });

  final double width, panel, fold1, fold3, ribbon, ribbonOff;
  final String letter;
  final String? title;

  Widget _face(int index) {
    // One third of the written sheet, the same paper and hand as the
    // opened letter.
    return ClipRect(
      child: SizedBox(
        width: width,
        height: panel,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ParchmentSlice(seed: 31 + index, edge: 0.3),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: -panel * index,
              height: panel * 3,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  width * 0.08,
                  width * 0.07,
                  width * 0.08,
                  width * 0.05,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null && title!.trim().isNotEmpty)
                      Text(
                        title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.display(
                          width * 0.07,
                          color: UsPalette.sepia,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        letter,
                        overflow: TextOverflow.fade,
                        style: AppTypography.capsuleHand(
                          color: UsPalette.sepia,
                          size: width * 0.058,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _back(int index) => SizedBox(
    width: width,
    height: panel,
    child: CustomPaint(painter: _ParchmentSlice(seed: 41 + index, edge: 0.3)),
  );

  Widget _folding(int index, double fold, {required bool top}) {
    final angle = math.pi * 0.985 * fold;
    final showBack = angle > math.pi / 2;
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0016)
      ..rotateX(top ? -angle : angle);
    return Transform(
      alignment: top ? Alignment.bottomCenter : Alignment.topCenter,
      transform: m,
      child: showBack
          // Seen from behind: the paper's plain back, the right way up.
          ? Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(1, -1, 1),
              child: _back(index),
            )
          : _face(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = panel;
    return SizedBox(
      width: width,
      height: p * 3,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, top: p, child: _face(1)),
          Positioned(left: 0, top: 0, child: _folding(0, fold1, top: true)),
          Positioned(
            left: 0,
            top: p * 2,
            child: _folding(2, fold3, top: false),
          ),
          if (ribbon > 0 && ribbonOff < 1)
            Positioned(
              left: width / 2 - width * 0.05,
              top: p,
              width: width * 0.1,
              height: p,
              child: Opacity(
                opacity: 1 - ribbonOff,
                child: Transform.translate(
                  offset: Offset(ribbonOff * width * 0.5, 0),
                  child: Transform.rotate(
                    angle: ribbonOff * 0.3,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: width * 0.1,
                        height: p * ribbon,
                        child: CustomPaint(
                          painter: _RibbonPainter(bow: ribbon),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ParchmentSlice extends CustomPainter {
  const _ParchmentSlice({required this.seed, required this.edge});

  final int seed;
  final double edge;

  @override
  void paint(Canvas canvas, Size size) {
    paintParchment(canvas, size, seed: seed, edge: edge);
    // A faint crease line along the top edge of each fold.
    canvas.drawLine(
      Offset.zero,
      Offset(size.width, 0),
      Paint()
        ..color = UsPalette.sepiaSoft.withValues(alpha: 0.25)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_ParchmentSlice old) =>
      old.seed != seed || old.edge != edge;
}

/// A rose ribbon band with a bow on it.
class _RibbonPainter extends CustomPainter {
  const _RibbonPainter({required this.bow});

  final double bow;

  @override
  void paint(Canvas canvas, Size size) {
    final band = Offset.zero & size;
    canvas.drawRect(
      band,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF7E2446), Color(0xFFB8456F), Color(0xFF7E2446)],
        ).createShader(band),
    );
    if (bow < 0.6) return;
    final k = ((bow - 0.6) / 0.4).clamp(0.0, 1.0);
    final c = Offset(size.width / 2, size.width * 1.4);
    final s = size.width * 1.6 * k;
    final loop = Paint()..color = const Color(0xFFB8456F);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF7E2446);
    for (final side in [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..cubicTo(
          c.dx + side * s * 0.4,
          c.dy - s * 0.55,
          c.dx + side * s,
          c.dy - s * 0.5,
          c.dx + side * s * 0.95,
          c.dy - s * 0.05,
        )
        ..cubicTo(
          c.dx + side * s * 0.9,
          c.dy + s * 0.3,
          c.dx + side * s * 0.4,
          c.dy + s * 0.2,
          c.dx,
          c.dy,
        )
        ..close();
      canvas.drawPath(path, loop);
      canvas.drawPath(path, edge);
      final tail = Path()
        ..moveTo(c.dx + side * s * 0.05, c.dy + s * 0.05)
        ..lineTo(c.dx + side * s * 0.45, c.dy + s * 0.85)
        ..lineTo(c.dx + side * s * 0.3, c.dy + s * 0.8)
        ..lineTo(c.dx + side * s * 0.2, c.dy + s * 0.95)
        ..close();
      canvas.drawPath(tail, Paint()..color = const Color(0xFFA23A62));
    }
    canvas.drawOval(
      Rect.fromCenter(center: c, width: s * 0.32, height: s * 0.28),
      Paint()..color = const Color(0xFF9B3159),
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.bow != bow;
}

/// The back of the envelope (aged paper) and, while it is open, the flap
/// pointing up behind the letter.
class _EnvelopeBackPainter extends CustomPainter {
  const _EnvelopeBackPainter({this.flapDepth});

  /// Negative: the open flap's height above the envelope.
  final double? flapDepth;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    canvas.drawShadow(Path()..addRRect(r), Colors.black, 10, true);
    canvas.save();
    canvas.clipRRect(r);
    paintParchment(canvas, size, seed: 23, edge: 0.45);
    // The inside of an envelope is a touch darker.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = UsPalette.sepiaSoft.withValues(alpha: 0.12),
    );
    canvas.restore();
    final d = flapDepth;
    if (d != null && d < 0) {
      final flap = Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, d)
        ..close();
      canvas.save();
      canvas.clipPath(flap);
      canvas.translate(0, d);
      paintParchment(canvas, Size(size.width, -d), seed: 25, edge: 0.4);
      canvas.restore();
      canvas.drawPath(
        flap,
        Paint()..color = UsPalette.sepiaSoft.withValues(alpha: 0.14),
      );
      canvas.drawPath(
        flap,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = UsPalette.sepiaSoft.withValues(alpha: 0.4),
      );
    }
  }

  @override
  bool shouldRepaint(_EnvelopeBackPainter old) => old.flapDepth != flapDepth;
}

/// The envelope's front pocket (two side folds and the bottom fold), and
/// the flap folded down over it once it is past upright.
class _EnvelopeFrontPainter extends CustomPainter {
  const _EnvelopeFrontPainter({this.flapDepth});

  final double? flapDepth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final pocket = Path()
      ..moveTo(0, h * 0.18)
      ..lineTo(w / 2, h * 0.6)
      ..lineTo(w, h * 0.18)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.save();
    canvas.clipPath(pocket);
    paintParchment(canvas, size, seed: 27, edge: 0.45);
    // Fold shading: the bottom fold catches less light.
    canvas.drawPath(
      Path()
        ..moveTo(0, h)
        ..lineTo(w / 2, h * 0.6)
        ..lineTo(w, h)
        ..close(),
      Paint()..color = UsPalette.sepiaSoft.withValues(alpha: 0.08),
    );
    canvas.restore();
    final crease = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = UsPalette.sepiaSoft.withValues(alpha: 0.35);
    canvas.drawLine(Offset(0, h * 0.18), Offset(w / 2, h * 0.6), crease);
    canvas.drawLine(Offset(w, h * 0.18), Offset(w / 2, h * 0.6), crease);
    canvas.drawLine(Offset(0, h), Offset(w / 2, h * 0.6), crease);
    canvas.drawLine(Offset(w, h), Offset(w / 2, h * 0.6), crease);

    final d = flapDepth;
    if (d != null && d > 0) {
      final flap = Path()
        ..moveTo(0, 0)
        ..lineTo(w, 0)
        ..lineTo(w / 2, d)
        ..close();
      canvas.drawShadow(flap, Colors.black, 4, false);
      canvas.save();
      canvas.clipPath(flap);
      paintParchment(canvas, Size(w, math.max(d, 1)), seed: 29, edge: 0.4);
      canvas.restore();
      canvas.drawPath(flap, crease);
    }
  }

  @override
  bool shouldRepaint(_EnvelopeFrontPainter old) => old.flapDepth != flapDepth;
}

/// A cream photo print with a soft shadow.
class _Polaroid extends StatelessWidget {
  const _Polaroid({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(6, 6, 6, 18),
    decoration: BoxDecoration(
      color: UsPalette.cream,
      borderRadius: BorderRadius.circular(3),
      boxShadow: const [
        BoxShadow(
          color: Color(0x73000000),
          blurRadius: 14,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: AspectRatio(
      aspectRatio: 1,
      child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
    ),
  );
}

/// A lit candle, tipped to pour: cream wax with a run down its side, a
/// wick, a flame and its warm halo. [flicker] is the timeline position.
class _CandlePainter extends CustomPainter {
  const _CandlePainter({required this.flicker});

  final double flicker;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // The lip sits at the top left; the candle leans down to the right.
    final lip = Offset(w * 0.12, h * 0.16);
    canvas.drawCircle(
      lip,
      w * 0.45,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFBE7A).withValues(alpha: 0.35),
            const Color(0xFFFFBE7A).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: lip, radius: w * 0.45)),
    );
    canvas.save();
    canvas.translate(lip.dx, lip.dy);
    canvas.rotate(-0.66); // about 38 degrees
    final bw = w * 0.2, bh = h * 0.78;
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(-bw / 2, 0, bw, bh),
      topLeft: Radius.circular(bw * 0.15),
      topRight: Radius.circular(bw * 0.15),
      bottomLeft: Radius.circular(bw * 0.1),
      bottomRight: Radius.circular(bw * 0.1),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFC9B79A),
            Color(0xFFF4EAD6),
            Color(0xFFFFF7EA),
            Color(0xFFE9DCC4),
            Color(0xFFBBA88A),
          ],
          stops: [0, 0.35, 0.5, 0.7, 1],
        ).createShader(body.outerRect),
    );
    // A run of melted wax down the side.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-bw / 2 + bw * 0.08, 0, bw * 0.3, bh * 0.24),
        Radius.circular(bw * 0.15),
      ),
      Paint()..color = const Color(0xFFFFF6E6),
    );
    // Wick and flame (pointing back up, against the tilt).
    canvas.drawLine(
      Offset.zero,
      Offset(0, -bw * 0.35),
      Paint()
        ..color = const Color(0xFF2A1A12)
        ..strokeWidth = 2,
    );
    canvas.save();
    canvas.translate(0, -bw * 0.35);
    canvas.rotate(0.66 + math.sin(flicker * 90) * 0.06);
    final fl = 1 + math.sin(flicker * 130) * 0.05;
    final flame = Path()
      ..moveTo(0, 0)
      ..cubicTo(
        bw * 0.4,
        -bw * 0.3 * fl,
        bw * 0.15,
        -bw * 0.9 * fl,
        0,
        -bw * 1.25 * fl,
      )
      ..cubicTo(-bw * 0.15, -bw * 0.9 * fl, -bw * 0.4, -bw * 0.3 * fl, 0, 0)
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, 0.6),
          colors: [Color(0xFFFFFFFF), Color(0xFFFFE7A6), Color(0xFFFFB347)],
          stops: [0, 0.35, 1],
        ).createShader(flame.getBounds())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CandlePainter old) => old.flicker != flicker;
}

/// A drop of wax with a thin trail above it.
class _DropPainter extends CustomPainter {
  const _DropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.42, 0, w * 0.16, h * 0.45),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [OldWax.face, OldWax.face.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.45)),
    );
    final drop = Path()
      ..moveTo(w / 2, h * 0.35)
      ..cubicTo(w * 0.95, h * 0.7, w * 0.85, h, w / 2, h)
      ..cubicTo(w * 0.15, h, w * 0.05, h * 0.7, w / 2, h * 0.35)
      ..close();
    canvas.drawPath(
      drop,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, 0.2),
          colors: [OldWax.light, OldWax.face, OldWax.dark],
        ).createShader(drop.getBounds()),
    );
  }

  @override
  bool shouldRepaint(_DropPainter old) => false;
}

/// A brass seal stamp with a dark wooden handle.
class _StampPainter extends CustomPainter {
  const _StampPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final handle = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.3, 0, w * 0.4, h * 0.66),
      topLeft: Radius.circular(w * 0.2),
      topRight: Radius.circular(w * 0.2),
    );
    canvas.drawRRect(
      handle,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF3B2116), Color(0xFF6E4630), Color(0xFF3B2116)],
        ).createShader(handle.outerRect),
    );
    final brass = const LinearGradient(
      colors: [Color(0xFF8C6A2E), Color(0xFFF1D98C), Color(0xFF8C6A2E)],
    );
    final collar = Rect.fromLTWH(w * 0.18, h * 0.64, w * 0.64, h * 0.1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(collar, Radius.circular(w * 0.05)),
      Paint()..shader = brass.createShader(collar),
    );
    final face = Rect.fromLTWH(0, h * 0.72, w, h * 0.22);
    canvas.drawShadow(Path()..addRect(face), Colors.black, 4, false);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        face,
        bottomLeft: Radius.circular(w * 0.14),
        bottomRight: Radius.circular(w * 0.14),
        topLeft: Radius.circular(w * 0.06),
        topRight: Radius.circular(w * 0.06),
      ),
      Paint()..shader = brass.createShader(face),
    );
  }

  @override
  bool shouldRepaint(_StampPainter old) => false;
}
