import 'package:flutter/material.dart';

import '../../models/therabot.dart';
import '../../services/therabot_service.dart';
import '../../theme/app_spacing.dart';
import '../../utils/daily_content.dart';
import '../../widgets/effects/motion.dart';
import '../../widgets/therabot/therabot_widgets.dart';
import 'shared_reflection_view.dart';

/// Past reflections: date, title, the shared reflection and both choices.
/// Never anyone's private answers or summaries (those are gone after 24
/// hours). Hiding is just for you; deleting needs both of you.
class TherabotHistoryScreen extends StatefulWidget {
  const TherabotHistoryScreen({
    super.key,
    required this.partnerName,
    this.myUsername,
    this.partnerUsername,
  });

  final String partnerName;

  /// Display only: shown in place of "Partner 1" / "Partner 2".
  final String? myUsername;
  final String? partnerUsername;

  @override
  State<TherabotHistoryScreen> createState() => _TherabotHistoryScreenState();
}

class _TherabotHistoryScreenState extends State<TherabotHistoryScreen> {
  List<TherabotHistoryEntry> _entries = const [];
  bool _showHidden = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Bumped on every load, so an older, slower load (say, from toggling
  /// "show hidden" twice) never overwrites a newer one.
  int _generation = 0;

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final entries = await TherabotService.history(includeHidden: _showHidden);
      if (!mounted || generation != _generation) return;
      setState(() {
        _entries = entries;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = therabotError(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _act(Future<void> Function() action, String done) async {
    try {
      await action();
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      therabotToast(context, therabotError(e).message);
    }
    await _load();
  }

  Future<void> _requestDelete(TherabotHistoryEntry e) async {
    final both = e.partnerRequestedDelete;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(both ? 'Delete for both of you?' : 'Ask to delete this?'),
        content: Text(
          both
              ? '${widget.partnerName} already asked to delete it. It will be gone for good, for both of you.'
              : "It is deleted for good only when ${widget.partnerName} agrees too. Until then it stays, "
                    'and you can change your mind.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(both ? 'Delete' : 'Ask to delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await TherabotService.requestDelete(e.sessionId, true);
      if (!mounted) return;
    } catch (err) {
      if (!mounted) return;
      therabotToast(context, therabotError(err).message);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return TherabotPage(
      title: 'Past reflections',
      onRefresh: _load,
      actions: [
        IconButton(
          tooltip: _showHidden
              ? 'Hide hidden reflections'
              : 'Show hidden reflections',
          icon: Icon(
            _showHidden ? Icons.visibility : Icons.visibility_off_outlined,
          ),
          onPressed: () {
            setState(() => _showHidden = !_showHidden);
            _load();
          },
        ),
      ],
      children: [
        if (_loading)
          const SizedBox(height: 480, child: SkeletonList(count: 3))
        else if (_error != null)
          TherabotErrorView(message: _error!, onRetry: _load)
        else if (_entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.huge),
            child: Text(
              _showHidden
                  ? 'No past reflections yet.'
                  : 'No past reflections yet. Finished reflections appear here.',
              textAlign: TextAlign.center,
              style: muted,
            ),
          )
        else ...[
          const PrivacyNote(
            'Only shared reflections are kept here. Private answers and summaries are never saved.',
          ),
          const SizedBox(height: AppSpacing.lg),
          ...staggered([
            for (final e in _entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _HistoryCard(
                  entry: e,
                  partnerName: widget.partnerName,
                  names: TherabotNames(
                    myPartnerNumber: e.myPartnerNumber,
                    myName: widget.myUsername,
                    partnerName: widget.partnerUsername,
                  ),
                  onHide: (hide) => _act(
                    () => TherabotService.setHidden(e.sessionId, hide),
                    hide
                        ? 'Hidden from your history'
                        : 'Shown in your history again',
                  ),
                  onRequestDelete: () => _requestDelete(e),
                  onCancelDelete: () => _act(
                    () => TherabotService.requestDelete(e.sessionId, false),
                    'Delete request withdrawn',
                  ),
                ),
              ),
          ]),
        ],
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entry,
    required this.partnerName,
    required this.names,
    required this.onHide,
    required this.onRequestDelete,
    required this.onCancelDelete,
  });

  final TherabotHistoryEntry entry;
  final String partnerName;
  final TherabotNames names;
  final ValueChanged<bool> onHide;
  final VoidCallback onRequestDelete;
  final VoidCallback onCancelDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final e = entry;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    // When it was finished (falls back to when it started).
    final when = e.completedAt ?? e.createdAt;
    final date = when.year == DateTime.now().year
        ? fullDate(when)
        : '${fullDate(when)} ${when.year}';

    String choice(TherabotChoice? c) =>
        c == null ? "Didn't choose" : '${c.emoji} ${c.label}';

    return TherabotCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title ?? 'Our reflection',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    // Everything here is completed, so only "hidden" is
                    // worth saying, and it sits under the title to leave
                    // the title room at large text sizes.
                    Text(
                      e.isHidden ? '$date · hidden' : date,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Options',
                onSelected: (v) => switch (v) {
                  'hide' => onHide(true),
                  'show' => onHide(false),
                  'delete' => onRequestDelete(),
                  'cancel' => onCancelDelete(),
                  _ => null,
                },
                itemBuilder: (_) => [
                  if (e.isHidden)
                    const PopupMenuItem(
                      value: 'show',
                      child: Text('Show in my history'),
                    )
                  else
                    const PopupMenuItem(
                      value: 'hide',
                      child: Text('Hide from my history'),
                    ),
                  if (e.iRequestedDelete)
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Withdraw delete request'),
                    )
                  else
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        e.partnerRequestedDelete
                            ? 'Delete for both of us'
                            : 'Ask to delete',
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'You: ${choice(e.myChoice)}  ·  $partnerName: ${choice(e.partnerChoice)}',
            style: muted,
          ),
          if (e.iRequestedDelete || e.partnerRequestedDelete) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              e.iRequestedDelete
                  ? 'You asked to delete this. Waiting for $partnerName.'
                  : '$partnerName asked to delete this. It is deleted only if you agree.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
          ],
          if (e.reflection != null)
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: AppSpacing.sm),
                title: Text(
                  'Read the shared reflection',
                  style: theme.textTheme.labelLarge,
                ),
                children: [
                  SharedReflectionView(
                    reflection: e.reflection!,
                    names: names,
                    animate: false,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Your saved insights. Only you can see them; delete any time.
class TherabotInsightsScreen extends StatefulWidget {
  const TherabotInsightsScreen({super.key});

  @override
  State<TherabotInsightsScreen> createState() => _TherabotInsightsScreenState();
}

class _TherabotInsightsScreenState extends State<TherabotInsightsScreen> {
  List<({String id, String body, DateTime createdAt})> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await TherabotService.insights();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = therabotError(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this insight?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await TherabotService.deleteInsight(id);
    } catch (e) {
      if (!mounted) return;
      therabotToast(context, therabotError(e).message);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return TherabotPage(
      title: 'My insights',
      onRefresh: _load,
      children: [
        const PrivacyNote(
          'Only you can see these. Therabot may gently use them in your own future summaries.',
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_loading)
          const SizedBox(height: 300, child: SkeletonList(count: 2, height: 70))
        else if (_error != null)
          TherabotErrorView(message: _error!, onRetry: _load)
        else if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxl),
            child: Text(
              'No insights yet. After a reflection, you can choose to keep one thing that helped.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final i in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: TherabotCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.body, style: theme.textTheme.bodyLarge),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            timeAgo(i.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(i.id),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
