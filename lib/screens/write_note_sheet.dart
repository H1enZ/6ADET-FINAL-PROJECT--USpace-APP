import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/note_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../utils/capsule_time.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/app_text_field.dart';
import '../widgets/atoms/seal_badge.dart';

/// Write a love note, or seal it as a Time Capsule that neither of you can
/// open until the chosen moment. Closes with `true` once sent.
class WriteNoteSheet extends StatefulWidget {
  const WriteNoteSheet({
    super.key,
    required this.coupleId,
    required this.partnerName,
    this.anniversary,
    this.startSealed = false,
  });

  final String coupleId;
  final String partnerName;
  final DateTime? anniversary;
  final bool startSealed;

  @override
  State<WriteNoteSheet> createState() => _WriteNoteSheetState();
}

class _WriteNoteSheetState extends State<WriteNoteSheet> {
  final _body = TextEditingController();
  final _teaser = TextEditingController();
  late bool _sealed = widget.startSealed;
  DateTime? _unlockAt;
  String? _preset;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    _teaser.dispose();
    super.dispose();
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _unlockAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
      helpText: 'Open on',
    );
    if (!mounted || day == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Open at',
    );
    if (!mounted || time == null) return;
    setState(() {
      _unlockAt = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      _preset = null;
      _error = null;
    });
  }

  Future<void> _send() async {
    if (_body.text.trim().isEmpty) {
      setState(() => _error = 'Write your note first.');
      return;
    }
    final unlock = _sealed ? _unlockAt : null;
    if (_sealed) {
      if (unlock == null) {
        setState(() => _error = 'Choose when the capsule opens.');
        return;
      }
      if (!unlock.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
        setState(() => _error = 'Choose a time in the future.');
        return;
      }
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await NoteService.send(
        coupleId: widget.coupleId,
        body: _body.text,
        unlockAt: unlock,
        capsuleTitle: _teaser.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final presets = capsulePresets(DateTime.now(), anniversary: widget.anniversary);
    final unlock = _unlockAt;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        0,
        AppSpacing.screenMargin,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (_sealed) ...[
                    const SealBadge(size: 30),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      _sealed ? 'Seal a time capsule' : 'A note for ${widget.partnerName}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Your note',
                controller: _body,
                hintText: _sealed
                    ? 'Write to the two of you in the future…'
                    : 'Write something sweet…',
                maxLength: 2000,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _sealed,
                onChanged: _sending ? null : (v) => setState(() => _sealed = v),
                title: const Text('Seal as a Time Capsule 🔒'),
                subtitle: Text(
                  'Neither of you can open it until the moment you choose. Not even you.',
                  style: muted,
                ),
              ),
              if (_sealed) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('OPENS', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final entry in presets.entries)
                      ChoiceChip(
                        label: Text(entry.key),
                        selected: _preset == entry.key,
                        onSelected: _sending
                            ? null
                            : (_) => setState(() {
                                  _preset = entry.key;
                                  _unlockAt = entry.value;
                                  _error = null;
                                }),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.event_outlined, size: 18),
                      label: const Text('Pick date & time'),
                      onPressed: _sending ? null : _pickCustom,
                    ),
                  ],
                ),
                if (unlock != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Opens ${longDate(unlock)} at ${clockTime(unlock)} (${opensIn(unlock)})',
                    style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Teaser on the envelope (optional)',
                  controller: _teaser,
                  hintText: 'e.g. Open on our anniversary',
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: _sealed ? 'Seal the capsule' : 'Send note',
                icon: _sealed ? Icons.lock_outline : Icons.send_outlined,
                onPressed: _send,
                isLoading: _sending,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
