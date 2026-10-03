import 'package:flutter/material.dart';

import '../../models/mood.dart';
import '../../models/mood_visual.dart';
import '../../theme/app_spacing.dart';

/// The partner's mood today, small and quiet under the hero: a coloured dot
/// and one line. Tapping opens mood history.
class PartnerMoodChip extends StatelessWidget {
  const PartnerMoodChip({
    super.key,
    required this.partnerName,
    required this.mood,
    required this.onTap,
  });

  final String partnerName;

  /// Their latest shared mood today, or null.
  final Mood? mood;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final m = mood;
    final text = m == null
        ? "$partnerName hasn't shared a mood today"
        : '$partnerName is feeling ${m.label}';
    final dot = m == null
        ? scheme.outline
        : MoodVisual.of(m).accentFor(theme.brightness);

    return Semantics(
      button: true,
      label: '$text. Open mood history',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: StadiumBorder(side: BorderSide(color: scheme.outline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.touchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
