part of 'chat_screen.dart';

// The chat screen's pieces: the day separator, message bubble, empty
// chat and the edit dialog.

/// A quiet day marker: the label between two hairlines, no pill.
class _DaySeparator extends StatelessWidget {
  const _DaySeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final line = Expanded(child: Divider(height: 1, color: scheme.outline));
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md, horizontal: AppSpacing.xl),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          line,
        ],
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

  /// Opens the tray, given where the bubble is on screen and whether it
  /// was opened from the keyboard (or a screen reader).
  final void Function(Rect anchor, bool viaKeyboard) onOpenMenu;
  final VoidCallback? onPhotoTap;

  /// Kept by the chat screen per message (a key made here would change on
  /// every rebuild and rebuild the bubble with it).
  final GlobalKey bubbleKey;

  void _open({bool viaKeyboard = false}) {
    final box = bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    onOpenMenu(box.localToGlobal(Offset.zero) & box.size, viaKeyboard);
  }

  void _openFromKeyboard() => _open(viaKeyboard: true);

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
                            alignment: Alignment.center,
                            child: UsIcon(UsIcons.image, color: scheme.primary),
                          )
                        : Image.network(
                            m.photoUrl!,
                            fit: BoxFit.cover,
                            // Keep showing the photo if its link is renewed.
                            gaplessPlayback: true,
                            // Hold the placeholder's size until it loads, so
                            // the conversation doesn't jump as it appears.
                            frameBuilder: (context, child, frame, sync) =>
                                frame == null && !sync
                                    ? Container(
                                        width: 200,
                                        height: 140,
                                        color: scheme.primaryContainer,
                                      )
                                    : child,
                            // A photo that can't load keeps the same box.
                            errorBuilder: (context, _, _) => Container(
                              width: 200,
                              height: 140,
                              color: scheme.primaryContainer,
                              alignment: Alignment.center,
                              child: UsIcon(UsIcons.image, color: scheme.primary),
                            ),
                          ),
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
            onTap: m.isDeleted ? null : _openFromKeyboard,
            onTapHint: m.isDeleted ? null : 'show reactions and options',
            customSemanticsActions: m.isDeleted
                ? null
                : {const CustomSemanticsAction(label: 'React'): _openFromKeyboard},
            child: FocusableActionDetector(
              enabled: !m.isDeleted,
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
                  _openFromKeyboard();
                  return null;
                }),
                // On the web, Enter sends ButtonActivateIntent, not ActivateIntent.
                ButtonActivateIntent:
                    CallbackAction<ButtonActivateIntent>(onInvoke: (_) {
                  _openFromKeyboard();
                  return null;
                }),
              },
              child: GestureDetector(
                key: bubbleKey,
                onLongPress: _open,
                onSecondaryTap: _open,
                // Sinks a touch while held, so the long-press feels like it
                // is working before the tray appears.
                child: PressScale(
                  enabled: !m.isDeleted,
                  scale: 0.98,
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
                // labelSmall's wide tracking is for small-caps labels; a
                // time reads better set close.
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.2),
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
    final scheme = theme.colorScheme;
    const starters = ['Good morning ❤️', 'Thinking of you', 'I miss you 🥺', 'How was your day?'];
    // A first-time moment, so it may arrive gently: heart, words, then the
    // starters, one after another.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: staggered([
            // The app's own heart on a quiet disc, not a generic chat icon.
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer,
              ),
              child: UsIcon(UsIcons.heart, size: 36, color: scheme.primary),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxl),
              child: Text('Say hi to $partnerName',
                  textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text('Only the two of you can ever read this chat.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxl),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in starters)
                    PressScale(
                      child: ActionChip(label: Text(s), onPressed: () => onPick(s)),
                    ),
                ],
              ),
            ),
          ]),
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
