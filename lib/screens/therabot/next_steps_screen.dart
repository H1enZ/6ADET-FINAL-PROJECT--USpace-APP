import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/therabot.dart';
import '../../services/therabot_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/effects/soft_hearts_background.dart';
import '../../widgets/home/quick_actions.dart';
import '../../widgets/notes/note_style.dart';
import '../../widgets/therabot/therabot_widgets.dart';

/// "What would help you now?": the last step of a Couple Reflection.
///
/// Each of you chooses privately (migration 017: neither sees the other's
/// pick until both have chosen). Then the two choices are compared: the
/// same step becomes a shared next step; different ones get a gentle bridge
/// (fixed wording, no AI). You can change your mind until your partner has
/// chosen too.
///
/// Closes with `true` when something changed.
class NextStepsScreen extends StatefulWidget {
  const NextStepsScreen({
    super.key,
    required this.session,
    required this.partnerName,
    required this.pageFor,
    required this.onOkayForNow,
    required this.onTalkPrivately,
  });

  final TherabotSession session;
  final String partnerName;

  /// The existing page for a step (Comfort, Talk, Space, Reconnect).
  final Widget Function(TherabotChoice choice, TherabotSession session) pageFor;
  final Future<void> Function() onOkayForNow;
  final Future<void> Function() onTalkPrivately;

  @override
  State<NextStepsScreen> createState() => _NextStepsScreenState();
}

class _NextStepsScreenState extends State<NextStepsScreen> {
  late TherabotSession _session = widget.session;
  bool _busy = false;
  bool _changed = false;
  Timer? _poll;

  static const _art = {
    TherabotChoice.comfort: QuickActionArt.comfort,
    TherabotChoice.talk: QuickActionArt.talk,
    TherabotChoice.space: QuickActionArt.breather,
    TherabotChoice.reconnect: QuickActionArt.reconnect,
  };

  @override
  void initState() {
    super.initState();
    _schedulePoll();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// While you wait for your partner's choice, check quietly now and then
  /// (whether they chose, never what, until you both have).
  void _schedulePoll() {
    _poll?.cancel();
    if (_session.myChoice != null && _session.partnerChoice == null) {
      _poll = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    try {
      final s = await TherabotService.current();
      if (!mounted || s == null || s.id != _session.id) return;
      setState(() => _session = s);
      _schedulePoll();
    } catch (_) {} // the next check, or a pull on the hub, will catch up
  }

  Future<void> _choose(TherabotChoice choice) async {
    if (_busy || _session.myChoice == choice || _session.partnerChoice != null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await TherabotService.choose(_session.id, choice);
      _changed = true;
      await _refresh();
    } catch (e) {
      if (mounted) therabotToast(context, therabotError(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _okayForNow() async {
    await widget.onOkayForNow();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _open(TherabotChoice choice) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => widget.pageFor(choice, _session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = _session;
    final mine = s.myChoice;
    final theirs = s.partnerChoice;
    final both = mine != null && theirs != null;

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: NotePalette.background,
        body: SoftHeartsBackground(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [NotePalette.backgroundTop, NotePalette.background],
          ),
          heartColor: NotePalette.rose.withValues(alpha: 0.045),
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.md,
                AppSpacing.screenMargin,
                AppSpacing.xxl,
              ),
              children: [
                _Header(
                  onBack: () => Navigator.of(context).pop(_changed),
                  done: both,
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (both)
                  _Result(
                    mine: mine,
                    theirs: theirs,
                    partnerName: widget.partnerName,
                    onOpenMine: () => _open(mine),
                    onOpenTheirs: mine == theirs ? null : () => _open(theirs),
                  )
                else ...[
                  Semantics(
                    header: true,
                    child: Text(
                      'What would help you now?',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: NotePalette.cream,
                        fontSize: 26,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Choose what feels right. ${widget.partnerName} will choose separately, and '
                    'Therabot will suggest a next step for both of you once you have both chosen.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: NotePalette.muted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (mine != null) ...[
                    _Waiting(
                      mine: mine,
                      partnerName: widget.partnerName,
                      partnerChose: s.partnerHasChosen,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _Grid(selected: mine, busy: _busy, art: _art, onTap: _choose),
                  const SizedBox(height: AppSpacing.xl),
                  _OkayRow(onTap: _okayForNow),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'End this reflection without choosing another step.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: NotePalette.muted,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Divider(color: NotePalette.pink.withValues(alpha: 0.12)),
                const SizedBox(height: AppSpacing.xl),
                _TalkCard(onTap: widget.onTalkPrivately),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.done});

  final VoidCallback onBack;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget bar(bool on) => Expanded(
      child: Container(
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: on
              ? NotePalette.pink
              : NotePalette.pink.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: NotePalette.card,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: NotePalette.cream,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next steps',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: NotePalette.cream,
                ),
              ),
              Text(
                done
                    ? 'Your reflection is complete.'
                    : 'Choose what would help you now.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: NotePalette.muted,
                ),
              ),
            ],
          ),
        ),
        // Reflect privately, shared reflection, next step: the last of three.
        Semantics(
          label: done ? 'All steps done' : 'Final step of three',
          excludeSemantics: true,
          child: SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(children: [bar(true), bar(true), bar(done)]),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  done ? 'Complete' : 'Final step',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: NotePalette.muted,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.selected,
    required this.busy,
    required this.art,
    required this.onTap,
  });

  final TherabotChoice? selected;
  final bool busy;
  final Map<TherabotChoice, QuickActionArt> art;
  final void Function(TherabotChoice) onTap;

  @override
  Widget build(BuildContext context) {
    final choices = TherabotChoice.values;
    Widget row(int i) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ChoiceCard(
              choice: choices[i],
              art: art[choices[i]]!,
              selected: selected == choices[i],
              busy: busy,
              onTap: onTap,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _ChoiceCard(
              choice: choices[i + 1],
              art: art[choices[i + 1]]!,
              selected: selected == choices[i + 1],
              busy: busy,
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        row(0),
        const SizedBox(height: AppSpacing.md),
        row(2),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.choice,
    required this.art,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final TherabotChoice choice;
  final QuickActionArt art;
  final bool selected;
  final bool busy;
  final void Function(TherabotChoice) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${choice.label}. ${choice.blurb}${selected ? '. Your choice' : ''}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: noteCardDecoration(
          selected: selected,
          radius: AppRadius.panel + 2,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.panel + 2),
            onTap: busy ? null : () => onTap(choice),
            child: Padding(
              padding: EdgeInsets.all(narrow ? AppSpacing.md : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      QuickActionArtView(art, size: narrow ? 58 : 72),
                      const Spacer(),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? NotePalette.rose
                              : Colors.white.withValues(alpha: 0.06),
                          border: Border.all(
                            color: NotePalette.pink.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          selected
                              ? Icons.check_rounded
                              : Icons.chevron_right_rounded,
                          size: 20,
                          color: selected
                              ? const Color(0xFF3A0A19)
                              : NotePalette.cream,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    choice.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: NotePalette.cream,
                      fontSize: narrow ? 15 : 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    choice.blurb,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: NotePalette.muted,
                      height: 1.4,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your choice',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: NotePalette.pink,
                        letterSpacing: 0.4,
                      ),
                    ),
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

class _Waiting extends StatelessWidget {
  const _Waiting({
    required this.mine,
    required this.partnerName,
    required this.partnerChose,
  });

  final TherabotChoice mine;
  final String partnerName;
  final bool partnerChose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: noteCardDecoration(radius: AppRadius.card),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: NotePalette.pink,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'You chose ${mine.label}, privately. Waiting for $partnerName to choose. '
              'You can change your mind until they do.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: NotePalette.cream,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Both chose: the same step, or a gentle bridge between two.
class _Result extends StatelessWidget {
  const _Result({
    required this.mine,
    required this.theirs,
    required this.partnerName,
    required this.onOpenMine,
    required this.onOpenTheirs,
  });

  final TherabotChoice mine;
  final TherabotChoice theirs;
  final String partnerName;
  final VoidCallback onOpenMine;
  final VoidCallback? onOpenTheirs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outcome = nextStepOutcome(mine, theirs);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: noteCardDecoration(
        selected: true,
        radius: AppRadius.panel + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: NotePalette.pink,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Reflection complete',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: NotePalette.pink,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            outcome.title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: NotePalette.cream,
              height: 1.25,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            mine == theirs
                ? 'You both chose ${mine.label}.'
                : 'You chose ${mine.label}. $partnerName chose ${theirs.label}.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: NotePalette.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            outcome.body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: NotePalette.cream,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          NotePrimaryButton(
            label: 'Open ${mine.label.toLowerCase()}',
            icon: Icons.chevron_right_rounded,
            iconAfter: true,
            onPressed: onOpenMine,
          ),
          if (onOpenTheirs != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: onOpenTheirs,
              style: TextButton.styleFrom(
                foregroundColor: NotePalette.pink,
                minimumSize: const Size(0, 44),
              ),
              child: Text('Look at ${theirs.label.toLowerCase()} too'),
            ),
          ],
        ],
      ),
    );
  }
}

class _OkayRow extends StatelessWidget {
  const _OkayRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: "We're okay for now",
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(color: NotePalette.pink.withValues(alpha: 0.45)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.favorite_border_rounded,
                  color: NotePalette.pink,
                ),
                Expanded(
                  child: Text(
                    "We're okay for now",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: NotePalette.pink,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: NotePalette.pink,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TalkCard extends StatelessWidget {
  const _TalkCard({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label:
          'Still have something on your mind? Talk privately with Therabot. Only you can see it.',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: noteCardDecoration(radius: AppRadius.panel + 2),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.panel + 2),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NotePalette.rose.withValues(alpha: 0.16),
                      border: Border.all(
                        color: NotePalette.pink.withValues(alpha: 0.35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: NotePalette.rose.withValues(alpha: 0.3),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: NotePalette.pink,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Still have something on your mind?',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: NotePalette.cream,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Talk privately with Therabot. Only you can see it.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: NotePalette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: NotePalette.cream,
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
