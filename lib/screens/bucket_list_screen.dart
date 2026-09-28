import 'package:flutter/material.dart';

import '../models/bucket_item.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/bucket_service.dart';
import '../services/couple_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/filter_pill.dart';
import '../utils/anniversary.dart';
import '../utils/money.dart';
import 'bucket_item_detail_screen.dart';
import 'bucket_item_sheet.dart';

/// Shared bucket list for the paired couple.
class BucketListScreen extends StatefulWidget {
  const BucketListScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<BucketListScreen> createState() => _BucketListScreenState();
}

class _BucketListScreenState extends State<BucketListScreen> {
  List<BucketItem> _items = [];
  Map<String, String> _names = {};
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
      final members = await CoupleService.members(_coupleId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _names = {for (final m in members) m.userId: m.displayName};
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
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => BucketItemSheet(coupleId: _coupleId),
    );
    if (saved != true) return;
    await _load();
    if (!mounted) return;
    _showMessage('Added to your bucket list');
  }

  Future<void> _open(BucketItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BucketItemDetailScreen(
          item: item,
          myUserId: widget.profile.userId,
          names: _names,
        ),
      ),
    );
    if (changed == true) await _load();
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
        content: Text(
          '"${item.title}" will be removed from the shared list, '
          'with its savings log.',
        ),
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
                child: _BucketRow(
                  item: item,
                  onToggle: () => _toggle(item),
                  onOpen: () => _open(item),
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

/// One row: checkbox to tick it done, and tap anywhere else to open it.
/// Shows where, when, and savings progress when there is a budget.
class _BucketRow extends StatelessWidget {
  const _BucketRow({
    required this.item,
    required this.onToggle,
    required this.onOpen,
  });

  final BucketItem item;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted =
        theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final progress = item.progress;
    final location = item.locationLabel;

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: item.isDone,
              onChanged: (_) => onToggle(),
              activeColor: scheme.tertiary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration:
                            item.isDone ? TextDecoration.lineThrough : null,
                        color: item.isDone ? scheme.tertiary : null,
                      ),
                    ),
                    if (location != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 16, color: scheme.primary),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: muted),
                          ),
                        ],
                      ),
                    ],
                    if (item.targetDate != null) ...[
                      const SizedBox(height: 2),
                      Text('Target: ${longDate(item.targetDate!)}',
                          style: muted),
                    ],
                    if (progress != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.chipBar),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          color: item.isFunded
                              ? scheme.tertiary
                              : scheme.primary,
                          backgroundColor: scheme.primaryContainer,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${formatPeso(item.saved)} of '
                        '${formatPeso(item.budget!)} saved',
                        style: muted,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
