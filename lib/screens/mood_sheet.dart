import 'package:flutter/material.dart';

import '../models/mood.dart';
import '../models/mood_visual.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/effects/motion.dart';
import '../widgets/home/mood_art.dart';

/// The note for today's mood, opened from "Add a note" on Home.
///
/// Mood sharing is automatic: tapping a mood here shares it at once through
/// [onPick], exactly like the mood card (no share switch, no confirm).
/// The button only saves the optional note text through [onSaveNote].
/// Emptying an existing note and saving removes the note, never the mood.
/// Closes with `true` when something was saved.
class MoodSheet extends StatefulWidget {
  const MoodSheet({
    super.key,
    required this.current,
    required this.currentNote,
    required this.onPick,
    required this.onSaveNote,
  });

  /// Today's mood, kept selected. Null if you haven't picked one yet.
  final Mood? current;

  /// Today's note, preloaded for editing.
  final String? currentNote;

  /// Shares a mood now. Resolves to false if the save failed (the sheet
  /// then puts the previous mood back).
  final Future<bool> Function(Mood mood) onPick;

  /// Saves the note (or removes it when [note] is null) for [mood].
  final Future<void> Function(Mood mood, String? note) onSaveNote;

  /// The notes column's limit in the database.
  static const maxNote = 280;

  @override
  State<MoodSheet> createState() => _MoodSheetState();
}

class _MoodSheetState extends State<MoodSheet> {
  late Mood? _mood = widget.current;
  late final _note = TextEditingController(text: widget.currentNote ?? '');
  bool _picking = false;
  bool _saving = false;
  String? _error;

  String get _original => widget.currentNote?.trim() ?? '';
  String get _text => _note.text.trim();
  bool get _hadNote => _original.isNotEmpty;
  bool get _changed => _text != _original;

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(Mood mood) async {
    if (_picking || _saving || mood == _mood) return;
    final previous = _mood;
    setState(() {
      _mood = mood;
      _picking = true;
      _error = null;
    });
    final ok = await widget.onPick(mood);
    if (!mounted) return;
    setState(() {
      if (!ok) _mood = previous;
      _picking = false;
    });
  }

  Future<void> _save() async {
    final mood = _mood;
    if (mood == null || !_changed || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSaveNote(mood, _text.isEmpty ? null : _text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _buttonLabel {
    if (!_hadNote) return 'Save note';
    if (_text.isEmpty) return 'Remove note';
    return 'Update note';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final length = _note.text.characters.length;

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
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final mood in Mood.selectableMoods)
                    ChoiceChip(
                      label: PopOnChange(
                        trigger: _mood == mood,
                        scale: _mood == mood ? 1.12 : 1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MoodArt(
                              visual: MoodVisual.of(mood),
                              size: 22,
                              semantic: false,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(mood.label),
                          ],
                        ),
                      ),
                      showCheckmark: false,
                      selected: _mood == mood,
                      onSelected: _picking || _saving
                          ? null
                          : (_) => _pick(mood),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Add a note', style: theme.textTheme.titleMedium),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Optional', style: muted),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                label: 'Note, optional',
                child: TextField(
                  controller: _note,
                  enabled: !_saving,
                  maxLength: MoodSheet.maxNote,
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'What’s behind this feeling?',
                    // The count shows quietly only near the limit.
                    counterText: length > MoodSheet.maxNote - 40
                        ? '$length / ${MoodSheet.maxNote}'
                        : '',
                  ),
                ),
              ),
              if (_mood == null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text('Pick a mood first, then add a note to it.', style: muted),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: _buttonLabel,
                onPressed: _mood == null || !_changed || _picking
                    ? null
                    : _save,
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

/// Today's notes behind your moods, opened from the small note marker on
/// the Home mood card. Same mood doesn't mean same reason, so each person's
/// note is shown under their name. Closes with `true` to add or edit yours.
class MoodNotesSheet extends StatelessWidget {
  const MoodNotesSheet({super.key, required this.notes, required this.hasMine});

  final List<({String name, String? note})> notes;
  final bool hasMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        0,
        AppSpacing.screenMargin,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Today’s notes', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          for (final n in notes) ...[
            Text(
              n.name,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              n.note == null ? 'No note today' : '“${n.note}”',
              style: n.note == null
                  ? theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    )
                  : theme.textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppButton(
            label: hasMine ? 'Edit my note' : 'Add a note',
            variant: AppButtonVariant.outlined,
            onPressed: () => Navigator.of(context).pop(true),
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}
