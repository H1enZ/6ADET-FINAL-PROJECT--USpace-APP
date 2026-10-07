import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../capsule/wax_seal.dart';
import 'motion.dart';
import '../atoms/us_icon.dart';

/// The moment a Time Capsule opens: the envelope appears, the wax seal
/// shakes and cracks, the flap opens and the note slides out. Tap "Read it"
/// to close. Skipped (the note simply appears) when motion is reduced.
Future<void> showSealOpening(
  BuildContext context, {
  required String fromName,
  required String preview,
  String? teaser,
}) async {
  if (motionOff(context)) return;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, _, _) =>
        _SealOpening(fromName: fromName, preview: preview, teaser: teaser),
  );
}

class _SealOpening extends StatefulWidget {
  const _SealOpening({required this.fromName, required this.preview, this.teaser});

  final String fromName;
  final String preview;
  final String? teaser;

  @override
  State<_SealOpening> createState() => _SealOpeningState();
}

class _SealOpeningState extends State<_SealOpening> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 0..1 progress of [t] inside the window [a]..[b].
  double _phase(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const w = 280.0, envH = 170.0;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final appear = Curves.easeOutBack.transform(_phase(t, 0, 0.18));
            final shake = t > 0.18 && t < 0.38 ? math.sin(_phase(t, 0.18, 0.38) * math.pi * 6) * 0.12 : 0.0;
            final cracked = t >= 0.38;
            final sealGone = Curves.easeIn.transform(_phase(t, 0.42, 0.55));
            final flap = Curves.easeInOut.transform(_phase(t, 0.5, 0.66)); // 0 closed, 1 open
            final rise = Curves.easeOutCubic.transform(_phase(t, 0.62, 0.88));
            final button = _phase(t, 0.88, 1);

            return SizedBox(
              width: w,
              height: 520,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // the note, rising out of the envelope
                  Positioned(
                    bottom: 110 + rise * 150,
                    child: Opacity(
                      opacity: rise,
                      child: Container(
                        width: w - 28,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.teaser ?? 'A time capsule',
                                style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary)),
                            const SizedBox(height: 2),
                            Text('From ${widget.fromName}', style: theme.textTheme.labelSmall),
                            const SizedBox(height: 8),
                            Text(widget.preview,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // the envelope body (in front of the note's lower part)
                  Positioned(
                    bottom: 70,
                    child: Transform.scale(
                      scale: appear,
                      child: SizedBox(
                        width: w,
                        height: envH,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: scheme.secondary,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14)],
                              ),
                            ),
                            // the flap: folds up and over as it opens
                            Transform(
                              alignment: Alignment.topCenter,
                              transform: Matrix4.diagonal3Values(1, 1 - 2 * flap, 1),
                              child: CustomPaint(
                                size: const Size(w, envH * 0.55),
                                painter: _FlapPainter(
                                    Color.lerp(scheme.secondary, Colors.black, 0.18)!),
                              ),
                            ),
                            // the wax seal
                            Positioned(
                              top: envH * 0.55 - 34,
                              child: Opacity(
                                opacity: 1 - sealGone,
                                child: Transform.rotate(
                                  angle: shake,
                                  child: Transform.scale(
                                    scale: 1 + sealGone * 0.5,
                                    child: WaxSeal(size: 68, crack: cracked ? 0.5 : 0),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // "Read it"
                  Positioned(
                    bottom: 0,
                    child: Opacity(
                      opacity: button,
                      child: FilledButton.icon(
                        onPressed: button < 0.5 ? null : () => Navigator.of(context).pop(),
                        icon: const UsIcon(UsIcons.mail, size: 20),
                        label: const Text('Read it'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FlapPainter extends CustomPainter {
  _FlapPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FlapPainter old) => old.color != color;
}
