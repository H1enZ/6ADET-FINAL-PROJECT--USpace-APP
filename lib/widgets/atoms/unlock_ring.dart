import 'package:flutter/material.dart';

/// Progress ring that fills as a wait goes by: the time to the next
/// anniversary now, and a Time Capsule's unlock later.
class UnlockRing extends StatelessWidget {
  const UnlockRing({
    super.key,
    required this.elapsedFraction,
    this.size = 88,
    this.strokeWidth = 7,
    this.color,
    this.trackColor,
    this.child,
  });

  /// 0.0 = just started waiting, 1.0 = done.
  final double elapsedFraction;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: elapsedFraction.clamp(0.0, 1.0).toDouble(),
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              color: color ?? scheme.primary,
              backgroundColor: trackColor ?? scheme.primaryContainer,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}
