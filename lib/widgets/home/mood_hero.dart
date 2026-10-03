import 'package:flutter/material.dart';

import '../../models/mood.dart';
import '../../models/mood_visual.dart';
import '../../theme/app_effects.dart';
import '../../theme/app_spacing.dart';
import '../atoms/fit_label.dart';
import '../effects/motion.dart';
import 'mood_art.dart';
import 'mood_particles.dart';

/// The big card at the top of Home: "Mikko is feeling LOVED today", a short
/// quote and the mood's illustration. It follows the mood being previewed,
/// so tapping a mood below changes it straight away; nothing is saved until
/// Share mood is pressed, and until then it says "not shared yet".
class MoodHero extends StatelessWidget {
  const MoodHero({
    super.key,
    required this.name,
    required this.mood,
    required this.pending,
    required this.saving,
    required this.hasPartner,
    required this.onShare,
    required this.onAddNote,
    this.actionsKey,
  });

  /// The signed-in person's first name.
  final String name;

  /// The mood to show: the one being previewed, else today's saved mood.
  /// Null when no mood has been picked today.
  final Mood? mood;

  /// True while [mood] is a preview that has not been saved yet.
  final bool pending;
  final bool saving;

  /// Decides the button wording: "Share mood" with a partner, else "Save".
  final bool hasPartner;
  final VoidCallback onShare;
  final VoidCallback onAddNote;

  /// On the Share / Add a note row, so Home can scroll it into view.
  final Key? actionsKey;

  static const double _accentBarWidth = 28;
  static const double _accentBarHeight = 4;

  /// AnimatedSize must not get a zero duration (it asserts), so "instant"
  /// is one millisecond. Always using AnimatedSize keeps the widget tree the
  /// same when reduce motion is switched, so buttons keep focus.
  static Duration _sizeTime(bool still) =>
      still ? const Duration(milliseconds: 1) : AppMotion.quick;

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
        AppGradients.blush(brightness).colors;
    final ink = scheme.onSurface;
    // Plum in light mode for a little colour with strong contrast.
    final titleColor = brightness == Brightness.dark ? ink : scheme.secondary;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    // Mood art fades and gently scales; words fade and rise a few pixels;
    // particles only fade, so the old ones drift out rather than vanish.
    Widget art(Widget child, Animation<double> a) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: Tween(begin: 0.94, end: 1.0).animate(a),
        child: child,
      ),
    );
    Widget words(Widget child, Animation<double> a) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(a),
        child: child,
      ),
    );
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
        borderRadius: BorderRadius.circular(AppRadius.hero),
        boxShadow: AppShadows.raised(scheme),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.hero),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: switchTime,
                child: visual == null
                    ? const SizedBox.shrink(key: ValueKey('none'))
                    : MoodParticlesLayer(
                        key: ValueKey(visual.mood),
                        style: visual.particles,
                        color: visual.colors.particle,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  final artSize = (box.maxWidth * 0.36).clamp(96.0, 160.0);
                  final textWidth = box.maxWidth - artSize - AppSpacing.sm;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            // Grows and shrinks smoothly as the quote
                            // length changes, instead of snapping.
                            child: AnimatedSize(
                              duration: _sizeTime(still),
                              curve: AppMotion.enter,
                              alignment: Alignment.topLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m == null
                                        ? 'Hi $name,'
                                        : '$name is feeling',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: ink,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  AnimatedSwitcher(
                                    duration: switchTime,
                                    transitionBuilder: words,
                                    layoutBuilder: _topLeft,
                                    child: m == null
                                        ? Text(
                                            'How are you feeling?',
                                            key: const ValueKey('none'),
                                            style: theme.textTheme.titleLarge
                                                ?.copyWith(color: titleColor),
                                          )
                                        // One line normally; with large
                                        // text it may wrap at spaces. It
                                        // never breaks mid-word.
                                        : FitLabel(
                                            m.label.toUpperCase(),
                                            key: ValueKey(m),
                                            maxWidth: textWidth,
                                            maxLines: largeText ? 2 : 1,
                                            textAlign: TextAlign.start,
                                            alignment: Alignment.centerLeft,
                                            style: theme
                                                .textTheme
                                                .headlineMedium
                                                ?.copyWith(color: titleColor),
                                          ),
                                  ),
                                  if (visual != null) ...[
                                    const SizedBox(height: AppSpacing.xs),
                                    // A short accent bar under the mood:
                                    // colour as decoration, never for words.
                                    AnimatedContainer(
                                      duration: switchTime,
                                      width: _accentBarWidth,
                                      height: _accentBarHeight,
                                      decoration: BoxDecoration(
                                        color: visual.accentFor(brightness),
                                        borderRadius: BorderRadius.circular(
                                          _accentBarHeight / 2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      pending
                                          ? 'today · not shared yet'
                                          : 'today',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(color: ink),
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.md),
                                  AnimatedSwitcher(
                                    duration: switchTime,
                                    transitionBuilder: words,
                                    layoutBuilder: _topLeft,
                                    child: Text(
                                      visual?.quote ??
                                          'Pick a mood below to share it.',
                                      key: ValueKey(m),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: ink,
                                            fontStyle: visual == null
                                                ? null
                                                : FontStyle.italic,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          SizedBox.square(
                            dimension: artSize,
                            child: AnimatedSwitcher(
                              duration: switchTime,
                              switchInCurve: AppMotion.enter,
                              switchOutCurve: AppMotion.exit,
                              transitionBuilder: art,
                              child: visual == null
                                  ? Opacity(
                                      key: const ValueKey('none'),
                                      opacity: 0.45,
                                      child: MoodArt(
                                        visual: MoodVisual.of(Mood.loved),
                                        size: artSize,
                                        semantic: false,
                                      ),
                                    )
                                  : MoodArt(
                                      key: ValueKey(visual.mood),
                                      visual: visual,
                                      size: artSize,
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      KeyedSubtree(
                        key: actionsKey,
                        child: AnimatedSize(
                          duration: _sizeTime(still),
                          curve: AppMotion.enter,
                          alignment: Alignment.topLeft,
                          child: _Actions(
                            pending: pending,
                            saving: saving,
                            hasPartner: hasPartner,
                            onShare: onShare,
                            onAddNote: onAddNote,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Old and new text stack while they cross-fade. The outgoing one is
  /// hidden from screen readers so only the new mood is read.
  static Widget _topLeft(Widget? current, List<Widget> previous) => Stack(
    alignment: Alignment.topLeft,
    children: [
      for (final p in previous) ExcludeSemantics(child: p),
      ?current,
    ],
  );
}

/// "Share mood" (only while a preview is unsaved) and "Add a note".
class _Actions extends StatelessWidget {
  const _Actions({
    required this.pending,
    required this.saving,
    required this.hasPartner,
    required this.onShare,
    required this.onAddNote,
  });

  final bool pending;
  final bool saving;
  final bool hasPartner;
  final VoidCallback onShare;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shareLabel = hasPartner ? 'Share mood' : 'Save mood';
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (pending)
          FilledButton.icon(
            onPressed: saving ? null : onShare,
            icon: saving
                ? SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.favorite_rounded, size: 18),
            // The label changes while saving, so the busy state is read
            // out and seen, not just a spinner.
            label: Text(saving ? 'Sharing…' : shareLabel),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
              shape: const StadiumBorder(),
            ),
          ),
        TextButton.icon(
          onPressed: saving ? null : onAddNote,
          icon: const Icon(Icons.edit_note_rounded, size: 20),
          label: const Text('Add a note'),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, AppSpacing.touchTarget),
            foregroundColor: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}
