import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/us_palette.dart';
import '../atoms/us_icon.dart';

/// A short burst of hearts floating up over the screen, e.g. after sending
/// a hug. Skipped when the device asks for reduced motion.
void showFloatingHearts(
  BuildContext context, {
  UsIconData icon = UsIcons.heart,
}) {
  if (MediaQuery.of(context).disableAnimations) return;
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _HeartBurst(icon: icon, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _HeartBurst extends StatefulWidget {
  const _HeartBurst({required this.icon, required this.onDone});

  final UsIconData icon;
  final VoidCallback onDone;

  @override
  State<_HeartBurst> createState() => _HeartBurstState();
}

class _Heart {
  _Heart(math.Random r)
      : x = 0.15 + r.nextDouble() * 0.7,
        delay = r.nextDouble() * 0.35,
        drift = (r.nextDouble() - 0.5) * 0.15,
        size = 22 + r.nextDouble() * 18;

  final double x;
  final double delay;
  final double drift;
  final double size;
}

class _HeartBurstState extends State<_HeartBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _hearts = <_Heart>[];

  @override
  void initState() {
    super.initState();
    final random = math.Random();
    for (var i = 0; i < 12; i++) {
      _hearts.add(_Heart(random));
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) => AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Stack(
            children: [
              for (final h in _hearts)
                () {
                  final t = ((_controller.value - h.delay) / (1 - h.delay))
                      .clamp(0.0, 1.0)
                      .toDouble();
                  return Positioned(
                    left: (h.x + h.drift * t) * box.maxWidth,
                    bottom: box.maxHeight * (0.1 + 0.55 * t),
                    child: Opacity(
                      opacity: t == 0 ? 0 : (1 - t),
                      child: Transform.scale(
                        scale: 0.6 + 0.6 * t,
                        child: UsIcon(
                          widget.icon,
                          size: h.size,
                          color: UsPalette.roseLight,
                        ),
                      ),
                    ),
                  );
                }(),
            ],
          ),
        ),
      ),
    );
  }
}
