import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/app_text_field.dart';
import '../widgets/atoms/section_label.dart';
import 'splash_screen.dart';

/// Signed in but not paired yet: start a couple, or join one with a code.
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
    final errorStyle = theme.textTheme.bodyMedium?.copyWith(color: scheme.error);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pair with your partner'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppSpacing.formMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Hi, ${widget.profile.displayName}.',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Start your space and send your partner the code, '
                    'or join the space they started.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),

                  // ---- Start ----
                  const SectionLabel(text: 'Start our space'),
                  Text("You'll get a 6-character code to send your partner.",
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: _anniversary == null
                        ? 'Add our anniversary (optional)'
                        : 'Anniversary: ${longDate(_anniversary!)}',
                    icon: Icons.event_outlined,
                    variant: AppButtonVariant.outlined,
                    onPressed: _busy ? null : _pickAnniversary,
                    fullWidth: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Start our space',
                    onPressed: _joining ? null : _start,
                    isLoading: _starting,
                    fullWidth: true,
                  ),
                  if (_startError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(_startError!, style: errorStyle),
                  ],

                  const SizedBox(height: AppSpacing.xxxl),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                        child: Text('or', style: theme.textTheme.labelSmall),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxxl),

                  // ---- Join ----
                  const SectionLabel(text: 'Join your partner'),
                  AppTextField(
                    label: 'Invite code',
                    controller: _code,
                    hintText: 'e.g. K7M2QX',
                    prefixIcon: Icons.key_outlined,
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
                    Text(_joinError!, style: errorStyle),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
