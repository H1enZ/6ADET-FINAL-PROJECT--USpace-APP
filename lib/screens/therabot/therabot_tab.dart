import 'package:flutter/material.dart';

import '../../models/couple.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../services/couple_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/atoms/app_button.dart';
import 'therabot_screen.dart';

/// Therabot as a bottom-navigation tab. Loads the couple once, then shows
/// the existing TherabotScreen unchanged. Therabot needs both partners, so
/// before pairing it explains that instead.
class TherabotTab extends StatefulWidget {
  const TherabotTab({super.key, required this.profile});

  final Profile profile;

  @override
  State<TherabotTab> createState() => _TherabotTabState();
}

class _TherabotTabState extends State<TherabotTab> {
  Couple? _couple;
  Profile? _me;
  Profile? _partner;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final coupleId = widget.profile.coupleId;
    if (coupleId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final couple = await CoupleService.couple(coupleId);
      final members = await ProfileService.withPhotos(
        await CoupleService.members(coupleId),
      );
      if (!mounted) return;
      setState(() {
        _couple = couple;
        _me =
            members
                .where((m) => m.userId == widget.profile.userId)
                .firstOrNull ??
            widget.profile;
        _partner = members
            .where((m) => m.userId != widget.profile.userId)
            .firstOrNull;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final couple = _couple;
    final partner = _partner;
    if (_error != null || couple == null || partner == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Therabot')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.formMaxWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error ??
                        'Therabot is for the two of you. Once your partner joins, you can reflect together here.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Try again',
                    variant: AppButtonVariant.outlined,
                    onPressed: _load,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return TherabotScreen(
      coupleId: couple.id,
      partnerName: partner.displayName,
      me: _me,
      partner: partner,
      anniversary: couple.anniversaryDate,
    );
  }
}
