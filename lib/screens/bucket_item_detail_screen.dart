import 'package:flutter/material.dart';

import '../models/bucket_contribution.dart';
import '../models/bucket_item.dart';
import '../services/auth_service.dart';
import '../services/bucket_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../utils/money.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/app_text_field.dart';
import '../widgets/atoms/section_label.dart';
import '../widgets/effects/motion.dart';
import 'bucket_item_sheet.dart';

/// One bucket-list item: where, when, the budget and the savings log.
/// Both partners can log savings; each can delete only their own entries.
/// Returns `true` when something changed so the list reloads.
class BucketItemDetailScreen extends StatefulWidget {
  const BucketItemDetailScreen({
    super.key,
    required this.item,
    required this.myUserId,
    required this.names,
  });

  final BucketItem item;
  final String myUserId;

  /// user id -> display name, for "saved by".
  final Map<String, String> names;

  @override
  State<BucketItemDetailScreen> createState() => _BucketItemDetailScreenState();
}

class _BucketItemDetailScreenState extends State<BucketItemDetailScreen> {
  late BucketItem _item = widget.item;
  List<BucketContribution> _entries = [];
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
      final entries = await BucketService.contributions(_item.id);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _item = _item.withSaved(
            entries.fold<double>(0, (sum, e) => sum + e.amount));
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

  String _name(String userId) => userId == widget.myUserId
      ? 'you'
      : (widget.names[userId] ?? 'your partner');

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _edit() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => BucketItemSheet(coupleId: _item.coupleId, item: _item),
    );
    if (saved != true) return;
    try {
      final fresh = await BucketService.item(_item.id);
      if (!mounted) return;
      setState(() {
        _item = fresh;
        _changed = true;
      });
      _showMessage('Changes saved');
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    }
  }

  Future<void> _addSavings() async {
    final result = await showDialog<({double amount, String note, DateTime date})>(
      context: context,
      builder: (_) => const _AddSavingsDialog(),
    );
    if (result == null) return;
    try {
      await BucketService.addContribution(
        itemId: _item.id,
        coupleId: _item.coupleId,
        amount: result.amount,
        savedOn: result.date,
        note: result.note,
      );
      _changed = true;
      await _load();
      if (!mounted) return;
      _showMessage(_item.isFunded
          ? 'Goal reached! ${formatPeso(result.amount)} added.'
          : '${formatPeso(result.amount)} added to your savings');
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    }
  }

  Future<void> _deleteEntry(BucketContribution entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this entry?'),
        content: Text('${formatPeso(entry.amount)} on '
            '${longDate(entry.savedOn)} will be removed from the savings log.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await BucketService.deleteContribution(entry.id);
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
    final item = _item;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bucket list'),
          actions: [
            IconButton(
              tooltip: 'Edit item',
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _loading ? null : _addSavings,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          icon: const Icon(Icons.savings_outlined),
          label: const Text('Add savings'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.sm,
                  AppSpacing.screenMargin,
                  96,
                ),
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      decoration:
                          item.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (item.isDone) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text('Done together \u2713',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: scheme.tertiary)),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (item.locationLabel != null)
                    _InfoRow(icon: Icons.place_outlined, text: item.locationLabel!),
                  if (item.targetDate != null)
                    _InfoRow(
                      icon: Icons.event_outlined,
                      text: 'Target: ${longDate(item.targetDate!)}',
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  _SavingsCard(item: item),
                  const SizedBox(height: AppSpacing.xxl),
                  SectionLabel(
                    text: 'Savings log',
                    actionLabel: 'Add',
                    onAction: _loading ? null : _addSavings,
                  ),
                  if (_error != null) ...[
                    Text(_error!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.error)),
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton(
                        label: 'Try again',
                        variant: AppButtonVariant.outlined,
                        onPressed: _load,
                      ),
                    ),
                  ] else if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_entries.isEmpty)
                    Text(
                      'Nothing saved yet. Each time one of you puts money '
                      'aside for this, add it here.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    )
                  else
                    for (final entry in _entries)
                      _EntryTile(
                        entry: entry,
                        byName: _name(entry.authorId),
                        onDelete: entry.authorId == widget.myUserId
                            ? () => _deleteEntry(entry)
                            : null,
                      ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'USpace keeps a record of your savings. The money itself '
                    'stays wherever you keep it, like a bank or e-wallet '
                    'savings account.',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Saved so far against the budget, with a progress bar and the monthly
/// amount needed to reach it by the target date.
class _SavingsCard extends StatelessWidget {
  const _SavingsCard({required this.item});

  final BucketItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = item.progress;
    final monthly = item.monthlyNeeded();
    final muted =
        theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SAVED SO FAR',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.budget == null
                ? formatPeso(item.saved)
                : '${formatPeso(item.saved)} of ${formatPeso(item.budget!)}',
            style: theme.textTheme.titleLarge,
          ),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.chipBar),
              child: AnimatedProgressBar(
                value: progress,
                minHeight: 10,
                color: item.isFunded ? scheme.tertiary : scheme.primary,
                backgroundColor: scheme.primaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.isFunded
                  ? 'Goal reached \u2713'
                  : '${(progress * 100).floor()}% \u00B7 '
                      '${formatPeso(item.remaining!)} to go',
              style: item.isFunded
                  ? theme.textTheme.labelLarge?.copyWith(color: scheme.tertiary)
                  : muted,
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Text('No budget set. Edit the item to add one and track your '
                'progress.', style: muted),
          ],
          if (monthly != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Save about ${formatPeso(monthly.ceilToDouble())} a month to '
              'reach it by ${longDate(item.targetDate!)}.',
              style: muted,
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.byName,
    required this.onDelete,
  });

  final BucketContribution entry;
  final String byName;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final note = entry.note;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.primary,
        child: const Icon(Icons.savings_outlined, size: 20),
      ),
      title: Text(formatPeso(entry.amount), style: theme.textTheme.titleMedium),
      subtitle: Text(
        '${longDate(entry.savedOn)} \u00B7 by $byName'
        '${note == null ? '' : '\n$note'}',
        style:
            theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      isThreeLine: note != null,
      trailing: onDelete == null
          ? null
          : IconButton(
              tooltip: 'Remove entry',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
    );
  }
}

/// Amount, optional note and date. Closes with a record, or null on Cancel.
class _AddSavingsDialog extends StatefulWidget {
  const _AddSavingsDialog();

  @override
  State<_AddSavingsDialog> createState() => _AddSavingsDialogState();
}

class _AddSavingsDialogState extends State<_AddSavingsDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'When did you save it?',
    );
    if (!mounted || picked == null) return;
    setState(() => _date = picked);
  }

  void _save() {
    final amount = parsePeso(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Enter an amount, e.g. 500 or 1,250.50.');
      return;
    }
    Navigator.of(context).pop((amount: amount, note: _note.text, date: _date));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add savings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Amount (\u20B1)',
              controller: _amount,
              hintText: 'e.g. 500',
              prefixIcon: Icons.savings_outlined,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Note (optional)',
              controller: _note,
              hintText: 'e.g. From my allowance',
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined),
              label: Text('Saved on ${longDate(_date)}'),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Add')),
      ],
    );
  }
}
