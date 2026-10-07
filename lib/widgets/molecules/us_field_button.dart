import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../atoms/us_icon.dart';

/// A form row that looks like a text field but opens a picker (a date, a
/// time): an uppercase label, then the value with an icon and a chevron.
/// The same in Add Memory, the Bucket List and Special dates.
class UsFieldButton extends StatelessWidget {
  const UsFieldButton({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.actionHint = 'Change date',
  });

  final String label;
  final String value;
  final UsIconData icon;
  final VoidCallback? onTap;

  /// What a tap does, for screen readers.
  final String actionHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Semantics(
          button: true,
          label: '$label, $value. $actionHint',
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: InputDecorator(
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: UsIcon(icon, size: 20, color: scheme.onSurfaceVariant),
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: UsIcon(
                    UsIcons.chevronRight,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                suffixIconConstraints: const BoxConstraints(),
              ),
              child: Text(value, style: theme.textTheme.bodyLarge),
            ),
          ),
        ),
      ],
    );
  }
}
