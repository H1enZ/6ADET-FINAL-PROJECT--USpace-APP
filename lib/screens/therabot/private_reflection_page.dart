import 'package:flutter/material.dart';

import '../../models/therabot.dart';
import '../../services/therabot_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/atoms/app_button.dart';
import '../../widgets/atoms/app_text_field.dart';
import '../../widgets/effects/motion.dart';
import '../../widgets/therabot/therabot_widgets.dart';

enum _Phase { questions, thinking, review, editing, safety }

/// Your private reflection: four questions, then Therabot's summary for you
/// to check. Nothing is approved for you: you approve it as it is, correct
/// it yourself, or clarify your answers and ask again.
///
/// Closes with `true` once you approved, so the hub can refresh.
class PrivateReflectionPage extends StatefulWidget {
  const PrivateReflectionPage({
    super.key,
    required this.sessionId,
    required this.expiresAt,
    required this.partnerName,
    this.submission,
  });

  final String sessionId;
  final DateTime expiresAt;
  final String partnerName;

  /// What you saved earlier in this session, if anything.
  final MySubmission? submission;

  @override
  State<PrivateReflectionPage> createState() => _PrivateReflectionPageState();
}

class _PrivateReflectionPageState extends State<PrivateReflectionPage> {
  late final List<TextEditingController> _fields = [
    for (var i = 0; i < therabotQuestions.length; i++)
      TextEditingController(text: _initialAnswer(i)),
  ];
  late List<String> _saved = [for (final c in _fields) c.text.trim()];
  late final _edit = TextEditingController();

  _Phase _phase = _Phase.questions;
  int _step = 0;
  PrivateReflection? _summary;
  late int _left = therabotMaxSummaries - (widget.submission?.aiAttempts ?? 0);
  String? _safetyMessage;
  String? _error;
  bool _busy = false;
  bool _justSaved = false;

  String _initialAnswer(int i) {
    final answers = widget.submission?.answers;
    return answers != null && i < answers.length ? answers[i] : '';
  }

  @override
  void initState() {
    super.initState();
    final sub = widget.submission;
    if (sub != null && sub.status == 'summary_ready' && sub.summary != null) {
      _summary = sub.summary;
      _phase = _Phase.review;
    }
  }

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    _edit.dispose();
    super.dispose();
  }

  /// Approving needs a summary from Therabot first, so with none left and
  /// none to approve, this session can't go further for you.
  String get _noSummariesLeft => _summary != null
      ? "You've used Therabot's summaries for this session. You can still "
            'correct yours yourself with Not quite.'
      : "You've used Therabot's summaries for this session, so it can't "
            'go further. You can end it from the Therabot page and start a '
            'new one.';

  List<String> get _current => [for (final c in _fields) c.text.trim()];
  bool get _changed => !_listEquals(_current, _saved);
  bool get _anyAnswer => _current.any((a) => a.isNotEmpty);

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Saves only when something changed, because saving clears any summary.
  Future<bool> _saveIfChanged() async {
    if (!_changed || !_anyAnswer) return true;
    try {
      await TherabotService.saveAnswers(widget.sessionId, _current);
      _saved = _current;
      _summary = null; // the database cleared it too
      if (mounted) setState(() => _justSaved = true);
      return true;
    } catch (e) {
      if (mounted) setState(() => _error = therabotError(e).message);
      return false;
    }
  }

  Future<void> _next() async {
    setState(() => _error = null);
    if (_step < therabotQuestions.length - 1) {
      setState(() => _busy = true);
      final ok = await _saveIfChanged();
      if (!mounted) return;
      setState(() {
        _busy = false;
        // A failed save keeps you on this question, next to its error.
        if (ok) _step++;
      });
      return;
    }
    await _reflect();
  }

  Future<void> _saveForLater() async {
    if (!_anyAnswer) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _busy = true);
    final ok = await _saveIfChanged();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    therabotToast(
      context,
      'Saved privately. Come back whenever you are ready.',
    );
    Navigator.of(context).pop(false);
  }

  Future<void> _reflect() async {
    if (!_anyAnswer) {
      setState(
        () => _error =
            'Answer at least one question first. Even a few words is enough.',
      );
      return;
    }
    // Nothing changed since the last summary: asking again would only spend
    // one of your summaries on the same words.
    if (_summary != null && !_changed) {
      setState(() {
        _error = null;
        _phase = _Phase.review;
      });
      return;
    }
    if (_left <= 0) {
      setState(() => _error = _noSummariesLeft);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    if (!await _saveIfChanged()) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.thinking);
    try {
      final result = await TherabotService.summarize(widget.sessionId);
      if (!mounted) return;
      switch (result) {
        case SummaryReady(:final reflection, :final summariesLeft):
          setState(() {
            _summary = reflection;
            _left = summariesLeft;
            _phase = _Phase.review;
          });
        case SummarySafety(:final message):
          setState(() {
            _safetyMessage = message;
            _phase = _Phase.safety;
          });
      }
    } catch (e) {
      if (!mounted) return;
      final error = therabotError(e);
      setState(() {
        if (error.code == 'rate_limited') _left = 0;
        _error = error.code == 'rate_limited' && _summary == null
            ? _noSummariesLeft
            : error.message;
        _phase = _summary != null ? _Phase.review : _Phase.questions;
      });
      // A failed call may or may not have used a summary on the server, and
      // the summary may even have been stored with only the reply lost:
      // read the real state back rather than guessing.
      try {
        final mine = await TherabotService.mySubmission(widget.sessionId);
        if (mounted && mine != null) {
          setState(() {
            _left = therabotMaxSummaries - mine.aiAttempts;
            if (mine.status == 'summary_ready' &&
                mine.summary != null &&
                !_changed) {
              _summary = mine.summary;
              _error = null;
              _phase = _Phase.review;
            }
          });
        }
      } catch (_) {
        // Keep the current count; the server still enforces the limit.
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve(String text) async {
    final t = text.trim();
    if (t.isEmpty) {
      setState(() => _error = 'Write a few words before approving.');
      return;
    }
    // Counted the way the database counts (code points), not UTF-16 units.
    if (t.runes.length > PrivateReflection.maxApprovedLength) {
      setState(
        () => _error = 'Your summary is a little too long. Try shortening it.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await TherabotService.approve(widget.sessionId, t);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = therabotError(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Back was pressed with words that are not saved yet: keep or discard.
  Future<void> _leaveWithUnsaved() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keep your words?'),
        content: const Text(
          'Some of what you wrote is not saved yet. It stays private either way.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('Save privately'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'save') {
      setState(() => _busy = true);
      final ok = await _saveIfChanged();
      if (!mounted) return;
      setState(() => _busy = false);
      if (!ok) return;
      therabotToast(
        context,
        'Saved privately. Come back whenever you are ready.',
      );
    }
    Navigator.of(context).pop(false);
  }

  /// Back was pressed while correcting the summary: keep editing or leave.
  Future<void> _leaveEditing() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave your changes?'),
        content: const Text(
          'Your version of the summary is not approved yet, so your changes '
          'will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
        ],
      ),
    );
    if (!mounted || leave != true) return;
    Navigator.of(context).pop(false);
  }

  bool get _editedSummary =>
      _phase == _Phase.editing &&
      _edit.text.trim() != (_summary?.approvalText ?? '').trim();

  void _notQuite() {
    _edit.text = _summary?.approvalText ?? '';
    setState(() {
      _error = null;
      _phase = _Phase.editing;
    });
  }

  void _clarify() {
    setState(() {
      _error = null;
      _step = 0;
      _phase = _Phase.questions;
    });
  }

  // ------------------------------------------------------------------ views

  @override
  Widget build(BuildContext context) {
    final title = switch (_phase) {
      _Phase.questions || _Phase.thinking => 'Your private reflection',
      _Phase.review || _Phase.editing => 'Your summary',
      _Phase.safety => 'Therabot',
    };
    return PopScope(
      canPop:
          !_busy &&
          !(_phase == _Phase.questions && _changed && _anyAnswer) &&
          // Typing doesn't rebuild, so editing always asks here first.
          _phase != _Phase.editing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _busy) return;
        if (_phase == _Phase.editing) {
          if (_editedSummary) {
            _leaveEditing();
          } else {
            Navigator.of(context).pop(false);
          }
        } else {
          _leaveWithUnsaved();
        }
      },
      child: TherabotPage(
        title: title,
        children: [
          AnimatedSwitcher(
            duration: Duration(milliseconds: motionOff(context) ? 0 : 320),
            switchInCurve: Curves.easeOutCubic,
            child: KeyedSubtree(
              key: ValueKey('$_phase-$_step'),
              child: switch (_phase) {
                _Phase.questions => _questions(context),
                _Phase.thinking => const TherabotThinking(
                  lines: [
                    'Reading your words gently…',
                    'Listening for what matters to you…',
                    'Putting it into a few careful sentences…',
                  ],
                ),
                _Phase.review => _review(context),
                _Phase.editing => _editing(context),
                _Phase.safety => TherabotSafetyView(
                  message: _safetyMessage ?? '',
                  onDone: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorLine(BuildContext context) => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        );

  Widget _questions(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final last = _step == therabotQuestions.length - 1;
    final hasSummary =
        widget.submission?.status == 'summary_ready' || _summary != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Question ${_step + 1} of ${therabotQuestions.length}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
              ),
            ),
            const Spacer(),
            ExcludeSemantics(
              excluding: !_justSaved,
              child: AnimatedOpacity(
                opacity: _justSaved ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  'Saved privately',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.chipBar),
          child: AnimatedProgressBar(
            value: (_step + 1) / therabotQuestions.length,
            color: scheme.primary,
            backgroundColor: scheme.primaryContainer,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        TherabotCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(therabotQuestions[_step], style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                therabotQuestionHints[_step],
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _fields[_step],
                maxLength: therabotMaxAnswerLength,
                minLines: 5,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                // Rebuild on every change so the back guard, the "replaces
                // your summary" note and the button label stay current.
                onChanged: (_) => setState(() => _justSaved = false),
                decoration: const InputDecoration(
                  hintText: 'Write as much or as little as you like…',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrivacyNote(
          'Only you can read your answers. ${widget.partnerName} never sees them.',
        ),
        const SizedBox(height: AppSpacing.sm),
        ExpiryNote(expiresAt: widget.expiresAt),
        if (hasSummary && _changed) ...[
          const SizedBox(height: AppSpacing.md),
          TherabotCard(
            tentative: true,
            child: Text(
              'Changing your answers replaces your current summary. '
              '${_left > 1
                  ? 'You have $_left summaries left.'
                  : _left == 1
                  ? 'This is your last summary for this session, so if it doesn\'t work out you can\'t get another one here.'
                  : ''}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        _errorLine(context),
        Row(
          children: [
            if (_step > 0) ...[
              Expanded(
                child: AppButton(
                  label: 'Back',
                  variant: AppButtonVariant.outlined,
                  onPressed: _busy ? null : () => setState(() => _step--),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              flex: 2,
              child: AppButton(
                label: !last
                    ? 'Next'
                    : _summary != null && !_changed
                    ? 'Nothing changed yet'
                    : 'Reflect with Therabot',
                icon: last ? Icons.auto_awesome_outlined : null,
                isLoading: _busy,
                onPressed: last && _summary != null && !_changed ? null : _next,
              ),
            ),
          ],
        ),
        if (_summary != null && !_changed) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Back to my summary',
            variant: AppButtonVariant.outlined,
            onPressed: _busy
                ? null
                : () => setState(() => _phase = _Phase.review),
            fullWidth: true,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: _busy ? null : _saveForLater,
            child: const Text('Save and finish later'),
          ),
        ),
      ],
    );
  }

  Widget _review(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = _summary;
    if (s == null) {
      return TherabotErrorView(
        message: _error ?? therabotMessages['internal']!,
        onRetry: _clarify,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: staggered([
        // Exactly the text "That's accurate" approves, needs included, so
        // you never approve words you have not seen.
        TherabotCard(
          tinted: true,
          label: 'Your private reflection',
          child: Text(
            s.approvalText,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        if (s.uncertainPoints.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          TherabotCard(
            tentative: true,
            label: "Therabot wasn't sure about",
            child: SoftList(
              items: s.uncertainPoints,
              italic: true,
              marker: '?',
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text('Does this feel right?', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'You decide. Nothing goes further until you approve it, and your words '
          'always win over Therabot\'s.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _errorLine(context),
        AppButton(
          label: "That's accurate",
          icon: Icons.check,
          isLoading: _busy,
          onPressed: () => _approve(s.approvalText),
          fullWidth: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Not quite',
          icon: Icons.edit_outlined,
          variant: AppButtonVariant.outlined,
          onPressed: _busy ? null : _notQuite,
          fullWidth: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Let me clarify',
          icon: Icons.chat_outlined,
          variant: AppButtonVariant.outlined,
          onPressed: _busy || _left <= 0 ? null : _clarify,
          fullWidth: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _left > 0
              ? 'Clarifying lets you add to your answers and ask again '
                    '($_left ${_left == 1 ? 'summary' : 'summaries'} left).'
              : "You've used your summaries for this session. You can still correct it yourself with Not quite.",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrivacyNote(
          'When you approve, only this summary (never your answers) is used to write '
          'a shared reflection for you and ${widget.partnerName}.',
        ),
      ]),
    );
  }

  Widget _editing(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Say it your way', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Change anything that isn\'t right. Your version replaces Therabot\'s, '
          'and it is the one you approve.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Your summary',
          controller: _edit,
          maxLength: PrivateReflection.maxApprovedLength,
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.md),
        PrivacyNote(
          'Only this summary, in your words, is used for the shared reflection. '
          '${widget.partnerName} never sees your answers.',
        ),
        const SizedBox(height: AppSpacing.xl),
        _errorLine(context),
        AppButton(
          label: 'Approve my version',
          icon: Icons.check,
          isLoading: _busy,
          onPressed: () => _approve(_edit.text),
          fullWidth: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Back to Therabot\'s version',
          variant: AppButtonVariant.outlined,
          onPressed: _busy
              ? null
              : () => setState(() => _phase = _Phase.review),
          fullWidth: true,
        ),
      ],
    );
  }
}
