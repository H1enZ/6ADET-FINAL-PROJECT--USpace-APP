import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../models/love_note.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../services/note_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../utils/capsule_time.dart';
import '../utils/daily_content.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/filter_pill.dart';
import '../widgets/atoms/seal_badge.dart';
import '../widgets/atoms/unlock_ring.dart';
import '../widgets/effects/floating_hearts.dart';
import '../widgets/effects/motion.dart';
import '../widgets/effects/seal_opening.dart';
import 'time_capsules/time_capsule_screen.dart';
import 'write_note_sheet.dart';

enum _Show { all, capsules, favorites }

/// Love Notes: every note you can read, plus Previous Capsules (the older
/// notes-based Time Capsules, which still open by themselves at their
/// moment). New Time Capsules live on their own screen. New notes arrive
/// live.
class LoveNotesScreen extends StatefulWidget {
  const LoveNotesScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<LoveNotesScreen> createState() => _LoveNotesScreenState();
}

class _LoveNotesScreenState extends State<LoveNotesScreen> {
  List<LoveNote> _notes = [];
  List<SealedNote> _sealed = [];
  Map<String, String> _names = {};
  _Show _show = _Show.all;
  bool _loading = true;
  String? _error;
  Timer? _tick;
  RealtimeChannel? _live;

  String get _coupleId => widget.profile.coupleId!;
  String get _myId => widget.profile.userId;

  String get _partnerName {
    for (final e in _names.entries) {
      if (e.key != _myId) return e.value;
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
    _tick?.cancel();
    final live = _live;
    if (live != null) NoteService.stopListening(live);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final before = {for (final s in _sealed) s.id};
      final members = await CoupleService.members(_coupleId);
      final notes = await NoteService.list(_coupleId);
      final sealed = await NoteService.sealed();
      if (!mounted) return;
      final justOpened = notes.where((n) => before.contains(n.id)).toList();
      setState(() {
        _names = {for (final m in members) m.userId: m.displayName};
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
        _showMessage(justOpened.length == 1
            ? 'A time capsule just opened 💌'
            : '${justOpened.length} time capsules just opened 💌');
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

  String _nameOf(String userId) =>
      userId == _myId ? 'You' : (_names[userId] ?? 'Your partner');

  Future<void> _write() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => WriteNoteSheet(coupleId: _coupleId, partnerName: _partnerName),
    );
    if (sent != true) return;
    await _load();
    if (!mounted) return;
    showEnvelopeFly(context, emoji: '💌');
    _showMessage('Sent to $_partnerName');
  }

  Future<void> _openTimeCapsules() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TimeCapsuleScreen(profile: widget.profile)),
    );
  }

  Future<void> _toggleFavorite(LoveNote note) async {
    final value = !note.isFavorite;
    setState(() => _notes = [for (final n in _notes) n.id == note.id ? n.withFavorite(value) : n]);
    if (value) showFloatingHearts(context);
    try {
      await NoteService.setFavorite(note.id, value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _notes = [for (final n in _notes) n.id == note.id ? note : n]);
      _showMessage(friendlyError(e));
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _delete(LoveNote note) async {
    if (!await _confirm('Delete this note?',
        'It will be removed for both of you.', 'Delete')) {
      return;
    }
    try {
      await NoteService.delete(note.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    }
  }

  Future<void> _cancel(SealedNote capsule) async {
    if (!await _confirm('Cancel this capsule?',
        'It will be deleted unopened. Nobody will ever read it.', 'Cancel capsule')) {
      return;
    }
    try {
      await NoteService.cancelCapsule(capsule.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

    final notes = switch (_show) {
      _Show.all => _notes,
      _Show.capsules => _notes.where((n) => n.wasCapsule).toList(),
      _Show.favorites => _notes.where((n) => n.isFavorite).toList(),
    };
    final showSealed = _show != _Show.favorites && _sealed.isNotEmpty;
    final nothing = _notes.isEmpty && _sealed.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Love notes'),
        actions: [
          IconButton(
            tooltip: 'Time capsules',
            onPressed: _openTimeCapsules,
            icon: const Icon(Icons.lock_clock_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-love-notes',
        onPressed: _loading ? null : _write,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Write a note'),
      ),
      body: _loading
          ? const SkeletonList()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenMargin, AppSpacing.sm, AppSpacing.screenMargin, 96),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
                            const SizedBox(height: AppSpacing.md),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: AppButton(
                                  label: 'Try again',
                                  variant: AppButtonVariant.outlined,
                                  onPressed: _load),
                            ),
                          ],
                          if (nothing && _error == null)
                            _EmptyNotes(onWrite: _write, onSeal: _openTimeCapsules)
                          else ...[
                            Wrap(
                              spacing: AppSpacing.sm,
                              children: [
                                FilterPill(label: 'All', selected: _show == _Show.all,
                                    count: _notes.length + _sealed.length,
                                    onTap: () => setState(() => _show = _Show.all)),
                                FilterPill(label: 'Previous capsules', selected: _show == _Show.capsules,
                                    count: _sealed.length + _notes.where((n) => n.wasCapsule).length,
                                    onTap: () => setState(() => _show = _Show.capsules)),
                                FilterPill(label: 'Favorites', selected: _show == _Show.favorites,
                                    count: _notes.where((n) => n.isFavorite).length,
                                    onTap: () => setState(() => _show = _Show.favorites)),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            if (showSealed) ...[
                              Text('PREVIOUS CAPSULES · SEALED', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                              const SizedBox(height: AppSpacing.sm),
                              for (final s in _sealed)
                                _SealedCard(
                                  capsule: s,
                                  fromName: _nameOf(s.authorId),
                                  isMine: s.authorId == _myId,
                                  onOpen: _load,
                                  onCancel: () => _cancel(s),
                                ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (notes.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: AppSpacing.xl),
                                child: Text(
                                  _show == _Show.favorites
                                      ? 'Tap the heart on a note to keep it here.'
                                      : 'No opened notes here yet.',
                                  textAlign: TextAlign.center,
                                  style: muted,
                                ),
                              ),
                            for (final n in notes)
                              _NoteBubble(
                                note: n,
                                fromName: _nameOf(n.authorId),
                                isMine: n.authorId == _myId,
                                onFavorite: () => _toggleFavorite(n),
                                onDelete: () => _delete(n),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// A sealed capsule: wax seal, teaser, who it's from, and a countdown ring.
/// When its moment arrives the seal breaks and tapping opens it.
class _SealedCard extends StatelessWidget {
  const _SealedCard({
    required this.capsule,
    required this.fromName,
    required this.isMine,
    required this.onOpen,
    required this.onCancel,
  });

  final SealedNote capsule;
  final String fromName;
  final bool isMine;
  final VoidCallback onOpen;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ready = capsule.isReady();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: scheme.secondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: ready ? onOpen : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                UnlockRing(
                  elapsedFraction: capsule.progress(),
                  size: 72,
                  strokeWidth: 5,
                  color: scheme.onSecondary,
                  trackColor: scheme.onSecondary.withValues(alpha: 0.2),
                  child: SealBadge(
                    size: 46,
                    state: ready ? SealState.broken : SealState.sealed,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        capsule.capsuleTitle ?? 'A previous time capsule',
                        style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ready
                            ? 'Ready to open! Tap to read 💌'
                            : 'Opens ${opensIn(capsule.unlockAt)}',
                        style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSecondary),
                      ),
                      Text(
                        'From ${fromName == 'You' ? 'you' : fromName} \u00B7 '
                        '${longDate(capsule.unlockAt)}, ${clockTime(capsule.unlockAt)}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.onSecondary.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
                if (isMine && !ready)
                  IconButton(
                    tooltip: 'Cancel capsule',
                    onPressed: onCancel,
                    icon: Icon(Icons.close, color: scheme.onSecondary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A readable note, like a chat bubble: yours on the right, theirs on the
/// left. Opened capsules say when they were sealed.
class _NoteBubble extends StatelessWidget {
  const _NoteBubble({
    required this.note,
    required this.fromName,
    required this.isMine,
    required this.onFavorite,
    required this.onDelete,
  });

  final LoveNote note;
  final String fromName;
  final bool isMine;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = isMine ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final fg = isMine ? scheme.onPrimaryContainer : scheme.onSurface;
    final small = theme.textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.75));

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.xs, AppSpacing.sm),
          decoration: BoxDecoration(
            color: bg,
            border: isMine ? null : Border.all(color: scheme.outline),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.bubble),
              topRight: const Radius.circular(AppRadius.bubble),
              bottomLeft: Radius.circular(isMine ? AppRadius.bubble : 4),
              bottomRight: Radius.circular(isMine ? 4 : AppRadius.bubble),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.wasCapsule)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      const SealBadge(size: 22, state: SealState.broken),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          '${note.capsuleTitle ?? 'Previous capsule'} \u00B7 sealed ${longDate(note.sentAt)}',
                          style: small,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Text(note.body, style: theme.textTheme.bodyLarge?.copyWith(color: fg)),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$fromName \u00B7 ${timeAgo(note.unlockAt ?? note.sentAt)}',
                      style: small,
                    ),
                  ),
                  IconButton(
                    tooltip: note.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                    visualDensity: VisualDensity.compact,
                    onPressed: onFavorite,
                    icon: AnimatedHeartIcon(
                        filled: note.isFavorite, size: 20, emptyColor: fg),
                  ),
                  if (isMine)
                    IconButton(
                      tooltip: 'Delete note',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                      icon: Icon(Icons.delete_outline, size: 20, color: fg),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes({required this.onWrite, required this.onSeal});

  final VoidCallback onWrite;
  final VoidCallback onSeal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
      child: Column(
        children: [
          const SealBadge(size: 72),
          const SizedBox(height: AppSpacing.lg),
          Text('Say it in writing', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Leave a love note for today, or write a Time Capsule that opens '
            'on your anniversary, a birthday, or a year from now.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              AppButton(label: 'Write a note', icon: Icons.edit_outlined, onPressed: onWrite),
              AppButton(
                label: 'Time capsules',
                icon: Icons.lock_outline,
                variant: AppButtonVariant.outlined,
                onPressed: onSeal,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
