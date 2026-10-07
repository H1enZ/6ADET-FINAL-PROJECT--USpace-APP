import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/atoms/us_icon.dart';

import '../../models/love_note.dart';
import '../../models/memory.dart';
import '../../services/auth_service.dart';
import '../../services/memory_service.dart';
import '../../services/note_service.dart';
import '../../services/therabot_service.dart';
import '../../theme/app_spacing.dart';
import '../../utils/anniversary.dart';
import '../../widgets/atoms/app_button.dart';
import '../../widgets/effects/motion.dart';
import '../../widgets/therabot/therabot_widgets.dart';
import '../add_memory_sheet.dart';
import '../memory_detail_screen.dart';
import '../../widgets/molecules/us_states.dart';

/// The order to revisit memories in: ones from this day in an earlier year
/// first, then favourites, then the rest in a shuffled order. Only real
/// memories from the Timeline; nothing is made up.
List<Memory> memoriesToRevisit(
  List<Memory> all,
  DateTime today,
  Random random,
) {
  final onThisDay = <Memory>[];
  final favourites = <Memory>[];
  final rest = <Memory>[];
  for (final m in all) {
    if (isOnThisDay(m.memoryDate, today)) {
      onThisDay.add(m);
    } else if (m.isFavorite) {
      favourites.add(m);
    } else {
      rest.add(m);
    }
  }
  favourites.shuffle(random);
  rest.shuffle(random);
  return [...onThisDay, ...favourites, ...rest];
}

/// Same day and month as [today], in an earlier year.
bool isOnThisDay(DateTime date, DateTime today) =>
    date.month == today.month &&
    date.day == today.day &&
    date.year < today.year;

/// "Today", "3 days ago", "5 months ago", "2 years ago".
String howLongAgo(DateTime date, DateTime today) {
  final from = DateTime(date.year, date.month, date.day);
  final to = DateTime(today.year, today.month, today.day);
  final days = to.difference(from).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  var months = (to.year - from.year) * 12 + to.month - from.month;
  if (to.day < from.day) months--;
  if (months >= 12) {
    final years = months ~/ 12;
    return years == 1 ? 'A year ago' : '$years years ago';
  }
  if (months >= 1) return months == 1 ? 'A month ago' : '$months months ago';
  return '$days days ago';
}

/// Reconnect › Shared memories: one real moment from your Timeline at a
/// time, to look back on together. You can send your partner a gentle
/// "Remember this?" love note about it.
class SharedMemoriesPage extends StatefulWidget {
  const SharedMemoriesPage({
    super.key,
    required this.coupleId,
    required this.partnerName,
  });

  final String coupleId;
  final String partnerName;

  @override
  State<SharedMemoriesPage> createState() => _SharedMemoriesPageState();
}

class _SharedMemoriesPageState extends State<SharedMemoriesPage> {
  List<Memory>? _memories;
  int _index = 0;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await MemoryService.list(widget.coupleId);
      if (!mounted) return;
      setState(() {
        _memories = memoriesToRevisit(all, DateTime.now(), Random());
        _index = 0;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = therabotError(e).message);
    }
  }

  void _next() {
    final count = _memories?.length ?? 0;
    if (count < 2) return;
    setState(() => _index = (_index + 1) % count);
  }

  Future<void> _addMemory() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AddMemorySheet(coupleId: widget.coupleId),
    );
    if (saved == true) await _load();
  }

  Future<void> _open(Memory memory) async {
    final mine = memory.authorId == AuthService.user?.id;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemoryDetailScreen(
          memory: memory,
          authorName: mine ? 'you' : widget.partnerName,
          isMine: mine,
        ),
      ),
    );
  }

  /// A love note about this memory, with an optional line of your own.
  /// Sent only after you press Send.
  Future<void> _remind(Memory memory) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) =>
          _RemindDialog(partnerName: widget.partnerName, memory: memory),
    );
    if (message == null || !mounted) return;
    final when = longDate(memory.memoryDate);
    final extra = message.trim();
    setState(() => _sending = true);
    try {
      await NoteService.send(
        coupleId: widget.coupleId,
        title: 'Remember this?',
        category: NoteCategory.love,
        body: [
          '${memory.caption} · $when',
          if (extra.isNotEmpty) extra,
        ].join('\n\n'),
      );
      if (!mounted) return;
      showEnvelopeFly(context);
    } catch (e) {
      if (!mounted) return;
      therabotToast(context, therabotError(e).message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final memories = _memories;

    final List<Widget> body;
    if (_error != null) {
      body = [TherabotErrorView(message: _error!, onRetry: _load)];
    } else if (memories == null) {
      body = const [UsInlineLoader(padding: AppSpacing.xxl)];
    } else if (memories.isEmpty) {
      body = [
        Text('No memories yet', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Moments you save on your Timeline show up here, so you can look '
          'back on them together.',
          style: muted,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Add a memory',
          usIcon: UsIcons.image,
          onPressed: _addMemory,
        ),
      ];
    } else {
      final memory = memories[_index];
      body = [
        _MemoryCard(memory: memory, onOpen: () => _open(memory)),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Send "Remember this?"',
          usIcon: UsIcons.heart,
          isLoading: _sending,
          onPressed: _sending ? null : () => _remind(memory),
        ),
        if (memories.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Another memory',
            usIcon: UsIcons.shuffle,
            variant: AppButtonVariant.outlined,
            onPressed: _sending ? null : _next,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          '${_index + 1} of ${memories.length} from your Timeline',
          textAlign: TextAlign.center,
          style: muted,
        ),
      ];
    }

    return TherabotPage(
      title: 'Shared memories',
      onRefresh: _load,
      children: [
        Text('A moment you shared', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Look back on something good, together. Only moments you saved '
          'on your Timeline.',
          style: muted,
        ),
        const SizedBox(height: AppSpacing.xl),
        ...body,
      ],
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.memory, required this.onOpen});

  final Memory memory;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = DateTime.now();
    final url = memory.photoUrl;
    final badges = [
      if (isOnThisDay(memory.memoryDate, today)) 'On this day',
      if (memory.isFavorite) 'Favourite',
    ];
    final description = memory.description?.trim() ?? '';
    final location = memory.location?.trim() ?? '';

    return Semantics(
      button: true,
      label: 'Open ${memory.caption}',
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: scheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (url != null)
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: scheme.surfaceContainer,
                      child: UsIcon(
                        UsIcons.image,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (badges.isNotEmpty) ...[
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final b in badges)
                            Chip(
                              label: Text(b),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    Text(memory.caption, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      '${longDate(memory.memoryDate)} · '
                      '${howLongAgo(memory.memoryDate, today)}'
                      '${location.isEmpty ? '' : ' · $location'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirms the "Remember this?" note, with an optional line of your own.
/// Closes with the line (maybe empty) on Send, or null.
class _RemindDialog extends StatefulWidget {
  const _RemindDialog({required this.partnerName, required this.memory});

  final String partnerName;
  final Memory memory;

  @override
  State<_RemindDialog> createState() => _RemindDialogState();
}

class _RemindDialogState extends State<_RemindDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Send ${widget.partnerName} "Remember this?"'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A love note about "${widget.memory.caption}". '
          'Add a few words if you like.',
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _text,
          autofocus: true,
          maxLength: 500,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. I still smile thinking about this day.',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Not now'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_text.text),
        child: const Text('Send'),
      ),
    ],
  );
}
