import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/section_label.dart';
import 'splash_screen.dart';

/// Profile & Settings. For now: who you are, and sign out.
/// Theme switch and name editing come in a later week.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.profile});

  final Profile profile;

  Future<void> _signOut(BuildContext context) async {
    await AuthService.signOut();
    if (!context.mounted) return;
    restartFlow(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          const SectionLabel(text: 'Signed in as'),
          Text(profile.displayName, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(AuthService.user?.email ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: AppSpacing.xxxl),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Sign out',
              icon: Icons.logout,
              variant: AppButtonVariant.outlined,
              onPressed: () => _signOut(context),
            ),
          ),
        ],
      ),
    );
  }
}
