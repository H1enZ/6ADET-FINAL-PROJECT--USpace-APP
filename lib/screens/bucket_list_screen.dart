import 'package:flutter/material.dart';

import '../models/bucket_item.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/bucket_service.dart';
import '../services/couple_service.dart';
import '../theme/app_effects.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/filter_pill.dart';
import '../utils/anniversary.dart';
import '../utils/money.dart';
import '../widgets/atoms/us_icon.dart';
import '../widgets/effects/motion.dart';
import '../widgets/molecules/us_confirm.dart';
import 'bucket_item_detail_screen.dart';
import 'bucket_item_sheet.dart';
import '../widgets/molecules/us_states.dart';
import '../services/couple_sync.dart';

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

  CoupleSyncHandle? _live;

  @override
  void initState() {
    super.initState();
    _load();
    // Goals and savings your partner adds, edits, completes or removes.
    try {
      _live = CoupleSync.listen(_coupleId, const {'bucket_items', 'bucket_contributions'}, () {
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

  void _showMessage(String text, {bool error = false}) =>
      showUsMessage(context, text, error: error);

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
    if (newValue) showConfetti(context); // ticked off together

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
      _showMessage(friendlyError(e), error: true);
    }
  }

  Future<void> _delete(BucketItem item) async {
    final confirmed = await showUsConfirm(
      context,
      title: 'Delete this goal?',
      message: '"${item.title}" will be removed from your shared list, '
          'with its savings log.',
      confirmLabel: 'Delete',
      destructive: true,
    );

    if (!confirmed) return;

    try {
      await BucketService.delete(item.id);
      if (!mounted) return;
      setState(() {
        _items = _items.where((current) => current.id != item.id).toList();
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Bucket List')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-bucket-list',
        onPressed: _loading ? null : _add,
        tooltip: 'Add bucket-list item',
        shape: const CircleBorder(),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const UsIcon(UsIcons.plus, size: 26),
      ),
      body: _loading
          ? const SkeletonList()
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
        child: UsErrorNotice(message: _error!, onRetry: _load),
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
                child: UsIcon(
                  UsIcons.trash,
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
    return UsEmptyState(
      icon: UsIcons.star,
      title: 'Nothing on your list yet',
      message: 'Add something you both want to experience together.',
      actionLabel: 'Add your first goal',
      actionIcon: UsIcons.plus,
      onAction: onAdd,
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    final done = filter == 'Done';
    return UsEmptyState(
      icon: done ? UsIcons.check : UsIcons.star,
      title: done ? 'Nothing completed yet' : 'Everything is done',
      message: done
          ? 'Goals you finish together will show up here.'
          : 'You have no unfinished goals right now.',
    );
  }
}

/// One goal as a soft card: a round tick to mark it done together, then
/// its title, where and when, and a slim savings bar when there is a budget.
/// Tap anywhere else to open it.
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
    final done = item.isDone;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final progress = item.progress;
    final location = item.locationLabel;
    final meta = [
      ?location,
      if (item.targetDate != null) longDate(item.targetDate!),
    ].join(' \u00B7 ');

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A round tick, 48 px to tap.
            Semantics(
              button: true,
              checked: done,
              label: done ? 'Mark as not done' : 'Mark as done together',
              excludeSemantics: true,
              child: InkResponse(
                onTap: onToggle,
                radius: 24,
                child: SizedBox.square(
                  dimension: AppSpacing.touchTarget,
                  child: Center(
                    child: AnimatedContainer(
                      duration: motionOff(context)
                          ? Duration.zero
                          : AppMotion.quick,
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? scheme.tertiary : Colors.transparent,
                        border: Border.all(
                          color: done ? scheme.tertiary : scheme.outline,
                          width: 1.6,
                        ),
                      ),
                      child: done
                          ? Center(
                              child: UsIcon(
                                UsIcons.check,
                                size: 14,
                                color: scheme.onTertiary,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: AnimatedOpacity(
                  opacity: done ? 0.7 : 1,
                  duration: motionOff(context) ? Duration.zero : AppMotion.quick,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: theme.textTheme.titleMedium),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (location != null) ...[
                              UsIcon(
                                UsIcons.pin,
                                size: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (done) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Done together',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.tertiary,
                          ),
                        ),
                      ] else if (progress != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: AnimatedProgressBar(
                            value: progress,
                            minHeight: 5,
                            color: item.isFunded
                                ? scheme.tertiary
                                : scheme.primary,
                            backgroundColor: scheme.primary.withValues(
                              alpha: 0.14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
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
            ),
          ],
        ),
      ),
    );
  }
}
