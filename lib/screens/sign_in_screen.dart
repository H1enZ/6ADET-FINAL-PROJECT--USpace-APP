import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../services/auth_service.dart';
import '../theme/app_effects.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_text_field.dart';
import '../widgets/atoms/us_icon.dart';
import '../widgets/brand/uspace_wordmark.dart';
import '../widgets/effects/motion.dart';
import '../widgets/effects/soft_hearts_background.dart';
import 'splash_screen.dart';

/// Sign in, or create an account. One form, two modes, on a soft card.
/// Auth itself is unchanged: AuthService.signIn / signUp, then restartFlow.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  // Replaced on a mode switch, so errors shown for the other mode go away
  // (the typed text lives in the controllers and stays).
  var _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _creatingAccount = false;
  bool _showPassword = false;
  bool _busy = false;

  /// Fields are checked as you type only after the first submit, so nobody
  /// is told off before they have finished.
  bool _triedSubmit = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String? _nameError(String? v) => (v == null || v.trim().isEmpty)
      ? 'Enter the name your partner will see.'
      : null;

  String? _emailError(String? v) {
    final value = v?.trim() ?? '';
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    return valid ? null : 'Enter a valid email address.';
  }

  String? _passwordError(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Enter your password.';
    if (_creatingAccount && value.length < 8) {
      return 'Use at least 8 characters.';
    }
    return null;
  }

  void _announce(String message) => SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
  );

  void _toggleMode() {
    setState(() {
      _creatingAccount = !_creatingAccount;
      _triedSubmit = false;
      _error = null;
      _info = null;
      _formKey = GlobalKey<FormState>();
    });
    _announce(_creatingAccount ? 'Create your account' : 'Sign in');
  }

  /// After a failed submit: move to the first field that needs fixing and
  /// say what is wrong, so nobody has to hunt for the error.
  void _focusFirstInvalid() {
    final fields = [
      if (_creatingAccount) (_nameFocus, _nameError(_name.text)),
      (_emailFocus, _emailError(_email.text)),
      (_passwordFocus, _passwordError(_password.text)),
    ].where((f) => f.$2 != null).toList();
    if (fields.isEmpty) return;
    fields.first.$1.requestFocus();
    _announce(
      fields.length == 1
          ? fields.first.$2!
          : '${fields.length} fields need fixing. ${fields.first.$2}',
    );
  }

  /// Show or hide the password, then put the cursor back in it so typing
  /// carries on there (the eye button doesn't move focus by itself).
  /// Same controller and focus node, so the text and selection are kept.
  void _togglePasswordVisibility() {
    final selection = _password.selection;
    // On the web, switching this while the browser's text input is open
    // leaves it with the old settings, and it loses the field as soon as
    // the field moves (for example when the error message goes away). So
    // let go of the field first; focusing it again opens a fresh one.
    _passwordFocus.unfocus();
    setState(() => _showPassword = !_showPassword);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _busy) return;
      _passwordFocus.requestFocus();
      // A field focused from code selects all its text on the web, so the
      // next key would replace the password. Put the caret back (focus
      // changes are applied in a microtask, so this runs after).
      Future.microtask(() {
        if (mounted && selection.isValid) _password.selection = selection;
      });
    });
  }

  /// Any edit clears the last error from the server.
  void _edited(String _) {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _triedSubmit = true);
    if (!_formKey.currentState!.validate()) {
      _focusFirstInvalid();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    _announce(_creatingAccount ? 'Creating your account…' : 'Signing in…');
    var failed = false;

    try {
      if (_creatingAccount) {
        final signedIn = await AuthService.signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
        if (!signedIn) {
          if (!mounted) return;
          setState(() {
            _creatingAccount = false;
            _triedSubmit = false;
            _info =
                'Check your email and tap the confirmation link, '
                'then sign in here.';
          });
          return;
        }
      } else {
        await AuthService.signIn(email: _email.text, password: _password.text);
      }
      if (!mounted) return;
      restartFlow(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
      failed = true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // Back to the password, ready to retry (once the fields are enabled).
    if (failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _passwordFocus.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final still = motionOff(context);
    // AnimatedSize must not get a zero duration (it asserts).
    final sizeTime = still ? const Duration(milliseconds: 1) : AppMotion.medium;
    final creating = _creatingAccount;

    return Scaffold(
      body: SoftHeartsBackground(
        gradient: AppGradients.blush(theme.brightness),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin,
                vertical: AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.formMaxWidth,
                ),
                child: FadeSlideIn(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: USpaceWordmark(size: 40, isHeader: true),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'A private space for the two of you',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppGradients.onBlushText(scheme),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      _FormCard(
                        child: AutofillGroup(
                          child: Form(
                            key: _formKey,
                            autovalidateMode: _triedSubmit
                                ? AutovalidateMode.onUserInteraction
                                : AutovalidateMode.disabled,
                            child: AnimatedSize(
                              duration: sizeTime,
                              curve: AppMotion.enter,
                              alignment: Alignment.topCenter,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      creating
                                          ? 'Create your account'
                                          : 'Welcome back',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    creating
                                        ? 'Make your space, then invite your partner.'
                                        : 'Sign in to your shared space.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  if (creating) ...[
                                    AppTextField(
                                      key: const ValueKey('name'),
                                      label: 'Your name',
                                      controller: _name,
                                      focusNode: _nameFocus,
                                      enabled: !_busy,
                                      onChanged: _edited,
                                      usIcon: UsIcons.profile,
                                      maxLength: 40,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      autofillHints: const [AutofillHints.name],
                                      textInputAction: TextInputAction.next,
                                      validator: _nameError,
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                  ],
                                  AppTextField(
                                    key: const ValueKey('email'),
                                    label: 'Email',
                                    controller: _email,
                                    focusNode: _emailFocus,
                                    enabled: !_busy,
                                    onChanged: _edited,
                                    usIcon: UsIcons.mail,
                                    keyboardType: TextInputType.emailAddress,
                                    // username too, so password managers
                                    // save the email with the password.
                                    autofillHints: const [
                                      AutofillHints.email,
                                      AutofillHints.username,
                                    ],
                                    textInputAction: TextInputAction.next,
                                    validator: _emailError,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  AppTextField(
                                    key: const ValueKey('password'),
                                    label: 'Password',
                                    controller: _password,
                                    focusNode: _passwordFocus,
                                    helperText: creating
                                        ? 'At least 8 characters.'
                                        : null,
                                    enabled: !_busy,
                                    onChanged: _edited,
                                    usIcon: UsIcons.lock,
                                    obscureText: !_showPassword,
                                    autofillHints: [
                                      creating
                                          ? AutofillHints.newPassword
                                          : AutofillHints.password,
                                    ],
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    suffix: IconButton(
                                      tooltip: _showPassword
                                          ? 'Hide password'
                                          : 'Show password',
                                      icon: UsIcon(
                                        _showPassword
                                            ? UsIcons.eyeOff
                                            : UsIcons.eye,
                                        size: 22,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: AppSpacing.touchTarget,
                                        minHeight: AppSpacing.touchTarget,
                                      ),
                                      onPressed: _busy
                                          ? null
                                          : _togglePasswordVisibility,
                                    ),
                                    validator: _passwordError,
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: AppSpacing.lg),
                                    _Notice(
                                      text: _error!,
                                      icon: UsIcons.alertCircle,
                                      color: scheme.error,
                                    ),
                                  ],
                                  if (_info != null) ...[
                                    const SizedBox(height: AppSpacing.lg),
                                    _Notice(
                                      text: _info!,
                                      icon: UsIcons.mail,
                                      color: scheme.tertiary,
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.xl),
                                  _PrimaryButton(
                                    label: creating
                                        ? 'Create account'
                                        : 'Sign in',
                                    busyLabel: creating
                                        ? 'Creating your account'
                                        : 'Signing in',
                                    busy: _busy,
                                    onPressed: _submit,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            creating ? 'Already have an account?' : 'New here?',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppGradients.onBlushText(scheme),
                            ),
                          ),
                          TextButton(
                            onPressed: _busy ? null : _toggleMode,
                            style: TextButton.styleFrom(
                              foregroundColor: AppGradients.onBlushLink(scheme),
                              minimumSize: const Size(
                                0,
                                AppSpacing.touchTarget,
                              ),
                            ),
                            child: Text(
                              creating ? 'Sign in' : 'Create an account',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The soft white card the form sits on.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        boxShadow: AppShadows.raised(scheme),
      ),
      child: child,
    );
  }
}

/// An error or info message, read out as soon as it appears.
class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.icon, required this.color});

  final String text;
  final UsIconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: UsIcon(icon, color: color, size: 20)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The main action: a full-width pill. While busy it shows a spinner (or,
/// with reduce motion, the words), is disabled, and says what it is doing.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busyLabel,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final String busyLabel;
  final bool busy;
  final VoidCallback onPressed;

  static const double _height = 52;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final still = motionOff(context);
    return Semantics(
      button: true,
      enabled: !busy,
      label: busy ? '$busyLabel…' : label,
      excludeSemantics: true,
      onTap: busy ? null : onPressed,
      // A minimum height, not a fixed one: with large text the label may
      // wrap and the pill grows instead of clipping it.
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(_height),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: const StadiumBorder(),
          elevation: 0,
          // Keep the rose colour while busy (dimmed), not the grey
          // disabled look, so it reads as "working" rather than "off".
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.7),
          disabledForegroundColor: scheme.onPrimary,
        ),
        child: !busy
            ? Text(label, textAlign: TextAlign.center)
            : still
            ? Text('$busyLabel…', textAlign: TextAlign.center)
            : SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: scheme.onPrimary,
                ),
              ),
      ),
    );
  }
}
