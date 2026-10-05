import 'package:flutter/material.dart';

import '../../theme/app_effects.dart';
import '../../theme/app_spacing.dart';
import '../effects/motion.dart';

/// Selectable pill with an optional count badge. Timeline uses it for years.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;

    return Semantics(
      selected: selected,
      button: true,
      child: PressScale(
        enabled: onTap != null,
        scale: 0.95,
        // Selection eases between rose and white instead of snapping.
        child: AnimatedContainer(
          duration: motionOff(context) ? Duration.zero : AppMotion.quick,
          curve: AppMotion.snappy,
          decoration: ShapeDecoration(
            color: selected ? scheme.primary : scheme.surfaceContainerHighest,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected ? scheme.primary : scheme.outline,
              ),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40, minWidth: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foreground,
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(width: AppSpacing.xs + 2),
                        Text(
                          '$count',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: foreground.withValues(alpha: 0.75),
                          ),
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
