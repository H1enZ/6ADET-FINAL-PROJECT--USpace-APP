import 'package:flutter/material.dart';

import '../models/memory.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../services/memory_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/filter_pill.dart';
import '../widgets/effects/floating_hearts.dart';
import '../widgets/molecules/memory_card.dart';
import '../widgets/effects/motion.dart';
import 'add_memory_sheet.dart';
import 'memory_detail_screen.dart';
import 'memory_tags_sheet.dart';

/// Filter keys: everything, favourites, or one tag.
const _all = '\u0000all';
const _favourites = '\u0000fav';

/// The couple's story as a vertical scrapbook, from the beginning to now
/// (or newest first). Filter by favorites or tags; tap a memory to open it.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Memory> _memories = [];
  Map<String, String> _names = {};
  String _filter = _all;
  bool _searching = false;
  final _search = TextEditingController();
  bool _oldestFirst = true;
  bool _loading = true;
  String? _error;

  String get _coupleId => widget.profile.coupleId!;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Every tag in use, built-ins first in their usual order, then your own
  /// alphabetically, with how many memories have each.
  List<(String, int)> get _tagsInUse {
    final counts = <String, int>{};
    for (final m in _memories) {
      for (final t in m.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final builtIn = [
      for (final t in MemoryTag.values)
        if (counts.containsKey(t.dbName)) (t.dbName, counts[t.dbName]!),
    ];
    final own = counts.entries
        .where((e) => MemoryTag.fromDb(e.key) == null)
        .map((e) => (e.key, e.value))
        .toList()
      ..sort((a, b) => a.$1.toLowerCase().compareTo(b.$1.toLowerCase()));
    return [...builtIn, ...own];
  }

  /// Your own tags (not built-ins), offered as chips when tagging.
  List<String> get _knownTags => [
        for (final t in _tagsInUse)
          if (MemoryTag.fromDb(t.$1) == null) t.$1,
      ];

  /// The filter in use, falling back to "All memories" when the chosen
  /// category no longer has any memories (so the page is never blank).
  String get _activeFilter {
    if (_filter == _all || _filter == _favourites) return _filter;
    return _memories.any((m) => m.tags.contains(_filter)) ? _filter : _all;
  }

  bool _matches(Memory m) {
    final passesFilter = switch (_activeFilter) {
      _all => true,
      _favourites => m.isFavorite,
      final tag => m.tags.contains(tag),
    };
    if (!passesFilter) return false;
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      m.title,
      m.description ?? '',
      m.location ?? '',
      for (final t in m.tags) tagLabel(t),
    ].any((field) => field.toLowerCase().contains(q));
  }

  Future<void> _load() async {
    try {
      final members = await CoupleService.members(_coupleId);
      final memories = await MemoryService.list(_coupleId);
      if (!mounted) return;
      setState(() {
        _names = {for (final m in members) m.userId: m.displayName};
        _memories = memories;
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

  List<Memory> get _visible {
    final list = _memories.where(_matches).toList();
    list.sort((a, b) => _oldestFirst
        ? a.memoryDate.compareTo(b.memoryDate)
        : b.memoryDate.compareTo(a.memoryDate));
    return list;
  }

  String _authorName(Memory m) => m.authorId == widget.profile.userId
      ? 'you'
      : (_names[m.authorId] ?? 'your partner');

  void _showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _add() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AddMemorySheet(coupleId: _coupleId, knownTags: _knownTags),
    );
    if (saved != true) return;
    await _load();
    if (!mounted) return;
    showFloatingHearts(context);
    _showMessage('Memory saved');
  }

  void _replace(Memory updated) {
    _memories = [for (final m in _memories) m.id == updated.id ? updated : m];
  }

  Future<void> _toggleFavourite(Memory memory) async {
    final willLove = !memory.isFavorite;
    setState(() => _replace(memory.copyWith(isFavorite: willLove)));
    if (willLove) showFloatingHearts(context);
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
          knownTags: _knownTags,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _retag(Memory memory) async {
    final saved = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => MemoryTagsSheet(memory: memory, known: _knownTags),
    );
    if (saved == null) return;
    await _load();
    if (!mounted) return;
    // Point to the category it just went into, with a button to go there.
    final added = saved.where((t) => !memory.tags.contains(t)).toList();
    final target = added.isNotEmpty ? added.last : (saved.isNotEmpty ? saved.last : null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(target == null
          ? 'Removed from all categories'
          : 'Moved to ${tagLabel(target)}'),
      action: target == null
          ? null
          : SnackBarAction(label: 'Show', onPressed: () => setState(() => _filter = target)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = _visible;

    // Build the rows: a year label whenever the year changes, then memories.
    final rows = <Widget>[];
    int? year;
    for (var i = 0; i < visible.length; i++) {
      final m = visible[i];
      if (m.memoryDate.year != year) {
        year = m.memoryDate.year;
        rows.add(_YearMarker(year: year));
      }
      rows.add(_TimelineEntry(
        memory: m,
        authorName: _authorName(m),
        tiltLeft: i.isEven,
        isLast: i == visible.length - 1,
        onTap: () => _open(m),
        onFavourite: () => _toggleFavourite(m),
        onRetag: () => _retag(m),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Our timeline'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Type to filter',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
            icon: Icon(_searching ? Icons.search_off : Icons.search),
          ),
          IconButton(
            tooltip: _oldestFirst ? 'Showing oldest first' : 'Showing newest first',
            onPressed: () => setState(() => _oldestFirst = !_oldestFirst),
            icon: Icon(_oldestFirst ? Icons.arrow_downward : Icons.arrow_upward),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : _add,
        tooltip: 'Add a memory',
        shape: const CircleBorder(),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const SkeletonList()
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.screenMargin),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_error!,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: scheme.error)),
                            const SizedBox(height: AppSpacing.md),
                            AppButton(
                                label: 'Try again',
                                variant: AppButtonVariant.outlined,
                                onPressed: _load),
                          ],
                        ),
                      ),
                    ),
                  if (_searching)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin,
                            AppSpacing.xs, AppSpacing.screenMargin, AppSpacing.xs),
                        child: TextField(
                          controller: _search,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Type to filter: title, story, place or tag',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear',
                                    onPressed: _search.clear,
                                    icon: const Icon(Icons.close),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  if (_memories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenMargin,
                            vertical: AppSpacing.xs),
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final f in [
                              (_all, 'All memories', _memories.length),
                              (_favourites, 'Favorites',
                                  _memories.where((m) => m.isFavorite).length),
                              for (final t in _tagsInUse) (t.$1, tagLabel(t.$1), t.$2),
                            ])
                              FilterPill(
                                label: f.$2,
                                selected: _activeFilter == f.$1,
                                count: f.$3,
                                onTap: () => setState(() => _filter = f.$1),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (_memories.isEmpty && _error == null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyTimeline(onAdd: _add),
                    )
                  else if (visible.isEmpty && _error == null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.huge),
                          child: Text(
                            _search.text.trim().isNotEmpty
                                ? 'Nothing matches "${_search.text.trim()}".'
                                : 'No memories here yet. Tap 🏷️ on a memory to move it '
                                    'into a category, or ❤️ to make it a favorite.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.sm, AppSpacing.screenMargin, 96),
                      sliver: SliverList(delegate: SliverChildListDelegate(rows)),
                    ),
                ],
              ),
            ),
    );
  }
}

/// The year, sitting on the timeline's line.
class _YearMarker extends StatelessWidget {
  const _YearMarker({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                    child: Icon(Icons.favorite, size: 18, color: scheme.onPrimary),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('$year', style: theme.textTheme.titleLarge?.copyWith(color: scheme.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One memory on the timeline: the line and a heart on the left, the
/// scrapbook card on the right. Fades in gently when it first appears.
class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.memory,
    required this.authorName,
    required this.tiltLeft,
    required this.isLast,
    required this.onTap,
    required this.onFavourite,
    required this.onRetag,
  });

  final Memory memory;
  final String authorName;
  final bool tiltLeft;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onFavourite;
  final VoidCallback onRetag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final m = memory;
    final still = MediaQuery.of(context).disableAnimations;

    final card = Material(
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (m.photos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Transform.rotate(
                    // a slight tilt, like a photo taped into a scrapbook
                    angle: still ? 0 : (tiltLeft ? -0.015 : 0.015),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            MemoryPhoto(url: m.photoUrl),
                            if (m.photos.length > 1)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('📷 ${m.photos.length}',
                                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Text(longDate(m.memoryDate).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary)),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(m.title, style: theme.textTheme.titleMedium)),
                  IconButton(
                    tooltip: 'Move to a category',
                    visualDensity: VisualDensity.compact,
                    onPressed: onRetag,
                    icon: Icon(Icons.sell_outlined, color: scheme.onSurfaceVariant),
                  ),
                  IconButton(
                    tooltip: m.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                    visualDensity: VisualDensity.compact,
                    onPressed: onFavourite,
                    icon: AnimatedHeartIcon(
                        filled: m.isFavorite, emptyColor: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              if (m.location != null)
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 16, color: scheme.primary),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(m.location!, style: muted)),
                  ],
                ),
              if (m.description != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(m.description!,
                    maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
              ],
              if (m.tags.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final t in m.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(tagLabel(t),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: scheme.onPrimaryContainer)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text('Added by $authorName', style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );

    final row = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // the line, with a heart where this memory sits
              SizedBox(
                width: 48,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: 0,
                      bottom: isLast ? null : 0,
                      height: isLast ? 28 : null,
                      child: Container(width: 2, color: scheme.primaryContainer),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: AnimatedHeartIcon(
                        filled: m.isFavorite,
                        size: 20,
                        emptyColor: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: card,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (still) return row;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
      ),
      child: row,
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const ideas = [
      '💕 The day you first met',
      '☕ Your first date',
      '📸 Your first picture together',
      '✈️ Your favourite trip',
      '✨ A random day that became special',
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined, size: 56, color: scheme.primary),
            const SizedBox(height: AppSpacing.lg),
            Text('Your story starts here', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text('Add the moments you never want to forget. Some ideas:',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.md),
            for (final idea in ideas)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(idea, style: theme.textTheme.bodyMedium),
              ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: 'Add your first memory', icon: Icons.add, onPressed: onAdd),
          ],
        ),
      ),
    );
  }
}
