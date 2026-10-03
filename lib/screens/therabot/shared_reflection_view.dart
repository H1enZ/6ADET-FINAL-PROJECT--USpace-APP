import 'package:flutter/material.dart';

import '../../models/therabot.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/effects/motion.dart';
import '../../widgets/therabot/therabot_widgets.dart';

/// The couple's shared reflection, exactly as Therabot returned it. It is
/// built only from the two approved summaries: no raw answers, no private
/// drafts. Sections that came back empty are left out, never filled in.
class SharedReflectionView extends StatelessWidget {
  const SharedReflectionView({
    super.key,
    required this.reflection,
    required this.myPartnerNumber,
    required this.partnerName,
    this.animate = true,
  });

  final SharedReflection reflection;
  final int myPartnerNumber;
  final String partnerName;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    const gap = SizedBox(height: AppSpacing.md);

    Widget perspective(int partner) {
      final p = reflection.perspectiveOf(partner);
      if (p == null) return const SizedBox.shrink();
      final mine = partner == myPartnerNumber;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: TherabotCard(
          tinted: mine,
          label: mine ? 'Your perspective' : "$partnerName's perspective",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                p.summary,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: mine ? scheme.onPrimaryContainer : null,
                ),
              ),
              if (p.needs.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  (mine ? 'What you need' : 'What $partnerName needs')
                      .toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: mine
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SoftPills(items: p.needs, onTinted: mine),
              ],
            ],
          ),
        ),
      );
    }

    final children = <Widget>[
      // Partner 1 first, then Partner 2, the same order for both of you.
      perspective(1),
      perspective(2),
      if (reflection.differences.isNotEmpty) ...[
        TherabotCard(
          label: 'Where you see it differently',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How Therabot understood your two summaries. You can '
                'correct it together.',
                style: muted,
              ),
              const SizedBox(height: AppSpacing.sm),
              SoftList(items: reflection.differences),
            ],
          ),
        ),
        gap,
      ],
      if (reflection.possibleMisunderstandings.isNotEmpty) ...[
        TherabotCard(
          tentative: true,
          label: 'Possible misunderstandings',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Only guesses, not facts. You two know what is true.',
                style: muted,
              ),
              const SizedBox(height: AppSpacing.sm),
              SoftList(
                items: reflection.possibleMisunderstandings,
                italic: true,
                marker: '?',
              ),
            ],
          ),
        ),
        gap,
      ],
      if (reflection.commonGround.isNotEmpty) ...[
        TherabotCard(
          label: 'Common ground',
          child: SoftList(items: reflection.commonGround, marker: '♡'),
        ),
        gap,
      ],
      if (reflection.discussionQuestions.isNotEmpty) ...[
        TherabotCard(
          label: 'Questions you could talk about',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < reflection.discussionQuestions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '${i + 1}.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          reflection.discussionQuestions[i],
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: animate ? staggered(children) : children,
    );
  }
}
