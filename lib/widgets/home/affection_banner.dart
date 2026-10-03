import 'package:flutter/material.dart';

import '../../theme/app_effects.dart';
import '../../theme/app_spacing.dart';

/// A hug, kiss or other gesture your partner sent that you have not seen
/// yet. Shown on Home only while there is one; it disappears once you
/// thank them or send one back.
class AffectionBanner extends StatelessWidget {
  const AffectionBanner({
    super.key,
    required this.partnerName,
    required this.unseen,
    required this.onSendBack,
    required this.onDismiss,
    this.busy = false,
  });

  final String partnerName;

  /// Rows from `affections` your partner sent that you have not seen.
  final List<Map<String, dynamic>> unseen;
  final VoidCallback onSendBack;
  final VoidCallback onDismiss;

  /// While a hug is being sent: both buttons wait, so a double tap can't
  /// send twice or dismiss twice.
  final bool busy;

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
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.soft(scheme),
        ),
        child: Column(
          // stretch, so the button Wrap below spans the card and can align end.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final a in unseen.take(3)) ...[
              Text(
                affectionText(a['kind'] as String, partnerName),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
              if (a['message'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '“${a['message']}”',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xs),
            ],
            if (unseen.length > 3)
              Text(
                '+ ${unseen.length - 3} more',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            // Wrap, not Row: on a narrow screen the second button moves to
            // its own line instead of overflowing.
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                TextButton(
                  onPressed: busy ? null : onDismiss,
                  child: const Text('Aww, thank you'),
                ),
                FilledButton.tonal(
                  onPressed: busy ? null : onSendBack,
                  child: const Text('Send a hug back'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
