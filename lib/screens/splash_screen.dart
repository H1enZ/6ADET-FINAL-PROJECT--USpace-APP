import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_button.dart';
import 'main_shell.dart';
import 'pair_screen.dart';
import 'sign_in_screen.dart';

/// Sends the user back to Splash, which works out where they belong.
/// Called after signing in, pairing and signing out.
void restartFlow(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
    (route) => false,
  );
}

/// The entry point. Decides between three routes:
///   no session              -> Sign in
///   signed in, not paired   -> Pair
///   signed in and paired    -> Home
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final started = DateTime.now();
    try {
      final Widget next;
      if (AuthService.session == null) {
        next = const SignInScreen();
      } else {
        final profile = await CoupleService.myProfile();
        if (profile == null) {
          throw StateError('no profile');
        }
        next = profile.isPaired
            ? MainShell(profile: profile)
            : PairScreen(profile: profile);
      }

      // Hold the splash briefly so it doesn't flash.
      final waited = DateTime.now().difference(started);
      const minimum = Duration(milliseconds: 700);
      if (waited < minimum) await Future<void>.delayed(minimum - waited);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => next),
      );
    } on StateError {
      if (!mounted) return;
      setState(() => _error =
          'Your account has no profile. Check that supabase/schema.sql '
          'was run on this Supabase project, then create the account again.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    }
  }

  void _retry() {
    setState(() => _error = null);
    _decide();
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (!mounted) return;
    restartFlow(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'USpace',
                  style: theme.textTheme.displayLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'A private space for the two of you.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
                if (_error == null)
                  Text('Checking your session…',
                      style: theme.textTheme.labelSmall)
                else ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(label: 'Try again', onPressed: _retry),
                  TextButton(onPressed: _signOut, child: const Text('Sign out')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
