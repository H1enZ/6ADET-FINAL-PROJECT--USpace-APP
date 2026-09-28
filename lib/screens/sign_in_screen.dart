import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/app_text_field.dart';
import 'splash_screen.dart';

/// Sign in, or create an account. One form, two modes.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _creatingAccount = false;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _creatingAccount = !_creatingAccount;
      _error = null;
      _info = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });

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
            _info = 'Check your email and tap the confirmation link, '
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppSpacing.formMaxWidth),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('USpace',
                          style: theme.textTheme.displayLarge
                              ?.copyWith(color: scheme.primary)),
                      const SizedBox(height: AppSpacing.xs),
                      Text('A private space for the two of you.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: AppSpacing.huge),
                      Text(
                        _creatingAccount ? 'Create your account' : 'Sign in',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (_creatingAccount) ...[
                        AppTextField(
                          label: 'Your name',
                          controller: _name,
                          prefixIcon: Icons.person_outline,
                          maxLength: 40,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter the name your partner will see.'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      AppTextField(
                        label: 'Email',
                        controller: _email,
                        prefixIcon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          final valid =
                              RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
                          return valid ? null : 'Enter a valid email address.';
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        label: 'Password',
                        controller: _password,
                        prefixIcon: Icons.lock_outline,
                        obscureText: !_showPassword,
                        autofillHints: [
                          _creatingAccount
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        suffix: IconButton(
                          tooltip:
                              _showPassword ? 'Hide password' : 'Show password',
                          icon: Icon(_showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                        validator: (v) {
                          final value = v ?? '';
                          if (value.isEmpty) return 'Enter your password.';
                          if (_creatingAccount && value.length < 8) {
                            return 'Use at least 8 characters.';
                          }
                          return null;
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(_error!,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: scheme.error)),
                      ],
                      if (_info != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(_info!,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: scheme.tertiary)),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      AppButton(
                        label: _creatingAccount ? 'Create account' : 'Sign in',
                        onPressed: _submit,
                        isLoading: _busy,
                        fullWidth: true,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: _busy ? null : _toggleMode,
                        child: Text(_creatingAccount
                            ? 'I already have an account'
                            : 'Create an account'),
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
