import 'package:flutter/material.dart';

import '../models/mood.dart';
import '../services/auth_service.dart';
import '../services/mood_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/app_text_field.dart';
import '../widgets/effects/motion.dart';

/// "How are you feeling today?" Pick a mood, optionally say why, and choose
/// whether your partner can see it. Closes with `true` once saved.
class MoodSheet extends StatefulWidget {
  const MoodSheet({
    super.key,
    required this.coupleId,
    required this.partnerName,
    this.current,
  });

  final String coupleId;
  final String partnerName;
  final Mood? current;

  @override
  State<MoodSheet> createState() => _MoodSheetState();
}

class _MoodSheetState extends State<MoodSheet> {
  late Mood? _mood = widget.current;
  final _note = TextEditingController();
  bool _shared = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final mood = _mood;
    if (mood == null) {
      setState(() => _error = 'Choose how you feel first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await MoodService.checkIn(
        coupleId: widget.coupleId,
        mood: mood,
        note: _note.text,
        shared: _shared,
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
    final scheme = theme.colorScheme;

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
              Text('How are you feeling?', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final mood in Mood.selectableMoods)
                    ChoiceChip(
                      label: PopOnChange(
                        trigger: _mood == mood,
                        scale: _mood == mood ? 1.18 : 1,
                        child: Text('${mood.emoji}  ${mood.label}'),
                      ),
                      selected: _mood == mood,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() {
                                _mood = mood;
                                _error = null;
                              }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                label: 'Why? (optional)',
                controller: _note,
                hintText: 'e.g. Finished my exams!',
                maxLength: 280,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _shared,
                onChanged:
                    _saving ? null : (value) => setState(() => _shared = value),
                title: Text('Share with ${widget.partnerName}'),
                subtitle: Text(
                  _shared
                      ? '${widget.partnerName} will see this mood.'
                      : 'Only you will see this one.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Save my mood',
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
