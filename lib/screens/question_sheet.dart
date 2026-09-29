import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/question_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/app_text_field.dart';

/// Answer (or change your answer to) today's question.
/// Closes with `true` once saved.
class QuestionSheet extends StatefulWidget {
  const QuestionSheet({
    super.key,
    required this.coupleId,
    required this.day,
    required this.question,
    this.currentAnswer,
  });

  final String coupleId;
  final DateTime day;
  final String question;
  final String? currentAnswer;

  @override
  State<QuestionSheet> createState() => _QuestionSheetState();
}

class _QuestionSheetState extends State<QuestionSheet> {
  late final _answer = TextEditingController(text: widget.currentAnswer);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_answer.text.trim().isEmpty) {
      setState(() => _error = 'Write your answer first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await QuestionService.answer(
        coupleId: widget.coupleId,
        day: widget.day,
        question: widget.question,
        answer: _answer.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        0,
        AppSpacing.screenMargin,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.formMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("TODAY'S QUESTION",
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.xs),
              Text(widget.question, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Your answer',
                controller: _answer,
                hintText: 'Take your time. Only the two of you will see this.',
                maxLength: 2000,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: widget.currentAnswer == null
                    ? 'Save my answer'
                    : 'Update my answer',
                onPressed: _save,
                isLoading: _saving,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
