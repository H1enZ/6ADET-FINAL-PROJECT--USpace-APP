import 'package:flutter/material.dart';

import '../models/memory.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../services/memory_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/filter_pill.dart';
import '../widgets/molecules/memory_card.dart';
import 'add_memory_sheet.dart';
import 'memory_detail_screen.dart';

/// Shared memories, newest first, filtered by year.
/// One column on a phone, two from 600 dp, three from 840 dp.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Memory> _memories = [];
  Map<String, String> _names = {};
  int? _year; // null means "All"
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
      final members = await CoupleService.members(_coupleId);
      final memories = await MemoryService.list(_coupleId);
      if (!mounted) return;
      setState(() {
        _names = {for (final m in members) m.userId: m.displayName};
        _memories = memories;
        if (_year != null && !_years.contains(_year)) _year = null;
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

  List<int> get _years {
    final years = {for (final m in _memories) m.memoryDate.year}.toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  List<Memory> get _visible => _year == null
      ? _memories
      : _memories.where((m) => m.memoryDate.year == _year).toList();

  String _authorName(Memory m) => m.authorId == widget.profile.userId
      ? 'you'
      : (_names[m.authorId] ?? 'your partner');

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _add() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AddMemorySheet(coupleId: _coupleId),
    );
    if (saved != true) return;
    await _load();
    if (!mounted) return;
    _showMessage('Memory saved');
  }

  void _replace(Memory updated) {
    _memories = [
      for (final m in _memories) m.id == updated.id ? updated : m,
    ];
  }

  Future<void> _toggleFavourite(Memory memory) async {
    // Update the heart straight away, then confirm with the database.
    setState(() => _replace(memory.copyWith(isFavorite: !memory.isFavorite)));
    try {
      final value = await MemoryService.toggleFavorite(memory.id);
      if (!mounted) return;
      setState(() => _replace(memory.copyWith(isFavorite: value)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _replace(memory));
      _showMessage(friendlyError(e));
    }
  }

  Future<void> _open(Memory memory) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MemoryDetailScreen(
          memory: memory,
          authorName: _authorName(memory),
          isMine: memory.authorId == widget.profile.userId,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Timeline')),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : _add,
        tooltip: 'Add a memory',
        shape: const CircleBorder(),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: LayoutBuilder(
                builder: (context, constraints) => CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (_error != null) _errorSliver(theme),
                    if (_years.isNotEmpty) _yearPills(),
                    if (_memories.isEmpty && _error == null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(onAdd: _add),
                      )
                    else
                      _grid(constraints.maxWidth),
                  ],
                ),
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
            Text(_error!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error)),
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

  Widget _yearPills() {
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
            for (final year in _years)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: FilterPill(
                  label: '$year',
                  selected: _year == year,
                  onTap: () => setState(() => _year = year),
                ),
              ),
            FilterPill(
              label: 'All',
              selected: _year == null,
              onTap: () => setState(() => _year = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(double width) {
    final columns = width >= AppSpacing.expandedMin
        ? 3
        : width >= AppSpacing.compactMax
            ? 2
            : 1;
    final layout =
        columns == 1 ? MemoryCardLayout.list : MemoryCardLayout.grid;
    const margin = AppSpacing.screenMargin;
    const gap = AppSpacing.lg;
    final cellWidth = (width - margin * 2 - gap * (columns - 1)) / columns;
    final aspect = columns == 1 ? 16 / 9 : 4 / 3;
    final visible = _visible;

    return SliverPadding(
      // Extra space at the bottom so the + button never covers a heart.
      padding: const EdgeInsets.fromLTRB(margin, AppSpacing.sm, margin, 96),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          mainAxisExtent: cellWidth / aspect + MemoryCard.footerHeight + 2,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final memory = visible[i];
            return MemoryCard(
              memory: memory,
              authorName: _authorName(memory),
              layout: layout,
              onTap: () => _open(memory),
              onFavourite: () => _toggleFavourite(memory),
            );
          },
          childCount: visible.length,
        ),
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
          Icon(Icons.photo_library_outlined,
              size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.lg),
          Text('No memories yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Start with the day you met, your first trip, or last weekend.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Add your first memory',
            icon: Icons.add,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
