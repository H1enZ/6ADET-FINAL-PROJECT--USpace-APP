part of 'mood_card.dart';

// The mood card's pieces: the shared (matched) mood, note lines and
// quiet actions, each partner's side, and the empty states.

/// Your moods match: one larger shared mood, "You ♥ partner" under it, and
/// a quiet marker when either of you left a note (tap to read them). The
/// notes themselves stay out of the card so it stays clean.
class _Shared extends StatelessWidget {
  const _Shared({
    required this.mood,
    required this.me,
    required this.partner,
    required this.onTap,
    required this.onShowNotes,
  });

  final Mood mood;
  final MoodPerson me;
  final MoodPerson partner;
  final VoidCallback onTap;
  final VoidCallback onShowNotes;

  static const double artSize = 100;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visual = MoodVisual.of(mood);
    final notes = [
      if ((me.note?.trim() ?? '').isNotEmpty) me.note,
      if ((partner.note?.trim() ?? '').isNotEmpty) partner.note,
    ].length;
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      letterSpacing: 0.2,
    );

    Widget person(MoodPerson p, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarCircle(name: p.name, imageUrl: p.avatarUrl, size: 20),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'You and ${partner.name} are both feeling ${mood.label}',
          hint: 'Change your mood',
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              visual
                                  .accentFor(Brightness.dark)
                                  .withValues(alpha: 0.32),
                              visual
                                  .accentFor(Brightness.dark)
                                  .withValues(alpha: 0),
                            ],
                          ),
                        ),
                        child: const SizedBox.square(dimension: 120),
                      ),
                      MoodArt(visual: visual, size: artSize, semantic: false),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${mood.label} together',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: person(me, 'You')),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 14,
                          color: UsPalette.rose,
                        ),
                      ),
                      Flexible(child: person(partner, partner.name)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // A quiet "2 notes" marker when either of you left one. Adding a
        // note starts from tapping the mood.
        if (notes > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          _QuietAction(
            icon: UsIcons.note,
            label: notes == 1 ? '1 note' : '$notes notes',
            semantics: 'Read today’s notes',
            onTap: onShowNotes,
          ),
        ],
      ],
    );
  }
}

/// A small, quiet text action with an icon: "2 notes", "Add a note".
class _QuietAction extends StatelessWidget {
  const _QuietAction({
    required this.icon,
    required this.label,
    required this.semantics,
    required this.onTap,
  });

  final UsIconData icon;
  final String label;
  final String semantics;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: onTap != null,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UsIcon(icon, size: 14, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Under a mood on the split card: the note as a single quiet line (tap to
/// read or edit). Nothing when there is no note: "Add a note" only appears
/// after you tap your mood, so the card itself stays clean.
class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.note, required this.isMe, this.onTap});

  final String? note;
  final bool isMe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = note?.trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Semantics(
      button: onTap != null,
      label: isMe ? 'Your note: $text. Edit' : 'Note: $text. Read',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UsIcon(UsIcons.note, size: 13, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of you on the couple state: avatar and name, the mood art, the mood
/// word and "TODAY". Your partner's side animates on its own when their
/// mood changes; yours opens the picker when tapped.
class _Side extends StatelessWidget {
  const _Side({
    required this.person,
    required this.isMe,
    this.slotKey,
    this.hideArt = false,
    this.onTap,
    this.onNote,
  });

  final MoodPerson person;
  final bool isMe;

  /// Yours: open the note sheet. Your partner's: show the notes in full.
  final VoidCallback? onNote;
  final Key? slotKey;
  final bool hideArt;
  final VoidCallback? onTap;

  static const double art = 84;

  /// The artwork's own size inside the slot. The travelling copy renders
  /// at this same size (and is scaled), so it is decoded once, not per frame.
  static const double artInner = 76;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final still = motionOff(context);
    final m = person.mood;
    final visual = m == null ? null : MoodVisual.of(m);
    final first = person.name.split(' ').first;

    // Partner changes: fade, rise a few pixels and settle; nothing else
    // on the card moves.
    Widget swap(Widget child) => AnimatedSwitcher(
      duration: still ? AppMotion.quick : const Duration(milliseconds: 380),
      // The old mood leaves quickly so the two never read as one word.
      reverseDuration: still
          ? AppMotion.quick
          : const Duration(milliseconds: 140),
      switchInCurve: AppMotion.snappy,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: still
            ? child
            : ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.0).animate(a),
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
      ),
      child: child,
    );

    final content = Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarCircle(
              name: person.name,
              imageUrl: person.avatarUrl,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                isMe ? 'You' : first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox.square(
          key: slotKey,
          dimension: art,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (visual != null)
                // A faint glow in the mood's own colour.
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        visual
                            .accentFor(theme.brightness)
                            .withValues(alpha: 0.28),
                        visual.accentFor(theme.brightness).withValues(alpha: 0),
                      ],
                    ),
                  ),
                  child: const SizedBox.square(dimension: art),
                ),
              Opacity(
                opacity: hideArt ? 0 : 1,
                child: swap(
                  visual == null
                      ? _EmptyArt(key: const ValueKey('none'))
                      : MoodArt(
                          key: ValueKey(visual.mood),
                          visual: visual,
                          size: artInner,
                          semantic: false,
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        swap(
          m == null
              ? Text(
                  'Not shared yet',
                  key: const ValueKey('none'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : Column(
                  key: ValueKey(m),
                  children: [
                    LayoutBuilder(
                      builder: (context, box) => FitLabel(
                        m.label,
                        maxWidth: box.maxWidth,
                        maxLines: 1,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'TODAY',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );

    final label = m == null
        ? '${isMe ? 'You' : first}: no mood shared yet'
        : '${isMe ? 'You are' : '$first is'} feeling ${m.label}';
    // The note line sits outside the side's own label, so screen readers
    // reach it as its own action.
    Widget withNote(Widget side) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        side,
        if (m != null) _NoteLine(note: person.note, isMe: isMe, onTap: onNote),
      ],
    );
    if (onTap == null) {
      // Same padding as the tappable side, so both sides line up.
      return withNote(
        Semantics(
          label: label,
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: content,
          ),
        ),
      );
    }
    return withNote(
      Semantics(
        button: true,
        label: label,
        hint: 'Change your mood',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// A quiet empty circle where a mood will be.
class _EmptyArt extends StatelessWidget {
  const _EmptyArt({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: _Side.art * 0.7,
      height: _Side.art * 0.7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: scheme.outline, width: 1.5),
      ),
      alignment: Alignment.center,
      child: UsIcon(
        UsIcons.mood,
        size: 22,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
  }
}

/// Before your partner joins.
class _EmptySide extends StatelessWidget {
  const _EmptySide({required this.name, required this.line});

  final String name;
  final String line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Text(
          name,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 6),
        const SizedBox.square(
          dimension: _Side.art,
          child: Center(child: _EmptyArt()),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          line,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
