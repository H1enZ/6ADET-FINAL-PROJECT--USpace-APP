import 'package:flutter/material.dart';

import '../models/important_date.dart';
import '../services/auth_service.dart';
import '../services/dates_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../widgets/atoms/app_text_field.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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

  void _showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

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
      _showMessage('Saved "${result.title}"');
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    }
  }

  Future<void> _delete(ImportantDate date) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this date?'),
        content: Text('"${date.title}" will be removed for both of you.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DatesService.delete(date.id);
      _changed = true;
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted =
        theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

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
          icon: const Icon(Icons.add),
          label: const Text('Add a date'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin,
                      AppSpacing.sm, AppSpacing.screenMargin, 96),
                  children: [
                    if (_error != null)
                      Text(_error!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: scheme.error)),
                    if (_dates.isEmpty && _error == null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.huge),
                        child: Text(
                          'Save the dates that matter to you both: your first '
                          'date, a trip, a monthsary. They will count down on Home.',
                          textAlign: TextAlign.center,
                          style: muted,
                        ),
                      ),
                    for (final d in _dates)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          foregroundColor: scheme.primary,
                          child: const Icon(Icons.event_outlined),
                        ),
                        title: Text(d.title, style: theme.textTheme.titleMedium),
                        subtitle: Text(
                          '${longDate(d.eventDate)}'
                          '${d.repeatsYearly ? ' \u00B7 every year' : ''}\n'
                          '${_countdown(d)}',
                          style: muted,
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'Remove',
                          onPressed: () => _delete(d),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
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
  if (days == 0) return 'Today! 🎉';
  if (days == 1) return 'Tomorrow';
  return 'In $days days';
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
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.event_outlined),
              label: Text(_date == null ? 'Choose the date' : longDate(_date!)),
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
