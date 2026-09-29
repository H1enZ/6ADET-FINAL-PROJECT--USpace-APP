import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

class QuickAction {
  const QuickAction(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
}

/// A grid of shortcut cards: 3 per row on phones, 6 on wide screens.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final perRow = box.maxWidth >= AppSpacing.compactMax ? 6 : 3;
        const gap = AppSpacing.sm;
        final width = (box.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final a in actions)
              SizedBox(
                width: width,
                child: Material(
                  color: scheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    side: BorderSide(color: scheme.outline),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: a.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md, horizontal: AppSpacing.xs),
                      child: Column(
                        children: [
                          Icon(a.icon,
                              color: a.onTap == null
                                  ? scheme.onSurfaceVariant
                                  : scheme.primary),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            a.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
