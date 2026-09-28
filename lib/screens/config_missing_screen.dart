import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Shown when the app was started without the Supabase settings,
/// instead of crashing on a blank screen.
class ConfigMissingScreen extends StatelessWidget {
  const ConfigMissingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.formMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('USpace', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.lg),
                Text('This build has no Supabase settings.',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                SelectableText(
                  'Running locally: copy .env.example to .env, fill in '
                  'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY, then run\n\n'
                  'flutter run -d chrome --dart-define-from-file=.env\n\n'
                  'On GitHub Pages: add both as repository secrets '
                  '(Settings > Secrets and variables > Actions) and push again.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
