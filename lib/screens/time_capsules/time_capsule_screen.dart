import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../models/love_note.dart';
import '../../models/profile.dart';
import '../../models/time_capsule.dart';
import '../../services/auth_service.dart';
import '../../services/couple_service.dart';
import '../../services/note_service.dart';
import '../../services/time_capsule_service.dart';
import '../../theme/app_spacing.dart';
import '../../utils/anniversary.dart';
import '../../utils/capsule_time.dart';
import '../../widgets/atoms/filter_pill.dart';
import '../../widgets/capsule/capsule_summary_card.dart';
import '../../widgets/capsule/envelope.dart';
import '../../widgets/effects/motion.dart';
import '../../widgets/notes/note_style.dart';
import '../love_note_detail_screen.dart';
import 'capsule_composer_screen.dart';
import 'capsule_view_screen.dart';

enum _Filter { sealed, ready, opened }

/// Time Capsules: your draft, then Sealed / Ready / Opened, each split into
/// what you sent and what you received.
///
/// Your partner's capsule appears here only once its ten minutes are over,
/// and no database event marks that moment, so while this screen is open it
/// refreshes every 30 seconds (and when the app comes back to the front).
/// Nothing polls once you leave it.
class TimeCapsuleScreen extends StatefulWidget {
  const TimeCapsuleScreen({
    super.key,
    required this.profile,
    this.openReady = false,
    this.highlightId,
    this.startComposing = false,
  });

  final Profile profile;

  /// Opened from the Home "Time Capsule" card: go straight to writing one
  /// (your draft, if you have one) once the list has loaded.
  final bool startComposing;

  /// Opened from a "ready" notification: show Ready (this visit only; the
  /// remembered filter is left as it was).
  final bool openReady;

  /// A capsule to point out, e.g. the one a notification is about.
  final String? highlightId;

  @override
  State<TimeCapsuleScreen> createState() => _TimeCapsuleScreenState();
}

class _TimeCapsuleScreenState extends State<TimeCapsuleScreen>
    with WidgetsBindingObserver {
  List<TimeCapsule> _capsules = [];
  Map<String, CapsuleContents> _contents = {};
  Map<String, List<CapsuleReply>> _replies = {};
  Map<String, int> _seen = {};
  Map<String, String> _names = {};
  DateTime? _anniversary;
  _Filter? _filter;
  bool _loading = true;
  String? _error;
  String? _hiddenDraft; // deleted, while Undo is still possible

  // Previous capsules: the older ones written as love notes with an unlock
  // time. Still sealed (envelope only, never the text), and opened (now
  // readable notes). Shown here so every capsule lives on one screen.
  List<SealedNote> _oldSealed = [];
  List<LoveNote> _oldOpened = [];

  Timer? _refresh;
  Timer? _tick;
  RealtimeChannel? _live;
  bool _active = false;

  // Your capsules in their ten minutes at the last tick, to notice the
  // moment one is sealed for good.
  Set<String> _inGrace = {};
  final Map<String, int> _pressed = {};

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
    WidgetsBinding.instance.addObserver(this);
    if (widget.openReady) _filter = _Filter.ready;
    TimeCapsuleService.lastFilter(_myId).then((v) {
      if (!mounted || v == null || _filter != null) return;
      final saved = _Filter.values.where((f) => f.name == v).firstOrNull;
      if (saved != null) setState(() => _filter = saved);
    });
    _start();
    _load().then((_) {
      if (mounted && widget.startComposing && _error == null) {
        _compose(capsule: _draft);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_active && ModalRoute.of(context)?.isCurrent == true) {
        _start();
        _load();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _stop();
    }
  }

  /// Timers and the live channel run only while this screen is in front.
  void _start() {
    if (_active) return;
    _active = true;
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) => _load());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    try {
      _live = TimeCapsuleService.listen(_coupleId, () {
        if (mounted) _load();
      });
    } catch (_) {}
  }

  void _stop() {
    _active = false;
    _refresh?.cancel();
    _tick?.cancel();
    _refresh = _tick = null;
    final live = _live;
    _live = null;
    if (live != null) TimeCapsuleService.stopListening(live);
  }

  /// Opens another screen with this one paused, and refreshes after.
  Future<T?> _push<T>(Widget screen) async {
    _stop();
    final result = await Navigator.of(
      context,
    ).push<T>(MaterialPageRoute(builder: (_) => screen));
    if (mounted) {
      _start();
      await _load();
    }
    return result;
  }

  void _onTick() {
    if (!mounted) return;
    final now = TimeCapsuleService.now();
    final grace = {
      for (final c in _capsules)
        if (c.senderId == _myId && c.inGrace(now)) c.id,
    };
    final sealedNow = _inGrace.difference(grace);
    _inGrace = grace;
    if (sealedNow.isNotEmpty) {
      for (final id in sealedNow) {
        _pressed[id] = (_pressed[id] ?? 0) + 1;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your Time Capsule is now sealed.')),
      );
      _load(); // its contents are no longer yours to read
    } else if (_oldSealed.any((n) => n.isReady(now: now))) {
      _load(); // a previous capsule's moment arrived
    }
    setState(() {});
  }

  Future<void> _load() async {
    try {
      await TimeCapsuleService.syncClock();
      final members = await CoupleService.members(_coupleId);
      final couple = await CoupleService.couple(_coupleId);
      final capsules = await TimeCapsuleService.list(_coupleId);
      final now = TimeCapsuleService.now();
      final readable = [
        for (final c in capsules)
          if (c.isOpened ||
              (c.senderId == _myId &&
                  (c.status == CapsuleStatus.draft ||
                      c.status == CapsuleStatus.editing ||
                      c.inGrace(now))))
            c.id,
      ];
      final contents = await TimeCapsuleService.contents(readable);
      final replies = await TimeCapsuleService.replies([
        for (final c in capsules)
          if (c.isOpened) c.id,
      ]);
      final seen = await TimeCapsuleService.seenSteps(_myId);
      var oldSealed = _oldSealed;
      var oldOpened = _oldOpened;
      try {
        oldSealed = await NoteService.sealed();
        oldOpened = [
          for (final n in await NoteService.list(_coupleId))
            if (n.wasCapsule) n,
        ];
      } catch (_) {} // the new capsules still show without them
      final justOpened = oldOpened
          .where((n) => _oldSealed.any((s) => s.id == n.id))
          .length;
      if (!mounted) return;
      setState(() {
        _names = {for (final m in members) m.userId: m.displayName};
        _anniversary = couple.anniversaryDate;
        _capsules = capsules;
        _contents = contents;
        _replies = replies;
        _seen = seen;
        _oldSealed = oldSealed;
        _oldOpened = oldOpened;
        _inGrace = {
          for (final c in capsules)
            if (c.senderId == _myId && c.inGrace(now)) c.id,
        };
        _filter ??= capsules.any((c) => c.senderId != _myId && c.isReady(now))
            ? _Filter.ready
            : _Filter.sealed;
        _error = null;
        _loading = false;
      });
      if (justOpened > 0) {
        _showMessage(
          justOpened == 1
              ? 'A previous capsule just opened. It is under Opened.'
              : '$justOpened previous capsules just opened. They are under Opened.',
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

  void _showMessage(String text, {SnackBarAction? action}) =>
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text), action: action));

  void _choose(_Filter f) {
    setState(() => _filter = f);
    TimeCapsuleService.rememberFilter(_myId, f.name);
  }

  TimeCapsule? get _draft => _capsules
      .where(
        (c) =>
            c.senderId == _myId &&
            c.status == CapsuleStatus.draft &&
            c.id != _hiddenDraft,
      )
      .firstOrNull;

  // ------------------------------------------------------------- actions

  Future<void> _compose({TimeCapsule? capsule, bool editing = false}) async {
    final contents = capsule == null ? null : _contents[capsule.id];
    final outcome = await _push<ComposerOutcome>(
      CapsuleComposerScreen(
        coupleId: _coupleId,
        partnerName: _partnerName,
        anniversary: _anniversary,
        draftId: editing ? null : capsule?.id,
        editingId: editing ? capsule?.id : null,
        title: contents?.title,
        letter: contents?.letter ?? '',
        unlockAt: capsule?.unlockAt,
        photoPath: contents?.photoPath,
        caption: contents?.photoCaption,
      ),
    );
    if (!mounted) return;
    if (outcome == ComposerOutcome.sealed) {
      _choose(_Filter.sealed);
      _showMessage('Sealed. You can still edit or cancel it for ten minutes.');
    } else if (outcome == ComposerOutcome.deleteDraft) {
      final draft = _capsules
          .where((c) => c.senderId == _myId && c.status == CapsuleStatus.draft)
          .firstOrNull;
      if (draft != null) _deleteWithUndo(draft);
    }
  }

  void _deleteWithUndo(TimeCapsule draft) {
    setState(() => _hiddenDraft = draft.id);
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Draft deleted'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
      ),
    );
    controller.closed.then((reason) async {
      if (reason == SnackBarClosedReason.action) {
        if (mounted) setState(() => _hiddenDraft = null);
        return;
      }
      try {
        await TimeCapsuleService.deleteDraft(draft.id);
      } catch (e) {
        if (mounted) _showMessage(friendlyError(e));
      }
      if (mounted) {
        setState(() => _hiddenDraft = null);
        await _load();
      }
    });
  }

  Future<void> _editInGrace(TimeCapsule c) async {
    try {
      await TimeCapsuleService.edit(c.id);
      if (!mounted) return;
      await _compose(
        capsule: TimeCapsule(
          id: c.id,
          senderId: c.senderId,
          status: CapsuleStatus.editing,
          createdAt: c.createdAt,
          unlockAt: c.unlockAt,
        ),
        editing: true,
      );
    } catch (e) {
      _showMessage(friendlyError(e));
      await _load();
    }
  }

  Future<void> _cancel(TimeCapsule c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this capsule?'),
        content: Text(
          'It will be deleted, and $_partnerName will never know it existed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel capsule'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await TimeCapsuleService.cancel(
        c.id,
        sealed: c.status == CapsuleStatus.sealed,
      );
      _showMessage('Capsule cancelled.');
    } catch (e) {
      _showMessage(friendlyError(e));
    }
    await _load();
  }

  Future<void> _cancelOld(SealedNote n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this capsule?'),
        content: const Text(
          'It will be deleted unopened. Nobody will ever read it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel capsule'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await NoteService.cancelCapsule(n.id);
      _showMessage('Capsule cancelled.');
    } catch (e) {
      _showMessage(friendlyError(e));
    }
    await _load();
  }

  Future<void> _viewOld(LoveNote n) => _push<bool>(
    LoveNoteDetailScreen(
      note: n,
      authorName:
          _names[n.authorId] ?? (n.authorId == _myId ? 'You' : _partnerName),
      isMine: n.authorId == _myId,
    ),
  );

  /// A previous capsule: sealed (envelope only) or opened (a readable note).
  Widget _oldCard(Object item, DateTime now) {
    String at(DateTime d) => '${longDate(d)}, ${clockTime(d)}';
    if (item is SealedNote) {
      final mine = item.authorId == _myId;
      final person = mine ? 'To $_partnerName' : 'From $_partnerName';
      return CapsuleSummaryCard(
        key: ValueKey('old-${item.id}'),
        state: CapsuleCardState.sealed,
        headlineLead: 'Opens',
        headlineAccent: opensIn(item.unlockAt, now: now),
        // A previous capsule's teaser was always shown on its envelope.
        subtitle:
            item.capsuleTitle ??
            (mine
                ? 'A sealed message for $_partnerName'
                : 'A special message for you'),
        person: person,
        when: at(item.unlockAt),
        trailing: mine
            ? IconButton(
                tooltip: 'Cancel capsule',
                onPressed: () => _cancelOld(item),
                icon: const Icon(Icons.close_rounded, color: NotePalette.cream),
              )
            : null,
        semanticLabel:
            'Sealed time capsule $person. Opens ${at(item.unlockAt)}',
      );
    }
    final n = item as LoveNote;
    final mine = n.authorId == _myId;
    final person = mine ? 'To $_partnerName' : 'From $_partnerName';
    final first = n.body.trim().split('\n').first;
    return CapsuleSummaryCard(
      key: ValueKey('old-${n.id}'),
      state: CapsuleCardState.opened,
      headlineLead: 'Opened',
      headlineAccent: 'on ${longDate(n.unlockAt!)}',
      subtitle: n.capsuleTitle ?? first,
      person: person,
      when: at(n.unlockAt!),
      onTap: () => _viewOld(n),
      semanticLabel:
          'Opened time capsule $person. ${n.capsuleTitle ?? ''} $first',
    );
  }

  Future<void> _view(TimeCapsule c) => _push<void>(
    CapsuleViewScreen(
      capsule: c,
      coupleId: _coupleId,
      myId: _myId,
      partnerName: _partnerName,
    ),
  );

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = TimeCapsuleService.now();
    final mine = _capsules.where((c) => c.senderId == _myId).toList();
    final theirs = _capsules.where((c) => c.senderId != _myId).toList();
    final draft = _draft;
    final editing = mine
        .where((c) => c.status == CapsuleStatus.editing)
        .toList();

    int byUnlock(TimeCapsule a, TimeCapsule b) =>
        a.unlockAt!.compareTo(b.unlockAt!);
    int byReady(TimeCapsule a, TimeCapsule b) =>
        a.readySince.compareTo(b.readySince);
    int byOpened(TimeCapsule a, TimeCapsule b) =>
        b.openedAt!.compareTo(a.openedAt!);

    final sealedSent =
        mine.where((c) => c.inGrace(now) || c.isWaiting(now)).toList()
          ..sort(byUnlock);
    final sealedReceived = theirs.where((c) => c.isWaiting(now)).toList()
      ..sort(byUnlock);
    final readyForMe = theirs.where((c) => c.isReady(now)).toList()
      ..sort(byReady);
    final readyForPartner = mine.where((c) => c.isReady(now)).toList()
      ..sort(byReady);
    final openedSent = mine.where((c) => c.isOpened).toList()..sort(byOpened);
    final openedReceived = theirs.where((c) => c.isOpened).toList()
      ..sort(byOpened);

    final oldSealed = _oldSealed.where((n) => !n.isReady(now: now)).toList();
    final oldOpened = _oldOpened;
    final filter = _filter ?? _Filter.sealed;
    final oldList = switch (filter) {
      _Filter.sealed => <Object>[...oldSealed],
      _Filter.ready => const <Object>[],
      _Filter.opened => <Object>[...oldOpened],
    };
    final (
      firstLabel,
      firstList,
      secondLabel,
      secondList,
      empty,
    ) = switch (filter) {
      _Filter.sealed => (
        'Sent',
        sealedSent,
        'Received',
        sealedReceived,
        'Nothing sealed for the future yet.',
      ),
      _Filter.ready => (
        'Ready for me',
        readyForMe,
        'Ready for my partner',
        readyForPartner,
        'No capsules waiting to be opened yet.',
      ),
      _Filter.opened => (
        'Sent',
        openedSent,
        'Received',
        openedReceived,
        'No opened capsules here yet.',
      ),
    };

    bool unread(TimeCapsule c) =>
        TimeCapsuleService.partnerStep(c, _replies[c.id] ?? const [], _myId) >
        (_seen[c.id] ?? 0);

    Widget card(TimeCapsule c) => _CapsuleCard(
      key: ValueKey(c.id),
      capsule: c,
      now: now,
      mine: c.senderId == _myId,
      partnerName: _partnerName,
      contents: _contents[c.id],
      replies: _replies[c.id] ?? const [],
      unread: unread(c),
      pressKey: _pressed[c.id],
      highlighted: c.id == widget.highlightId,
      onEdit: () => _editInGrace(c),
      onCancel: () => _cancel(c),
      onOpen: () => _view(c),
    );

    List<Widget> section(String label, List<TimeCapsule> list) => [
      Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.lg,
          bottom: AppSpacing.sm,
        ),
        child: Semantics(
          header: true,
          child: Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      if (list.isEmpty)
        Text(
          'None yet.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        )
      else
        for (final c in list) card(c),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Time capsules')),
      floatingActionButton: _loading || draft != null || _hiddenDraft != null
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab-capsules',
              onPressed: () => _compose(),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Write a capsule'),
            ),
      body: _loading
          ? const SkeletonList()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.sm,
                  AppSpacing.screenMargin,
                  96,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            Text(
                              _error!,
                              style: TextStyle(color: scheme.error),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: _load,
                                child: const Text('Try again'),
                              ),
                            ),
                          ],
                          if (draft != null)
                            _DraftCard(
                              title: 'Continue your draft',
                              subtitle: _draftLine(_contents[draft.id]),
                              onTap: () => _compose(capsule: draft),
                            ),
                          for (final c in editing)
                            _DraftCard(
                              title: 'Finish editing your sealed capsule',
                              subtitle:
                                  'Hidden from $_partnerName until you seal it again.',
                              onTap: () => _compose(capsule: c, editing: true),
                              onCancel: () => _cancel(c),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              FilterPill(
                                label: 'Sealed',
                                selected: filter == _Filter.sealed,
                                count:
                                    sealedSent.length +
                                    sealedReceived.length +
                                    oldSealed.length,
                                onTap: () => _choose(_Filter.sealed),
                              ),
                              FilterPill(
                                label: 'Ready',
                                selected: filter == _Filter.ready,
                                count:
                                    readyForMe.length + readyForPartner.length,
                                onTap: () => _choose(_Filter.ready),
                              ),
                              FilterPill(
                                label: 'Opened',
                                selected: filter == _Filter.opened,
                                count:
                                    openedSent.length +
                                    openedReceived.length +
                                    oldOpened.length,
                                onTap: () => _choose(_Filter.opened),
                              ),
                            ],
                          ),
                          if (firstList.isEmpty &&
                              secondList.isEmpty &&
                              oldList.isEmpty)
                            _Empty(text: empty)
                          else ...[
                            if (firstList.isNotEmpty ||
                                secondList.isNotEmpty) ...[
                              ...section(firstLabel, firstList),
                              ...section(secondLabel, secondList),
                            ],
                            if (oldList.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.lg,
                                  bottom: AppSpacing.sm,
                                ),
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    'PREVIOUS CAPSULES',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              for (final o in oldList) _oldCard(o, now),
                            ],
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

  String _draftLine(CapsuleContents? c) {
    if (c == null) return 'Only you can see it.';
    final line = c.title ?? c.firstLine;
    return line.isEmpty ? 'Only you can see it.' : line;
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onCancel,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const MiniEnvelope(look: EnvelopeLook.draft, width: 56),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onCancel != null)
                  TextButton(onPressed: onCancel, child: const Text('Cancel'))
                else
                  Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One capsule in a list. Sealed and ready cards show only safe details
/// (who, when, a countdown); opened cards add the title and first line.
class _CapsuleCard extends StatelessWidget {
  const _CapsuleCard({
    super.key,
    required this.capsule,
    required this.now,
    required this.mine,
    required this.partnerName,
    required this.contents,
    required this.replies,
    required this.unread,
    required this.onEdit,
    required this.onCancel,
    required this.onOpen,
    this.pressKey,
    this.highlighted = false,
  });

  final TimeCapsule capsule;
  final DateTime now;
  final bool mine;
  final String partnerName;
  final CapsuleContents? contents;
  final List<CapsuleReply> replies;
  final bool unread;
  final Object? pressKey;
  final bool highlighted;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onOpen;

  static String _mmss(Duration d) {
    final s = d.inSeconds.clamp(0, 599);
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = capsule;
    final grace = c.inGrace(now);
    final ready = c.isReady(now);
    final person = mine ? 'To $partnerName' : 'From $partnerName';
    String at(DateTime d) => '${longDate(d)}, ${clockTime(d)}';
    // A sealed capsule's title stays hidden: only its sender, during the
    // ten editable minutes, and anyone once it's opened may see it.
    final safeLine = mine
        ? 'A sealed message for $partnerName'
        : 'A special message for you';

    if (c.isOpened) {
      final title = contents?.title;
      final first = contents?.firstLine ?? '';
      final receiverReplied = replies.any((r) => r.authorId == c.receiverId);
      final senderReplied = replies.any((r) => r.authorId == c.senderId);
      final status = receiverReplied && senderReplied
          ? 'You both replied'
          : mine
          ? (receiverReplied
                ? '$partnerName replied'
                : "They've opened your capsule")
          : (receiverReplied ? 'You replied' : "Reply when you're ready");
      return CapsuleSummaryCard(
        key: key,
        state: CapsuleCardState.opened,
        headlineLead: 'Opened',
        headlineAccent: 'on ${longDate(c.openedAt!)}',
        subtitle:
            title ??
            (first.isNotEmpty
                ? first
                : (mine
                      ? 'Your message to $partnerName'
                      : 'A message from $partnerName')),
        person: person,
        when: at(c.unlockAt!),
        note: status,
        noteColor: NotePalette.muted,
        unread: unread,
        highlighted: highlighted,
        onTap: onOpen,
        semanticLabel:
            'Opened time capsule. ${title ?? ''} $person. $first. $status',
      );
    }

    if (grace) {
      final left = c.editableUntil!.difference(now);
      return CapsuleSummaryCard(
        key: key,
        state: CapsuleCardState.grace,
        headlineLead: 'Opens',
        headlineAccent: opensIn(c.unlockAt!, now: now),
        subtitle: contents?.title ?? safeLine,
        person: person,
        when: at(c.unlockAt!),
        note: 'Editable for ${_mmss(left)}',
        unread: unread,
        highlighted: highlighted,
        actions: [
          CapsuleCardButton(label: 'Cancel', onPressed: onCancel),
          CapsuleCardButton(
            label: 'Edit',
            icon: Icons.edit_outlined,
            primary: true,
            onPressed: onEdit,
          ),
        ],
        semanticLabel:
            'Sealed time capsule to $partnerName, editable for ${left.inMinutes} more minutes',
      );
    }

    if (ready) {
      return CapsuleSummaryCard(
        key: key,
        state: CapsuleCardState.ready,
        headlineLead: 'Ready',
        headlineAccent: mine ? 'when they are' : 'to open',
        subtitle: safeLine,
        person: person,
        when: 'Ready since ${at(c.readySince)}',
        unread: unread,
        highlighted: highlighted,
        onTap: mine ? null : onOpen,
        actions: [
          if (!mine)
            CapsuleCardButton(
              label: 'Open now',
              icon: Icons.drafts_outlined,
              primary: true,
              onPressed: onOpen,
            ),
        ],
        semanticLabel: mine
            ? 'Your time capsule to $partnerName is ready. Ready when they are.'
            : 'A time capsule from $partnerName is ready to open',
      );
    }

    return CapsuleSummaryCard(
      key: key,
      state: CapsuleCardState.sealed,
      headlineLead: 'Opens',
      headlineAccent: opensIn(c.unlockAt!, now: now),
      subtitle: safeLine,
      person: person,
      when: at(c.unlockAt!),
      // Shown on this visit once its ten minutes run out on screen.
      note: mine && pressKey != null
          ? 'Your Time Capsule is now sealed.'
          : null,
      noteColor: const Color(0xFF7FBFA0),
      unread: unread,
      highlighted: highlighted,
      semanticLabel:
          'Sealed time capsule $person. Opens ${longDate(c.unlockAt!)} at ${clockTime(c.unlockAt!)}',
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
      child: Column(
        children: [
          const MiniEnvelope(look: EnvelopeLook.sealed, width: 96),
          const SizedBox(height: AppSpacing.lg),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
