import 'package:flutter/material.dart';

import '../models/memory.dart';
import '../services/auth_service.dart';
import '../services/memory_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../widgets/effects/floating_hearts.dart';
import '../widgets/molecules/memory_card.dart';
import '../widgets/effects/motion.dart';
import '../theme/app_effects.dart';
import '../widgets/molecules/us_confirm.dart';
import 'add_memory_sheet.dart';
import 'memory_tags_sheet.dart';
import '../widgets/atoms/us_icon.dart';
import '../widgets/molecules/us_states.dart';

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

  void _showMessage(String text, {bool error = false}) =>
      showUsMessage(context, text, error: error);

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
      _showMessage(friendlyError(e), error: true);
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
        coupleId: _memory.coupleId,
        memory: _memory,
        knownTags: widget.knownTags,
      ),
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
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e), error: true);
    }
  }

  Future<void> _retag() async {
    final saved = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => MemoryTagsSheet(memory: _memory, known: widget.knownTags),
    );
    if (saved == null) return;
    try {
      final fresh = await MemoryService.get(_memory.id);
      if (!mounted) return;
      setState(() {
        _memory = fresh;
        _changed = true;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e), error: true);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showUsConfirm(
      context,
      title: 'Delete this memory?',
      message:
          'It will be removed for both of you, with all its photos. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
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
      _showMessage(friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final m = _memory;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final still = motionOff(context);

    // One quiet line under the title: date, place, who added it.
    Widget meta(UsIconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UsIcon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: Text(text, style: muted)),
      ],
    );

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
              tooltip: m.isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
              onPressed: _busy ? null : _toggleFavourite,
              icon: AnimatedHeartIcon(filled: m.isFavorite),
            ),
            // Both partners can edit; only the author can delete.
            IconButton(
              tooltip: 'Edit memory',
              onPressed: _busy ? null : _edit,
              icon: const UsIcon(UsIcons.edit, size: 22),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              enabled: !_busy,
              icon: const UsIcon(UsIcons.more, size: 22),
              onSelected: (v) => v == 'delete' ? _delete() : _retag(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'tags',
                  child: Row(
                    children: [
                      const UsIcon(UsIcons.tag, size: 20),
                      const SizedBox(width: AppSpacing.md),
                      const Text('Change tags'),
                    ],
                  ),
                ),
                if (widget.isMine)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        UsIcon(UsIcons.trash, size: 20, color: scheme.error),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          'Delete memory',
                          style: TextStyle(color: scheme.error),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
              children: [
                if (m.photos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenMargin,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            PageView.builder(
                              controller: _pages,
                              itemCount: m.photos.length,
                              onPageChanged: (i) => setState(() => _page = i),
                              itemBuilder: (_, i) =>
                                  MemoryPhoto(url: m.photos[i].url),
                            ),
                            if (m.photos.length > 1)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: AppSpacing.sm,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (
                                          var i = 0;
                                          i < m.photos.length;
                                          i++
                                        )
                                          AnimatedContainer(
                                            duration: still
                                                ? Duration.zero
                                                : AppMotion.fade,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 2.5,
                                            ),
                                            width: i == _page ? 14 : 5,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: i == _page ? 1 : 0.55,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenMargin,
                    AppSpacing.xl,
                    AppSpacing.screenMargin,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          m.title,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.lg,
                        runSpacing: AppSpacing.xs,
                        children: [
                          meta(UsIcons.calendar, longDate(m.memoryDate)),
                          if (m.location != null)
                            meta(UsIcons.pin, m.location!),
                          meta(
                            UsIcons.profile,
                            'Added by ${widget.authorName}',
                          ),
                        ],
                      ),
                      if (m.tags.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final t in m.tags)
                              ActionChip(
                                avatar: UsIcon(
                                  tagIcon(t),
                                  size: 16,
                                  color: scheme.primary,
                                ),
                                label: Text(tagLabel(t)),
                                onPressed: _busy ? null : _retag,
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Divider(color: scheme.outline),
                      const SizedBox(height: AppSpacing.lg),
                      if (m.description != null)
                        Text(m.description!, style: theme.textTheme.bodyLarge)
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No story yet. What do you want to remember about this day?',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _edit,
                              icon: const UsIcon(UsIcons.edit, size: 18),
                              label: const Text('Add the story'),
                            ),
                          ],
                        ),
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
