import 'package:flutter/material.dart';

import '../../models/mood.dart';
import '../../theme/app_spacing.dart';
import 'home_card.dart';

/// Today's mood for both of you, and the last 7 days at a glance.
class MoodCard extends StatelessWidget {
  const MoodCard({
    super.key,
    required this.entries,
    required this.myUserId,
    required this.partnerId,
    required this.partnerName,
    required this.today,
    required this.onCheckIn,
    required this.onHistory,
  });

  final List<MoodEntry> entries;
  final String myUserId;
  final String? partnerId;
  final String partnerName;
  final DateTime today;
  final VoidCallback onCheckIn;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted =
        theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final mine = latestMoodOn(entries, myUserId, today);
    final theirs =
        partnerId == null ? null : latestMoodOn(entries, partnerId!, today);
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    Widget row(String who, MoodEntry? e, String empty) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e?.mood.emoji ?? '\u2014',
                  style: const TextStyle(fontSize: 26)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e == null ? '$who: $empty' : '$who: ${e.mood.label}',
                      style: theme.textTheme.titleMedium,
                    ),
                    if (e?.note != null) Text(e!.note!, style: muted),
                    if (e != null && !e.isShared)
                      Text('Only you can see this', style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        );

    return HomeCard(
      title: "Today's mood",
      actionLabel: 'History',
      onAction: onHistory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row('You', mine, 'not checked in yet'),
          if (partnerId != null)
            row(partnerName, theirs, 'hasn\'t shared a mood today'),
          const SizedBox(height: AppSpacing.xs),
          // last 7 days: your mood over your partner's
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 6; i >= 0; i--)
                () {
                  final day = today.subtract(Duration(days: i));
                  final a = latestMoodOn(entries, myUserId, day);
                  final b = partnerId == null
                      ? null
                      : latestMoodOn(entries, partnerId!, day);
                  return Column(
                    children: [
                      Text(letters[day.weekday - 1],
                          style: theme.textTheme.labelSmall),
                      Text(a?.mood.emoji ?? '\u00B7',
                          style: const TextStyle(fontSize: 16)),
                      Text(b?.mood.emoji ?? '\u00B7',
                          style: const TextStyle(fontSize: 16)),
                    ],
                  );
                }(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: onCheckIn,
              icon: const Icon(Icons.mood),
              label: Text(mine == null ? 'Check in' : 'Update my mood'),
            ),
          ),
        ],
      ),
    );
  }
}
