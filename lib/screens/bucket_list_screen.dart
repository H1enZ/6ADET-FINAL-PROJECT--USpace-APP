import 'package:flutter/material.dart';

import '../models/bucket_item.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/bucket_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/app_text_field.dart';
import '../widgets/atoms/filter_pill.dart';
import '../utils/anniversary.dart';

/// Shared bucket list for the paired couple.
class BucketListScreen extends StatefulWidget {
  const BucketListScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<BucketListScreen> createState() => _BucketListScreenState();
}

class _BucketListScreenState extends State<BucketListScreen> {
  List<BucketItem> _items = [];
  String _filter = 'To do';
  bool _loading = true;
  String? _error;

  String get _coupleId => widget.profile.coupleId!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await BucketService.list(_coupleId);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  List<BucketItem> get _visible {
    switch (_filter) {
      case 'Done':
        return _items.where((item) => item.isDone).toList();
      case 'All':
        return _items;
      default:
        return _items.where((item) => !item.isDone).toList();
    }
  }

  int get _todoCount => _items.where((item) => !item.isDone).length;
  int get _doneCount => _items.where((item) => item.isDone).length;

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _add() async {
    final result = await showDialog<({String title, DateTime? targetDate})>(
      context: context,
      builder: (_) => const _AddBucketItemDialog(),
    );
    if (result == null) return;

    try {
      await BucketService.add(
        coupleId: _coupleId,
        title: result.title,
        targetDate: result.targetDate,
      );
      await _load();
      if (!mounted) return;
      _showMessage('Added to your bucket list');
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    }
  }

  Future<void> _toggle(BucketItem item) async {
    final newValue = !item.isDone;

    // Update the screen first so the checkbox feels instant.
    setState(() {
      _items = [
        for (final current in _items)
          current.id == item.id ? current.withDone(newValue) : current,
      ];
    });

    try {
      await BucketService.setDone(item.id, newValue);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = [
          for (final current in _items)
            current.id == item.id ? item : current,
        ];
      });
      _showMessage(friendlyError(e));
    }
  }

  Future<void> _delete(BucketItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('"${item.title}" will be removed from the shared list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await BucketService.delete(item.id);
      if (!mounted) return;
      setState(() {
        _items = _items.where((current) => current.id != item.id).toList();
      });
      _showMessage('Bucket-list item deleted');
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Bucket List')),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : _add,
        tooltip: 'Add bucket-list item',
        shape: const CircleBorder(),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (_error != null) _errorSliver(theme),
                  _filterPills(),
                  if (_items.isEmpty && _error == null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(onAdd: _add),
                    )
                  else if (_visible.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _FilteredEmptyState(filter: _filter),
                    )
                  else
                    _itemList(),
                ],
              ),
            ),
    );
  }

  Widget _errorSliver(ThemeData theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Try again',
              variant: AppButtonVariant.outlined,
              onPressed: _load,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterPills() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: AppSpacing.touchTarget + AppSpacing.sm,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.xs,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilterPill(
                label: 'To do',
                count: _todoCount,
                selected: _filter == 'To do',
                onTap: () => setState(() => _filter = 'To do'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilterPill(
                label: 'Done',
                count: _doneCount,
                selected: _filter == 'Done',
                onTap: () => setState(() => _filter = 'Done'),
              ),
            ),
            FilterPill(
              label: 'All',
              count: _items.length,
              selected: _filter == 'All',
              onTap: () => setState(() => _filter = 'All'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemList() {
    final visible = _visible;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.sm,
        AppSpacing.screenMargin,
        96,
      ),
      sliver: SliverList.builder(
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final item = visible[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Dismissible(
              key: ValueKey(item.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                await _delete(item);
                return false;
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: CheckboxListTile(
                  value: item.isDone,
                  onChanged: (_) => _toggle(item),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    item.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          decoration:
                              item.isDone ? TextDecoration.lineThrough : null,
                          color: item.isDone
                              ? Theme.of(context).colorScheme.tertiary
                              : null,
                        ),
                  ),
                  subtitle: item.targetDate == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Target: ${longDate(item.targetDate!)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.huge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Nothing on your list yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Add something you both want to experience together.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Add your first goal',
            icon: Icons.add,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Text(
          filter == 'Done'
              ? 'Nothing has been completed yet.'
              : 'You have no unfinished items.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

/// The Add dialog. It is its own StatefulWidget so it owns the text
/// controller and disposes it only when the dialog is really gone
/// (not while it is still animating closed).
class _AddBucketItemDialog extends StatefulWidget {
  const _AddBucketItemDialog();

  @override
  State<_AddBucketItemDialog> createState() => _AddBucketItemDialogState();
}

class _AddBucketItemDialogState extends State<_AddBucketItemDialog> {
  final _title = TextEditingController();
  DateTime? _targetDate;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: now,
      lastDate: DateTime(2100),
      helpText: 'When do you want to do it?',
    );
    if (!mounted || picked == null) return;
    setState(() => _targetDate = picked);
  }

  /// Save is always tappable; an empty title shows a message instead.
  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Write what you want to do together.');
      return;
    }
    Navigator.of(context).pop((title: title, targetDate: _targetDate));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add to bucket list'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'What do you want to do together?',
              controller: _title,
              hintText: 'e.g. Visit Japan',
              prefixIcon: Icons.favorite_border,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'TARGET DATE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                _targetDate == null
                    ? 'Choose a date (optional)'
                    : longDate(_targetDate!),
              ),
            ),
            if (_targetDate != null)
              TextButton(
                onPressed: () => setState(() => _targetDate = null),
                child: const Text('Remove date'),
              ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
