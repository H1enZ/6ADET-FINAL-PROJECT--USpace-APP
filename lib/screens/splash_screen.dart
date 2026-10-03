import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../theme/app_effects.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/brand/uspace_wordmark.dart';
import '../widgets/effects/motion.dart';
import '../widgets/effects/soft_hearts_background.dart';
import 'main_shell.dart';
import 'pair_screen.dart';
import 'sign_in_screen.dart';

/// Sends the user back to Splash, which works out where they belong.
/// Called after signing in, pairing and signing out.
void restartFlow(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    _fadeRoute(context, const SplashScreen()),
    (route) => false,
  );
}

/// A soft, quick fade between the entry screens (none with reduce motion).
PageRoute<void> _fadeRoute(BuildContext context, Widget page) {
  final still = motionOff(context);
  return PageRouteBuilder<void>(
    transitionDuration: still ? Duration.zero : AppMotion.quick,
    reverseTransitionDuration: still ? Duration.zero : AppMotion.quick,
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
      child: child,
    ),
  );
}

/// The signed-in account has no profile row (schema not applied).
class _NoProfile implements Exception {
  const _NoProfile();
}

/// The entry point. A short, quiet moment with the wordmark while it decides
/// where you belong:
///   no session              -> Sign in
///   signed in, not paired   -> Pair
///   signed in and paired    -> Home
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  String? _error;

  /// True once the check has taken a while, to show a quiet "loading" line.
  bool _slow = false;

  /// Shows the "slow" line; cancelled on retry, routing and dispose.
  Timer? _slowTimer;

  // The wordmark fades in and settles from 0.96 to 1.0, quickly.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _intro,
    curve: AppMotion.enter,
  );
  late final Animation<double> _scale = Tween(
    begin: 0.96,
    end: 1.0,
  ).animate(_fade);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (motionOff(context)) {
      _intro.value = 1; // shown at once, no movement
    } else {
      _intro.forward();
    }
    _decide();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _intro.dispose();
    super.dispose();
  }

  Future<void> _decide() async {
    final started = DateTime.now();
    final still = motionOff(context);
    // After a moment, say we're still working, so a slow network doesn't
    // look like a frozen screen.
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _error == null) setState(() => _slow = true);
    });
    try {
      final Widget next;
      if (AuthService.session == null) {
        next = const SignInScreen();
      } else {
        final profile = await CoupleService.myProfile();
        if (profile == null) throw const _NoProfile();
        next = profile.isPaired
            ? MainShell(profile: profile)
            : PairScreen(profile: profile);
      }

      // Hold just long enough for the wordmark to land, so it doesn't flash.
      final minimum = still
          ? const Duration(milliseconds: 300)
          : const Duration(milliseconds: 500);
      final waited = DateTime.now().difference(started);
      if (waited < minimum) await Future<void>.delayed(minimum - waited);

      _slowTimer?.cancel();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(_fadeRoute(context, next));
    } on _NoProfile {
      _slowTimer?.cancel();
      if (!mounted) return;
      setState(
        () => _error =
            "We couldn't find your profile. Sign out, then sign in or "
            'create your account again.',
      );
    } catch (e) {
      _slowTimer?.cancel();
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _slow = false;
    });
    _decide();
  }

  Future<void> _signOut() async {
    try {
      await AuthService.signOut();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
      return;
    }
    if (!mounted) return;
    restartFlow(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SoftHeartsBackground(
        gradient: AppGradients.blush(theme.brightness),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.formMaxWidth,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _fade,
                      child: ScaleTransition(
                        scale: _scale,
                        child: Column(
                          children: [
                            const USpaceWordmark(size: 44, isHeader: true),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'A private space for the two of you',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppGradients.onBlushText(scheme),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.huge),
                    if (_error != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(label: 'Try again', onPressed: _retry),
                      TextButton(
                        onPressed: _signOut,
                        style: TextButton.styleFrom(
                          foregroundColor: AppGradients.onBlushLink(scheme),
                          minimumSize: const Size(
                            AppSpacing.touchTarget,
                            AppSpacing.touchTarget,
                          ),
                        ),
                        child: const Text('Sign out'),
                      ),
                    ] else
                      // Reserved height, so the wordmark never jumps.
                      SizedBox(
                        height: AppSpacing.xxl,
                        child: AnimatedOpacity(
                          opacity: _slow ? 1 : 0,
                          duration: motionOff(context)
                              ? Duration.zero
                              : AppMotion.medium,
                          child: Semantics(
                            liveRegion: _slow,
                            child: Text(
                              'Opening your space…',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppGradients.onBlushText(scheme),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
