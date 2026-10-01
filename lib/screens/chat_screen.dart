import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../models/chat_message.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../theme/app_spacing.dart';
import '../utils/capsule_time.dart';
import '../widgets/atoms/avatar_circle.dart';

/// The couple's private chat. Messages arrive in real time; your partner's
/// messages are marked read while this screen is open.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.coupleId,
    required this.me,
    required this.partner,
  });

  final String coupleId;
  final Profile me;
  final Profile partner;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = [];
  Map<String, Map<String, String>> _reactions = {};
  bool _loading = true;
  bool _sending = false;
  bool _showEmojis = false;
  String? _error;
  RealtimeChannel? _live;

  String get _myId => widget.me.userId;

  @override
  void initState() {
    super.initState();
    _load(scrollToEnd: true);
    try {
      _live = ChatService.listen(widget.coupleId, () {
        if (mounted) _load();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    final live = _live;
    if (live != null) ChatService.stopListening(live);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _nearBottom =>
      !_scroll.hasClients ||
      _scroll.position.maxScrollExtent - _scroll.position.pixels < 160;

  Future<void> _load({bool scrollToEnd = false}) async {
    final stick = scrollToEnd || _nearBottom;
    try {
      final messages = await ChatService.recent(widget.coupleId);
      final reactions = await ChatService.reactions(widget.coupleId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _reactions = reactions;
        _error = null;
        _loading = false;
      });
      if (messages.any((m) => m.senderId != _myId && m.readAt == null)) {
        unawaited(ChatService.markRead().catchError((_) {}));
      }
      if (stick) _jumpToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final still = MediaQuery.of(context).disableAnimations;
      final end = _scroll.position.maxScrollExtent;
      if (still) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(end,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ChatService.send(widget.coupleId, text);
      if (preset == null) _input.clear();
      await _load(scrollToEnd: true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (file == null) return;
      setState(() => _sending = true);
      final dot = file.name.lastIndexOf('.');
      final ext = dot == -1 ? 'jpg' : file.name.substring(dot + 1);
      await ChatService.sendPhoto(
        widget.coupleId,
        await file.readAsBytes(),
        ext,
        caption: _input.text,
      );
      _input.clear();
      await _load(scrollToEnd: true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _insertEmoji(String emoji) {
    final sel = _input.selection;
    final text = _input.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    _input.value = TextEditingValue(
      text: text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _openActions(ChatMessage m) async {
    if (m.isDeleted) return;
    final mine = m.senderId == _myId;
    final myReaction = _reactions[m.id]?[_myId];
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final e in chatReactions)
                    InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => Navigator.of(context).pop('react:$e'),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: e == myReaction
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                ],
              ),
            ),
            if (myReaction != null)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Remove my reaction'),
                onTap: () => Navigator.of(context).pop('unreact'),
              ),
            if (m.body != null)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy text'),
                onTap: () => Navigator.of(context).pop('copy'),
              ),
            if (mine && m.body != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () => Navigator.of(context).pop('edit'),
              ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete for both of us'),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    try {
      if (choice.startsWith('react:')) {
        await ChatService.react(widget.coupleId, m.id, choice.substring(6));
      } else if (choice == 'unreact') {
        await ChatService.removeReaction(m.id);
      } else if (choice == 'copy') {
        await Clipboard.setData(ClipboardData(text: m.body!));
        if (!mounted) return;
        _showMessage('Copied');
        return;
      } else if (choice == 'edit') {
        final text = await showDialog<String>(
          context: context,
          builder: (_) => _EditDialog(initial: m.body!),
        );
        if (text == null || text.trim() == m.body) return;
        await ChatService.edit(m.id, text);
      } else if (choice == 'delete') {
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete this message?'),
            content: const Text('It will be removed for both of you.'),
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
        if (ok != true) return;
        await ChatService.delete(m.id);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    }
  }

  void _viewPhoto(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton.filledTonal(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = widget.partner;

    // The last message of mine, for the "Seen" / "Sent" receipt.
    String? lastMineId;
    for (final m in _messages.reversed) {
      if (m.senderId == _myId && !m.isDeleted) {
        lastMineId = m.id;
        break;
      }
    }

    final items = <Widget>[];
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final prev = i > 0 ? _messages[i - 1] : null;
      final next = i < _messages.length - 1 ? _messages[i + 1] : null;
      final newDay = prev == null ||
          dayLabel(prev.createdAt) != dayLabel(m.createdAt);
      if (newDay) items.add(_DaySeparator(label: dayLabel(m.createdAt)));
      items.add(_Bubble(
        message: m,
        mine: m.senderId == _myId,
        startsGroup: newDay || prev == null || !sameGroup(prev, m),
        endsGroup: next == null || !sameGroup(m, next),
        reactions: _reactions[m.id] ?? const {},
        receipt: m.id == lastMineId ? (m.readAt != null ? 'Seen' : 'Sent') : null,
        onLongPress: () => _openActions(m),
        onPhotoTap: m.photoUrl == null ? null : () => _viewPhoto(m.photoUrl!),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            AvatarCircle(name: p.displayName, imageUrl: p.avatarUrl, size: 36),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.displayName, style: theme.textTheme.titleMedium),
                  Text('Private chat \u00B7 only you two',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center,
                                  style: TextStyle(color: scheme.error)),
                              TextButton(onPressed: _load, child: const Text('Try again')),
                            ],
                          ),
                        ),
                      )
                    : _messages.isEmpty
                        ? _EmptyChat(
                            partnerName: p.displayName,
                            onPick: (text) => _send(text),
                          )
                        : Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: ListView(
                                controller: _scroll,
                                padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                                    AppSpacing.md, AppSpacing.md, AppSpacing.md),
                                children: items,
                              ),
                            ),
                          ),
          ),
          if (_showEmojis)
            Container(
              color: scheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  for (final e in const ['❤️', '🥰', '😘', '🤗', '😂', '🥺', '😊',
                    '😢', '🙏', '👍', '🎉', '🌙', '☀️', '🌸', '💌', '🫂'])
                    IconButton(
                      onPressed: () => _insertEmoji(e),
                      icon: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                border: Border(top: BorderSide(color: scheme.outline)),
              ),
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Emoji',
                        onPressed: () => setState(() => _showEmojis = !_showEmojis),
                        icon: Icon(_showEmojis
                            ? Icons.keyboard_outlined
                            : Icons.emoji_emotions_outlined),
                      ),
                      IconButton(
                        tooltip: 'Send a photo',
                        onPressed: _sending ? null : _sendPhoto,
                        icon: const Icon(Icons.photo_outlined),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 4000,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Message',
                            counterText: '',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      IconButton.filled(
                        tooltip: 'Send',
                        onPressed: _sending ? null : () => _send(),
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
        ),
      ),
    );
  }
}

/// One message bubble. Long-press (or right-click) for reactions, copy,
/// edit and delete.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.startsGroup,
    required this.endsGroup,
    required this.reactions,
    required this.receipt,
    required this.onLongPress,
    required this.onPhotoTap,
  });

  final ChatMessage message;
  final bool mine;
  final bool startsGroup;
  final bool endsGroup;
  final Map<String, String> reactions;
  final String? receipt;
  final VoidCallback onLongPress;
  final VoidCallback? onPhotoTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final m = message;
    final bg = mine ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = mine ? scheme.onPrimary : scheme.onSurface;
    const r = Radius.circular(AppRadius.bubble);
    const tight = Radius.circular(4);

    final radius = BorderRadius.only(
      topLeft: mine || startsGroup ? r : tight,
      bottomLeft: mine || endsGroup ? r : tight,
      topRight: !mine || startsGroup ? r : tight,
      bottomRight: !mine || endsGroup ? r : tight,
    );

    final Widget content;
    if (m.isDeleted) {
      content = Text('Message deleted',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: fg.withValues(alpha: 0.7), fontStyle: FontStyle.italic));
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.photoPath != null)
            Padding(
              padding: EdgeInsets.only(bottom: m.body == null ? 0 : AppSpacing.xs),
              child: GestureDetector(
                onTap: onPhotoTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240, maxHeight: 280),
                    child: m.photoUrl == null
                        ? Container(
                            width: 200,
                            height: 140,
                            color: scheme.primaryContainer,
                            child: Icon(Icons.photo_outlined, color: scheme.primary),
                          )
                        : Image.network(m.photoUrl!, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          if (m.body != null)
            Text(m.body!, style: theme.textTheme.bodyLarge?.copyWith(color: fg)),
        ],
      );
    }

    final counts = <String, int>{};
    for (final e in reactions.values) {
      counts[e] = (counts[e] ?? 0) + 1;
    }

    return Padding(
      padding: EdgeInsets.only(top: startsGroup ? AppSpacing.sm : 2),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: onLongPress,
            onSecondaryTap: onLongPress,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.75 > 480
                      ? 480
                      : MediaQuery.sizeOf(context).width * 0.75),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: radius,
                  border: mine ? null : Border.all(color: scheme.outline),
                ),
                child: content,
              ),
            ),
          ),
          if (counts.isNotEmpty)
            Transform.translate(
              offset: const Offset(0, -4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outline),
                ),
                child: Text(
                  counts.entries
                      .map((e) => e.value > 1 ? '${e.key}${e.value}' : e.key)
                      .join(' '),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          if (endsGroup)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(
                [
                  clockTime(m.createdAt),
                  if (m.isEdited) 'edited',
                  if (receipt != null) receipt!,
                ].join(' \u00B7 '),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.partnerName, required this.onPick});

  final String partnerName;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const starters = ['Good morning ❤️', 'Thinking of you', 'I miss you 🥺', 'How was your day?'];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.lg),
            Text('Say hi to $partnerName', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text('Only the two of you can ever read this chat.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                for (final s in starters)
                  ActionChip(label: Text(s), onPressed: () => onPick(s)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.initial});

  final String initial;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit message'),
      content: TextField(
        controller: _text,
        autofocus: true,
        minLines: 1,
        maxLines: 5,
        maxLength: 4000,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final t = _text.text.trim();
            if (t.isNotEmpty) Navigator.of(context).pop(t);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
