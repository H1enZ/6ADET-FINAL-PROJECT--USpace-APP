import 'package:flutter/material.dart';

import '../models/memory.dart';
import '../services/auth_service.dart';
import '../services/memory_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../widgets/molecules/memory_card.dart';

/// One memory, full size. Either partner can favourite it; only the author
/// can delete it. Returns `true` when something changed so the list reloads.
class MemoryDetailScreen extends StatefulWidget {
  const MemoryDetailScreen({
    super.key,
    required this.memory,
    required this.authorName,
    required this.isMine,
  });

  final Memory memory;
  final String authorName;
  final bool isMine;

  @override
  State<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends State<MemoryDetailScreen> {
  late Memory _memory = widget.memory;
  bool _changed = false;
  bool _busy = false;

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleFavourite() async {
    setState(() => _busy = true);
    try {
      final value = await MemoryService.toggleFavorite(_memory.id);
      if (!mounted) return;
      setState(() {
        _memory = _memory.copyWith(isFavorite: value);
        _changed = true;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this memory?'),
        content: const Text(
            'It will be removed for both of you, with its photo. '
            'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
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
    final fav = _memory.isFavorite;

    return PopScope<Object?>(
      canPop: false,
      // Back button and browser back both return whether anything changed.
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Memory'),
          actions: [
            IconButton(
              tooltip: fav ? 'Remove from favourites' : 'Add to favourites',
              onPressed: _busy ? null : _toggleFavourite,
              icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                  color: fav ? scheme.primary : null),
            ),
            if (widget.isMine)
              IconButton(
                tooltip: 'Delete memory',
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              children: [
                if (_memory.photoUrl != null)
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: MemoryPhoto(url: _memory.photoUrl),
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_memory.caption, style: theme.textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${longDate(_memory.memoryDate)} \u00B7 added by ${widget.authorName}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
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
