import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../theme/app_effects.dart';
import '../theme/app_spacing.dart';
import '../theme/us_palette.dart';
import '../utils/anniversary.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/app_text_field.dart';
import '../widgets/atoms/us_icon.dart';
import '../widgets/effects/motion.dart';
import '../widgets/effects/soft_hearts_background.dart';
import '../widgets/molecules/us_field_button.dart';
import 'splash_screen.dart';

/// Signed in but not paired yet: start a couple, or join one with a code.
/// Same backdrop as Sign in, so it reads as the next step of one flow.
class PairScreen extends StatefulWidget {
  const PairScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final _code = TextEditingController();

  DateTime? _anniversary;
  bool _starting = false;
  bool _joining = false;
  String? _startError;
  String? _joinError;

  bool get _busy => _starting || _joining;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _pickAnniversary() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _anniversary ?? now,
      firstDate: DateTime(1970),
      lastDate: now,
      helpText: 'The day you got together',
    );
    if (!mounted || picked == null) return;
    setState(() => _anniversary = picked);
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _startError = null;
    });
    try {
      await CoupleService.createCouple(anniversary: _anniversary);
      if (!mounted) return;
      restartFlow(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _startError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _joinError = 'Invite codes are 6 characters.');
      return;
    }
    setState(() {
      _joining = true;
      _joinError = null;
    });
    try {
      await CoupleService.joinCouple(code);
      if (!mounted) return;
      restartFlow(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _joinError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
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
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

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
                      Semantics(
                        header: true,
                        child: Text(
                          'Hi, ${widget.profile.displayName}.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Start your space and send your partner the code, '
                        'or join the space they started.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppGradients.onBlushText(scheme),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      _PairCard(
                        icon: UsIcons.heart,
                        title: 'Start our space',
                        body:
                            "You'll get a 6-character code to send your "
                            'partner.',
                        children: [
                          UsFieldButton(
                            label: 'Anniversary (optional)',
                            value: _anniversary == null
                                ? 'Add a date'
                                : longDate(_anniversary!),
                            icon: UsIcons.calendar,
                            actionHint: 'Choose a date',
                            onTap: _busy ? null : _pickAnniversary,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            label: 'Start our space',
                            onPressed: _joining ? null : _start,
                            isLoading: _starting,
                            fullWidth: true,
                          ),
                          if (_startError != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _startError!,
                              style: muted?.copyWith(color: scheme.error),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      _PairCard(
                        icon: UsIcons.key,
                        title: 'Join your partner',
                        body: 'Type the code from the space they started.',
                        children: [
                          AppTextField(
                            label: 'Invite code',
                            controller: _code,
                            hintText: 'e.g. K7M2QX',
                            usIcon: UsIcons.key,
                            maxLength: 6,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _join(),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppButton(
                            label: 'Join space',
                            variant: AppButtonVariant.outlined,
                            onPressed: _starting ? null : _join,
                            isLoading: _joining,
                            fullWidth: true,
                          ),
                          if (_joinError != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _joinError!,
                              style: muted?.copyWith(color: scheme.error),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Center(
                        child: TextButton.icon(
                          onPressed: _busy ? null : _signOut,
                          style: TextButton.styleFrom(
                            foregroundColor: AppGradients.onBlushLink(scheme),
                            minimumSize: const Size(0, AppSpacing.touchTarget),
                          ),
                          icon: const UsIcon(UsIcons.logout, size: 18),
                          label: const Text('Sign out'),
                        ),
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

/// One way in: a quiet card with a small icon, a title and a line of help.
class _PairCard extends StatelessWidget {
  const _PairCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.children,
  });

  final UsIconData icon;
  final String title;
  final String body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: UsPalette.card,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        border: Border.all(color: UsPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: UsIcon(icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}
