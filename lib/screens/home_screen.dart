import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/couple.dart';
import '../models/memory.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../services/memory_service.dart';
import '../services/profile_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/avatar_circle.dart';
import '../widgets/atoms/section_label.dart';
import '../widgets/molecules/countdown_card.dart';
import '../widgets/molecules/memory_card.dart';
import 'memory_detail_screen.dart';

/// Home: who is in the space, the anniversary countdown, and (while waiting)
/// the code to send your partner. Pull down to refresh.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Couple? _couple;
  List<Profile> _members = [];
  Memory? _latest;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final coupleId = widget.profile.coupleId!;
      final couple = await CoupleService.couple(coupleId);
      final members =
          await ProfileService.withPhotos(await CoupleService.members(coupleId));
      final latest = await MemoryService.list(coupleId, limit: 1);
      if (!mounted) return;
      setState(() {
        _couple = couple;
        _members = members;
        _latest = latest.isEmpty ? null : latest.first;
        _error = null;
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

  Profile? get _partner {
    for (final m in _members) {
      if (m.userId != widget.profile.userId) return m;
    }
    return null;
  }

  String _authorName(Memory m) {
    if (m.authorId == widget.profile.userId) return 'you';
    for (final p in _members) {
      if (p.userId == m.authorId) return p.displayName;
    }
    return 'your partner';
  }

  Future<void> _openLatest(Memory memory) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MemoryDetailScreen(
          memory: memory,
          authorName: _authorName(memory),
          isMine: memory.authorId == widget.profile.userId,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _setAnniversary() async {
    final couple = _couple;
    if (couple == null) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: couple.anniversaryDate ?? now,
      firstDate: DateTime(1970),
      lastDate: now,
      helpText: 'The day you got together',
    );
    if (picked == null) return;
    try {
      await CoupleService.setAnniversary(couple.id, picked);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Anniversary saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final couple = _couple;
    final names = _members.map((m) => m.displayName).join(' & ');

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          children: [
            if (_error != null) ...[
              Text(_error!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.error)),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: 'Try again',
                  variant: AppButtonVariant.outlined,
                  onPressed: _load,
                ),
              ),
            ],
            if (couple != null) ...[
              Text(names,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: scheme.primary)),
              const SizedBox(height: AppSpacing.lg),
              if (_partner == null) ...[
                _InviteBanner(code: couple.pairingCode),
                const SizedBox(height: AppSpacing.lg),
              ],
              CountdownCard(
                anniversary: couple.anniversaryDate,
                onTap: _setAnniversary,
              ),
              if (_members.any((m) => m.birthday != null)) ...[
                const SizedBox(height: AppSpacing.xxl),
                const SectionLabel(text: 'Birthdays'),
                for (final m in _members)
                  if (m.birthday != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          AvatarCircle(
                            name: m.displayName,
                            imageUrl: m.avatarUrl,
                            size: 36,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              birthdayLine(
                                birthday: m.birthday!,
                                isMe: m.userId == widget.profile.userId,
                                name: m.displayName,
                              ),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              const SectionLabel(text: 'Latest memory'),
              if (_latest == null)
                Text('No memories yet. Add one from the Timeline tab.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant))
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: MemoryCard(
                      memory: _latest!,
                      authorName: _authorName(_latest!),
                      onTap: () => _openLatest(_latest!),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown until the partner joins: the code, with a copy button.
class _InviteBanner extends StatelessWidget {
  const _InviteBanner({required this.code});

  final String code;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Code copied')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Waiting for your partner',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: scheme.onPrimaryContainer)),
          const SizedBox(height: AppSpacing.xs),
          Text('Send them this code so they can join. Pull down to refresh '
              'once they have.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onPrimaryContainer)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  code,
                  style: theme.textTheme.titleLarge?.copyWith(
                    letterSpacing: 6,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy code',
                icon: const Icon(Icons.copy_rounded),
                color: scheme.onPrimaryContainer,
                onPressed: () => _copy(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
