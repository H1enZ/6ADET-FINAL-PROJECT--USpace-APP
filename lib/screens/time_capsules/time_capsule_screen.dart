import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../models/profile.dart';
import '../../models/time_capsule.dart';
import '../../services/auth_service.dart';
import '../../services/couple_service.dart';
import '../../services/time_capsule_service.dart';
import '../../theme/app_spacing.dart';
import '../../utils/anniversary.dart';
import '../../utils/capsule_time.dart';
import '../../widgets/atoms/filter_pill.dart';
import '../../widgets/capsule/envelope.dart';
import '../../widgets/effects/motion.dart';
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
      if (!mounted) return;
      setState(() {
        _names = {for (final m in members) m.userId: m.displayName};
        _anniversary = couple.anniversaryDate;
        _capsules = capsules;
        _contents = contents;
        _replies = replies;
        _seen = seen;
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

    final filter = _filter ?? _Filter.sealed;
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
                                    sealedSent.length + sealedReceived.length,
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
                                    openedSent.length + openedReceived.length,
                                onTap: () => _choose(_Filter.opened),
                              ),
                            ],
                          ),
                          if (firstList.isEmpty && secondList.isEmpty)
                            _Empty(text: empty)
                          else ...[
                            ...section(firstLabel, firstList),
                            ...section(secondLabel, secondList),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = capsule;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final grace = c.inGrace(now);
    final ready = c.isReady(now);
    final whoLine = mine ? 'To $partnerName' : 'From $partnerName';

    final EnvelopeLook look;
    final List<Widget> lines;
    Widget? actions;
    VoidCallback? onTap;
    String? semantic;

    if (c.isOpened) {
      look = EnvelopeLook.opened;
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
      lines = [
        Text(
          title ?? whoLine,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (title != null) Text(whoLine, style: muted),
        if (first.isNotEmpty)
          Text(
            first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        Text('Opened ${longDate(c.openedAt!)} · $status', style: muted),
      ];
      onTap = onOpen;
      semantic =
          'Opened time capsule. ${title ?? ''} $whoLine. $first. $status';
    } else if (grace) {
      look = EnvelopeLook.sealed;
      final left = c.editableUntil!.difference(now);
      lines = [
        Text(whoLine, style: theme.textTheme.titleMedium),
        Text(
          'Opens ${longDate(c.unlockAt!)} at ${clockTime(c.unlockAt!)}',
          style: muted,
        ),
        Semantics(
          liveRegion: false,
          child: Text(
            'Editable for ${_mmss(left)}',
            style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
          ),
        ),
      ];
      actions = Wrap(
        spacing: AppSpacing.sm,
        children: [
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      );
      semantic =
          'Sealed time capsule to $partnerName, editable for ${left.inMinutes} more minutes';
    } else if (ready) {
      look = mine ? EnvelopeLook.sealed : EnvelopeLook.ready;
      lines = [
        Text(whoLine, style: theme.textTheme.titleMedium),
        Text(
          'Ready since ${longDate(c.readySince)} at ${clockTime(c.readySince)}',
          style: muted,
        ),
        Text(
          mine ? 'Ready when they are.' : 'Ready to open',
          style: theme.textTheme.labelLarge?.copyWith(
            color: mine ? scheme.onSurfaceVariant : scheme.primary,
          ),
        ),
      ];
      if (!mine) {
        actions = FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.drafts_outlined, size: 18),
          label: const Text('Open now'),
        );
        onTap = onOpen;
      }
      semantic = mine
          ? 'Your time capsule to $partnerName is ready. Ready when they are.'
          : 'A time capsule from $partnerName is ready to open';
    } else {
      look = EnvelopeLook.sealed;
      lines = [
        Text(whoLine, style: theme.textTheme.titleMedium),
        Text(
          'Opens ${longDate(c.unlockAt!)} at ${clockTime(c.unlockAt!)}',
          style: muted,
        ),
        Text(
          opensIn(c.unlockAt!, now: now),
          style: theme.textTheme.labelLarge?.copyWith(color: scheme.secondary),
        ),
        // Shown on this visit once its ten minutes run out on screen.
        if (mine && pressKey != null)
          Text(
            'Your Time Capsule is now sealed.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.tertiary),
          ),
      ];
      semantic =
          'Sealed time capsule $whoLine. Opens ${longDate(c.unlockAt!)} at ${clockTime(c.unlockAt!)}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: highlighted
              ? BorderSide(color: scheme.primary, width: 2)
              : BorderSide(color: scheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Semantics(
            label: semantic + (unread ? '. New' : ''),
            excludeSemantics: actions == null,
            container: true,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MiniEnvelope(look: look, width: 64, pressKey: pressKey),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: lines,
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(
                            left: AppSpacing.sm,
                            top: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (actions != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(alignment: Alignment.centerRight, child: actions),
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
