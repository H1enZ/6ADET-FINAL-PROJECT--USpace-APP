import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/us_palette.dart';
import '../atoms/us_icon.dart';
import '../effects/soft_hearts_background.dart' show heartPath;
import '../notes/note_style.dart';

/// Where a Time Capsule is in its life, as shown on its card.
enum CapsuleCardState { sealed, grace, ready, opened }

/// One Time Capsule as a calm plum card: a small still wax seal on the
/// left, then a quiet status label, one headline line (the countdown, or
/// "Ready to open"), a subtitle and one "From Ana · 4 Nov, 8:00 AM" line.
/// The same card in every state, so a capsule in its ten editable minutes
/// looks like itself with buttons added. Nothing on it moves by itself.
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

  /// ...then "in 30 days", in rose. Either may be empty.
  final String headlineAccent;

  /// The capsule's title when the viewer may see it, or a safe line such
  /// as "A special message for you".
  final String subtitle;

  /// "From therabot-d" / "To therabot-e".
  final String person;

  /// "4 Nov, 8:00 AM".
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

  /// A small control on the right, e.g. a cancel button.
  final Widget? trailing;
  final bool unread;
  final bool highlighted;

  static const _radius = AppRadius.card + 4;

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
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final tap = onTap ?? () => _explain(context);
    final ready = state == CapsuleCardState.ready;

    final body = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SealArea(state: state, size: narrow ? 52 : 60),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusLabel(state: state, unread: unread),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: headlineLead),
                          if (headlineLead.isNotEmpty &&
                              headlineAccent.isNotEmpty)
                            const TextSpan(text: ' '),
                          TextSpan(
                            text: headlineAccent,
                            style: const TextStyle(color: UsPalette.roseLight),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NotePalette.display(narrow ? 18 : 20),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: NotePalette.cream,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$person · $when',
                      // Narrow phones may wrap it rather than cut the date.
                      maxLines: narrow ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: NotePalette.muted,
                      ),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        note!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: noteColor ?? NotePalette.pink,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.xs),
                trailing!,
              ],
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
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
            colors: [UsPalette.cardRaised, UsPalette.card],
          ),
          border: Border.all(
            color: highlighted || ready ? UsPalette.lineStrong : UsPalette.line,
            width: highlighted ? 1.6 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(_radius),
            onTap: tap,
            child: Semantics(
              container: true,
              button: true,
              label: semanticLabel + (unread ? '. New' : ''),
              excludeSemantics: actions.isEmpty && trailing == null,
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

/// The wax seal, still: cracked once the capsule is opened.
class _SealArea extends StatelessWidget {
  const _SealArea({required this.state, required this.size});

  final CapsuleCardState state;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SealPainter(cracked: state == CapsuleCardState.opened),
        ),
      ),
    ),
  );
}

class _SealPainter extends CustomPainter {
  _SealPainter({required this.cracked});

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
    final r = s * 0.40;

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

  }

  @override
  bool shouldRepaint(_SealPainter old) => old.cracked != cracked;
}

/// "SEALED" / "READY" / "OPENED" as a quiet label, with a dot when new.
class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.state, required this.unread});

  final CapsuleCardState state;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (state) {
      CapsuleCardState.sealed || CapsuleCardState.grace => (
        'SEALED',
        UsIcons.lock,
      ),
      CapsuleCardState.ready => ('READY', UsIcons.timeCapsule),
      CapsuleCardState.opened => ('OPENED', UsIcons.loveNotes),
    };
    return Row(
      children: [
        UsIcon(icon, size: 13, color: NotePalette.pink),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: NotePalette.pink,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        if (unread) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: NotePalette.rose,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

/// The small pill buttons used on the card: Cancel, Edit, Open now.
class CapsuleCardButton extends StatelessWidget {
  const CapsuleCardButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
  });

  final String label;
  final UsIconData? icon;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? UsPalette.onRose : NotePalette.pink;
    return Material(
      color: primary ? UsPalette.rose : Colors.transparent,
      shape: StadiumBorder(
        side: primary
            ? BorderSide.none
            : BorderSide(color: NotePalette.pink.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  UsIcon(icon!, size: 18, color: fg),
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
    );
  }
}
