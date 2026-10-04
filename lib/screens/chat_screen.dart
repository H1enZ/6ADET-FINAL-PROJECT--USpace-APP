import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../models/chat_message.dart';
import '../models/chat_reaction.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../theme/app_spacing.dart';
import '../utils/capsule_time.dart';
import '../widgets/atoms/avatar_circle.dart';
import '../widgets/chat/reaction_chips.dart';
import '../widgets/chat/reaction_tray.dart';
import '../widgets/effects/motion.dart';

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

  // New-message animation: ids seen so far, and the ones that just arrived.
  final Set<String> _seen = {};
  Set<String> _fresh = {};
  bool _firstLoadDone = false;
  int _sentCount = 0;

  /// One key per message bubble, so the tray can open right next to it.
  final Map<String, GlobalKey> _bubbleKeys = {};

  // Loads can overlap (your own action plus the realtime echo, or your
  // partner's change). Only the newest load's result is applied.
  int _loadGeneration = 0;
  bool _wantEnd = false;

  // Your reaction writes still in flight: message id -> the value shown
  // until the write finishes (null = removed). Laid over every load, so a
  // load that started before the write can't bring back the old reaction.
  final Map<String, String?> _pendingMine = {};
  final Map<String, int> _writeToken = {};
  int _writeSeq = 0;

  /// While the tray is open the list must not scroll away under it.
  bool _trayOpen = false;

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
    final generation = ++_loadGeneration;
    if (scrollToEnd) _wantEnd = true;
    final stick = _nearBottom;
    try {
      final messages = await ChatService.recent(widget.coupleId);
      final reactions = await ChatService.reactions(widget.coupleId);
      if (!mounted || generation != _loadGeneration) return; // a newer load won
      final ids = messages.map((m) => m.id).toSet();
      for (final e in _pendingMine.entries) {
        final mine = {...?reactions[e.key]};
        if (e.value == null) {
          mine.remove(_myId);
        } else {
          mine[_myId] = e.value!;
        }
        reactions[e.key] = mine;
      }
      setState(() {
        _fresh = _firstLoadDone ? ids.difference(_seen) : <String>{};
        _seen.addAll(ids);
        _firstLoadDone = true;
        _messages = messages;
        _reactions = reactions;
        _bubbleKeys.removeWhere((id, _) => !ids.contains(id));
        _error = null;
        _loading = false;
      });
      if (messages.any((m) => m.senderId != _myId && m.readAt == null)) {
        unawaited(ChatService.markRead().catchError((_) {}));
      }
      if ((stick || _wantEnd) && !_trayOpen) {
        _wantEnd = false;
        _jumpToEnd();
      }
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
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
      if (mounted) setState(() => _sentCount++);
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

  /// Long-press (or right-click, or the screen reader's "React" action):
  /// the floating reaction tray next to the message, with the message's
  /// other actions under it.
  Future<void> _openActions(ChatMessage m, Rect anchor) async {
    if (m.isDeleted) return;
    final mine = m.senderId == _myId;
    final myStored = _reactions[m.id]?[_myId];
    _trayOpen = true;
    final choice = await showReactionTray(
      context,
      anchor: anchor,
      alignEnd: mine,
      // An older emoji reaction highlights its USpace match, if it has one.
      current: myStored == null ? null : ReactionView.of(myStored)?.reaction,
      actions: [
        if (myStored != null) MessageAction.removeReaction,
        if (m.body != null) MessageAction.copy,
        if (mine && m.body != null) MessageAction.edit,
        if (mine) MessageAction.delete,
      ],
    );
    _trayOpen = false;
    if (choice == null || !mounted) return;

    final reaction = choice.reaction;
    if (reaction != null) {
      // Choosing your current reaction again takes it away (also when it
      // is an older emoji shown as that reaction). Read it again: it may
      // have changed while the tray was open.
      final now = _reactions[m.id]?[_myId];
      final current = now == null ? null : ReactionView.of(now);
      if (current?.reaction == reaction) {
        await _removeReaction(m);
      } else {
        await _setReaction(m, reaction);
      }
      return;
    }

    try {
      switch (choice.action!) {
        case MessageAction.removeReaction:
          await _removeReaction(m);
          return;
        case MessageAction.copy:
          await Clipboard.setData(ClipboardData(text: m.body!));
          if (!mounted) return;
          _showMessage('Copied');
          return;
        case MessageAction.edit:
          final text = await showDialog<String>(
            context: context,
            builder: (_) => _EditDialog(initial: m.body!),
          );
          if (text == null || text.trim() == m.body) return;
          await ChatService.edit(m.id, text);
        case MessageAction.delete:
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

  /// Read out shortly after the tray closes, so the screen reader doesn't
  /// drop it while focus moves back to the chat.
  void _announce(String message) {
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      );
    });
  }

  /// Shows your reaction at once, then saves it (replacing any earlier one).
  Future<void> _setReaction(ChatMessage m, ChatReaction reaction) async {
    final before = _reactions[m.id]?[_myId];
    final previous = before == null ? null : ReactionView.of(before);
    _announce(previous == null
        ? 'Reacted with ${reaction.label}'
        : 'Changed your reaction from ${previous.label} to ${reaction.label}');
    await _write(m.id, reaction.key, before,
        () => ChatService.react(widget.coupleId, m.id, reaction));
  }

  Future<void> _removeReaction(ChatMessage m) async {
    final before = _reactions[m.id]?[_myId];
    if (before == null) return;
    final label = ReactionView.of(before)?.label;
    _announce(label == null ? 'Reaction removed' : 'Removed your $label reaction');
    await _write(m.id, null, before, () async {
      await ChatService.removeReaction(m.id);
      // The removal itself is saved; if the nudge to your partner fails,
      // they still see it on their next reload.
      final live = _live;
      if (live != null) {
        ChatService.announceReactionsChanged(live).catchError((_) {});
      }
    });
  }

  /// Shows [value] as your reaction (null = none) while [save] runs. If it
  /// fails and nothing newer was chosen meanwhile, [before] comes back.
  Future<void> _write(String messageId, String? value, String? before,
      Future<void> Function() save) async {
    final token = ++_writeSeq;
    _writeToken[messageId] = token;
    _pendingMine[messageId] = value;
    _showMine(messageId, value);
    try {
      await save();
      if (_writeToken[messageId] == token) _pendingMine.remove(messageId);
      if (mounted) await _load();
    } catch (e) {
      if (_writeToken[messageId] != token) return; // a newer choice stands
      _pendingMine.remove(messageId);
      if (!mounted) return;
      _showMine(messageId, before);
      _announce("Couldn't save your reaction");
      _showMessage(friendlyError(e));
    }
  }

  /// Sets (or clears, with null) your reaction on one message on screen.
  void _showMine(String messageId, String? stored) {
    final next = {...?_reactions[messageId]};
    if (stored == null) {
      next.remove(_myId);
    } else {
      next[_myId] = stored;
    }
    setState(() => _reactions = {..._reactions, messageId: next});
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
      if (newDay) {
        items.add(_DaySeparator(
            key: ValueKey('day-${dayLabel(m.createdAt)}'),
            label: dayLabel(m.createdAt)));
      }
      final mineMsg = m.senderId == _myId;
      final bubble = _Bubble(
        message: m,
        mine: m.senderId == _myId,
        startsGroup: prev == null || newDay || !sameGroup(prev, m),
        endsGroup: next == null || !sameGroup(m, next),
        reactions: _reactions[m.id] ?? const {},
        myId: _myId,
        partnerName: p.displayName,
        bubbleKey: _bubbleKeys.putIfAbsent(m.id, GlobalKey.new),
        receipt: m.id == lastMineId ? (m.readAt != null ? 'Seen' : 'Sent') : null,
        onOpenMenu: (anchor) => _openActions(m, anchor),
        onPhotoTap: m.photoUrl == null ? null : () => _viewPhoto(m.photoUrl!),
      );
      // Keyed by message, so each bubble keeps its own state when older
      // messages drop off the top of the list.
      items.add(KeyedSubtree(
        key: ValueKey('msg-${m.id}'),
        child: _fresh.contains(m.id)
            ? FadeSlideIn(
                key: ValueKey('in-${m.id}'),
                from: Offset(mineMsg ? 28 : -28, 6),
                child: bubble,
              )
            : bubble,
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
                ? const SkeletonList(count: 6, height: 52)
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
                      PopOnChange(
                        trigger: _sentCount,
                        child: IconButton.filled(
                        tooltip: 'Send',
                        onPressed: _sending ? null : () => _send(),
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send),
                      ),
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
  const _DaySeparator({super.key, required this.label});

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

/// One message bubble. Long-press (or right-click, Enter when focused, or
/// the screen reader's "React" action) opens the reaction tray with copy,
/// edit and delete.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.startsGroup,
    required this.endsGroup,
    required this.reactions,
    required this.myId,
    required this.partnerName,
    required this.bubbleKey,
    required this.receipt,
    required this.onOpenMenu,
    required this.onPhotoTap,
  });

  final ChatMessage message;
  final bool mine;
  final bool startsGroup;
  final bool endsGroup;
  final Map<String, String> reactions;
  final String myId;
  final String partnerName;
  final String? receipt;

  /// Opens the tray, given where the bubble is on screen.
  final ValueChanged<Rect> onOpenMenu;
  final VoidCallback? onPhotoTap;

  /// Kept by the chat screen per message (a key made here would change on
  /// every rebuild and rebuild the bubble with it).
  final GlobalKey bubbleKey;

  void _open() {
    final box = bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    onOpenMenu(box.localToGlobal(Offset.zero) & box.size);
  }

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

    return Padding(
      padding: EdgeInsets.only(top: startsGroup ? AppSpacing.sm : 2),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Keyboard: Tab to a message, Enter opens the tray. Screen
          // readers get a "React" action as well as long-press.
          Semantics(
            onTap: m.isDeleted ? null : _open,
            onTapHint: m.isDeleted ? null : 'show reactions and options',
            customSemanticsActions: m.isDeleted
                ? null
                : {const CustomSemanticsAction(label: 'React'): _open},
            child: FocusableActionDetector(
              enabled: !m.isDeleted,
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
                  _open();
                  return null;
                }),
              },
              child: GestureDetector(
                key: bubbleKey,
                onLongPress: _open,
                onSecondaryTap: _open,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.75 > 480
                          ? 480
                          : MediaQuery.sizeOf(context).width * 0.75),
                  child: Builder(
                    builder: (context) {
                      // A visible ring when the bubble has keyboard focus.
                      final focused = Focus.of(context).hasPrimaryFocus &&
                          FocusManager.instance.highlightMode ==
                              FocusHighlightMode.traditional;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: radius,
                          border: mine ? null : Border.all(color: scheme.outline),
                        ),
                        foregroundDecoration: focused
                            ? BoxDecoration(
                                borderRadius: radius,
                                border: Border.all(
                                    color: mine ? scheme.secondary : scheme.primary,
                                    width: 2),
                              )
                            : null,
                        child: content,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: ReactionChips(
              reactions: reactions,
              myId: myId,
              partnerName: partnerName,
              onTap: _open,
            ),
          ),
          if (endsGroup)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(
                [
                  clockTime(m.createdAt),
                  if (m.isEdited) 'edited',
                  ?receipt,
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
