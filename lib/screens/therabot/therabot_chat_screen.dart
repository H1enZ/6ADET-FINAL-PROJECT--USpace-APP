import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/atoms/us_icon.dart';
import '../../widgets/molecules/us_confirm.dart';
import 'package:flutter/services.dart';

import '../../models/therabot_chat.dart';
import '../../services/therabot_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/effects/motion.dart';
import '../../widgets/notes/note_style.dart';
import '../../widgets/therabot/therabot_widgets.dart';
import '../../theme/us_palette.dart';

enum ChatMode { talk, couple }

/// Therabot's guided chat.
///
/// PRIVATE TALK ([ChatMode.talk]): just you and Therabot. Nothing goes to
/// your partner and nothing becomes a couple reflection.
///
/// COUPLE REFLECTION ([ChatMode.couple]): your own private part. You agree
/// first (consent), then talk; when you finish, Therabot writes a short
/// summary of your perspective, and only that is used for the shared
/// reflection. Your partner never sees these messages.
///
/// Closes with `true` when something changed that the hub should reload.
class TherabotChatScreen extends StatefulWidget {
  const TherabotChatScreen({
    super.key,
    required this.mode,
    required this.partnerName,
    this.sessionId,
    this.initial,
    this.expiresAt,
  });

  final ChatMode mode;
  final String partnerName;

  /// Couple Reflection: the session, or null to start a new one (you pick
  /// what it's about, agree, and then it's created).
  final String? sessionId;

  /// A chat to continue, or null to begin.
  final ChatView? initial;
  final DateTime? expiresAt;

  @override
  State<TherabotChatScreen> createState() => _TherabotChatScreenState();
}

class _TherabotChatScreenState extends State<TherabotChatScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  late ChatView? _view = widget.initial;
  late String? _sessionId = widget.sessionId;

  /// When the reflection closes; set here too when you start a new one.
  late DateTime? _expiresAt = widget.expiresAt;
  bool _busy = false;

  /// Saving a kept summary: busy, but Therabot isn't writing a reply.
  bool _saving = false;
  bool _changed = false;
  String? _sending; // your message, shown while Therabot replies
  String? _safety;
  ChatFinished? _finished;
  bool _hideChips = false;

  /// Couple Reflection, before it exists: what you chose to reflect on.
  ChatChip? _pendingReason;

  bool get _talk => widget.mode == ChatMode.talk;
  bool get _starting => widget.mode == ChatMode.couple && _sessionId == null;

  /// The partner who joins agrees before anything else.
  bool get _needsConsent =>
      widget.mode == ChatMode.couple &&
      _view == null &&
      (_pendingReason != null || !_starting);

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    _toBottom(jump: true);
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (jump || motionOff(context)) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Runs a request: shows your words straight away, Therabot "writing",
  /// then the reply. On failure your text comes back to the box.
  Future<void> _run(
    Future<ChatResult> Function() request, {
    String? said,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _sending = said;
    });
    _toBottom();
    try {
      final result = await request();
      if (!mounted) return;
      _changed = true;
      setState(() {
        _hideChips = false;
        switch (result) {
          case ChatUpdated(:final view):
            // Replies don't repeat the summary: keep the last one, so
            // "Show me what you heard" can bring it back.
            final kept = _view?.summary;
            _view = view.summary == null && kept != null
                ? view.copyWith(summary: kept)
                : view;
          case ChatSafety(:final message):
            _safety = message;
          case ChatFinished():
            _finished = result;
        }
        _sending = null;
      });
      _toBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = null);
      if (said != null && _input.text.isEmpty) _input.text = said;
      therabotToast(context, therabotError(e).message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------- actions

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    final view = _view;
    if (view == null) {
      // Your own words as the opening reason.
      if (text.length > 120) {
        therabotToast(
          context,
          'Keep this first part short. You can say more right after.',
        );
        return;
      }
      _input.clear();
      if (_talk) {
        await _run(
          () => TherabotService.talkStart('custom', reasonText: text),
          said: text,
        );
      } else {
        setState(() => _pendingReason = ChatChip('custom', text));
      }
      return;
    }
    _input.clear();
    if (_talk) {
      await _run(
        () => TherabotService.talkMessage(view.talkId!, text),
        said: text,
      );
    } else {
      await _run(
        () => TherabotService.chatMessage(_sessionId!, text),
        said: text,
      );
    }
  }

  Future<void> _chip(ChatChip chip) async {
    final view = _view;
    if (view == null) {
      if (_talk) {
        await _run(() => TherabotService.talkStart(chip.key), said: chip.label);
      } else {
        setState(() => _pendingReason = chip);
      }
      return;
    }
    switch (view.stage) {
      case 'open':
        if (chip.key == 'not_ready') {
          Navigator.of(context).pop(_changed);
          return;
        }
        await _run(
          () => TherabotService.chatPick(_sessionId!, chip.key),
          said: chip.label,
        );
      case 'goal':
        await _run(
          () => _talk
              ? TherabotService.talkGoal(view.talkId!, chip.key)
              : TherabotService.chatGoal(_sessionId!, chip.key),
          said: chip.label,
        );
      default:
        if (chip.key == 'more') {
          setState(() => _hideChips = true);
          _focus.requestFocus();
          _toBottom();
        } else if (chip.key == 'summary') {
          await _run(() async {
            try {
              return await TherabotService.talkSummary(view.talkId!);
            } on TherabotException catch (e) {
              // Out of new summaries: show the last one again.
              final kept = _view?.summary;
              if (e.code != 'rate_limited' || kept == null) rethrow;
              return ChatUpdated(
                view.copyWith(stage: 'summary', summary: kept),
              );
            }
          });
        } else if (chip.key == 'finish') {
          await _run(() => TherabotService.chatFinish(_sessionId!));
        }
    }
  }

  /// Couple Reflection: you agreed. Starts the session if you're the one
  /// starting it, then opens your private part.
  Future<void> _consent() async {
    if (_busy) return;
    final reason = _pendingReason;
    var sessionId = _sessionId;
    if (sessionId == null) {
      setState(() => _busy = true);
      try {
        sessionId = await TherabotService.start();
      } catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        therabotToast(context, therabotError(e).message, error: true);
        // Often: your partner just started one. Back to the hub to see it.
        Navigator.of(context).pop(true);
        return;
      }
      if (!mounted) return;
      setState(() {
        _sessionId = sessionId;
        // A new session is open for exactly 24 hours (migration 011).
        _expiresAt = DateTime.now().add(const Duration(hours: 24));
        _busy = false;
      });
    }
    final id = sessionId;
    await _run(
      () => TherabotService.chatOpen(
        id,
        reasonKey: reason?.key,
        reasonText: reason?.key == 'custom' ? reason?.label : null,
      ),
      said: reason?.label,
    );
  }

  Future<void> _keepSummary(String text) async {
    final id = _view?.talkId;
    if (id == null) return;
    setState(() {
      _busy = true;
      _saving = true;
    });
    try {
      await TherabotService.talkSaveSummary(id, text);
      if (!mounted) return;
      _changed = true;
      setState(
        () => _view = _view?.copyWith(stage: 'done', summary: text.trim()),
      );
    } catch (e) {
      if (mounted) therabotToast(context, therabotError(e).message, error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
        });
      }
    }
  }

  Future<void> _editSummary() async {
    final current = _view?.summary ?? '';
    final edited = await showDialog<String>(
      context: context,
      builder: (_) => _EditSummaryDialog(initial: current),
    );
    if (edited == null || edited.trim().isEmpty) return;
    await _keepSummary(edited);
  }

  Future<void> _finishTalk() async {
    final id = _view?.talkId;
    if (id != null && _view?.stage != 'done') {
      try {
        await TherabotService.talkFinish(id);
      } catch (_) {} // it clears by itself after 24 hours anyway
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _deleteTalk() async {
    final id = _view?.talkId;
    if (id == null) return;
    if (_busy) return;
    final ok = await showUsConfirm(
      context,
      title: 'Delete this private talk?',
      message: 'Your messages and summary are deleted right away.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
      destructive: true,
    );
    if (!ok) return;
    try {
      await TherabotService.talkDelete(id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) therabotToast(context, therabotError(e).message, error: true);
    }
  }

  void _explainPrivacy() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: NotePalette.card,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          0,
          AppSpacing.screenMargin,
          AppSpacing.xxl,
        ),
        child: Text(
          _talk
              ? 'Private Talk is just for you. ${widget.partnerName} can\'t see it, it never becomes a couple '
                    'reflection, and it clears after 24 hours. You can delete it any time.'
              : 'Your messages stay private to you: ${widget.partnerName} never sees them. When you finish, '
                    'Therabot writes a short summary of your perspective, and only that summary is used for your '
                    'shared reflection. Everything private clears after 24 hours.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: NotePalette.cream),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final view = _view;
    final messages = <ChatMsg>[
      if (view != null)
        ...view.messages
      else ...[
        ChatMsg(
          fromTherabot: true,
          text: _talk ? talkGreeting : coupleGreeting,
        ),
        if (_pendingReason != null)
          ChatMsg(fromTherabot: false, text: _pendingReason!.label),
      ],
    ];
    // Before a Couple Reflection is joined, the partner who joins sees only
    // the consent card: no greeting that could hint at the other's topic.
    final showMessages =
        !(widget.mode == ChatMode.couple && view == null && !_starting);

    final List<ChatChip> chips;
    if (_busy ||
        _hideChips ||
        _safety != null ||
        _finished != null ||
        _needsConsent ||
        view?.stage == 'summary' ||
        view?.stage == 'done') {
      chips = const [];
    } else if (view == null) {
      chips = _talk ? talkReasons : coupleReasons;
    } else {
      chips = view.chips;
    }

    final stage = view?.stage;
    final canType =
        !_busy &&
        _safety == null &&
        _finished == null &&
        !_needsConsent &&
        (view == null ||
            [
              'open',
              'chat',
              'goal',
              'wrap',
              if (_talk) 'summary',
            ].contains(stage)) &&
        !(view != null &&
            view.turnsLeft == 0 &&
            stage == 'wrap' &&
            !_hideChips &&
            !_talk);

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: NotePalette.background,
        body: TherabotBackground(
          child: SafeArea(
            child: Column(
              children: [
                _Header(
                  title: _talk ? 'Private Talk' : 'Couple Reflection',
                  privacy: _talk
                      ? 'Private to you'
                      : 'Your conversation stays private',
                  expiresAt: _expiresAt,
                  onBack: () => Navigator.of(context).pop(_changed),
                  onPrivacy: _explainPrivacy,
                  menu: [
                    PopupMenuItem(
                      value: 'later',
                      child: Text(
                        _talk
                            ? 'Save and come back later'
                            : 'Save and finish later',
                      ),
                    ),
                    if (_talk && view?.talkId != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete this talk'),
                      ),
                  ],
                  onMenu: (v) => v == 'delete'
                      ? _deleteTalk()
                      : Navigator.of(context).pop(_changed),
                ),
                Expanded(
                  child: _safety != null
                      ? ListView(
                          padding: const EdgeInsets.all(
                            AppSpacing.screenMargin,
                          ),
                          children: [
                            TherabotSafetyView(
                              message: _safety!,
                              onDone: () => Navigator.of(context).pop(true),
                            ),
                          ],
                        )
                      : ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenMargin,
                            AppSpacing.md,
                            AppSpacing.screenMargin,
                            AppSpacing.lg,
                          ),
                          children: [
                            if (showMessages)
                              for (final m in messages) _Bubble(message: m),
                            // "Keep talking": a visible go-ahead (not saved).
                            if (_hideChips && view != null)
                              const _Bubble(
                                message: ChatMsg(
                                  fromTherabot: true,
                                  text: "Of course. Go on, I'm listening.",
                                ),
                              ),
                            if (_sending != null)
                              _Bubble(
                                message: ChatMsg(
                                  fromTherabot: false,
                                  text: _sending!,
                                ),
                              ),
                            if (_busy && !_saving && view != null ||
                                _busy && !_saving && _talk && view == null)
                              const _Typing(),
                            if (_needsConsent)
                              _ConsentCard(
                                partnerName: widget.partnerName,
                                joining: !_starting,
                                busy: _busy,
                                onContinue: _consent,
                                onNotReady: () =>
                                    Navigator.of(context).pop(_changed),
                              ),
                            if (_talk &&
                                (stage == 'summary' || stage == 'done') &&
                                view?.summary != null)
                              _SummaryCard(
                                summary: view!.summary!,
                                kept: stage == 'done',
                                busy: _busy,
                                onKeep: () => _keepSummary(view.summary!),
                                onEdit: _editSummary,
                                onContinue:
                                    stage == 'done' || view.turnsLeft == 0
                                    ? null
                                    : () => _focus.requestFocus(),
                                onFinish: _finishTalk,
                              ),
                            if (_finished != null)
                              _FinishedCard(
                                partnerName: widget.partnerName,
                                both: _finished!.bothFinished,
                                onBack: () => Navigator.of(context).pop(true),
                              ),
                          ],
                        ),
                ),
                if (chips.isNotEmpty) _Chips(chips: chips, onTap: _chip),
                if (_safety == null &&
                    _finished == null &&
                    !_needsConsent &&
                    stage != 'done')
                  _Composer(
                    controller: _input,
                    focusNode: _focus,
                    enabled: canType,
                    busy: _busy,
                    hint: view == null
                        ? 'Or type your own…'
                        : "Write what's on your mind…",
                    onSend: _send,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ pieces

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.privacy,
    required this.expiresAt,
    required this.onBack,
    required this.onPrivacy,
    required this.menu,
    required this.onMenu,
  });

  final String title;
  final String privacy;
  final DateTime? expiresAt;
  final VoidCallback onBack;
  final VoidCallback onPrivacy;
  final List<PopupMenuEntry<String>> menu;
  final void Function(String) onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.labelSmall?.copyWith(
      color: NotePalette.muted,
      letterSpacing: 0.2,
    );
    final left = expiresAt?.difference(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const UsIcon(UsIcons.back,
              color: NotePalette.cream,
            ),
            onPressed: onBack,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: NotePalette.cream,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Semantics(
                      button: true,
                      label: '$privacy. Tap to learn more',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: onPrivacy,
                        borderRadius: BorderRadius.circular(99),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const UsIcon(UsIcons.lock,
                                size: 14,
                                color: NotePalette.pink,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                privacy,
                                style: small?.copyWith(color: NotePalette.pink),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (left != null && !left.isNegative)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const UsIcon(UsIcons.history,
                            size: 14,
                            color: NotePalette.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            left.inHours >= 1
                                ? '${left.inHours}h remaining'
                                : '${left.inMinutes} min remaining',
                            style: small,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const UsIcon(UsIcons.more, color: NotePalette.cream),
            itemBuilder: (_) => menu,
            onSelected: onMenu,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMsg message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = !message.fromTherabot;
    final bubble = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: mine ? UsPalette.rose : UsPalette.card,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 4),
          bottomRight: Radius.circular(mine ? 4 : 18),
        ),
      ),
      child: Text(
        message.text,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: mine ? UsPalette.onRose : NotePalette.cream,
          height: 1.45,
        ),
      ),
    );
    return Semantics(
      label: '${mine ? 'You' : 'Therabot'}: ${message.text}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          mainAxisAlignment: mine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mine) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: UsIcon(
                  UsIcons.therabot,
                  size: 16,
                  color: NotePalette.muted,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: bubble,
              ),
            ),
            if (mine) const SizedBox(width: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// "Therabot is writing": three soft dots (still with reduced motion on).
class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionOff(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Therabot is writing',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 36, bottom: AppSpacing.md),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: UsPalette.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: NotePalette.pink.withValues(alpha: 0.18),
              ),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Opacity(
                        opacity:
                            0.35 +
                            0.65 * (((_c.value * 3 - i) % 3) < 1 ? 1 : 0),
                        child: const CircleAvatar(
                          radius: 3.5,
                          backgroundColor: NotePalette.pink,
                        ),
                      ),
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

class _Chips extends StatelessWidget {
  const _Chips({required this.chips, required this.onTap});

  final List<ChatChip> chips;
  final void Function(ChatChip) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin + 24,
        0,
        AppSpacing.screenMargin,
        AppSpacing.sm,
      ),
      // At most about a third of the screen, so the conversation stays in
      // view on small phones; scrolls if the choices need more room.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.34,
        ),
        child: SingleChildScrollView(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              alignment: WrapAlignment.start,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in chips)
                  Semantics(
                    button: true,
                    label: c.label,
                    excludeSemantics: true,
                    child: Material(
                      color: NotePalette.rose.withValues(alpha: 0.12),
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => onTap(c),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 6,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: 1,
                              child: Text(
                                c.label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: NotePalette.cream,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
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

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.busy,
    required this.hint,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool busy;
  final String hint;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = enabled && controller.text.trim().isNotEmpty;
    final long = controller.text.length > 1600;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: UsPalette.ink,
        border: const Border(top: BorderSide(color: UsPalette.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            // Enter sends; Shift+Enter starts a new line.
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  if (canSend) onSend();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: NotePalette.cream,
                ),
                cursorColor: NotePalette.rose,
                decoration: InputDecoration(
                  hintText: busy ? 'Therabot is writing…' : hint,
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: NotePalette.muted.withValues(alpha: 0.7),
                  ),
                  counterText: long ? '${controller.text.length}/2000' : '',
                  counterStyle: theme.textTheme.labelSmall?.copyWith(
                    color: NotePalette.muted,
                  ),
                  filled: true,
                  fillColor: UsPalette.card,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: NotePalette.pink.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: NotePalette.pink.withValues(alpha: 0.2),
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: NotePalette.pink.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(
                      color: NotePalette.rose,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Material(
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              color: canSend ? UsPalette.rose : NotePalette.card,
              child: Ink(
                child: IconButton(
                  tooltip: 'Send',
                  onPressed: canSend ? onSend : null,
                  icon: UsIcon(UsIcons.send,
                    color: canSend
                        ? UsPalette.onRose
                        : NotePalette.muted.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Couple Reflection: what happens with your words, agreed BEFORE you start.
class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.partnerName,
    required this.joining,
    required this.busy,
    required this.onContinue,
    required this.onNotReady,
  });

  final String partnerName;
  final bool joining;
  final bool busy;
  final VoidCallback onContinue;
  final VoidCallback onNotReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge?.copyWith(
      color: NotePalette.muted,
      height: 1.45,
    );
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: therabotCardDecoration(radius: AppRadius.panel + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (joining) ...[
            Text(
              'Your partner started a reflection for the two of you.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: NotePalette.cream,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Take your time and share your side privately.', style: body),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            children: [
              const UsIcon(UsIcons.lock,
                size: 20,
                color: NotePalette.pink,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Your conversation with Therabot stays private.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: NotePalette.cream,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Therabot will use a short summary of your perspective (never your raw messages) to help create '
            'a shared reflection after both of you finish. $partnerName never sees what you write here.',
            style: body,
          ),
          const SizedBox(height: AppSpacing.xl),
          NotePrimaryButton(
            label: 'Continue privately',
            icon: UsIcons.chevronRight,
            iconAfter: true,
            loading: busy,
            onPressed: onContinue,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: busy ? null : onNotReady,
            style: TextButton.styleFrom(
              foregroundColor: NotePalette.pink,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Not ready yet'),
          ),
        ],
      ),
    );
  }
}

/// Private Talk: "Here's what I heard", just for you.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.summary,
    required this.kept,
    required this.busy,
    required this.onKeep,
    required this.onEdit,
    required this.onContinue,
    required this.onFinish,
  });

  final String summary;
  final bool kept;
  final bool busy;
  final VoidCallback onKeep;
  final VoidCallback onEdit;
  final VoidCallback? onContinue;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget quiet(String label, UsIconData icon, VoidCallback onTap) =>
        TextButton.icon(
          onPressed: busy ? null : onTap,
          style: TextButton.styleFrom(
            foregroundColor: NotePalette.pink,
            minimumSize: const Size(0, 44),
          ),
          icon: UsIcon(icon, size: 18),
          label: Text(label),
        );
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: therabotCardDecoration(radius: AppRadius.panel + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Here's what I heard",
            style: theme.textTheme.titleMedium?.copyWith(
              color: NotePalette.cream,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            summary,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: NotePalette.cream,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const UsIcon(UsIcons.lock,
                size: 14,
                color: NotePalette.muted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  kept
                      ? 'Kept privately. It clears after 24 hours.'
                      : 'Only you can see this.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: NotePalette.muted,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!kept)
            NotePrimaryButton(
              label: 'Keep this summary',
              icon: UsIcons.star,
              loading: busy,
              onPressed: onKeep,
            ),
          if (kept)
            NotePrimaryButton(
              label: 'Finish for now',
              icon: UsIcons.check,
              onPressed: onFinish,
            ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              quiet('Edit it', UsIcons.edit, onEdit),
              if (onContinue != null)
                quiet(
                  'Continue talking',
                  UsIcons.chat,
                  onContinue!,
                ),
              if (!kept) quiet('Finish for now', UsIcons.check, onFinish),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinishedCard extends StatelessWidget {
  const _FinishedCard({
    required this.partnerName,
    required this.both,
    required this.onBack,
  });

  final String partnerName;
  final bool both;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: therabotCardDecoration(radius: AppRadius.panel + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your reflection is complete.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: NotePalette.cream,
                  ),
                ),
              ),
              const UsIcon(UsIcons.check,
                color: NotePalette.pink,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            both
                ? 'You have both finished. Therabot is writing your shared reflection now.'
                : 'Waiting for $partnerName to finish theirs.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: NotePalette.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          NotePrimaryButton(
            label: 'Back to Therabot',
            icon: UsIcons.chevronRight,
            iconAfter: true,
            onPressed: onBack,
          ),
        ],
      ),
    );
  }
}

class _EditSummaryDialog extends StatefulWidget {
  const _EditSummaryDialog({required this.initial});

  final String initial;

  @override
  State<_EditSummaryDialog> createState() => _EditSummaryDialogState();
}

class _EditSummaryDialogState extends State<_EditSummaryDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit your summary'),
    content: TextField(
      controller: _c,
      autofocus: true,
      minLines: 4,
      maxLines: 10,
      maxLength: 1500,
      textCapitalization: TextCapitalization.sentences,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_c.text),
        child: const Text('Save'),
      ),
    ],
  );
}
