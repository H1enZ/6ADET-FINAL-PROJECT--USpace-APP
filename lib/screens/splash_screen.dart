import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/seal_badge.dart';
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
///   no session              -> Sign in (waits for a tap first)
///   signed in, not paired   -> Pair
///   signed in and paired    -> Home
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _error;

  /// Set once the session check is done and the next screen is Sign in.
  /// The splash then waits for a tap instead of moving on by itself.
  Widget? _waitingForTap;

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
      const minimum = Duration(milliseconds: 1400);
      if (waited < minimum) await Future<void>.delayed(minimum - waited);

      if (!mounted) return;
      if (next is SignInScreen) {
        setState(() => _waitingForTap = next);
      } else {
        _go(next);
      }
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

  void _go(Widget next) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => next),
    );
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
    final scheme = theme.colorScheme;

    final waiting = _waitingForTap;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: waiting == null ? null : () => _go(waiting),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            // Full width, so everything is centred like the mockup.
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  const SealBadge(size: 96),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'USpace',
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: scheme.secondary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(width: 56, height: 2, color: scheme.primary),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '\u201CThe diary of what\u2019s next\u201D',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(flex: 3),
                  if (_error == null && waiting != null) ...[
                    Semantics(
                      button: true,
                      label: 'Continue to sign in',
                      child: Icon(Icons.touch_app_outlined,
                          color: scheme.primary, size: 28),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Tap anywhere to continue',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: scheme.primary),
                    ),
                  ] else if (_error == null) ...[
                    const _LoadingDots(),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Checking your session\u2026',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ] else ...[
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.error),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(label: 'Try again', onPressed: _retry),
                    TextButton(onPressed: _signOut, child: const Text('Sign out')),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three dots fading from rose to blush, as in the mockup.
class _LoadingDots extends StatelessWidget {
  const _LoadingDots();

  @override
  Widget build(BuildContext context) {
    final rose = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final alpha in const [1.0, 0.5, 0.25])
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: rose.withValues(alpha: alpha),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}
