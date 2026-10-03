import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../../theme/app_spacing.dart';
import '../../utils/daily_content.dart';
import '../atoms/avatar_circle.dart';
import '../effects/heartbeat.dart';

/// "Good morning, Mikko ❤️", today's date, your partner, today's line, and
/// any hug or kiss your partner sent that you have not seen yet.
class WelcomeCard extends StatelessWidget {
  const WelcomeCard({
    super.key,
    required this.me,
    required this.partner,
    required this.now,
    required this.unseenAffection,
    required this.onSendBack,
    required this.onDismissAffection,
  });

  final Profile me;
  final Profile? partner;
  final DateTime now;

  /// Rows from `affections` your partner sent that you have not seen.
  final List<Map<String, dynamic>> unseenAffection;
  final VoidCallback onSendBack;
  final VoidCallback onDismissAffection;

  static String affectionText(String kind, String name) => switch (kind) {
        'hug' => '$name sent you a big warm hug 🫂',
        'kiss' => '$name sent you a kiss 💋',
        'cuddle' => '$name sent you a cuddle 🤗',
        'comfort' => '$name sent you some comfort 💗',
        'listen' => '$name wants to talk. Can you listen? 👂',
        _ => '$name sent you some love ❤️',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onCard = scheme.onPrimaryContainer;
    final firstName = me.displayName.split(' ').first;
    final p = partner;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fullDate(now).toUpperCase(),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: onCard.withValues(alpha: 0.75))),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Flexible(
                child: Text('${greetingFor(now)}, $firstName',
                    style: theme.textTheme.titleLarge?.copyWith(color: onCard)),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Heartbeat(child: Text('❤️', style: TextStyle(fontSize: 20))),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              AvatarCircle(
                  name: me.displayName,
                  imageUrl: me.avatarUrl,
                  size: 40,
                  background: scheme.surfaceContainerHighest),
              const SizedBox(width: AppSpacing.xs),
              if (p != null)
                AvatarCircle(
                    name: p.displayName,
                    imageUrl: p.avatarUrl,
                    size: 40,
                    background: scheme.surfaceContainerHighest),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  p == null
                      ? 'Waiting for your partner to join'
                      : 'You & ${p.displayName}',
                  style: theme.textTheme.titleMedium?.copyWith(color: onCard),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '\u201C${dailyLine(now)}\u201D',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onCard,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (unseenAffection.isNotEmpty && p != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final a in unseenAffection.take(3)) ...[
                    Text(affectionText(a['kind'] as String, p.displayName),
                        style: theme.textTheme.titleMedium),
                    if (a['message'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('\u201C${a['message']}\u201D',
                            style: theme.textTheme.bodyMedium),
                      ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  if (unseenAffection.length > 3)
                    Text('+ ${unseenAffection.length - 3} more',
                        style: theme.textTheme.labelSmall),
                  // Wrap, not Row: on a narrow screen the second button
                  // moves to its own line instead of overflowing.
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      TextButton(
                          onPressed: onDismissAffection,
                          child: const Text('Aww, thank you')),
                      FilledButton.tonal(
                          onPressed: onSendBack,
                          child: const Text('Send a hug back')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
