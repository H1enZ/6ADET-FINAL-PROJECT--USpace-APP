import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../models/time_capsule.dart';
import '../../services/auth_service.dart';
import '../../services/time_capsule_service.dart';
import '../../theme/app_spacing.dart';
import '../../utils/anniversary.dart';
import '../../utils/capsule_time.dart';
import '../../widgets/atoms/us_icon.dart';
import '../../widgets/capsule/candle_ceremony.dart';
import '../../widgets/capsule/envelope.dart';
import '../../widgets/capsule/monogram_seal.dart';
import '../../widgets/capsule/opened_capsule.dart';
import '../../widgets/effects/motion.dart';
import '../../widgets/notes/note_style.dart';

/// One capsule, for reading. The receiver of a ready capsule opens it here
/// (the full envelope opening, once); an opened capsule goes straight to
/// its contents and the replies.
class CapsuleViewScreen extends StatefulWidget {
  const CapsuleViewScreen({
    super.key,
    required this.capsule,
    required this.coupleId,
    required this.myId,
    required this.partnerName,
    this.myName,
  });

  final TimeCapsule capsule;
  final String coupleId;
  final String myId;
  final String partnerName;

  /// Your own name, for the letter's sign-off when you wrote it.
  final String? myName;

  @override
  State<CapsuleViewScreen> createState() => _CapsuleViewScreenState();
}

enum _Stage { closed, opening, envelope, reading }

class _CapsuleViewScreenState extends State<CapsuleViewScreen> {
  late TimeCapsule _capsule = widget.capsule;
  CapsuleContents? _contents;
  List<CapsuleReply> _replies = [];
  Uint8List? _photo;
  bool _photoFailed = false;
  String? _error;
  bool _busy = false;
  late _Stage _stage = widget.capsule.isOpened ? _Stage.reading : _Stage.closed;
  bool _revealAnimation = false;
  RealtimeChannel? _live;

  bool get _iAmSender => _capsule.senderId == widget.myId;
  String get _senderName => _iAmSender ? 'you' : widget.partnerName;

  @override
  void initState() {
    super.initState();
    if (_capsule.isOpened) _load();
    try {
      _live = TimeCapsuleService.listen(widget.coupleId, () {
        if (mounted && _stage == _Stage.reading) _load();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    final live = _live;
    if (live != null) TimeCapsuleService.stopListening(live);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final all = await TimeCapsuleService.list(widget.coupleId);
      final capsule = all.where((c) => c.id == _capsule.id).firstOrNull;
      if (capsule == null) {
        throw const AppException('This capsule is no longer here.');
      }
      final contents = await TimeCapsuleService.contents([capsule.id]);
      final replies = await TimeCapsuleService.replies([capsule.id]);
      if (!mounted) return;
      setState(() {
        _capsule = capsule;
        _contents = contents[capsule.id] ?? _contents;
        _replies = replies[capsule.id] ?? [];
        _error = null;
      });
      unawaited(
        TimeCapsuleService.markSeen(
          widget.myId,
          capsule.id,
          TimeCapsuleService.partnerStep(capsule, _replies, widget.myId),
        ),
      );
      if (_photo == null && _contents?.photoPath != null) await _loadPhoto();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _loadPhoto() async {
    final path = _contents?.photoPath;
    if (path == null) return;
    setState(() => _photoFailed = false);
    try {
      final bytes = await TimeCapsuleService.downloadOpenedPhoto(path);
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) setState(() => _photoFailed = true);
    }
  }

  /// The receiver opens it: the database decides, then the envelope plays.
  Future<void> _open() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final contents = await TimeCapsuleService.open(_capsule.id);
      _contents = contents;
      if (contents.photoPath != null) {
        // A moment for the photo, so it can peek out of the envelope.
        await _loadPhoto().timeout(
          const Duration(seconds: 6),
          onTimeout: () {},
        );
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = _Stage.envelope;
      });
      unawaited(_load());
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = (MediaQuery.sizeOf(context).width - 64).clamp(220.0, 360.0);

    final Widget body = switch (_stage) {
      _Stage.closed || _Stage.opening => _closed(theme, width),
      _Stage.envelope => Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          CapsuleOpeningCeremony(
            width: width,
            // The sender's initial is pressed into the wax.
            initial: sealInitial(
              _iAmSender ? (widget.myName ?? '') : widget.partnerName,
            ),
            title: _contents?.title,
            letter: _contents?.letter ?? '',
            photo: _photo,
            onReveal: () => setState(() {
              _stage = _Stage.reading;
              _revealAnimation = true;
            }),
          ),
        ],
      ),
      _Stage.reading => _reading(theme),
    };

    final list = RefreshIndicator(
      onRefresh: _stage == _Stage.reading ? _load : () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          AppSpacing.md,
          AppSpacing.screenMargin,
          64,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: body,
            ),
          ),
        ],
      ),
    );

    if (_stage != _Stage.reading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _iAmSender ? 'Your time capsule' : 'From ${widget.partnerName}',
          ),
        ),
        body: list,
      );
    }

    final narrow = MediaQuery.sizeOf(context).width < 360;

    // Opened: the dark plum page, just the back button and the title.
    // The background sits behind the whole screen, so the header is part of
    // the page rather than a separate strip.
    return NotesBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          foregroundColor: NotePalette.pink,
          centerTitle: true,
          leading: IconButton(
            tooltip: 'Back',
            icon: const UsIcon(UsIcons.back, size: 22),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Your time capsule',
            style: NotePalette.display(narrow ? 21 : 24),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            // A small decorative heart, left out where the title needs
            // the room.
            if (!narrow)
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  child: UsIcon(
                    UsIcons.heart,
                    size: 22,
                    color: NotePalette.rose.withValues(alpha: 0.55),
                  ),
                ),
              ),
          ],
        ),
        body: list,
      ),
    );
  }

  Widget _closed(ThemeData theme, double width) {
    final scheme = theme.colorScheme;
    final ready = _capsule.isReady(TimeCapsuleService.now()) && !_iAmSender;
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xl),
        MiniEnvelope(
          look: ready ? EnvelopeLook.ready : EnvelopeLook.sealed,
          width: width,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          ready ? 'A time capsule from ${widget.partnerName}' : 'Still sealed',
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Sealed for ${longDate(_capsule.unlockAt!)} at ${clockTime(_capsule.unlockAt!)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _error!,
            style: TextStyle(color: scheme.error),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (ready)
          FilledButton.icon(
            onPressed: _busy ? null : _open,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const UsIcon(UsIcons.loveNotes, size: 20),
            label: Text(_busy ? 'Opening...' : 'Open now'),
          )
        else
          Text(
            _iAmSender
                ? 'Ready when they are.'
                : 'It opens ${opensIn(_capsule.unlockAt!, now: TimeCapsuleService.now())}.',
            style: theme.textTheme.bodyLarge,
          ),
      ],
    );
  }

  Widget _reading(ThemeData theme) {
    final scheme = theme.colorScheme;
    final contents = _contents;
    if (contents == null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.huge),
        child: Center(
          child: _error != null
              ? Column(
                  children: [
                    Text(_error!, style: TextStyle(color: scheme.error)),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OpenedCapsule(
          reveal: _revealAnimation,
          title: contents.title,
          letter: contents.letter,
          caption: contents.photoCaption,
          hasPhoto: contents.photoPath != null,
          photo: _photo,
          photoFailed: _photoFailed,
          onRetryPhoto: _loadPhoto,
          signature: (
            name: _iAmSender ? (widget.myName ?? 'You') : widget.partnerName,
            written: _capsule.sealedAt ?? _capsule.createdAt,
          ),
        ),
        const SizedBox(height: 48),
        _Replies(
          key: ValueKey('replies-${_replies.length}'),
          capsule: _capsule,
          replies: _replies,
          myId: widget.myId,
          partnerName: widget.partnerName,
          senderName: _senderName,
          onChanged: _load,
        ),
        const SizedBox(height: AppSpacing.xxl),
        _Details(capsule: _capsule),
      ],
    );
  }
}

/// When it was sealed for and opened: small, and only when asked for.
class _Details extends StatefulWidget {
  const _Details({required this.capsule});

  final TimeCapsule capsule;

  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(color: NotePalette.muted);
    final unlock = widget.capsule.unlockAt;
    final opened = widget.capsule.openedAt;
    return Column(
      children: [
        Semantics(
          expanded: _open,
          child: TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            style: TextButton.styleFrom(
              foregroundColor: NotePalette.muted,
              minimumSize: const Size(0, 44),
            ),
            icon: UsIcon(
              _open ? UsIcons.chevronUp : UsIcons.chevronDown,
              size: 18,
            ),
            label: const Text('Details'),
          ),
        ),
        if (_open) ...[
          if (unlock != null)
            Text(
              'Sealed for ${longDate(unlock)} at ${clockTime(unlock)}',
              style: small,
              textAlign: TextAlign.center,
            ),
          if (opened != null)
            Text(
              'Opened ${longDate(opened)} at ${clockTime(opened)}',
              style: small,
              textAlign: TextAlign.center,
            ),
        ],
      ],
    );
  }
}

/// The reply section of an opened capsule. The receiver writes first; the
/// sender then answers once; after that both stay as they are.
class _Replies extends StatefulWidget {
  const _Replies({
    super.key,
    required this.capsule,
    required this.replies,
    required this.myId,
    required this.partnerName,
    required this.senderName,
    required this.onChanged,
  });

  final TimeCapsule capsule;
  final List<CapsuleReply> replies;
  final String myId;
  final String partnerName;
  final String senderName;
  final Future<void> Function() onChanged;

  @override
  State<_Replies> createState() => _RepliesState();
}

class _RepliesState extends State<_Replies> {
  final _text = TextEditingController();
  bool _composing = false;
  bool _sending = false;
  bool _expanded = false;
  String? _error;

  CapsuleReply? _by(String? id) =>
      widget.replies.where((r) => r.authorId == id).firstOrNull;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send({required bool finalResponse}) async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    if (finalResponse) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Send your reply?'),
          content: const Text(
            'You each have one reply. Once you send yours, both stay exactly as they are.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Send'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await TimeCapsuleService.reply(widget.capsule.id, body);
      if (!mounted) return;
      setState(() => _composing = false);
      await widget.onChanged();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _bubble(ThemeData theme, String who, String body) {
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(AppRadius.bubble),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            who,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(body, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _composer(
    ThemeData theme, {
    required String hint,
    required String action,
    required bool finalResponse,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _text,
          maxLength: TimeCapsuleService.replyMax,
          minLines: 2,
          maxLines: 6,
          autofocus: _composing,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: hint),
        ),
        if (_error != null)
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (_composing)
                TextButton(
                  onPressed: _sending
                      ? null
                      : () => setState(() => _composing = false),
                  child: const Text('Cancel'),
                ),
              FilledButton(
                onPressed: _sending
                    ? null
                    : () => _send(finalResponse: finalResponse),
                child: Text(_sending ? 'Sending...' : action),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = widget.capsule;
    final iAmReceiver = c.receiverId == widget.myId;
    final first = _by(c.receiverId); // the receiver's reply
    final response = _by(c.senderId); // the sender's answer
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final receiverLabel = iAmReceiver ? 'You' : widget.partnerName;
    final senderLabel = iAmReceiver ? widget.partnerName : 'You';

    final List<Widget> children;
    if (first != null && response != null) {
      // Complete: collapsed until tapped.
      children = [
        Semantics(
          button: true,
          expanded: _expanded,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: UsIcon(UsIcons.chat, color: scheme.primary),
            title: const Text('You both replied'),
            trailing: UsIcon(
              _expanded ? UsIcons.chevronUp : UsIcons.chevronDown,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
        ),
        if (_expanded) ...[
          _bubble(theme, receiverLabel, first.body),
          _bubble(theme, senderLabel, response.body),
        ],
      ];
    } else if (iAmReceiver) {
      if (first == null) {
        children = [
          Text('Reply when you\'re ready', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _composer(
            theme,
            hint: 'Write back to ${widget.partnerName}',
            action: 'Send reply',
            finalResponse: false,
          ),
        ];
      } else if (_composing) {
        children = [
          Text('Edit your reply', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _composer(
            theme,
            hint: 'Your reply',
            action: 'Save',
            finalResponse: false,
          ),
        ];
      } else {
        children = [
          _bubble(theme, 'You', first.body),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Waiting for ${widget.partnerName} to answer.',
                  style: muted,
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _text.text = first.body;
                  _composing = true;
                }),
                icon: const UsIcon(UsIcons.edit, size: 18),
                label: const Text('Edit reply'),
              ),
            ],
          ),
        ];
      }
    } else {
      // I sent it.
      if (first == null) {
        children = [
          Row(
            children: [
              UsIcon(UsIcons.loveNotes, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  "They've opened your capsule",
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ];
      } else if (_composing) {
        children = [
          _bubble(theme, widget.partnerName, first.body),
          _composer(
            theme,
            hint: 'Your one answer',
            action: 'Send',
            finalResponse: true,
          ),
        ];
      } else {
        children = [
          _bubble(theme, widget.partnerName, first.body),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => setState(() {
                _text.clear();
                _composing = true;
              }),
              icon: const UsIcon(UsIcons.send, size: 18),
              label: const Text('Reply'),
            ),
          ),
        ];
      }
    }

    return AnimatedSize(
      duration: motionOff(context)
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 250),
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
