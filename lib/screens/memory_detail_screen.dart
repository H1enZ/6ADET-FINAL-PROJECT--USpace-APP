import 'package:flutter/material.dart';

import '../models/memory.dart';
import '../services/auth_service.dart';
import '../services/memory_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../widgets/effects/floating_hearts.dart';
import '../widgets/molecules/memory_card.dart';
import '../widgets/effects/motion.dart';
import 'add_memory_sheet.dart';
import 'memory_tags_sheet.dart';

/// One memory, full size: swipe through its photos, read the story.
/// Either partner can favourite, tag or edit it; only the author can delete it.
/// Returns `true` when something changed so the list reloads.
class MemoryDetailScreen extends StatefulWidget {
  const MemoryDetailScreen({
    super.key,
    required this.memory,
    required this.authorName,
    required this.isMine,
    this.knownTags = const [],
  });

  final Memory memory;
  final String authorName;
  final bool isMine;

  /// Your own tags used on other memories, offered when tagging.
  final List<String> knownTags;

  @override
  State<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends State<MemoryDetailScreen> {
  late Memory _memory = widget.memory;
  final _pages = PageController();
  int _page = 0;
  bool _changed = false;
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _toggleFavourite() async {
    setState(() => _busy = true);
    try {
      final value = await MemoryService.toggleFavorite(_memory.id);
      if (!mounted) return;
      setState(() {
        _memory = _memory.copyWith(isFavorite: value);
        _changed = true;
      });
      if (value) showFloatingHearts(context);
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AddMemorySheet(
          coupleId: _memory.coupleId, memory: _memory, knownTags: widget.knownTags),
    );
    if (saved != true) return;
    try {
      final fresh = await MemoryService.get(_memory.id);
      if (!mounted) return;
      setState(() {
        _memory = fresh;
        _changed = true;
        _page = 0;
      });
      if (_pages.hasClients) _pages.jumpToPage(0);
      _showMessage('Changes saved');
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    }
  }

  Future<void> _retag() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => MemoryTagsSheet(memory: _memory, known: widget.knownTags),
    );
    if (saved != true) return;
    try {
      final fresh = await MemoryService.get(_memory.id);
      if (!mounted) return;
      setState(() {
        _memory = fresh;
        _changed = true;
      });
      _showMessage('Moved');
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this memory?'),
        content: const Text('It will be removed for both of you, with all its '
            'photos. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await MemoryService.delete(_memory);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final m = _memory;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Memory'),
          actions: [
            IconButton(
              tooltip: 'Move to a category',
              onPressed: _busy ? null : _retag,
              icon: const Icon(Icons.sell_outlined),
            ),
            IconButton(
              tooltip: m.isFavorite ? 'Remove from favorites' : 'Add to favorites',
              onPressed: _busy ? null : _toggleFavourite,
              icon: AnimatedHeartIcon(filled: m.isFavorite),
            ),
            // Both partners can edit; only the author can delete.
            IconButton(
              tooltip: 'Edit memory',
              onPressed: _busy ? null : _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
            if (widget.isMine) ...[
              IconButton(
                tooltip: 'Delete memory',
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              children: [
                if (m.photos.isNotEmpty) ...[
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: m.photos.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => MemoryPhoto(url: m.photos[i].url),
                    ),
                  ),
                  if (m.photos.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < m.photos.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _page ? 18 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _page ? scheme.primary : scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(longDate(m.memoryDate).toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(m.title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.sm),
                      if (m.location != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              Icon(Icons.place_outlined, size: 18, color: scheme.primary),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(child: Text(m.location!, style: muted)),
                            ],
                          ),
                        ),
                      if (m.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final t in m.tags)
                                ActionChip(
                                  label: Text(tagLabel(t)),
                                  onPressed: _busy ? null : _retag,
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ),
                      if (m.description != null)
                        Text(m.description!, style: theme.textTheme.bodyLarge)
                      else
                        Text('Tap ✏️ to add the story behind this memory.', style: muted),
                      const SizedBox(height: AppSpacing.xl),
                      Text('Added by ${widget.authorName}', style: muted),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
