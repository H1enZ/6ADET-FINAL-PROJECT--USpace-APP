import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../utils/anniversary.dart';
import '../atoms/unlock_ring.dart';
import '../effects/motion.dart';

/// The plum anniversary card on Home, with its ring.
/// With no anniversary set, it invites the couple to add one.
class CountdownCard extends StatelessWidget {
  const CountdownCard({
    super.key,
    required this.anniversary,
    this.onTap,
    this.today,
  });

  final DateTime? anniversary;
  final VoidCallback? onTap;

  /// Only for tests. Leave null in the app.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onCard = scheme.onSecondary;

    final Widget body;
    if (anniversary == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your anniversary',
              style: theme.textTheme.titleMedium?.copyWith(color: onCard)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Add the day you got together to start the countdown.',
            style: theme.textTheme.bodyMedium?.copyWith(color: onCard),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Tap to add it',
              style: theme.textTheme.labelLarge?.copyWith(color: onCard)),
        ],
      );
    } else {
      final info = AnniversaryInfo.from(anniversary!, today: today);
      final headline = info.yearsAtNext == 0
          ? 'Day one'
          : info.isToday
              ? 'Today'
              : '${info.daysUntilNext}';
      final caption = info.yearsAtNext == 0
          ? 'Your first anniversary is a year from today.'
          : info.isToday
              ? 'Happy ${ordinal(info.yearsAtNext)} anniversary.'
              : '${info.daysUntilNext == 1 ? 'day' : 'days'} to your '
                  '${ordinal(info.yearsAtNext)} anniversary, '
                  '${shortDate(info.nextDate)}';

      body = Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: CountUpText(
                    headline,
                    maxLines: 1,
                    style: theme.textTheme.displayLarge
                        ?.copyWith(color: onCard),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(caption,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: onCard)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${info.daysTogether} days together since '
                  '${longDate(anniversary!)}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: onCard.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          UnlockRing(
            elapsedFraction: info.isToday ? 1 : info.yearProgress,
            color: onCard,
            trackColor: onCard.withValues(alpha: 0.2),
            child: Text(
              info.yearsAtNext == 0 ? '♥' : '${info.yearsAtNext}y',
              style: theme.textTheme.titleMedium?.copyWith(color: onCard),
            ),
          ),
        ],
      );
    }

    return Material(
      color: scheme.secondary,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: body,
        ),
      ),
    );
  }
}
