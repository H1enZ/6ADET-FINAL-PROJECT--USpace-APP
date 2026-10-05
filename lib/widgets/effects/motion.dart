import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../../theme/app_effects.dart';
import 'floating_hearts.dart';

// USpace motion: "playful but quick". Everyday movement is short and calm
// (150-450 ms); celebrations (hugs, confetti, the wax seal) are bouncier.
// Everything here checks the device's "reduce motion" setting first and
// shows the calm, still version when it is on.

// disableAnimationsOf listens to this one setting only, so callers do not
// rebuild on unrelated MediaQuery changes (e.g. the keyboard opening).
bool motionOff(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// Fades and slides a child in once, when it first appears. Give each item
/// in a list a growing [index] so they arrive one after another.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.from = const Offset(0, 18),
  });

  final Widget child;
  final int index;
  final Offset from;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // With reduce motion it is simply there: no delay, no frames spent.
    if (motionOff(context)) {
      _c.value = 1;
      return;
    }
    final delay = Duration(milliseconds: 55 * math.min(widget.index, 8));
    Future<void>.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = motionOff(context);
    // Always the same widgets, so switching reduce motion never rebuilds the
    // child (a focused text field keeps focus). FadeTransition changes the
    // layer's opacity without repainting what is inside it.
    return FadeTransition(
      opacity: still ? kAlwaysCompleteAnimation : _t,
      child: AnimatedBuilder(
        animation: _t,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: still ? Offset.zero : widget.from * (1 - _t.value),
          child: child,
        ),
      ),
    );
  }
}

/// Wraps each child so a column of cards arrives one after another.
/// A child's key is carried onto its wrapper, so keyed sections keep their
/// state (and don't fade in again) when something appears above them.
List<Widget> staggered(List<Widget> children) => [
      for (var i = 0; i < children.length; i++)
        FadeSlideIn(
          key: children[i].key == null ? null : ValueKey(children[i].key),
          index: i,
          child: children[i],
        ),
    ];

/// Shrinks its child a little while a finger or mouse is pressed on it, so
/// a tap feels heard the moment it lands. It only listens to the pointer and
/// never takes part in the gesture, so taps, long-presses and scrolling
/// underneath work exactly as before. Still with reduced motion.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true, this.scale = 0.97});

  final Widget child;

  /// False for a disabled control: no feedback for a press that does nothing.
  final bool enabled;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;
  Offset? _origin;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  // Once the finger travels it is a scroll or a drag, not a press: let go,
  // so a card doesn't stay shrunk while the list scrolls under it.
  void _moved(PointerMoveEvent e) {
    final origin = _origin;
    if (_down && origin != null && (e.position - origin).distance > kTouchSlop) {
      _set(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !motionOff(context);
    final pressed = active && _down;
    return Listener(
      onPointerDown: active
          ? (e) {
              _origin = e.position;
              _set(true);
            }
          : null,
      onPointerMove: _moved,
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: pressed ? widget.scale : 1,
        // Down quickly, release a little slower: the press feels immediate,
        // the settle feels soft.
        duration: pressed ? AppMotion.pressIn : AppMotion.pressOut,
        curve: AppMotion.snappy,
        child: widget.child,
      ),
    );
  }
}

/// A quick "pop" every time [trigger] changes (not on first build). With
/// [bounce] it settles with a little wobble, for rare happy moments; without
/// it, a calm settle that suits something you do many times a day.
class PopOnChange extends StatefulWidget {
  const PopOnChange({
    super.key,
    required this.trigger,
    required this.child,
    this.scale = 1.3,
    this.bounce = true,
  });

  final Object? trigger;
  final Widget child;
  final double scale;
  final bool bounce;

  @override
  State<PopOnChange> createState() => _PopOnChangeState();
}

class _PopOnChangeState extends State<PopOnChange> with SingleTickerProviderStateMixin {
  // Made in initState, not lazily: with reduce motion build() never touches
  // it, and a lazy controller first created in dispose() throws.
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  }

  @override
  void didUpdateWidget(PopOnChange old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && !motionOff(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (motionOff(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        // up quickly, then settle back
        final t = _c.value;
        final settle = widget.bounce ? Curves.elasticOut : AppMotion.snappy;
        final s = t < 0.35
            ? 1 + (widget.scale - 1) * Curves.easeOut.transform(t / 0.35)
            : 1 + (widget.scale - 1) * (1 - settle.transform((t - 0.35) / 0.65));
        return Transform.scale(scale: _c.isAnimating ? s : 1, child: child);
      },
    );
  }
}

/// A heart icon that pops when it becomes filled.
class AnimatedHeartIcon extends StatelessWidget {
  const AnimatedHeartIcon({super.key, required this.filled, this.size, this.color, this.emptyColor});

  final bool filled;
  final double? size;
  final Color? color;
  final Color? emptyColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopOnChange(
      trigger: filled,
      scale: filled ? 1.45 : 1,
      child: Icon(
        filled ? Icons.favorite : Icons.favorite_border,
        size: size,
        color: filled ? (color ?? scheme.primary) : emptyColor,
      ),
    );
  }
}

/// Counts up to a number (e.g. "262" days) the first time it shows.
/// Text that is not a whole number is shown as it is.
class CountUpText extends StatelessWidget {
  const CountUpText(this.text, {super.key, this.style, this.maxLines});

  final String text;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final target = int.tryParse(text);
    if (target == null || target <= 0 || motionOff(context)) {
      return Text(text, style: style, maxLines: maxLines);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target.toDouble()),
      duration: Duration(milliseconds: math.min(1200, 400 + target)),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: style, maxLines: maxLines),
    );
  }
}

/// A progress bar that fills smoothly to [value].
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.minHeight = 6,
  });

  final double value;
  final Color color;
  final Color backgroundColor;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    Widget bar(double v) => LinearProgressIndicator(
          value: v,
          minHeight: minHeight,
          color: color,
          backgroundColor: backgroundColor,
        );
    if (motionOff(context)) return bar(value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => bar(v),
    );
  }
}

/// Grey placeholder cards with a moving shine, shown while loading.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 4, this.height = 110});

  final int count;
  final double height;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300));

  // The shimmer only runs when motion is on; with reduce motion it stays
  // still instead of ticking every frame.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionOff(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final shine = scheme.primaryContainer;
    final still = motionOff(context);
    return Semantics(
      label: 'Loading',
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: widget.count,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final x = still ? 0.0 : _c.value * 3 - 1.5;
                  return Container(
                    height: i == 0 ? widget.height * 1.4 : widget.height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment(x - 1, 0),
                        end: Alignment(x + 1, 0),
                        colors: [base, shine, base],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

OverlayEntry? _insert(BuildContext context, Widget Function(VoidCallback done) build) {
  if (motionOff(context)) return null;
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return null;
  late final OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => IgnorePointer(child: build(() => entry.remove())));
  overlay.insert(entry);
  return entry;
}

/// A hug, kiss or cuddle: the emoji grows big in the middle, pulses like a
/// heartbeat, then floats away with hearts.
void showGesturePulse(BuildContext context, String emoji) {
  final entry = _insert(context, (done) => _Pulse(emoji: emoji, onDone: done));
  if (entry == null) return; // reduced motion: nothing moves
  Future<void>.delayed(const Duration(milliseconds: 650), () {
    if (context.mounted) showFloatingHearts(context, emoji: emoji);
  });
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.emoji, required this.onDone});
  final String emoji;
  final VoidCallback onDone;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final grow = Curves.elasticOut.transform((t / 0.4).clamp(0.0, 1.0));
        final beat = t > 0.4 && t < 0.8 ? 1 + 0.12 * math.sin((t - 0.4) / 0.4 * 2 * math.pi * 2).abs() : 1.0;
        final fade = t < 0.8 ? 1.0 : 1 - (t - 0.8) / 0.2;
        return Center(
          child: Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: grow * beat,
              child: Text(widget.emoji, style: const TextStyle(fontSize: 120)),
            ),
          ),
        );
      },
    );
  }
}

/// An envelope that flies up and away after sending a love note.
void showEnvelopeFly(BuildContext context, {String emoji = '💌'}) {
  _insert(context, (done) => _EnvelopeFly(emoji: emoji, onDone: done));
}

class _EnvelopeFly extends StatefulWidget {
  const _EnvelopeFly({required this.emoji, required this.onDone});
  final String emoji;
  final VoidCallback onDone;
  @override
  State<_EnvelopeFly> createState() => _EnvelopeFlyState();
}

class _EnvelopeFlyState extends State<_EnvelopeFly> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInCubic.transform(_c.value);
        final appear = Curves.easeOutBack.transform((_c.value / 0.25).clamp(0.0, 1.0));
        return Stack(
          children: [
            Positioned(
              left: size.width / 2 - 40 + t * size.width * 0.45,
              top: size.height * 0.62 - t * size.height * 0.75,
              child: Opacity(
                opacity: (1 - t * 0.9).clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: -0.25 + t * 0.6,
                  child: Transform.scale(
                    scale: appear * (1 - t * 0.4),
                    child: Text(widget.emoji, style: const TextStyle(fontSize: 80)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Confetti falling across the screen, in the app's colours.
void showConfetti(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final colors = [scheme.primary, scheme.secondary, scheme.tertiary, const Color(0xFFE8B04B), scheme.primaryContainer];
  _insert(context, (done) => _Confetti(colors: colors, onDone: done));
}

class _Piece {
  _Piece(math.Random r, this.color)
      : x = r.nextDouble(),
        delay = r.nextDouble() * 0.25,
        speed = 0.7 + r.nextDouble() * 0.6,
        drift = (r.nextDouble() - 0.5) * 0.3,
        spin = (r.nextDouble() - 0.5) * 12,
        w = 6 + r.nextDouble() * 6,
        h = 10 + r.nextDouble() * 8;
  final double x, delay, speed, drift, spin, w, h;
  final Color color;
}

class _Confetti extends StatefulWidget {
  const _Confetti({required this.colors, required this.onDone});
  final List<Color> colors;
  final VoidCallback onDone;
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final List<_Piece> _pieces;
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    _pieces = [for (var i = 0; i < 90; i++) _Piece(r, widget.colors[i % widget.colors.length])];
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) =>
          SizedBox.expand(child: CustomPaint(painter: _ConfettiPainter(_pieces, _c.value))),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * local * size.height * 1.1 * p.speed + local * 40;
      final x = (p.x + p.drift * local + 0.03 * math.sin(local * 10 + p.x * 6)) * size.width;
      paint.color = p.color.withValues(alpha: local > 0.85 ? (1 - local) / 0.15 : 1);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h * (0.4 + 0.6 * math.cos(local * 8).abs())), const Radius.circular(2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
