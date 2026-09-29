import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../theme/app_spacing.dart';
import '../../utils/daily_content.dart';
import 'home_card.dart';

/// What the two of you have been up to, newest first. Updates live.
class ActivityFeed extends StatelessWidget {
  const ActivityFeed({
    super.key,
    required this.activities,
    required this.myUserId,
    required this.names,
  });

  final List<Activity> activities;
  final String myUserId;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted =
        theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

    return HomeCard(
      title: 'Recent activity',
      child: activities.isEmpty
          ? Text('Nothing yet. Check in your mood, answer today\'s question, '
              'or send a hug to get things started.', style: muted)
          : Column(
              children: [
                for (final a in activities)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: scheme.primaryContainer,
                          child: Text(a.emoji, style: const TextStyle(fontSize: 14)),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            a.describe(
                              name: names[a.actorId] ?? 'Your partner',
                              isMe: a.actorId == myUserId,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(timeAgo(a.createdAt), style: muted),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
