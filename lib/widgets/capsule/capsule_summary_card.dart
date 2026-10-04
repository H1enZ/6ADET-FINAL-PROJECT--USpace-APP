import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../effects/motion.dart';
import '../effects/soft_hearts_background.dart' show heartPath;
import '../notes/note_style.dart';

/// Where a Time Capsule is in its life, as shown on its card.
enum CapsuleCardState { sealed, grace, ready, opened }

/// One Time Capsule as a plum card: a glossy wax seal on the left, then a
/// status chip, a big headline (the countdown, or "Ready to open"), a
/// subtitle, and who / when lines, with a chevron on the right. The same
/// card in every state, so a capsule in its ten editable minutes looks like
/// itself with buttons added.
///
/// The card only shows what the caller passes in: callers must never pass a
/// sealed capsule's hidden title (see [subtitle]).
class CapsuleSummaryCard extends StatelessWidget {
  const CapsuleSummaryCard({
    super.key,
    required this.state,
    required this.headlineLead,
    required this.headlineAccent,
    required this.subtitle,
    required this.person,
    required this.when,
    required this.semanticLabel,
    this.note,
    this.noteColor,
    this.onTap,
    this.actions = const [],
    this.trailing,
    this.unread = false,
    this.highlighted = false,
  });

  final CapsuleCardState state;

  /// "Opens", in cream...
  final String headlineLead;

  /// ...then "in 30 days", in a rose gradient. Either may be empty.
  final String headlineAccent;

  /// The capsule's title when the viewer may see it, or a safe line such
  /// as "A special message for you".
  final String subtitle;

  /// "From therabot-d" / "To therabot-e".
  final String person;

  /// "4 Nov 2026, 8:00 AM".
  final String when;

  /// An extra small line: "Editable for 09:43", "You both replied".
  final String? note;
  final Color? noteColor;

  final String semanticLabel;

  /// Tapping the whole card. When null, a tap just says when the capsule
  /// opens (it can't be opened early), so every card answers a tap.
  final VoidCallback? onTap;

  /// Buttons under the text: Edit / Cancel, Open now.
  final List<Widget> actions;

  /// Replaces the chevron, e.g. a cancel button.
  final Widget? trailing;
  final bool unread;
  final bool highlighted;

  static const _radius = 28.0;

  void _explain(BuildContext context) {
    final text = switch (state) {
      CapsuleCardState.ready => 'Waiting to be opened. $when.',
      CapsuleCardState.opened => 'Opened.',
      _ => 'Sealed until $when. It opens by itself, not a moment sooner.',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glow = state == CapsuleCardState.ready;
    // Narrow phones: a smaller seal and headline leave the text room.
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final tap = onTap ?? () => _explain(context);
    final headlineSize = narrow ? 22.0 : 26.0;

    final body = Padding(
      padding: EdgeInsets.fromLTRB(
        narrow ? AppSpacing.sm : AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _SealArea(state: state, size: narrow ? 84 : 104),
              SizedBox(width: narrow ? AppSpacing.sm : AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatusChip(state: state),
                        if (unread) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: NotePalette.rose,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: headlineLead),
                          if (headlineLead.isNotEmpty &&
                              headlineAccent.isNotEmpty)
                            const TextSpan(text: ' '),
                          TextSpan(
                            text: headlineAccent,
                            style: TextStyle(
                              foreground: Paint()
                                ..shader =
                                    const LinearGradient(
                                      colors: [
                                        Color(0xFFFFC2D3),
                                        NotePalette.pink,
                                        Color(0xFFF07FA2),
                                      ],
                                    ).createShader(
                                      Rect.fromLTWH(
                                        0,
                                        0,
                                        headlineSize * 7,
                                        headlineSize,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NotePalette.display(
                        headlineSize,
                        color: const Color(0xFFFFF6F1),
                      ).copyWith(height: 1.1, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: NotePalette.cream,
                        fontSize: narrow ? 15 : 16,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Meta(icon: Icons.person_outline_rounded, text: person),
                    const SizedBox(height: AppSpacing.xs),
                    _Meta(icon: Icons.calendar_month_outlined, text: when),
                    if (note != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        note!,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: noteColor ?? NotePalette.pink,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              trailing ?? _Chevron(size: narrow ? 36 : 42),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions,
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3D1A33), Color(0xFF2A1226), Color(0xFF1C0D19)],
          ),
          border: Border.all(
            color: highlighted || glow
                ? NotePalette.borderBright
                : NotePalette.pink.withValues(alpha: 0.32),
            width: highlighted ? 1.6 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: NotePalette.rose.withValues(
                alpha: glow || highlighted ? 0.28 : 0.10,
              ),
              blurRadius: 24,
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(_radius),
            onTap: tap,
            splashColor: NotePalette.rose.withValues(alpha: 0.15),
            child: Stack(
              children: [
                const Positioned.fill(child: _CardLights(radius: _radius)),
                Semantics(
                  container: true,
                  button: true,
                  label: semanticLabel + (unread ? '. New' : ''),
                  excludeSemantics: actions.isEmpty && trailing == null,
                  child: body,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inner light: a soft top-edge highlight, a rose glow in the lower right,
/// and a few faint hearts in the top-right corner.
class _CardLights extends StatelessWidget {
  const _CardLights({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(painter: _CardLightsPainter()),
      ),
    ),
  );
}

class _CardLightsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(1.05, 1.1),
          radius: 0.9,
          colors: [
            NotePalette.rose.withValues(alpha: 0.20),
            NotePalette.rose.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.35],
        ).createShader(rect),
    );
    final heart = Paint()..color = NotePalette.pink.withValues(alpha: 0.07);
    for (final (dx, dy, w) in const [
      (0.90, 0.10, 26.0),
      (0.84, 0.30, 38.0),
      (0.95, 0.42, 16.0),
    ]) {
      final c = Offset(size.width * dx, size.height * dy);
      canvas.drawPath(
        heartPath(Rect.fromCenter(center: c, width: w, height: w)),
        heart,
      );
    }
  }

  @override
  bool shouldRepaint(_CardLightsPainter old) => false;
}

/// The glossy wax seal, its glow, an orbit ribbon, sparkles and hearts.
/// Ready capsules breathe gently (still with reduced motion on).
class _SealArea extends StatefulWidget {
  const _SealArea({required this.state, required this.size});

  final CapsuleCardState state;
  final double size;

  @override
  State<_SealArea> createState() => _SealAreaState();
}

class _SealAreaState extends State<_SealArea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_SealArea old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final on = widget.state == CapsuleCardState.ready && !motionOff(context);
    if (on && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!on && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SealPainter(
            pulse: _pulse,
            cracked: widget.state == CapsuleCardState.opened,
          ),
        ),
      ),
    ),
  );
}

class _SealPainter extends CustomPainter {
  _SealPainter({required this.pulse, required this.cracked})
    : super(repaint: pulse);

  final Animation<double> pulse;
  final bool cracked;

  // Fixed wobble for the wax rim, so it looks hand-pressed but never jumps.
  static const _bumps = [
    1.0,
    0.92,
    1.04,
    0.95,
    1.02,
    0.9,
    1.05,
    0.96,
    1.0,
    0.93,
    1.03,
    0.94,
    1.01,
    0.91,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final t = Curves.easeInOut.transform(pulse.value);
    final r = s * 0.30 * (1 + t * 0.04);

    // Glow and a faint halo ring.
    canvas.drawCircle(
      c,
      s / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            NotePalette.rose.withValues(alpha: 0.38 + t * 0.15),
            NotePalette.rose.withValues(alpha: 0.10),
            NotePalette.rose.withValues(alpha: 0),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: s / 2)),
    );
    canvas.drawCircle(
      c,
      s * 0.44,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = NotePalette.pink.withValues(alpha: 0.16),
    );

    // Orbit ribbon: the back half goes behind the seal.
    final orbit = Rect.fromCenter(center: c, width: s * 0.98, height: s * 0.30);
    void ribbon(double start, double sweep) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-0.42);
      canvas.translate(-c.dx, -c.dy);
      canvas.drawArc(
        orbit,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.022
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [
              NotePalette.pink.withValues(alpha: 0.15),
              NotePalette.pink.withValues(alpha: 0.85),
              NotePalette.rose.withValues(alpha: 0.5),
            ],
          ).createShader(orbit),
      );
      canvas.restore();
    }

    ribbon(math.pi, math.pi);

    // Wax: a lumpy rim made of overlapping blobs.
    final wax = Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.9));
    for (var i = 0; i < _bumps.length; i++) {
      final a = i * 2 * math.pi / _bumps.length;
      wax.addOval(
        Rect.fromCircle(
          center: c + Offset(math.cos(a), math.sin(a)) * r * 0.82 * _bumps[i],
          radius: r * 0.22,
        ),
      );
    }
    canvas.drawPath(
      wax.shift(Offset(0, r * 0.12)),
      Paint()
        ..color = const Color(0xFF12050D).withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );
    final waxRect = Rect.fromCircle(center: c, radius: r * 1.1);
    canvas.drawPath(
      wax,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 0.95,
          colors: [
            Color(0xFFE98AA8),
            Color(0xFFC24C74),
            Color(0xFF8E2A50),
            Color(0xFF5E1734),
          ],
          stops: [0, 0.35, 0.72, 1],
        ).createShader(waxRect),
    );

    // Raised inner ring: a dark groove with a light edge under it.
    final inner = r * 0.62;
    canvas.drawCircle(
      c + Offset(r * 0.03, r * 0.04),
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = const Color(0xFFFFC4D5).withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..color = const Color(0xFF7A1E42).withValues(alpha: 0.75),
    );
    canvas.drawCircle(
      c,
      inner - r * 0.04,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.3, 0.4),
          colors: [Color(0xFFB03C66), Color(0xFF962F55)],
        ).createShader(Rect.fromCircle(center: c, radius: inner)),
    );

    // Embossed heart: shadow below-right, light above-left, then the face.
    final hw = r * 0.74;
    Rect heartAt(Offset o) =>
        Rect.fromCenter(center: c + o, width: hw, height: hw * 0.92);
    canvas.drawPath(
      heartPath(heartAt(Offset(r * 0.04, r * 0.06))),
      Paint()..color = const Color(0xFF5E1532).withValues(alpha: 0.8),
    );
    canvas.drawPath(
      heartPath(heartAt(Offset(-r * 0.03, -r * 0.04))),
      Paint()..color = const Color(0xFFFFC9D8).withValues(alpha: 0.65),
    );
    canvas.drawPath(
      heartPath(heartAt(Offset.zero)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD7648A), Color(0xFFA0345C)],
        ).createShader(heartAt(Offset.zero)),
    );

    // Gloss on the wax.
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-r * 0.45, -r * 0.55),
        width: r * 0.55,
        height: r * 0.28,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.42)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
    );

    if (cracked) {
      final crack = Path()
        ..moveTo(c.dx - r * 0.15, c.dy - r * 1.0)
        ..lineTo(c.dx + r * 0.05, c.dy - r * 0.45)
        ..lineTo(c.dx - r * 0.12, c.dy - r * 0.05)
        ..lineTo(c.dx + r * 0.10, c.dy + r * 0.35)
        ..lineTo(c.dx - r * 0.02, c.dy + r * 1.0);
      canvas.drawPath(
        crack.shift(Offset(r * 0.03, r * 0.03)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.05
          ..color = const Color(0xFFFFC4D5).withValues(alpha: 0.5),
      );
      canvas.drawPath(
        crack,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.07
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF3E0C22),
      );
    }

    // Front half of the ribbon over the seal.
    ribbon(0, math.pi);

    // Sparkles and hearts around it.
    void sparkle(Offset p, double k) {
      final path = Path()
        ..moveTo(p.dx, p.dy - k)
        ..quadraticBezierTo(p.dx, p.dy, p.dx + k, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + k)
        ..quadraticBezierTo(p.dx, p.dy, p.dx - k, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - k)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFD6E2).withValues(alpha: 0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
      );
    }

    sparkle(Offset(s * 0.86, s * 0.17), s * 0.06);
    sparkle(Offset(s * 0.13, s * 0.80), s * 0.05);
    final heartPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF6A9C1), Color(0xFFD4557F)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(
      heartPath(
        Rect.fromCenter(
          center: Offset(s * 0.13, s * 0.18),
          width: s * 0.17,
          height: s * 0.16,
        ),
      ),
      heartPaint,
    );
    canvas.drawPath(
      heartPath(
        Rect.fromCenter(
          center: Offset(s * 0.88, s * 0.74),
          width: s * 0.11,
          height: s * 0.10,
        ),
      ),
      heartPaint,
    );
  }

  @override
  bool shouldRepaint(_SealPainter old) => old.cracked != cracked;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});

  final CapsuleCardState state;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (state) {
      CapsuleCardState.sealed ||
      CapsuleCardState.grace => ('SEALED', Icons.lock_rounded),
      CapsuleCardState.ready => ('READY', Icons.lock_open_rounded),
      CapsuleCardState.opened => ('OPENED', Icons.mark_email_read_rounded),
    };
    final ready = state == CapsuleCardState.ready;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 14, 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NotePalette.rose.withValues(alpha: ready ? 0.38 : 0.24),
            NotePalette.rose.withValues(alpha: ready ? 0.22 : 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: NotePalette.pink.withValues(alpha: ready ? 0.8 : 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: NotePalette.pink),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: NotePalette.pink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(icon, size: 16, color: NotePalette.muted),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: NotePalette.muted,
            fontSize: 13.5,
          ),
        ),
      ),
    ],
  );
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.03),
        ],
      ),
      border: Border.all(color: NotePalette.pink.withValues(alpha: 0.35)),
    ),
    child: Icon(
      Icons.chevron_right_rounded,
      size: size * 0.6,
      color: const Color(0xFFFFF6F1),
    ),
  );
}

/// The pink pill buttons used on the card: Edit, Open now.
class CapsuleCardButton extends StatelessWidget {
  const CapsuleCardButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? const Color(0xFF3A0A19) : NotePalette.pink;
    return Material(
      color: primary ? null : Colors.transparent,
      shape: StadiumBorder(
        side: primary
            ? BorderSide.none
            : BorderSide(color: NotePalette.pink.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: primary
            ? const BoxDecoration(gradient: NotePalette.buttonGradient)
            : null,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
