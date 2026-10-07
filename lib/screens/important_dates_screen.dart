import 'package:flutter/material.dart';

import '../models/important_date.dart';
import '../services/auth_service.dart';
import '../services/dates_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../widgets/atoms/app_text_field.dart';
import '../widgets/atoms/us_icon.dart';
import '../widgets/molecules/us_confirm.dart';
import '../widgets/molecules/us_field_button.dart';
import '../widgets/molecules/us_states.dart';
import '../widgets/effects/motion.dart';
import '../services/couple_sync.dart';

/// All the couple's special dates, soonest first. Either partner can add or
/// remove them. Returns `true` when something changed.
class ImportantDatesScreen extends StatefulWidget {
  const ImportantDatesScreen({super.key, required this.coupleId});

  final String coupleId;

  @override
  State<ImportantDatesScreen> createState() => _ImportantDatesScreenState();
}

class _ImportantDatesScreenState extends State<ImportantDatesScreen> {
  List<ImportantDate> _dates = [];
  bool _loading = true;
  bool _changed = false;
  String? _error;

  CoupleSyncHandle? _live;

  @override
  void initState() {
    super.initState();
    _load();
    // Dates your partner adds, edits or removes.
    try {
      _live = CoupleSync.listen(widget.coupleId, const {'important_dates'}, () {
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
      final dates = await DatesService.list(widget.coupleId);
      if (!mounted) return;
      setState(() {
        _dates = dates;
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

  void _showMessage(String text, {bool error = false}) =>
      showUsMessage(context, text, error: error);

  Future<void> _add() async {
    final result = await showDialog<({String title, DateTime date, bool yearly})>(
      context: context,
      builder: (_) => const _AddDateDialog(),
    );
    if (result == null) return;
    try {
      await DatesService.add(
        coupleId: widget.coupleId,
        title: result.title,
        date: result.date,
        repeatsYearly: result.yearly,
      );
      _changed = true;
      await _load();
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e), error: true);
    }
  }

  Future<void> _delete(ImportantDate date) async {
    final ok = await showUsConfirm(
      context,
      title: 'Remove this date?',
      message: '"${date.title}" will be removed for both of you.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    try {
      await DatesService.delete(date.id);
      _changed = true;
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Special dates')),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab-important-dates',
          onPressed: _loading ? null : _add,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          icon: const UsIcon(UsIcons.plus, size: 20),
          label: const Text('Add a date'),
        ),
        body: _loading
            ? const SkeletonList(count: 5, height: 72)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin,
                      AppSpacing.sm, AppSpacing.screenMargin, 96),
                  children: [
                    if (_error != null) ...[
                      UsErrorNotice(message: _error!, onRetry: _load),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (_dates.isEmpty && _error == null)
                      const UsEmptyState(
                        icon: UsIcons.calendar,
                        title: 'No special dates yet',
                        message:
                            'Save the dates that matter to you both: your first '
                            'date, a trip, a monthsary. They will count down on Home.',
                      ),
                    for (final d in _dates)
                      _DateCard(date: d, onRemove: () => _delete(d)),
                  ],
                ),
              ),
      ),
    );
  }
}

String _countdown(ImportantDate d) {
  final days = d.daysUntil();
  if (days == null) return 'Passed';
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return 'In $days days';
}

/// One special date: a soft card with the calendar mark, its name, the date
/// (and "every year"), and how far away it is.
class _DateCard extends StatelessWidget {
  const _DateCard({required this.date, required this.onRemove});

  final ImportantDate date;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final soon = (date.daysUntil() ?? 999) <= 7;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: UsIcon(UsIcons.calendar, size: 20, color: scheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${longDate(date.eventDate)}'
                    '${date.repeatsYearly ? ' \u00B7 every year' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _countdown(date),
              style: theme.textTheme.labelMedium?.copyWith(
                color: soon ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed: onRemove,
              icon: UsIcon(
                UsIcons.trash,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddDateDialog extends StatefulWidget {
  const _AddDateDialog();

  @override
  State<_AddDateDialog> createState() => _AddDateDialogState();
}

class _AddDateDialogState extends State<_AddDateDialog> {
  final _title = TextEditingController();
  DateTime? _date;
  bool _yearly = true;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 10),
    );
    if (!mounted || picked == null) return;
    setState(() => _date = picked);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the date a name.');
      return;
    }
    if (_date == null) {
      setState(() => _error = 'Choose the date.');
      return;
    }
    Navigator.of(context).pop((title: title, date: _date!, yearly: _yearly));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add a special date'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'What is it?',
              controller: _title,
              hintText: 'e.g. Our first date',
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.md),
            UsFieldButton(
              label: 'Date',
              value: _date == null ? 'Choose the date' : longDate(_date!),
              icon: UsIcons.calendar,
              onTap: _pick,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _yearly,
              onChanged: (v) => setState(() => _yearly = v),
              title: const Text('Every year'),
            ),
            if (_error != null)
              Text(_error!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
