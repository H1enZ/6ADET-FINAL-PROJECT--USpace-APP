import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../services/profile_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/us_icon.dart';
import 'chat_screen.dart';

/// Chat as a bottom-navigation tab. Loads the two of you once, then shows
/// the existing ChatScreen unchanged. MainShell builds this only while the
/// tab is open, so Chat loads, marks messages read and listens for new ones
/// exactly as it did when it was a pushed screen.
class ChatTab extends StatefulWidget {
  const ChatTab({super.key, required this.profile});

  final Profile profile;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
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
      final members = await ProfileService.withPhotos(
        await CoupleService.members(coupleId),
      );
      if (!mounted) return;
      setState(() {
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
    final scheme = theme.colorScheme;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final coupleId = widget.profile.coupleId;
    final partner = _partner;
    if (_error != null || coupleId == null || partner == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
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
                  UsIcon(UsIcons.chat, size: 40, color: scheme.primary),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _error ??
                        'Your private chat opens once your partner joins with your invite code.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Try again',
                      variant: AppButtonVariant.outlined,
                      onPressed: _load,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    return ChatScreen(coupleId: coupleId, me: _me!, partner: partner);
  }
}
