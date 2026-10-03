import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../../models/therabot.dart';
import '../../services/therabot_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/atoms/app_button.dart';
import '../../widgets/effects/floating_hearts.dart';
import '../../widgets/effects/motion.dart';
import '../../widgets/therabot/therabot_widgets.dart';
import '../chat_screen.dart';
import 'next_step_pages.dart';
import 'private_reflection_page.dart';
import 'shared_reflection_view.dart';
import 'therabot_history_screen.dart';

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
  TherabotSession? _session;
  MySubmission? _submission;
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

  /// Set ONLY when the server refused to start a session because of the
  /// daily limit (it alone knows the count): shown in place of the Start
  /// button until you try again or the session changes.
  String? _dailyLimit;

  String get _partner => widget.partnerName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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
      if (!mounted || generation != _generation) return;
      setState(() {
        if (session?.id != _session?.id) _resetSessionState();
        _session = session;
        _submission = submission;
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
    _dailyLimit = null;
  }

  static bool _isDailyLimit(TherabotException e) =>
      e.code == 'invalid_state' &&
      e.message.contains('Therabot sessions a day');

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

  /// Starts a NEW session and opens its blank questions straight away.
  /// The questions page is created fresh, with no answers from before.
  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await TherabotService.start();
    } catch (e) {
      if (!mounted) return;
      final error = therabotError(e);
      setState(() {
        _busy = false;
        // The server's answer stays on screen instead of a passing toast.
        if (_isDailyLimit(error)) _dailyLimit = error.message;
      });
      if (!_isDailyLimit(error)) therabotToast(context, error.message);
      await _load();
      return;
    }
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    setState(() => _busy = false);
    final s = _session;
    if (s != null &&
        s.status == TherabotStatus.collecting &&
        _submission == null) {
      await _openPrivate();
    }
  }

  /// Clears a limit message and tries again (time may have passed).
  Future<void> _retryStart() async {
    setState(() => _dailyLimit = null);
    await _start();
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

  /// Asks before recording a choice, because your partner sees it. You can
  /// also just look at a step without choosing it.
  Future<String?> _askChoose(TherabotChoice choice) {
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            0,
            AppSpacing.screenMargin,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${choice.emoji}  ${choice.label}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Choosing it lets $_partner see that you picked ${choice.label}. You can '
                'change your mind while this reflection is open.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Choose ${choice.label}',
                onPressed: () => Navigator.of(context).pop('choose'),
                fullWidth: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Just look first',
                variant: AppButtonVariant.outlined,
                onPressed: () => Navigator.of(context).pop('look'),
                fullWidth: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _choose(TherabotChoice choice) async {
    final s = _session;
    if (s == null) return;
    var record = false;
    if (s.myChoice != choice) {
      final answer = await _askChoose(choice);
      if (!mounted || answer == null) return;
      record = answer == 'choose';
    }
    if (record) {
      setState(() => _busy = true);
      try {
        await TherabotService.choose(s.id, choice);
      } catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        therabotToast(context, therabotError(e).message);
        return;
      }
      if (!mounted) return;
      setState(() => _busy = false);
      await _load();
      if (!mounted) return;
    }
    final fresh = _session ?? s;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => _pageFor(choice, fresh)));
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
        builder: (_) => TherabotHistoryScreen(partnerName: _partner),
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
    return TherabotPage(
      title: 'Therabot',
      onRefresh: _load,
      actions: [
        IconButton(
          tooltip: 'Past reflections',
          icon: const Icon(Icons.history),
          onPressed: _openHistory,
        ),
        PopupMenuButton<String>(
          tooltip: 'More',
          onSelected: (v) => switch (v) {
            'insights' => _push(const TherabotInsightsScreen()),
            'end' => _end(),
            'delete' => _deleteMine(),
            _ => null,
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'insights', child: Text('My insights')),
            if (canEnd)
              const PopupMenuItem(
                value: 'end',
                child: Text('End this session'),
              ),
            if (canDelete)
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete my answers'),
              ),
          ],
        ),
      ],
      children: _loading
          ? const [SizedBox(height: 480, child: SkeletonList(count: 3))]
          : staggered([
              // In safety mode the usual "shared reflection" intro is left out.
              TherabotHeader(
                caption: safetyMode
                    ? null
                    : 'A private space for both of you to reflect separately before '
                          'seeing a shared reflection.',
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_error != null)
                TherabotErrorView(message: _error!, onRetry: _load)
              else
                _stage(context),
            ]),
    );
  }

  Widget _stage(BuildContext context) {
    final s = _session;
    if (s == null) return _intro(context, ended: false);
    switch (s.status) {
      case TherabotStatus.collecting:
        return _collecting(context, s);
      case TherabotStatus.reflecting:
        return _reflectingView(context);
      case TherabotStatus.reflectionReady:
        return s.reflection == null
            ? _intro(context, ended: true)
            : _reflection(context, s);
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

  Widget _intro(BuildContext context, {required bool ended}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ended) ...[
          TherabotCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This session has ended',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "When you're both ready, either of you can start a new one.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        TherabotCard(
          label: 'How it works',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, step) in const [
                'Each of you answers four questions, privately.',
                'Therabot writes you a private summary. You check it, correct it, and approve it.',
                'Once you both approve, you see a shared reflection together.',
                'Each of you chooses what would help next. You decide; Therabot never picks.',
              ].indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          '${i + 1}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(step, style: theme.textTheme.bodyLarge),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrivacyNote(
          "$_partner never sees your answers or your private summary, and you never "
          'see theirs. Private answers are cleared after 24 hours.',
        ),
        const SizedBox(height: AppSpacing.xl),
        _startSection(
          context,
          label: ended ? 'Start a new reflection' : 'Start a reflection',
        ),
      ],
    );
  }

  /// The Start button, or the daily-limit message in its place.
  Widget _startSection(BuildContext context, {required String label}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final limit = _dailyLimit;
    if (limit != null) {
      return TherabotCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Taking a pause for today',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Semantics(liveRegion: true, child: Text(limit, style: muted)),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _busy ? null : _retryStart,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: label,
          icon: Icons.auto_awesome_outlined,
          isLoading: _busy,
          onPressed: _start,
          fullWidth: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "Either of you can start. Therabot isn't therapy, and it never decides who is right.",
          textAlign: TextAlign.center,
          style: muted,
        ),
      ],
    );
  }

  /// A finished session: both of you chose a next step. The reflection
  /// itself lives in Past reflections; here you can start a new one, or
  /// quietly reopen a next-step page.
  Widget _completed(BuildContext context, TherabotSession s) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final mine = s.myChoice;
    final theirs = s.partnerChoice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TherabotCard(
          tinted: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reflection complete 💗',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${s.title == null ? 'Your reflection is' : '"${s.title}" is'} '
                'saved in Past reflections, where you can read it again any time.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
              if (mine != null && theirs != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'You chose ${mine.label} · $_partner chose ${theirs.label}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Primary action first: a finished session never blocks a new one.
        _startSection(context, label: 'Start a new reflection'),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'See Past reflections',
          icon: Icons.history,
          variant: AppButtonVariant.outlined,
          onPressed: _openHistory,
          fullWidth: true,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text('Revisit a next step', style: muted),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final c in TherabotChoice.values)
              TextButton(
                onPressed: () => _revisit(c, s),
                child: Text('${c.emoji} ${c.label}'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _progressRow(
    BuildContext context,
    String who,
    bool done,
    String text,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            done ? Icons.favorite : Icons.favorite_border,
            size: 18,
            color: done ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              who,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _collecting(BuildContext context, TherabotSession s) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sub = _submission;
    final mine = s.myProgress;
    final partnerDone = s.partnerProgress == TherabotProgress.approved;

    final myText = switch (mine) {
      TherabotProgress.approved => 'Finished',
      TherabotProgress.submitted => 'Summary ready to review',
      TherabotProgress.pending => sub == null ? 'Not started' : 'In progress',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TherabotCard(
          label: s.title ?? 'This session',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _progressRow(
                context,
                'You',
                mine == TherabotProgress.approved,
                myText,
              ),
              // Couple-visible progress only: finished or not. Nothing else.
              _progressRow(
                context,
                _partner,
                partnerDone,
                partnerDone ? 'Finished' : 'Not finished yet',
              ),
              const SizedBox(height: AppSpacing.xs),
              ExpiryNote(expiresAt: s.expiresAt),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (mine == TherabotProgress.approved)
          _waiting(context, partnerDone)
        else ...[
          if (!s.iStarted && sub == null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                "$_partner started a reflection. Join whenever you're ready. There's no rush.",
                style: theme.textTheme.bodyLarge,
              ),
            ),
          TherabotCard(
            tinted: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  mine == TherabotProgress.submitted
                      ? 'Your private summary is ready'
                      : sub == null
                      ? 'Your private reflection'
                      : 'Pick up where you left off',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  mine == TherabotProgress.submitted
                      ? 'Read it, correct anything that is not quite right, and approve it when it feels true.'
                      : 'Four gentle questions, just for you. Take your time.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: mine == TherabotProgress.submitted
                      ? 'Review my summary'
                      : sub == null
                      ? 'Begin my reflection'
                      : 'Continue my reflection',
                  onPressed: _busy ? null : _openPrivate,
                  fullWidth: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrivacyNote(
            "$_partner never sees your answers. You never see theirs.",
          ),
        ],
      ],
    );
  }

  Widget _waiting(BuildContext context, bool partnerDone) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TherabotCard(
          tinted: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your reflection is complete 💗',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                partnerDone
                    ? 'You have both finished. Your shared reflection is on its way.'
                    : "Your partner hasn't finished their reflection yet.",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'While you wait, just for you',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Clarify my thoughts',
          icon: Icons.edit_note,
          variant: AppButtonVariant.outlined,
          onPressed: () => _push(
            TherabotPrivateNotePage(
              coupleId: widget.coupleId,
              partnerName: _partner,
              draft: false,
            ),
          ),
          fullWidth: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Draft something for later',
          icon: Icons.drafts_outlined,
          variant: AppButtonVariant.outlined,
          onPressed: () => _push(
            TherabotPrivateNotePage(
              coupleId: widget.coupleId,
              partnerName: _partner,
              draft: true,
            ),
          ),
          fullWidth: true,
        ),
        const SizedBox(height: AppSpacing.md),
        const PrivacyNote(
          'These stay private. They are never sent, and Therabot does not read them.',
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

    String choiceLine() {
      if (mine == null && theirs == null) {
        return 'Each of you chooses for yourself. Different choices are okay.';
      }
      if (mine == null) {
        return '$_partner has chosen. Take your time choosing yours.';
      }
      if (theirs == null) {
        return 'You chose ${mine.label}. $_partner hasn\'t chosen yet.';
      }
      if (mine == theirs) return 'You both chose ${mine.label}.';
      return 'You chose ${mine.label} and $_partner chose ${theirs.label}. You need different '
          "things right now, and that's okay. Each of you can do what helps; there's no need to agree.";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Not complete yet: the server keeps this session open (and refuses
        // a new one) until both of you have chosen, or for 24 hours.
        if (mine != null && theirs == null) ...[
          TherabotCard(
            tentative: true,
            child: Text(
              "You've chosen ${mine.label}. This reflection completes when "
              '$_partner chooses too (or after 24 hours), and then you can '
              'start a new one.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
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
          'Written only from the two summaries you each approved.',
          style: muted,
        ),
        const SizedBox(height: AppSpacing.lg),
        SharedReflectionView(
          reflection: s.reflection!,
          myPartnerNumber: s.myPartnerNumber,
          partnerName: _partner,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text('What would help you next?', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(choiceLine(), style: muted),
        const SizedBox(height: AppSpacing.md),
        NextStepGrid(selected: mine, onTap: _choose, busy: _busy),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          label: "We're okay for now",
          icon: Icons.favorite_border,
          variant: AppButtonVariant.outlined,
          onPressed: _okayForNow,
          fullWidth: true,
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
