import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/love_note.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/us_palette.dart';
import '../atoms/us_icon.dart';
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

  // Letter paper (the shared paper tokens).
  static const paper = UsPalette.paper;
  static const paperEdge = UsPalette.paperEdge;
  static const ink = UsPalette.paperInk;
  static const inkSoft = UsPalette.paperInkSoft;

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

/// The icon for a note type, from the USpace line set.
class NoteCategoryIcon extends StatelessWidget {
  const NoteCategoryIcon(
    this.category, {
    super.key,
    this.size = 26,
    this.color = NotePalette.rose,
  });

  final NoteCategory? category;
  final double size;
  final Color color;

  static UsIconData iconOf(NoteCategory? c) => switch (c) {
    NoteCategory.justBecause => UsIcons.sparkle,
    NoteCategory.thankYou => UsIcons.flower,
    NoteCategory.missingYou => UsIcons.moon,
    NoteCategory.proudOfYou => UsIcons.star,
    NoteCategory.love => UsIcons.heart,
    null => UsIcons.loveNotes,
  };

  @override
  Widget build(BuildContext context) =>
      UsIcon(iconOf(category), size: size, color: color);
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
    final color = onPaper ? NotePalette.inkSoft : NotePalette.pink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        capsule && category == null
            ? UsIcon(UsIcons.timeCapsule, size: 14, color: NotePalette.rose)
            : NoteCategoryIcon(
                category,
                size: 14,
                color: onPaper ? NotePalette.deepRose : NotePalette.rose,
              ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.1,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
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
          colors: [UsPalette.cream, UsPalette.paper],
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
                  NoteCategory.love,
                  size: width * 0.24,
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
    color: UsPalette.cardRaised,
    alignment: Alignment.center,
    child: const UsIcon(UsIcons.image, color: NotePalette.pink),
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
  final UsIconData icon;
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
            color: NotePalette.rose,
            borderRadius: BorderRadius.circular(999),
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
                            color: UsPalette.onRose,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!iconAfter) ...[
                              UsIcon(
                                icon,
                                size: 20,
                                color: UsPalette.onRose,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Text(
                              label,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontSize: 16,
                                    color: UsPalette.onRose,
                                  ),
                            ),
                            if (iconAfter) ...[
                              const SizedBox(width: AppSpacing.xs),
                              UsIcon(
                                icon,
                                size: 20,
                                color: UsPalette.onRose,
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
        ? [
            Color.lerp(NotePalette.cardTop, NotePalette.rose, 0.16)!,
            NotePalette.cardTop,
          ]
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
