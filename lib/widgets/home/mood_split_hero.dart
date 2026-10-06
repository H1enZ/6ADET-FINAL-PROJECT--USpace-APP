import 'package:flutter/material.dart';

import '../../models/mood.dart';
import '../../models/mood_visual.dart';
import '../../theme/app_effects.dart';
import '../../theme/app_spacing.dart';
import '../atoms/fit_label.dart';
import '../effects/motion.dart';
import 'mood_art.dart';
import 'mood_hero.dart';
import 'mood_particles.dart';

/// "Both of us" on Home: the mood hero split down the middle. Your half and
/// your partner's half each take their own mood's colours, artwork, word and
/// line, like the single hero. Tapping a half opens that person's own view;
/// the arrow flips through Both, You and your partner.
class MoodSplitHero extends StatelessWidget {
  const MoodSplitHero({
    super.key,
    required this.myName,
    required this.myMood,
    required this.myNote,
    required this.myPending,
    required this.partnerName,
    required this.partnerMood,
    required this.partnerNote,
    required this.onOpenMine,
    required this.onOpenPartner,
    required this.onAddNote,
    required this.flipLabel,
    required this.onFlip,
  });

  final String myName;
  final Mood? myMood;
  final String? myNote;

  /// True while my mood is a preview that has not been shared yet.
  final bool myPending;

  final String partnerName;
  final Mood? partnerMood;
  final String? partnerNote;

  final VoidCallback onOpenMine;
  final VoidCallback onOpenPartner;
  final VoidCallback onAddNote;

  /// What the arrow does next, e.g. "See your mood".
  final String flipLabel;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: "Today's moods",
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.hero),
          boxShadow: AppShadows.raised(scheme),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.hero),
          child: LayoutBuilder(
            builder: (context, box) {
              final half = (box.maxWidth - 1) / 2;
              return Stack(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _Half(
                            heading: myMood == null ? 'You' : 'You are feeling',
                            mood: myMood,
                            note: myNote,
                            pending: myPending,
                            empty: 'Pick a mood below to share it.',
                            onTap: onOpenMine,
                            onAddNote: myMood != null && !myPending
                                ? onAddNote
                                : null,
                            // Leaves room for the arrow on the right half only.
                            rightInset: 0,
                            width: half,
                          ),
                        ),
                        Container(
                          width: 1,
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                        Expanded(
                          child: _Half(
                            heading: partnerMood == null
                                ? partnerName
                                : '$partnerName is feeling',
                            mood: partnerMood,
                            note: partnerNote,
                            pending: false,
                            empty: 'Their mood shows here once they share it.',
                            onTap: onOpenPartner,
                            rightInset: 28,
                            width: half,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: MoodFlipButton(label: flipLabel, onPressed: onFlip),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: AppSpacing.sm,
                    child: MoodViewDots(index: 0),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({
    required this.heading,
    required this.mood,
    required this.note,
    required this.pending,
    required this.empty,
    required this.onTap,
    required this.rightInset,
    required this.width,
    this.onAddNote,
  });

  /// The half's width, measured by the parent.
  final double width;

  final String heading;
  final Mood? mood;
  final String? note;
  final bool pending;

  /// Shown instead of a quote when there is no mood yet today.
  final String empty;
  final VoidCallback onTap;
  final VoidCallback? onAddNote;

  /// Space kept clear at the top right, under the flip arrow.
  final double rightInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final still = motionOff(context);
    final m = mood;
    final visual = m == null ? null : MoodVisual.of(m);
    final gradient =
        visual?.gradientFor(brightness) ??
        [scheme.surfaceContainerHighest, scheme.surfaceContainerLow];
    final ink = scheme.onSurface;
    final soft = ink.withValues(alpha: 0.82);
    final shownNote = note?.trim() ?? '';
    final line = shownNote.isNotEmpty ? '“$shownNote”' : visual?.quote ?? empty;
    final switchTime = still ? Duration.zero : AppMotion.medium;

    return AnimatedContainer(
      duration: still ? Duration.zero : AppMotion.slow,
      curve: AppMotion.enter,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              if (visual != null)
                Positioned.fill(
                  child: MoodParticlesLayer(
                    key: ValueKey(visual.mood),
                    style: visual.particles,
                    color: visual.colors.particle,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                child: Builder(
                  builder: (context) {
                    // Inside the padding: lg on the left, md on the right.
                    final inner = width - AppSpacing.lg - AppSpacing.md;
                    final artSize = (inner * 0.55).clamp(56.0, 84.0);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: rightInset),
                          child: SizedBox.square(
                            dimension: artSize,
                            child: AnimatedSwitcher(
                              duration: switchTime,
                              child: visual == null
                                  ? Opacity(
                                      key: const ValueKey('none'),
                                      opacity: 0.4,
                                      child: MoodArt(
                                        visual: MoodVisual.of(Mood.calm),
                                        size: artSize,
                                        semantic: false,
                                      ),
                                    )
                                  : MoodArt(
                                      key: ValueKey(visual.mood),
                                      visual: visual,
                                      size: artSize,
                                      semantic: false,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          heading,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: soft,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (m == null)
                          Text(
                            'No mood yet',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: ink,
                            ),
                          )
                        else
                          FitLabel(
                            m.label.toUpperCase(),
                            maxWidth: inner,
                            maxLines: 1,
                            textAlign: TextAlign.start,
                            alignment: Alignment.centerLeft,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: ink,
                              letterSpacing: 0.4,
                            ),
                          ),
                        if (visual != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Container(
                            width: 24,
                            height: 3,
                            decoration: BoxDecoration(
                              color: visual.accentFor(brightness),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          pending ? 'Not shared yet' : line,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: soft,
                            fontStyle: visual == null && shownNote.isEmpty
                                ? null
                                : FontStyle.italic,
                          ),
                        ),
                        if (onAddNote != null && shownNote.isEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          InkWell(
                            onTap: onAddNote,
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs,
                              ),
                              child: Text(
                                '+ Add a note',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color:
                                      visual?.accentFor(brightness) ??
                                      scheme.primary,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
