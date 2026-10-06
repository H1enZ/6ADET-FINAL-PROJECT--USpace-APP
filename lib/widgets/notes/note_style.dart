import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/love_note.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/us_palette.dart';
import '../effects/soft_hearts_background.dart';
import '../home/quick_actions.dart';

/// Colours and type for the Love Notes screens (dark only): plum cards,
/// rose accents, cream text, and cream / blush paper for an opened note.
class NotePalette {
  NotePalette._();

  // Shared USpace tokens (lib/theme/us_palette.dart) under the names the
  // Love Notes, Capsule and Therabot screens already use.
  static const background = UsPalette.ink;
  static const backgroundTop = UsPalette.surface;
  static const card = UsPalette.card;
  static const cardTop = UsPalette.cardRaised;
  static const border = UsPalette.line;
  static const borderBright = UsPalette.lineStrong;
  static const cream = UsPalette.cream;
  static const muted = UsPalette.muted;
  static const pink = UsPalette.roseLight;
  static const rose = UsPalette.rose;
  static const deepRose = UsPalette.roseDeep;

  // Letter paper: only on an opened note or capsule letter.
  static const paper = Color(0xFFF8E6E4);
  static const paperEdge = Color(0xFFEBCFCF);
  static const ink = Color(0xFF3B1F2E);
  static const inkSoft = Color(0xFF7A5566);

  /// The big rose button (dark text on it).
  static const buttonGradient = LinearGradient(
    colors: [UsPalette.roseLight, UsPalette.rose],
  );

  /// Screen titles ("Love Notes") and the letter's title.
  static TextStyle display(double size, {Color color = cream}) =>
      AppTypography.display(size, color: color);

  /// The letter itself, on paper.
  static TextStyle letter({Color color = ink}) =>
      AppTypography.letter(color: color);
}

/// The dark plum page with the slow, faint hearts used on Splash and
/// Sign in. Taps pass through; the hearts are hidden from screen readers
/// and stay still with reduce-motion on.
class NotesBackground extends StatelessWidget {
  const NotesBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SoftHeartsBackground(
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [NotePalette.backgroundTop, NotePalette.background],
    ),
    heartColor: NotePalette.rose.withValues(alpha: 0.07),
    child: child,
  );
}

/// The icon for a note type. One family: rounded Material shapes filled
/// with the same rose gradient; "Love" is two overlapping hearts.
class NoteCategoryIcon extends StatelessWidget {
  const NoteCategoryIcon(this.category, {super.key, this.size = 26});

  final NoteCategory? category;
  final double size;

  static IconData iconOf(NoteCategory? c) => switch (c) {
    NoteCategory.justBecause => Icons.favorite_rounded,
    NoteCategory.thankYou => Icons.local_florist_rounded,
    NoteCategory.missingYou => Icons.nightlight_round,
    NoteCategory.proudOfYou => Icons.star_rounded,
    NoteCategory.love => Icons.favorite_rounded,
    null => Icons.mail_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final Widget glyph = category == NoteCategory.love
        ? SizedBox.square(
            dimension: size,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: size * 0.04,
                  child: Icon(Icons.favorite_rounded, size: size * 0.72),
                ),
                Positioned(
                  right: 0,
                  bottom: size * 0.02,
                  child: Icon(Icons.favorite_rounded, size: size * 0.62),
                ),
              ],
            ),
          )
        : Icon(iconOf(category), size: size);
    return ExcludeSemantics(
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB3C7), NotePalette.rose, NotePalette.deepRose],
        ).createShader(r),
        child: glyph,
      ),
    );
  }
}

/// A small rose pill with the note type: "Just Because".
class NoteCategoryBadge extends StatelessWidget {
  const NoteCategoryBadge({
    super.key,
    this.category,
    this.capsule = false,
    this.onPaper = false,
  });

  final NoteCategory? category;

  /// An opened Time Capsule from before categories.
  final bool capsule;

  /// Darker text for the cream letter paper.
  final bool onPaper;

  @override
  Widget build(BuildContext context) {
    final label = category?.label ?? (capsule ? 'Time Capsule' : 'Love Note');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: onPaper
            ? NotePalette.pink.withValues(alpha: 0.35)
            : NotePalette.rose.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: onPaper
              ? NotePalette.rose.withValues(alpha: 0.35)
              : NotePalette.pink.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          capsule && category == null
              ? const Icon(
                  Icons.lock_clock_rounded,
                  size: 13,
                  color: NotePalette.rose,
                )
              : NoteCategoryIcon(category, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 0.2,
              fontSize: 11.5,
              color: onPaper ? NotePalette.ink : NotePalette.pink,
            ),
          ),
        ],
      ),
    );
  }
}

/// A cream instant-photo frame with a strip of tape and a heart. Slightly
/// turned by [turn] degrees (keep it small).
class NotePolaroid extends StatelessWidget {
  const NotePolaroid({
    super.key,
    required this.url,
    required this.width,
    this.turn = -3,
    this.heart = true,
  });

  final String? url;
  final double width;
  final double turn;
  final bool heart;

  @override
  Widget build(BuildContext context) {
    final border = width * 0.06;
    final photo = width - border * 2;
    final frame = Container(
      width: width,
      padding: EdgeInsets.fromLTRB(border, border, border, border * 3.2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF4EF), Color(0xFFF5DEDF)],
        ),
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: width * 0.08,
            offset: Offset(0, width * 0.04),
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: photo,
        child: url == null
            ? const _PhotoMissing()
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _PhotoMissing(),
              ),
      ),
    );
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: turn * math.pi / 180,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            frame,
            // Tape across the top.
            Positioned(
              top: -width * 0.05,
              left: width * 0.32,
              child: Transform.rotate(
                angle: 0.04,
                child: Container(
                  width: width * 0.36,
                  height: width * 0.1,
                  color: NotePalette.pink.withValues(alpha: 0.55),
                ),
              ),
            ),
            if (heart)
              Positioned(
                right: -width * 0.08,
                bottom: -width * 0.06,
                child: NoteCategoryIcon(
                  NoteCategory.justBecause,
                  size: width * 0.28,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoMissing extends StatelessWidget {
  const _PhotoMissing();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF4A1D42),
    alignment: Alignment.center,
    child: const Icon(Icons.image_outlined, color: NotePalette.pink),
  );
}

/// The left side of a note card when there is no photo: the love-letter
/// drawing on a soft tile, so no card shows an empty frame.
class NoteArtTile extends StatelessWidget {
  const NoteArtTile({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.card),
      gradient: RadialGradient(
        colors: [
          NotePalette.rose.withValues(alpha: 0.18),
          NotePalette.rose.withValues(alpha: 0.02),
        ],
      ),
    ),
    alignment: Alignment.center,
    child: QuickActionArtView(QuickActionArt.loveNote, size: size * 0.92),
  );
}

/// The wide pink button: "Write a Love Note", "Send Love Note".
class NotePrimaryButton extends StatelessWidget {
  const NotePrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.iconAfter = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  /// Puts the icon after the label, for a "go on" arrow.
  final bool iconAfter;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || loading ? 1 : 0.5,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: NotePalette.buttonGradient,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: NotePalette.rose.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: enabled ? onPressed : null,
              child: SizedBox(
                height: 54,
                child: Center(
                  child: loading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF3A0A19),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!iconAfter) ...[
                              Icon(
                                icon,
                                size: 22,
                                color: const Color(0xFF3A0A19),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Text(
                              label,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontSize: 16,
                                    color: const Color(0xFF3A0A19),
                                  ),
                            ),
                            if (iconAfter) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Icon(
                                icon,
                                size: 22,
                                color: const Color(0xFF3A0A19),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The plum card style shared by the list cards and the type picker.
BoxDecoration noteCardDecoration({
  bool selected = false,
  double radius = AppRadius.panel,
}) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: selected
        ? [const Color(0xFF5A2244), const Color(0xFF3A1730)]
        : const [NotePalette.cardTop, NotePalette.card],
  ),
  border: Border.all(
    color: selected ? NotePalette.borderBright : NotePalette.border,
    width: selected ? 1.6 : 1,
  ),
  boxShadow: [
    BoxShadow(
      color: selected
          ? NotePalette.rose.withValues(alpha: 0.30)
          : Colors.black.withValues(alpha: 0.30),
      blurRadius: selected ? 16 : 12,
      offset: const Offset(0, 6),
    ),
  ],
);
