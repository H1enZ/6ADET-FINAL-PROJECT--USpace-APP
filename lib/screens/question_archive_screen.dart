import 'package:flutter/material.dart';

import '../models/question_answer.dart';
import '../services/auth_service.dart';
import '../services/question_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../widgets/atoms/us_icon.dart';
import '../widgets/effects/motion.dart';
import '../widgets/molecules/us_states.dart';
import '../services/couple_sync.dart';

/// Past daily questions with both answers, newest first. Your partner's
/// answer only shows for days you answered too (the database enforces it).
class QuestionArchiveScreen extends StatefulWidget {
  const QuestionArchiveScreen({
    super.key,
    required this.coupleId,
    required this.myUserId,
    required this.partnerName,
  });

  final String coupleId;
  final String myUserId;
  final String partnerName;

  @override
  State<QuestionArchiveScreen> createState() => _QuestionArchiveScreenState();
}

class _QuestionArchiveScreenState extends State<QuestionArchiveScreen> {
  List<QuestionAnswer> _answers = [];
  bool _loading = true;
  String? _error;

  CoupleSyncHandle? _live;

  @override
  void initState() {
    super.initState();
    _load();
    // Answers as they come in (your partner's shows once you have answered).
    try {
      _live = CoupleSync.listen(widget.coupleId, const {'question_answers'}, () {
        if (mounted) _load();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final answers = await QuestionService.archive(widget.coupleId);
      if (!mounted) return;
      setState(() {
        _answers = answers;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted =
        theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

    // Group answers by day, keeping newest first.
    final days = <DateTime, List<QuestionAnswer>>{};
    for (final a in _answers) {
      days.putIfAbsent(a.questionDate, () => []).add(a);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Our questions')),
      body: _loading
          ? const SkeletonList(count: 5, height: 72)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                children: [
                  if (_error != null) ...[
                    UsErrorNotice(message: _error!, onRetry: _load),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (days.isEmpty && _error == null)
                    const UsEmptyState(
                      icon: UsIcons.question,
                      title: 'No answers yet',
                      message:
                          'Your answers will collect here, one question a day.',
                    ),
                  for (final entry in days.entries) ...[
                    Text(longDate(entry.key),
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(entry.value.first.question,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    for (final a in entry.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: a.userId == widget.myUserId
                                  ? 'You: '
                                  : '${widget.partnerName}: ',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: a.answer),
                          ]),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    if (entry.value.length == 1 &&
                        entry.value.first.userId == widget.myUserId)
                      Text('${widget.partnerName} didn\'t answer this one.',
                          style: muted),
                    const Divider(height: AppSpacing.xxxl),
                  ],
                ],
              ),
            ),
    );
  }
}
