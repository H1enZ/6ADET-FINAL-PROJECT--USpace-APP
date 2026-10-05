import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../models/love_note.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../services/note_service.dart';
import '../services/profile_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/effects/floating_hearts.dart';
import '../widgets/effects/motion.dart';
import '../widgets/effects/seal_opening.dart';
import '../widgets/home/quick_actions.dart';
import '../widgets/notes/note_style.dart';
import 'love_note_detail_screen.dart';
import 'time_capsules/time_capsule_screen.dart';
import 'write_love_note_screen.dart';
import '../widgets/effects/smooth_scroll.dart';

/// Love Notes: every note you can read, filtered by type, plus Previous
/// Capsules (the older notes-based Time Capsules, which still open by
/// themselves at their moment). New Time Capsules live on their own screen,
/// reached from the card under the Write button. New notes arrive live.
class LoveNotesScreen extends StatefulWidget {
  const LoveNotesScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<LoveNotesScreen> createState() => _LoveNotesScreenState();
}

class _LoveNotesScreenState extends State<LoveNotesScreen> {
  /// Mouse-wheel scrolling glides instead of jumping.
  final _scroll = SmoothScrollController();

  List<LoveNote> _notes = [];
  List<SealedNote> _sealed = [];
  Map<String, Profile> _people = {};
  bool _loading = true;
  String? _error;
  Timer? _tick;
  RealtimeChannel? _live;

  String get _coupleId => widget.profile.coupleId!;
  String get _myId => widget.profile.userId;

  String get _partnerName {
    for (final e in _people.entries) {
      if (e.key != _myId) return e.value.displayName;
    }
    return 'your partner';
  }

  @override
  void initState() {
    super.initState();
    _load();
    // Re-draw countdowns, and reload when a capsule's moment arrives.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (_sealed.any((s) => s.isReady())) {
        _load();
      } else {
        setState(() {});
      }
    });
    try {
      _live = NoteService.listen(_coupleId, () {
        if (mounted) _load();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _scroll.dispose();
    _tick?.cancel();
    final live = _live;
    if (live != null) NoteService.stopListening(live);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final before = {for (final s in _sealed) s.id};
      final members = await ProfileService.withPhotos(
        await CoupleService.members(_coupleId),
      );
      final notes = await NoteService.list(_coupleId);
      final sealed = await NoteService.sealed();
      if (!mounted) return;
      final justOpened = notes.where((n) => before.contains(n.id)).toList();
      setState(() {
        _people = {for (final m in members) m.userId: m};
        _notes = notes;
        _sealed = sealed;
        _error = null;
        _loading = false;
      });
      if (justOpened.isNotEmpty) {
        final first = justOpened.first;
        final from = _nameOf(first.authorId);
        await showSealOpening(
          context,
          fromName: from == 'You' ? 'you' : from,
          teaser: first.capsuleTitle,
          preview: first.body,
        );
        if (!mounted) return;
        showFloatingHearts(context, emoji: '💌');
        _showMessage(
          justOpened.length == 1
              ? 'A time capsule just opened 💌'
              : '${justOpened.length} time capsules just opened 💌',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  void _showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  String _nameOf(String userId) => userId == _myId
      ? 'You'
      : (_people[userId]?.displayName ?? 'Your partner');

  Future<void> _write() async {
    final sent = await openWriteLoveNote(
      context,
      coupleId: _coupleId,
      partnerName: _partnerName,
    );
    if (!sent) return;
    await _load();
    if (!mounted) return;
    showEnvelopeFly(context, emoji: '💌');
    _showMessage('Sent to $_partnerName');
  }

  Future<void> _open(LoveNote note) async {
    final author = _people[note.authorId];
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoveNoteDetailScreen(
          note: note,
          authorName:
              author?.displayName ??
              (note.authorId == _myId ? 'You' : 'Your partner'),
          authorAvatarUrl: author?.avatarUrl,
          isMine: note.authorId == _myId,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _openTimeCapsules() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TimeCapsuleScreen(profile: widget.profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final notes = _notes;
    const side = EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin);

    return Scaffold(
      backgroundColor: NotePalette.background,
      body: NotesBackground(
        child: SafeArea(
          bottom: false,
          child: _loading
              ? const SkeletonList()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      0,
                      AppSpacing.xl,
                      0,
                      AppSpacing.xxl,
                    ),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: side,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const _Header(),
                                    const SizedBox(height: AppSpacing.xl),
                                    NotePrimaryButton(
                                      label: 'Write a Love Note',
                                      icon: Icons.add_rounded,
                                      onPressed: _write,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    _CapsuleLink(onTap: _openTimeCapsules),
                                    const SizedBox(height: AppSpacing.xl),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Padding(
                                padding: side,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (_error != null) ...[
                                      Text(
                                        _error!,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme.colorScheme.error,
                                            ),
                                      ),
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
                                    if (notes.isEmpty && _error == null)
                                      const _EmptyNotes()
                                    else
                                      for (final n in notes)
                                        _NoteCard(
                                          note: n,
                                          onTap: () => _open(n),
                                        ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Semantics(
                header: true,
                child: Text('Love Notes', style: NotePalette.display(36)),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            // Two small hearts beside the title.
            ExcludeSemantics(
              child: SizedBox(
                width: 34,
                height: 34,
                child: Stack(
                  children: [
                    Positioned(
                      left: 2,
                      top: 0,
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 18,
                        color: NotePalette.rose.withValues(alpha: 0.85),
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 12,
                        color: NotePalette.pink.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Little words worth keeping.',
          style: theme.textTheme.bodyLarge?.copyWith(color: NotePalette.pink),
        ),
      ],
    );
  }
}

/// The way into Time Capsules: a slim plum row under the Write button.
class _CapsuleLink extends StatelessWidget {
  const _CapsuleLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Time Capsules. Write a letter that opens later',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: noteCardDecoration(radius: AppRadius.card),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  const QuickActionArtView(QuickActionArt.capsule, size: 50),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time Capsules',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: NotePalette.cream,
                          ),
                        ),
                        Text(
                          'Write a letter that opens later',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: NotePalette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _Chevron(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One note in the list: its photo (or the love-letter drawing), its type,
/// title and first line, the date, and a chevron. Tap to open it.
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap});

  final LoveNote note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = note.title;
    final firstLine = note.body.trim().split('\n').first;
    final when = note.unlockAt ?? note.sentAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        button: true,
        label: [
          note.category?.label ??
              (note.wasCapsule ? 'Time capsule' : 'Love note'),
          ?title,
          firstLine,
          longDate(when),
          if (note.isFavorite) 'favorite',
        ].join('. '),
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: noteCardDecoration(),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.panel),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 90,
                      child: Center(
                        child: note.photoPath != null
                            ? NotePolaroid(
                                url: note.photoUrl,
                                width: 70,
                                turn: -4,
                              )
                            : const NoteArtTile(size: 72),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NoteCategoryBadge(
                            category: note.category,
                            capsule: note.wasCapsule,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (title != null)
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: NotePalette.cream,
                              ),
                            ),
                          Text(
                            firstLine,
                            maxLines: title == null ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: title == null
                                  ? NotePalette.cream
                                  : NotePalette.muted,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  longDate(when),
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: NotePalette.muted,
                                  ),
                                ),
                              ),
                              if (note.isFavorite) ...[
                                const SizedBox(width: AppSpacing.xs),
                                const Icon(
                                  Icons.favorite_rounded,
                                  size: 14,
                                  color: NotePalette.rose,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const _Chevron(),
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

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.06),
      border: Border.all(color: NotePalette.border),
    ),
    child: const Icon(
      Icons.chevron_right_rounded,
      size: 20,
      color: NotePalette.cream,
    ),
  );
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          const QuickActionArtView(QuickActionArt.loveNote, size: 96),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Say it in writing',
            textAlign: TextAlign.center,
            style: NotePalette.display(22),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Leave a love note for today. It stays here for both of you.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: NotePalette.muted,
            ),
          ),
        ],
      ),
    );
  }
}
