import 'package:flutter/material.dart';

import '../../models/therabot.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/effects/motion.dart';
import '../../widgets/therabot/therabot_widgets.dart';

/// The couple's shared reflection, exactly as Therabot returned it. It is
/// built only from the two perspective summaries: never anyone's private
/// chat, answers or drafts. Sections that came back empty are left out, never filled in.
class SharedReflectionView extends StatelessWidget {
  const SharedReflectionView({
    super.key,
    required this.reflection,
    required this.names,
    this.animate = true,
  });

  final SharedReflection reflection;

  /// Shows "Partner 1" / "Partner 2" as usernames. Display only.
  final TherabotNames names;
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
      final mine = partner == names.myPartnerNumber;
      final name = names.of(partner);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: TherabotCard(
          tinted: mine,
          label: "$name's perspective",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PartnerText(
                p.summary,
                names: names,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: mine ? scheme.onPrimaryContainer : null,
                ),
              ),
              if (p.needs.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'What $name needs'.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: mine
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SoftPills(items: p.needs, onTinted: mine, names: names),
              ],
            ],
          ),
        ),
      );
    }

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    final children = <Widget>[
      // 1. What you both seem to be experiencing (and what each may need):
      //    Partner 1 first, then Partner 2, the same order for both of you.
      heading('What you both seem to be experiencing'),
      perspective(1),
      perspective(2),
      // 2. Where your perspectives overlap.
      if (reflection.commonGround.isNotEmpty) ...[
        TherabotCard(
          label: 'Where your perspectives overlap',
          child: SoftList(
            items: reflection.commonGround,
            marker: '•',
            names: names,
          ),
        ),
        gap,
      ],
      // 3. Where you experienced things differently.
      if (reflection.differences.isNotEmpty) ...[
        TherabotCard(
          label: 'Where you experienced things differently',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How Therabot understood your two perspectives. You can '
                'correct it together.',
                style: muted,
              ),
              const SizedBox(height: AppSpacing.sm),
              SoftList(items: reflection.differences, names: names),
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
                names: names,
              ),
            ],
          ),
        ),
        gap,
      ],
      // 4. Something you could try together.
      if (reflection.somethingToTry.isNotEmpty) ...[
        TherabotCard(
          label: 'Something you could try together',
          child: SoftList(items: reflection.somethingToTry, names: names),
        ),
        gap,
      ],
      // 5. A gentle conversation starter.
      if (reflection.discussionQuestions.isNotEmpty) ...[
        TherabotCard(
          label: 'Gentle conversation starters',
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
                        child: PartnerText(
                          reflection.discussionQuestions[i],
                          names: names,
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
