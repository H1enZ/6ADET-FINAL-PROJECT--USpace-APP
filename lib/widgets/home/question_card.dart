import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import 'home_card.dart';

/// Today's question, your answer, and your partner's (once you have
/// answered; the database keeps it hidden until then).
class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.question,
    required this.myAnswer,
    required this.partnerAnswer,
    required this.partnerAnswered,
    required this.partnerName,
    required this.hasPartner,
    required this.onAnswer,
    required this.onArchive,
  });

  final String question;
  final String? myAnswer;
  final String? partnerAnswer;
  final bool partnerAnswered;
  final String partnerName;
  final bool hasPartner;
  final VoidCallback onAnswer;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted =
        theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

    final String partnerLine;
    if (!hasPartner) {
      partnerLine = 'Your partner can answer once they join.';
    } else if (myAnswer == null && partnerAnswered) {
      partnerLine = '$partnerName answered! Answer too to see theirs. 💌';
    } else if (partnerAnswer != null) {
      partnerLine = '';
    } else {
      partnerLine = 'Waiting for $partnerName\'s answer.';
    }

    return HomeCard(
      title: "Today's question",
      actionLabel: 'Past',
      onAction: onArchive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(question, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (myAnswer != null) ...[
            Text('You', style: theme.textTheme.labelSmall),
            Text(myAnswer!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (partnerAnswer != null) ...[
            Text(partnerName, style: theme.textTheme.labelSmall),
            Text(partnerAnswer!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (partnerLine.isNotEmpty) Text(partnerLine, style: muted),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: onAnswer,
              icon: const Icon(Icons.edit_note),
              label: Text(myAnswer == null ? 'Answer' : 'Edit my answer'),
            ),
          ),
        ],
      ),
    );
  }
}
