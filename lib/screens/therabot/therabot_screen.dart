import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/profile.dart';
import '../../models/therabot.dart';
import '../../models/therabot_chat.dart';
import '../../services/auth_service.dart';
import '../../services/therabot_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/atoms/app_button.dart';
import '../../widgets/effects/floating_hearts.dart';
import '../../widgets/effects/soft_hearts_background.dart';
import '../../widgets/effects/motion.dart';
import '../../widgets/atoms/avatar_circle.dart';
import '../../widgets/notes/note_style.dart';
import '../../widgets/therabot/therabot_widgets.dart';
import '../chat_screen.dart';
import '../work_it_out_screen.dart' show ResolutionNotesPage;
import 'next_step_pages.dart';
import 'next_steps_screen.dart';
import 'private_reflection_page.dart';
import 'therabot_chat_screen.dart';
import 'shared_reflection_view.dart';
import 'therabot_history_screen.dart';
import '../../widgets/effects/smooth_scroll.dart';

/// Therabot: "A private relationship reflection assistant".
///
/// COUPLE → AI ASSISTS → COUPLE DECIDES. Each of you reflects privately,
/// approves your own summary, and only then sees a shared reflection. Then
/// each of you picks your own next step.
///
/// This hub shows whatever stage your couple's current session is at.
class TherabotScreen extends StatefulWidget {
  const TherabotScreen({
    super.key,
    required this.coupleId,
    required this.partnerName,
    this.me,
    this.partner,
    this.anniversary,
  });

  final String coupleId;
  final String partnerName;

  /// Both profiles, when known, let Talk open your chat.
  final Profile? me;
  final Profile? partner;
  final DateTime? anniversary;

  @override
  State<TherabotScreen> createState() => _TherabotScreenState();
}

class _TherabotScreenState extends State<TherabotScreen> {
  /// Mouse-wheel scrolling glides instead of jumping.
  final _scroll = SmoothScrollController();

  TherabotSession? _session;
  MySubmission? _submission;

  /// Your own Couple Reflection chat (null before you agreed to take part),
  /// and your open Private Talk, if any. Only ever your own.
  ChatView? _chat;
  ChatView? _talk;
  bool _loading = true;
  bool _busy = false;
  bool _reflecting = false;
  String? _error;
  String? _reflectError;
  String? _reflectErrorCode;

  /// When we found your partner's request already writing the reflection.
  /// The server lets go of a stuck request after 90 seconds, so after that
  /// you are offered Try again instead of waiting until the session ends.
  DateTime? _partnerWritingSince;
  Timer? _poll;

  String get _partner => widget.partnerName;

  /// Display only: "Partner 1" / "Partner 2" as your two usernames, by who
  /// started the session (you may well be Partner 2).
  TherabotNames _names(int myPartnerNumber) => TherabotNames(
    myPartnerNumber: myPartnerNumber,
    myName: widget.me?.displayName,
    partnerName: widget.partner?.displayName,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _poll?.cancel();
    super.dispose();
  }

  /// Bumped on every load, so a slow, older load never overwrites a newer
  /// one (for example a poll that started just before you chose a step).
  int _generation = 0;

  /// The session we already asked to write a reflection for. Asking again
  /// only happens when you tap Try again: every try uses one of 3.
  String? _autoReflected;

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final session = await TherabotService.current();
      // Your own row, whatever the stage, so you can always delete it.
      // If this fails we show an error rather than guess "nothing saved",
      // which could let new answers replace the ones you wrote.
      final submission = session == null
          ? null
          : await TherabotService.mySubmission(session.id);
      final chat =
          session != null && session.status == TherabotStatus.collecting
          ? await TherabotService.myChat(session.id)
          : null;
      // A Private Talk is a bonus here: if it can't load, the hub still works.
      ChatView? talk;
      try {
        talk = await TherabotService.openTalk();
      } catch (_) {}
      if (!mounted || generation != _generation) return;
      setState(() {
        if (session?.id != _session?.id) _resetSessionState();
        _session = session;
        _submission = submission;
        _chat = chat;
        _talk = talk;
        _error = null;
        _loading = false;
      });
      _schedulePoll();
      if (session != null &&
          session.status == TherabotStatus.reflecting &&
          _autoReflected != session.id) {
        _autoReflected = session.id;
        unawaited(_reflect());
      }
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = therabotError(e).message;
        _loading = false;
      });
    }
  }

  /// Forgets everything that belonged to the previous session, so nothing
  /// (errors, waiting state, a limit message) carries over to a new one.
  void _resetSessionState() {
    _reflecting = false;
    _reflectError = null;
    _reflectErrorCode = null;
    _partnerWritingSince = null;
  }

  /// While waiting on your partner (or on the reflection), checks again
  /// quietly every 20 seconds. Progress only, never their content.
  void _schedulePoll() {
    _poll?.cancel();
    final s = _session;
    final waiting =
        s != null &&
        ((s.status == TherabotStatus.collecting &&
                s.myProgress == TherabotProgress.approved) ||
            (s.status == TherabotStatus.reflecting && _reflectError == null) ||
            (s.hasReflection && s.partnerChoice == null));
    if (!waiting) return;
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !_busy && !_reflecting) _load();
    });
  }

  Future<void> _reflect() async {
    final s = _session;
    if (s == null || _reflecting) return;
    setState(() {
      _reflecting = true;
      _reflectError = null;
      _reflectErrorCode = null;
      _partnerWritingSince = null;
    });
    try {
      final status = await TherabotService.reflect(s.id);
      if (!mounted) return;
      _reflecting = false;
      await _load();
      if (!mounted) return;
      if (status == 'reflection_ready') {
        showFloatingHearts(context, emoji: '💗');
      }
    } catch (e) {
      if (!mounted) return;
      final error = therabotError(e);
      setState(() {
        _reflecting = false;
        // "Already being written" (your partner's request got there first):
        // the poll picks it up. Anything else waits for a tap on Try again.
        _reflectError = error.code == 'invalid_state' ? null : error.message;
        _reflectErrorCode = error.code;
        _partnerWritingSince = error.code == 'invalid_state'
            ? DateTime.now()
            : null;
      });
      _schedulePoll();
    }
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (done != null) therabotToast(context, done);
      await _load();
    } catch (e) {
      if (!mounted) return;
      therabotToast(context, therabotError(e).message);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, String yes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(yes),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _end() async {
    final s = _session;
    if (s == null) return;
    final ok = await _confirm(
      'End this session?',
      "Neither of you will get a shared reflection from it. No reason is shared, "
          'and you can start again whenever you are ready.',
      'End session',
    );
    if (ok) await _run(() => TherabotService.end(s.id), done: 'Session ended');
  }

  Future<void> _deleteMine() async {
    final s = _session;
    if (s == null) return;
    final ok = await _confirm(
      'Delete your answers now?',
      'Your answers and your private summary are deleted right away. If your shared '
          'reflection is not ready yet, this session ends for both of you.',
      'Delete',
    );
    if (ok) {
      await _run(
        () => TherabotService.deleteMyAnswers(s.id),
        done: 'Your answers were deleted',
      );
    }
  }

  /// Couple Reflection: start a new one (choose a topic, agree, talk), or
  /// continue / join the current one.
  Future<void> _openCouple() async {
    final s = _session;
    final open = s != null && s.status == TherabotStatus.collecting;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TherabotChatScreen(
          mode: ChatMode.couple,
          partnerName: _partner,
          sessionId: open ? s.id : null,
          initial: open ? _chat : null,
          expiresAt: open ? s.expiresAt : null,
        ),
      ),
    );
    if (mounted) await _load();
  }

  /// Private Talk: continue your open one, or start a new one.
  Future<void> _openTalk() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TherabotChatScreen(
          mode: ChatMode.talk,
          partnerName: _partner,
          initial: _talk,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openPrivate() async {
    final s = _session;
    if (s == null) return;
    final approved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrivateReflectionPage(
          sessionId: s.id,
          expiresAt: s.expiresAt,
          partnerName: _partner,
          submission: _submission,
        ),
      ),
    );
    if (!mounted) return;
    if (approved == true) {
      showFloatingHearts(context, emoji: '💗');
      therabotToast(context, 'Approved. Your part is done 💗');
    }
    await _load();
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  VoidCallback? get _openChat {
    final me = widget.me;
    final partner = widget.partner;
    if (me == null || partner == null) return null;
    return () =>
        _push(ChatScreen(coupleId: widget.coupleId, me: me, partner: partner));
  }

  Widget _pageFor(TherabotChoice choice, TherabotSession s) => switch (choice) {
    TherabotChoice.comfort => TherabotComfortPage(
      coupleId: widget.coupleId,
      partnerName: _partner,
    ),
    TherabotChoice.talk => TherabotTalkPage(
      questions: s.reflection?.discussionQuestions ?? const [],
      names: _names(s.myPartnerNumber),
      partnerName: _partner,
      onOpenChat: _openChat,
    ),
    TherabotChoice.space => TherabotSpacePage(
      coupleId: widget.coupleId,
      partnerName: _partner,
      onTalk: () => _pushReplacementTalk(s),
    ),
    TherabotChoice.reconnect => TherabotReconnectPage(
      coupleId: widget.coupleId,
      partnerName: _partner,
      anniversary: widget.anniversary,
    ),
  };

  void _pushReplacementTalk(TherabotSession s) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => _pageFor(TherabotChoice.talk, s)),
    );
  }

  Future<void> _openNextSteps(TherabotSession s) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NextStepsScreen(
          session: s,
          partnerName: _partner,
          pageFor: _pageFor,
          onOkayForNow: _okayForNow,
          onTalkPrivately: _openTalk,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _okayForNow() async {
    final s = _session;
    if (s == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TherabotCompletionPage(sessionId: s.id),
      ),
    );
    // Stay in Therabot, on whatever the session is now (often complete).
    if (mounted) await _load();
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TherabotHistoryScreen(
          partnerName: _partner,
          myUsername: widget.me?.displayName,
          partnerUsername: widget.partner?.displayName,
        ),
      ),
    );
    if (mounted) await _load();
  }

  /// Opens a next-step page again from a finished reflection. Nothing is
  /// recorded: your choice was already made.
  Future<void> _revisit(TherabotChoice choice, TherabotSession s) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => _pageFor(choice, s)));
    if (mounted) await _load();
  }

  Future<void> _nameIt() async {
    final s = _session;
    if (s == null) return;
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: s.title ?? ''),
    );
    if (title == null) return;
    await _run(() => TherabotService.setTitle(s.id, title));
  }

  // ------------------------------------------------------------------ views

  /// The shared reflection on this screen, so "View shared reflection" can
  /// glide down to it.
  final _reflectionKey = GlobalKey();

  void _showReflection() {
    final target = _reflectionKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: motionOff(context)
          ? Duration.zero
          : const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  /// Notes kept with "Clarify my thoughts" or "Draft something for later".
  void _openSavedNotes() {
    final myId = AuthService.user?.id;
    if (myId == null) return;
    _push(
      ResolutionNotesPage(
        coupleId: widget.coupleId,
        myUserId: myId,
        partnerName: _partner,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final canEnd =
        s != null &&
        (s.status == TherabotStatus.collecting ||
            s.status == TherabotStatus.reflecting);
    final canDelete = s != null && _submission != null;
    final safetyMode =
        s?.status == TherabotStatus.closed && (_submission?.isSafety ?? false);

    final menu = PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded, color: NotePalette.cream),
      onSelected: (v) => switch (v) {
        'history' => _openHistory(),
        'insights' => _push(const TherabotInsightsScreen()),
        'notes' => _openSavedNotes(),
        'end' => _end(),
        'delete' => _deleteMine(),
        _ => null,
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'history', child: Text('Past reflections')),
        const PopupMenuItem(value: 'insights', child: Text('My insights')),
        const PopupMenuItem(value: 'notes', child: Text('Saved notes')),
        if (canEnd)
          const PopupMenuItem(value: 'end', child: Text('End this session')),
        if (canDelete)
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete my answers'),
          ),
      ],
    );

    final children = _loading
        ? const <Widget>[SizedBox(height: 480, child: SkeletonList(count: 3))]
        : staggered([
            if (!safetyMode) ...[
              Text(
                'A quiet space to reflect before you come back together.',
                style: GoogleFonts.poppins(
                  fontSize: MediaQuery.sizeOf(context).width < 360 ? 23 : 27,
                  fontWeight: FontWeight.w400,
                  height: 1.25,
                  color: NotePalette.cream,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
            if (_error != null)
              TherabotErrorView(message: _error!, onRetry: _load)
            else
              _stage(context),
            // One privacy line for the whole screen (safety mode has its own).
            if (!safetyMode && _error == null) ...[
              const SizedBox(height: AppSpacing.xxl),
              _PrivacyBlock(partnerName: _partner),
            ],
          ]);

    return Scaffold(
      backgroundColor: NotePalette.background,
      body: SoftHeartsBackground(
        // Calmer than Home: the same slow hearts, fainter.
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NotePalette.backgroundTop, NotePalette.background],
        ),
        heartColor: NotePalette.rose.withValues(alpha: 0.045),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.lg,
                AppSpacing.screenMargin,
                AppSpacing.xxl,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HubHeader(menu: menu),
                        const SizedBox(height: AppSpacing.xxl),
                        ...children,
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

  Widget _stage(BuildContext context) {
    final s = _session;
    if (s == null) return _intro(context, ended: false);
    switch (s.status) {
      case TherabotStatus.collecting:
        return _collecting(context, s);
      case TherabotStatus.reflecting:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sessionCard(s, mine: 'Finished', partner: 'Finished'),
            const SizedBox(height: AppSpacing.lg),
            _reflectingView(context),
          ],
        );
      case TherabotStatus.reflectionReady:
        if (s.reflection == null) return _intro(context, ended: true);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ActionCard(
              icon: Icons.favorite_rounded,
              title: 'Your shared reflection is ready',
              body: 'You both finished reflecting.',
              button: 'View shared reflection',
              onPressed: _showReflection,
            ),
            const SizedBox(height: AppSpacing.xxl),
            KeyedSubtree(key: _reflectionKey, child: _reflection(context, s)),
            const SizedBox(height: AppSpacing.xxl),
            // Private Talk stays available, separate from the reflection.
            _talkCard(context),
          ],
        );
      case TherabotStatus.completed:
        // Finished: it lives in Past reflections now, not on the hub.
        return _completed(context, s);
      case TherabotStatus.closed:
        final sub = _submission;
        if (sub != null && sub.isSafety) {
          // Safety mode, for you only. Your partner sees a plain "ended".
          return TherabotSafetyView(
            message: sub.safetyMessage ?? therabotSafetyFallback,
            onDone: () => Navigator.of(context).pop(),
          );
        }
        return _intro(context, ended: true);
      case TherabotStatus.unknown:
        return _intro(context, ended: true);
    }
  }

  /// Both of you side by side, with where each of you is (couple-visible
  /// progress only: finished or not), and the time left.
  Widget _sessionCard(
    TherabotSession s, {
    required String mine,
    required String partner,
    bool mineActive = false,
  }) {
    return _SessionCard(
      title: s.title,
      me: widget.me,
      partner: widget.partner,
      partnerName: _partner,
      myStatus: mine,
      myActive: mineActive,
      myDone: mine == 'Finished',
      partnerStatus: partner,
      partnerDone: partner == 'Finished',
      expiresAt: s.expiresAt,
    );
  }

  /// No reflection open: "What do you need today?" and the two ways in.
  Widget _intro(BuildContext context, {required bool ended}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ended) ...[
          Text(
            "That session has ended. Whenever you're ready, you can start again.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: NotePalette.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _modeChoice(context),
      ],
    );
  }

  /// The two Therabot modes, side by side in purpose.
  Widget _modeChoice(BuildContext context, {bool coupleAvailable = true}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What do you need today?',
          style: theme.textTheme.titleLarge?.copyWith(color: NotePalette.cream),
        ),
        const SizedBox(height: AppSpacing.md),
        if (coupleAvailable)
          _ActionCard(
            icon: Icons.favorite_rounded,
            title: 'Reflect on something together',
            body:
                'Each of you talks privately with Therabot about the same thing. Then you both see one '
                'neutral, shared reflection, made only from short summaries of your two perspectives.',
            button: 'Reflect together',
            onPressed: _busy ? null : _openCouple,
          ),
        if (coupleAvailable) const SizedBox(height: AppSpacing.lg),
        _talkCard(context),
      ],
    );
  }

  /// Private Talk: always available, never shared.
  Widget _talkCard(BuildContext context) {
    final resume = _talk != null;
    return _ActionCard(
      icon: Icons.lock_outline_rounded,
      title: resume
          ? 'Continue your private talk'
          : 'Talk privately with Therabot',
      body: resume
          ? 'Pick up where you left off. Only you can see it.'
          : 'Just you and Therabot: vent, think something through, or get advice. Nothing goes to '
                '$_partner, and it never becomes a couple reflection.',
      button: resume ? 'Continue talking' : 'Talk privately',
      onPressed: _busy ? null : _openTalk,
      quiet: true,
    );
  }

  /// A finished session: both of you chose a next step. The reflection
  /// itself lives in Past reflections; here you can start something new, or
  /// quietly reopen a next-step page.
  Widget _completed(BuildContext context, TherabotSession s) {
    final mine = s.myChoice;
    final theirs = s.partnerChoice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionCard(
          icon: Icons.check_circle_outline_rounded,
          title: 'Reflection complete',
          body:
              '${s.title == null ? 'Your reflection is' : '"${s.title}" is'} '
              'saved in Past reflections, where you can read it again any time.'
              '${mine != null && theirs != null ? '\n\n${nextStepOutcome(mine, theirs).title}. ${nextStepOutcome(mine, theirs).body}' : ''}',
          secondary: TextButton.icon(
            onPressed: _openHistory,
            style: TextButton.styleFrom(foregroundColor: NotePalette.pink),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('See Past reflections'),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        // A finished session never blocks a new one.
        _modeChoice(context),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Revisit a next step',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: NotePalette.muted),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final c in TherabotChoice.offered)
              TextButton(
                onPressed: () => _revisit(c, s),
                style: TextButton.styleFrom(foregroundColor: NotePalette.pink),
                child: Text(c.label),
              ),
          ],
        ),
      ],
    );
  }

  Widget _collecting(BuildContext context, TherabotSession s) {
    final sub = _submission;
    final chat = _chat;
    final mine = s.myProgress;
    final partnerDone = s.partnerProgress == TherabotProgress.approved;
    // An older-style session (four questions), started before the guided
    // chat: kept working as it was.
    final legacy = sub != null && chat == null;

    final myText = switch (mine) {
      TherabotProgress.approved => 'Finished',
      TherabotProgress.submitted => 'Summary to review',
      TherabotProgress.pending => sub == null ? 'Not started' : 'In progress',
    };

    final Widget action;
    if (mine == TherabotProgress.approved) {
      action = _waiting(context, partnerDone);
    } else if (legacy && mine == TherabotProgress.submitted) {
      action = _ActionCard(
        icon: Icons.fact_check_outlined,
        title: 'Your private summary is ready',
        body:
            'Read it, correct anything that is not quite right, and approve it when it feels true.',
        button: 'Review my summary',
        onPressed: _busy ? null : _openPrivate,
      );
    } else if (legacy) {
      action = _ActionCard(
        icon: Icons.edit_note_rounded,
        title: 'Continue your reflection',
        body: 'Pick up where you left off.',
        button: 'Continue reflection',
        onPressed: _busy ? null : _openPrivate,
      );
    } else if (chat != null) {
      action = _ActionCard(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Continue your reflection',
        body: 'Pick up your private conversation with Therabot.',
        button: 'Continue reflection',
        onPressed: _busy ? null : _openCouple,
      );
    } else if (!s.iStarted) {
      // Neutral: never how your partner described it, not even the topic.
      action = _ActionCard(
        icon: Icons.favorite_border_rounded,
        title: 'Your partner started a reflection for the two of you.',
        body: 'Take your time and share your side privately.',
        button: 'Share my side',
        onPressed: _busy ? null : _openCouple,
      );
    } else {
      action = _ActionCard(
        icon: Icons.auto_awesome_rounded,
        title: 'Start your reflection',
        body: 'Take a little time for yourself before you come back together.',
        button: 'Start reflection',
        onPressed: _busy ? null : _openCouple,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sessionCard(
          s,
          mine: myText,
          mineActive: mine != TherabotProgress.approved,
          partner: partnerDone ? 'Finished' : 'Not finished yet',
        ),
        const SizedBox(height: AppSpacing.lg),
        action,
        const SizedBox(height: AppSpacing.xl),
        // Private Talk stays available, separate from the reflection.
        _talkCard(context),
      ],
    );
  }

  Widget _waiting(BuildContext context, bool partnerDone) {
    final theme = Theme.of(context);
    Widget note(String label, IconData icon, bool draft) => OutlinedButton.icon(
      onPressed: () => _push(
        TherabotPrivateNotePage(
          coupleId: widget.coupleId,
          partnerName: _partner,
          draft: draft,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: NotePalette.pink,
        side: BorderSide(color: NotePalette.pink.withValues(alpha: 0.4)),
        minimumSize: const Size(0, 44),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionCard(
          icon: Icons.check_circle_outline_rounded,
          title: 'Your reflection is complete',
          body: partnerDone
              ? 'You have both finished. Your shared reflection is on its way.'
              : "Waiting for $_partner to finish theirs.\n\nYou'll both see the "
                    "shared reflection once you've both finished.",
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'While you wait, just for you (never sent)',
          style: theme.textTheme.bodyMedium?.copyWith(color: NotePalette.muted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            note('Clarify my thoughts', Icons.edit_note_rounded, false),
            note('Draft something for later', Icons.drafts_outlined, true),
          ],
        ),
      ],
    );
  }

  Widget _reflectingView(BuildContext context) {
    if (_reflectError != null && !_reflecting) {
      // Out of tries: another tap could only fail the same way.
      final exhausted = _reflectErrorCode == 'rate_limited';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TherabotErrorView(
            message: _reflectError!,
            onRetry: exhausted ? null : _reflect,
          ),
          if (exhausted) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'End this session',
              variant: AppButtonVariant.outlined,
              onPressed: _busy ? null : _end,
              fullWidth: true,
            ),
          ],
        ],
      );
    }
    final since = _partnerWritingSince;
    final stalled =
        !_reflecting &&
        since != null &&
        DateTime.now().difference(since) > const Duration(seconds: 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TherabotThinking(
          lines: [
            'Bringing both of your reflections together…',
            'Looking for what each of you needs…',
            'Writing gently, without taking sides…',
          ],
        ),
        if (stalled) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'This is taking longer than usual.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: _reflect,
              child: const Text('Try again'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _reflection(BuildContext context, TherabotSession s) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final mine = s.myChoice;
    final theirs = s.partnerChoice;
    final String status;
    if (mine == null) {
      status = s.partnerHasChosen
          ? '$_partner has chosen privately. Take your time choosing yours.'
          : 'Each of you chooses privately. Neither of you sees the other\'s choice until you both have.';
    } else {
      status =
          'You chose ${mine.label}, privately. Waiting for $_partner to choose.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                s.title ?? 'Your shared reflection',
                style: theme.textTheme.titleLarge,
              ),
            ),
            if (s.status == TherabotStatus.reflectionReady)
              TextButton.icon(
                onPressed: _busy ? null : _nameIt,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(s.title == null ? 'Name it' : 'Rename'),
              ),
          ],
        ),
        Text(
          'Written only from short summaries of your two perspectives, never your private chats.',
          style: muted,
        ),
        const SizedBox(height: AppSpacing.lg),
        SharedReflectionView(
          reflection: s.reflection!,
          names: _names(s.myPartnerNumber),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _ActionCard(
          icon: Icons.route_rounded,
          title: 'What would help you now?',
          body: theirs != null ? 'You have both chosen.' : status,
          button: mine == null
              ? 'Choose a next step'
              : 'See or change my choice',
          onPressed: _busy ? null : () => _openNextSteps(s),
        ),
        const SizedBox(height: AppSpacing.md),
        ExpiryNote(expiresAt: s.expiresAt),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'This reflection moves to Past reflections once you have both chosen a '
          'next step, or after 24 hours.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Owns its text controller, so it is disposed only after the dialog has
/// finished closing.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this reflection'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            maxLength: 60,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. The weekend plans',
            ),
          ),
          Text(
            'Either of you can rename it until you have both chosen a next step. '
            'Then the name is kept for your history.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// "Therabot" and its line, a small glowing reflection mark, and the menu.
class _HubHeader extends StatelessWidget {
  const _HubHeader({required this.menu});

  final Widget menu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(top: 2, right: AppSpacing.md),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: NotePalette.rose.withValues(alpha: 0.16),
            border: Border.all(color: NotePalette.pink.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: NotePalette.rose.withValues(alpha: 0.35),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 20,
            color: NotePalette.pink,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Therabot',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 26,
                    color: NotePalette.cream,
                  ),
                ),
              ),
              Text(
                'Private relationship reflection',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: NotePalette.muted,
                ),
              ),
            ],
          ),
        ),
        menu,
      ],
    );
  }
}

/// THIS SESSION: you and your partner side by side, joined by a small
/// heart, with each of your statuses and the time left underneath.
class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.title,
    required this.me,
    required this.partner,
    required this.partnerName,
    required this.myStatus,
    required this.myActive,
    required this.myDone,
    required this.partnerStatus,
    required this.partnerDone,
    required this.expiresAt,
  });

  final String? title;
  final Profile? me;
  final Profile? partner;
  final String partnerName;
  final String myStatus;
  final bool myActive;
  final bool myDone;
  final String partnerStatus;
  final bool partnerDone;
  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final avatar = narrow ? 56.0 : 66.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: noteCardDecoration(radius: AppRadius.panel + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            (title ?? 'This session').toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: NotePalette.muted,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Person(
                  name: 'You',
                  realName: me?.displayName ?? 'You',
                  imageUrl: me?.avatarUrl,
                  status: myStatus,
                  active: myActive && !myDone,
                  done: myDone,
                  size: avatar,
                ),
              ),
              // The heart between you, at avatar height.
              SizedBox(
                height: avatar,
                width: narrow ? 56 : 76,
                child: const _HeartLink(),
              ),
              Expanded(
                child: _Person(
                  name: partnerName,
                  realName: partner?.displayName ?? partnerName,
                  imageUrl: partner?.avatarUrl,
                  status: partnerStatus,
                  active: false,
                  done: partnerDone,
                  size: avatar,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(height: 1, color: NotePalette.pink.withValues(alpha: 0.15)),
          const SizedBox(height: AppSpacing.md),
          ExpiryNote(expiresAt: expiresAt),
        ],
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({
    required this.name,
    required this.realName,
    required this.imageUrl,
    required this.status,
    required this.active,
    required this.done,
    required this.size,
  });

  final String name;
  final String realName;
  final String? imageUrl;
  final String status;
  final bool active;
  final bool done;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$name: $status',
      excludeSemantics: true,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: NotePalette.pink.withValues(
                      alpha: done || active ? 0.75 : 0.3,
                    ),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: NotePalette.rose.withValues(
                        alpha: done || active ? 0.35 : 0.1,
                      ),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: AvatarCircle(
                  name: realName,
                  imageUrl: imageUrl,
                  size: size,
                  background: const Color(0xFF4A1D42),
                ),
              ),
              if (done)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: NotePalette.background,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: NotePalette.pink,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: NotePalette.cream,
            ),
          ),
          Text(
            status,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: active || done ? NotePalette.pink : NotePalette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two thin lines with a small glowing heart between them.
class _HeartLink extends StatelessWidget {
  const _HeartLink();

  @override
  Widget build(BuildContext context) {
    Widget line() => Expanded(
      child: Container(
        height: 1,
        color: NotePalette.pink.withValues(alpha: 0.35),
      ),
    );
    return ExcludeSemantics(
      child: Row(
        children: [
          line(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.favorite_rounded,
              size: 16,
              color: NotePalette.rose,
              shadows: [
                Shadow(
                  color: NotePalette.rose.withValues(alpha: 0.8),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          line(),
        ],
      ),
    );
  }
}

/// The one main thing to do now: a burgundy card with a title, a line or
/// two, and the big pink button.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.body,
    this.button,
    this.onPressed,
    this.secondary,
    this.quiet = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? button;
  final VoidCallback? onPressed;
  final Widget? secondary;

  /// A secondary card: plain plum, outlined button, so the main action
  /// stays the strongest thing on the screen.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: quiet
          ? noteCardDecoration(radius: AppRadius.panel + 2)
          : BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.panel + 2),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4A1C3A), Color(0xFF2E1226)],
              ),
              border: Border.all(
                color: NotePalette.pink.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: NotePalette.rose.withValues(alpha: 0.18),
                  blurRadius: 24,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: NotePalette.cream,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(icon, size: 22, color: NotePalette.pink),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: NotePalette.muted,
            ),
          ),
          if (button != null) ...[
            const SizedBox(height: AppSpacing.xl),
            if (quiet)
              OutlinedButton.icon(
                onPressed: onPressed,
                iconAlignment: IconAlignment.end,
                style: OutlinedButton.styleFrom(
                  foregroundColor: NotePalette.pink,
                  side: BorderSide(
                    color: NotePalette.pink.withValues(alpha: 0.55),
                  ),
                  minimumSize: const Size.fromHeight(50),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.chevron_right_rounded),
                label: Text(button!),
              )
            else
              NotePrimaryButton(
                label: button!,
                icon: Icons.chevron_right_rounded,
                iconAfter: true,
                onPressed: onPressed,
              ),
          ],
          if (secondary != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(alignment: Alignment.centerLeft, child: secondary),
          ],
        ],
      ),
    );
  }
}

/// The one privacy line on the hub, matching what Therabot really does:
/// neither of you ever sees the other's answers or private summary.
class _PrivacyBlock extends StatelessWidget {
  const _PrivacyBlock({required this.partnerName});

  final String partnerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2, right: AppSpacing.md),
          child: Icon(
            Icons.lock_outline_rounded,
            size: 22,
            color: NotePalette.muted,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your answers stay private.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: NotePalette.cream,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$partnerName never sees your answers or your private summary, '
                'and you never see theirs. A shared reflection is written only '
                'from short summaries of your two perspectives, and Private Talk is never shared.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: NotePalette.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
