import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../effects/motion.dart';
import 'wax_seal.dart';

/// Cream paper tones for the envelope (the same in light and dark mode:
/// it is a paper object, not a surface).
class PaperColors {
  PaperColors._();

  static const back = Color(0xFFEADBC6);
  static const pocket = Color(0xFFF4E8D8);
  static const flap = Color(0xFFF0E2CE);
  static const flapInside = Color(0xFFE2CFB4);
  static const edge = Color(0xFFD3BC9D);
  static const letter = Color(0xFFFFFCF6);
  static const ink = Color(0xFF3B2A33);
  static const rule = Color(0xFFEADFCF);
}

/// A cream paper envelope, drawn at any point between sealed and opened.
///
/// [flap] 0 = closed, 1 = folded open. [letterOut] 0 = inside, 1 = slid
/// out about half its height. The wax seal sits on the flap's tip while
/// the flap is closed: [seal] 0 = none, 1 = pressed; [sealCrack] breaks it.
/// The space above the envelope is reserved for the flap and letter.
class CapsuleEnvelope extends StatelessWidget {
  const CapsuleEnvelope({
    super.key,
    required this.width,
    this.flap = 0,
    this.letterOut = 0,
    this.seal = 1,
    this.sealScale = 1,
    this.sealCrack = 0,
    this.photo,
    this.onLetterTap,
    this.letterLabel,
  });

  final double width;
  final double flap;
  final double letterOut;
  final double seal;
  final double sealScale;
  final double sealCrack;

  /// A photo peeking out behind the letter (opening only).
  final Uint8List? photo;
  final VoidCallback? onLetterTap;
  final String? letterLabel;

  static double heightFor(double width) => width * 0.66 * 1.6;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = w * 0.66; // the envelope itself
    final head = h * 0.6; // room above it
    final fold = math.cos(
      math.pi * flap.clamp(0.0, 1.0),
    ); // 1 closed .. -1 open
    final apexDepth = h * 0.56;
    final letterTop = head + h * 0.08 - letterOut * h * 0.6;

    final letter = Positioned(
      left: w * 0.07,
      width: w * 0.86,
      top: letterTop,
      height: h * 0.86,
      child: GestureDetector(
        onTap: onLetterTap,
        child: Semantics(
          button: onLetterTap != null,
          label: letterLabel,
          child: Container(
            decoration: BoxDecoration(
              color: PaperColors.letter,
              borderRadius: BorderRadius.circular(w * 0.012),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: w * 0.02,
                ),
              ],
            ),
            child: CustomPaint(painter: _RulesPainter()),
          ),
        ),
      ),
    );

    final photoBytes = photo;
    return SizedBox(
      width: w,
      height: head + h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: head,
            height: h,
            child: CustomPaint(
              painter: _BackPainter(fold: fold, apexDepth: apexDepth),
            ),
          ),
          if (photoBytes != null && letterOut > 0)
            Positioned(
              left: w * 0.54,
              width: w * 0.34,
              top: head + h * 0.1 - letterOut * h * 1.05,
              height: w * 0.34,
              child: Transform.rotate(
                angle: 0.09,
                child: Container(
                  padding: EdgeInsets.all(w * 0.012),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: w * 0.02,
                      ),
                    ],
                  ),
                  child: Image.memory(
                    photoBytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          letter,
          Positioned(
            left: 0,
            right: 0,
            top: head,
            height: h,
            child: IgnorePointer(child: CustomPaint(painter: _PocketPainter())),
          ),
          if (fold > 0)
            Positioned(
              left: 0,
              right: 0,
              top: head,
              height: h,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FlapPainter(depth: apexDepth * fold),
                ),
              ),
            ),
          if (seal > 0 && fold > 0)
            Positioned(
              left: w / 2 - w * 0.11,
              top: head + apexDepth * fold - w * 0.11,
              width: w * 0.22,
              height: w * 0.22,
              child: IgnorePointer(
                child: Opacity(
                  opacity: seal.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: sealScale,
                    child: WaxSeal(size: w * 0.22, crack: sealCrack),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RulesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = PaperColors.rule
      ..strokeWidth = math.max(1, size.width * 0.004);
    final gap = size.height / 9;
    for (var i = 2; i < 8; i++) {
      final y = gap * i;
      canvas.drawLine(
        Offset(size.width * 0.1, y),
        Offset(size.width * (i == 7 ? 0.6 : 0.9), y),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The back of the envelope, and the flap when it is folded open behind.
class _BackPainter extends CustomPainter {
  _BackPainter({required this.fold, required this.apexDepth});

  final double fold;
  final double apexDepth;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.02),
    );
    canvas.drawShadow(
      Path()..addRRect(r),
      Colors.black,
      size.width * 0.02,
      false,
    );
    canvas.drawRRect(r, Paint()..color = PaperColors.back);
    if (fold < 0) {
      final tip = Offset(size.width / 2, apexDepth * fold);
      final flap = Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(tip.dx, tip.dy)
        ..close();
      canvas.drawPath(flap, Paint()..color = PaperColors.flapInside);
      canvas.drawPath(
        flap,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = PaperColors.edge,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackPainter old) =>
      old.fold != fold || old.apexDepth != apexDepth;
}

/// The front pocket: the two side folds and the bottom fold.
class _PocketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final meet = Offset(w / 2, h * 0.52);
    final pocket = Path()
      ..moveTo(0, h * 0.02)
      ..lineTo(meet.dx, meet.dy)
      ..lineTo(w, h * 0.02)
      ..lineTo(w, h - w * 0.02)
      ..quadraticBezierTo(w, h, w - w * 0.02, h)
      ..lineTo(w * 0.02, h)
      ..quadraticBezierTo(0, h, 0, h - w * 0.02)
      ..close();
    canvas.drawPath(pocket, Paint()..color = PaperColors.pocket);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, w * 0.003)
      ..color = PaperColors.edge;
    canvas.drawLine(Offset(0, h), meet, edge);
    canvas.drawLine(Offset(w, h), meet, edge);
    canvas.drawLine(
      Offset(0, h * 0.02),
      meet,
      edge..color = PaperColors.edge.withValues(alpha: 0.6),
    );
    canvas.drawLine(Offset(w, h * 0.02), meet, edge);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The flap, folded down over the pocket by [depth].
class _FlapPainter extends CustomPainter {
  _FlapPainter({required this.depth});

  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    final flap = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, depth)
      ..close();
    canvas.drawShadow(flap, Colors.black, size.width * 0.01, false);
    canvas.drawPath(
      flap,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF6EBDC), PaperColors.flap],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      flap,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, size.width * 0.003)
        ..color = PaperColors.edge,
    );
  }

  @override
  bool shouldRepaint(covariant _FlapPainter old) => old.depth != depth;
}

/// What a small envelope on a card shows.
enum EnvelopeLook { draft, sealed, ready, opened }

/// A small envelope for cards. A ready capsule's seal breathes gently
/// (still, with reduce motion). [pressKey] changes trigger one soft press
/// of the seal: the moment a capsule is sealed for good.
class MiniEnvelope extends StatefulWidget {
  const MiniEnvelope({
    super.key,
    required this.look,
    this.width = 72,
    this.pressKey,
  });

  final EnvelopeLook look;
  final double width;
  final Object? pressKey;

  @override
  State<MiniEnvelope> createState() => _MiniEnvelopeState();
}

class _MiniEnvelopeState extends State<MiniEnvelope>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(MiniEnvelope old) {
    super.didUpdateWidget(old);
    _syncPulse();
    if (old.pressKey != widget.pressKey &&
        widget.pressKey != null &&
        !motionOff(context)) {
      _press.forward(from: 0);
    }
  }

  void _syncPulse() {
    final want = widget.look == EnvelopeLook.ready && !motionOff(context);
    if (want && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!want && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _press]),
        builder: (context, _) {
          final press = _press.isAnimating
              ? 1 +
                    0.12 *
                        math.sin(
                          math.pi * Curves.easeOut.transform(_press.value),
                        )
              : 1.0;
          final pulse = 1 + 0.07 * Curves.easeInOut.transform(_pulse.value);
          return CapsuleEnvelope(
            width: widget.width,
            flap: switch (look) {
              EnvelopeLook.draft || EnvelopeLook.opened => 1,
              _ => 0,
            },
            letterOut: switch (look) {
              EnvelopeLook.draft => 0.25,
              EnvelopeLook.opened => 0.5,
              _ => 0,
            },
            seal: look == EnvelopeLook.sealed || look == EnvelopeLook.ready
                ? 1
                : 0,
            sealScale: pulse * press,
          );
        },
      ),
    );
  }
}

/// The first opening: the seal cracks, the flap opens, and the letter slides
/// partly out (the photo, if any, peeking behind it). Tapping the letter
/// calls [onReveal]. With reduce motion it starts already open.
class EnvelopeOpening extends StatefulWidget {
  const EnvelopeOpening({
    super.key,
    required this.width,
    required this.onReveal,
    this.photo,
  });

  final double width;
  final VoidCallback onReveal;
  final Uint8List? photo;

  @override
  State<EnvelopeOpening> createState() => _EnvelopeOpeningState();
}

class _EnvelopeOpeningState extends State<EnvelopeOpening>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
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

  static bool _keyboardFocused(Set<WidgetState> states) =>
      states.contains(WidgetState.focused) &&
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  double _span(double from, double to, [Curve curve = Curves.easeInOutCubic]) =>
      curve.transform(((_c.value - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final shake = _c.value < 0.16
            ? math.sin(_c.value * 120) * (1 - _c.value / 0.16) * 0.06
            : 0.0;
        final done = _c.isCompleted;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: shake,
              child: CapsuleEnvelope(
                width: widget.width,
                sealCrack: _span(0.12, 0.28, Curves.easeOut),
                seal: 1 - _span(0.26, 0.4),
                flap: _span(0.3, 0.58),
                letterOut: 0.8 * _span(0.58, 0.92, Curves.easeOutCubic),
                photo: widget.photo,
                onLetterTap: done ? widget.onReveal : null,
                letterLabel: 'Read the letter',
              ),
            ),
            const SizedBox(height: 16),
            AnimatedOpacity(
              opacity: done ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              child: TextButton.icon(
                onPressed: done ? widget.onReveal : null,
                // A clear ring for keyboard focus (the default overlay is
                // faint on the dark background). Only when focus came from
                // the keyboard, so a mouse or touch never shows it.
                style: ButtonStyle(
                  side: WidgetStateProperty.resolveWith(
                    (states) => _keyboardFocused(states)
                        ? BorderSide(color: theme.colorScheme.primary, width: 3)
                        : BorderSide.none,
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => _keyboardFocused(states)
                        ? theme.colorScheme.primary.withValues(alpha: 0.16)
                        : null,
                  ),
                ),
                icon: const Icon(Icons.touch_app_outlined),
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

/// The sealing moment: the letter slides into the envelope, the flap closes
/// and the wax seal is pressed down. Calls [onDone] when finished. With
/// reduce motion it shows the sealed envelope straight away.
class EnvelopeSealing extends StatefulWidget {
  const EnvelopeSealing({super.key, required this.width, required this.onDone});

  final double width;
  final VoidCallback onDone;

  @override
  State<EnvelopeSealing> createState() => _EnvelopeSealingState();
}

class _EnvelopeSealingState extends State<EnvelopeSealing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
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

  double _span(double from, double to, [Curve curve = Curves.easeInOutCubic]) =>
      curve.transform(((_c.value - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final stamp = _span(0.62, 0.8, Curves.easeOutBack);
        final impact = _c.value > 0.74 && _c.value < 0.84
            ? math.sin((_c.value - 0.74) / 0.1 * math.pi) * 3
            : 0.0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(0, impact),
              child: CapsuleEnvelope(
                width: widget.width,
                letterOut: 0.8 * (1 - _span(0.0, 0.32)),
                flap: 1 - _span(0.32, 0.6),
                seal: _span(0.6, 0.7),
                sealScale: 1.8 - 0.8 * stamp,
              ),
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: _span(0.82, 1),
              child: Column(
                children: [
                  Text('Sealed', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _c.value >= 0.82 ? widget.onDone : null,
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
