import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../atoms/section_label.dart';

/// The white outlined card every Home section sits in, with a small-caps
/// title and an optional action on the right.
class HomeCard extends StatelessWidget {
  const HomeCard({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.cardPadding, AppSpacing.sm, AppSpacing.sm, AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(text: title, actionLabel: actionLabel, onAction: onAction),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: child,
          ),
        ],
      ),
    );
  }
}
