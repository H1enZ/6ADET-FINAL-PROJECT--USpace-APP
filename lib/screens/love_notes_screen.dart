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
import '../theme/app_typography.dart';
import '../theme/us_palette.dart';
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
import '../widgets/atoms/us_icon.dart';
import '../widgets/molecules/us_states.dart';

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
        showFloatingHearts(context, icon: UsIcons.loveNotes);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

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
    showEnvelopeFly(context);
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
                                    AppButton(
                                      label: 'Write a love note',
                                      usIcon: UsIcons.plus,
                                      fullWidth: true,
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
                                      UsErrorNotice(
                                        message: _error!,
                                        onRetry: _load,
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                    ],
                                    if (notes.isEmpty && _error == null)
                                      const _EmptyNotes()
                                    else
                                      for (final n in notes)
                                        _NoteCard(
                                          note: n,
                                          from: n.authorId == _myId
                                              ? 'you'
                                              : _nameOf(n.authorId),
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
        Semantics(
          header: true,
          child: Text('Love Notes', style: NotePalette.display(36)),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Little words worth keeping.',
          style: theme.textTheme.bodyLarge?.copyWith(color: NotePalette.muted),
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
                  const QuickActionArtView(QuickActionArt.capsule, size: 40),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time Capsules',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: NotePalette.cream,
                          ),
                        ),
                        Text(
                          'Write a letter that opens later',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: NotePalette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const UsIcon(
                    UsIcons.chevronRight,
                    size: 20,
                    color: NotePalette.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One note in the list, as a small letter on cream paper: its type, its
/// title and first line in the letter hand, who it is from and when, and
/// its photo as a little Polaroid. The whole letter opens it.
class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.from,
    required this.onTap,
  });

  final LoveNote note;

  /// "you", or your partner's name.
  final String from;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = note.title;
    final firstLine = note.body.trim().split('\n').first;
    final when = note.unlockAt ?? note.sentAt;
    final type =
        note.category?.label ??
        (note.wasCapsule ? 'Time capsule' : 'Love note');
    const radius = BorderRadius.all(Radius.circular(6));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        button: true,
        label: [
          type,
          'From $from',
          ?title,
          firstLine,
          longDate(when),
          if (note.photoPath != null) 'with a photo',
          if (note.isFavorite) 'favorite',
        ].join('. '),
        excludeSemantics: true,
        child: PressScale(
          scale: 0.98,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              color: Colors.transparent,
              child: Ink(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      UsPalette.paperLight,
                      UsPalette.paper,
                      UsPalette.paperEdge,
                    ],
                    stops: [0, 0.6, 1],
                  ),
                ),
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md + 2,
                      AppSpacing.md,
                      AppSpacing.md + 2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: NoteCategoryBadge(
                                      category: note.category,
                                      capsule: note.wasCapsule,
                                      onPaper: true,
                                    ),
                                  ),
                                  if (note.isFavorite) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    const UsIcon(
                                      UsIcons.heart,
                                      size: 14,
                                      color: NotePalette.deepRose,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              if (title != null)
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: NotePalette.display(
                                    18,
                                    color: NotePalette.ink,
                                  ),
                                ),
                              Text(
                                firstLine,
                                maxLines: title == null ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.letter(
                                  color: NotePalette.ink,
                                  size: 15,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'From $from \u00B7 ${longDate(when)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: NotePalette.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (note.photoPath != null) ...[
                          const SizedBox(width: AppSpacing.md),
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: NotePolaroid(
                              url: note.photoUrl,
                              width: 66,
                              turn: 4,
                              heart: false,
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes();

  @override
  Widget build(BuildContext context) {
    return UsEmptyState(
      art: const QuickActionArtView(QuickActionArt.loveNote, size: 96),
      title: 'Say it in writing',
      titleStyle: NotePalette.display(22),
      message: 'Leave a love note for today. It stays here for both of you.',
      mutedColor: NotePalette.muted,
    );
  }
}
