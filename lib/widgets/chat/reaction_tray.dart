import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../models/chat_reaction.dart';
import '../../theme/app_effects.dart';
import '../../theme/app_spacing.dart';
import '../atoms/fit_label.dart';
import '../effects/motion.dart';
import '../effects/soft_hearts_background.dart' show heartPath;
import 'reaction_art.dart';

/// Other things you can do with a message, under the reactions.
enum MessageAction { removeReaction, copy, edit, delete }

/// What was chosen in the message menu: a reaction, or an action.
@immutable
class MessageMenuChoice {
  const MessageMenuChoice.react(ChatReaction this.reaction) : action = null;
  const MessageMenuChoice.action(MessageAction this.action) : reaction = null;

  final ChatReaction? reaction;
  final MessageAction? action;
}

/// Opens the floating USpace reaction tray next to a message.
///
/// [anchor] is the message bubble in global coordinates; the tray sits just
/// above it (or below, near the top of the screen) and always stays on
/// screen. [current] is your reaction on this message, highlighted; choosing
/// it again removes it. [actions] are listed under the tray. [autofocus]
/// focuses a reaction straight away; pass true only when the tray was
/// opened from the keyboard, so a mouse user doesn't see a focus ring that
/// looks like a chosen reaction.
Future<MessageMenuChoice?> showReactionTray(
  BuildContext context, {
  required Rect anchor,
  required bool alignEnd,
  required ChatReaction? current,
  required List<MessageAction> actions,
  bool autofocus = false,
}) {
  final still = motionOff(context);
  // The tray is laid out in the Navigator's overlay, which is not at the
  // window's origin when the app is shown inside the desktop phone frame.
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  final local = Rect.fromPoints(
    overlay.globalToLocal(anchor.topLeft),
    overlay.globalToLocal(anchor.bottomRight),
  );
  return showGeneralDialog<MessageMenuChoice>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close reactions',
    barrierColor: Colors.black.withValues(alpha: 0.12),
    transitionDuration: still ? Duration.zero : AppMotion.quick,
    pageBuilder: (context, _, _) => _MessageMenu(
      anchor: local,
      alignEnd: alignEnd,
      current: current,
      actions: actions,
      autofocus: autofocus,
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(curved),
          alignment: alignEnd ? Alignment.bottomRight : Alignment.bottomLeft,
          child: child,
        ),
      );
    },
  );
}

class _MessageMenu extends StatelessWidget {
  const _MessageMenu({
    required this.anchor,
    required this.alignEnd,
    required this.current,
    required this.actions,
    required this.autofocus,
  });

  final Rect anchor;
  final bool alignEnd;
  final ChatReaction? current;
  final List<MessageAction> actions;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final padding =
        MediaQuery.paddingOf(context) +
        EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom);
    return CustomSingleChildLayout(
      delegate: _MenuLayout(
        anchor: anchor,
        alignEnd: alignEnd,
        padding: padding,
      ),
      child: Semantics(
        // Announced as its own screen when it opens.
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: 'Reactions and message options',
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: alignEnd
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _ReactionTray(current: current, autofocus: autofocus),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ActionsCard(actions: actions),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Puts the menu next to the message, inside the safe area, never off
/// screen: above the bubble if it fits, otherwise below it, otherwise as
/// close as possible.
class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout({
    required this.anchor,
    required this.alignEnd,
    required this.padding,
  });

  final Rect anchor;
  final bool alignEnd;
  final EdgeInsets padding;

  static const double _margin = AppSpacing.sm;
  static const double _gap = AppSpacing.xs;
  static const double _maxWidth = 420;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = constraints.maxWidth - padding.horizontal - 2 * _margin;
    final height = constraints.maxHeight - padding.vertical - 2 * _margin;
    return BoxConstraints.loose(
      Size(math.max(0, math.min(width, _maxWidth)), math.max(0, height)),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size child) {
    final left = padding.left + _margin;
    final right = size.width - padding.right - _margin - child.width;
    final x = (alignEnd ? anchor.right - child.width : anchor.left)
        .clamp(left, math.max(left, right))
        .toDouble();

    final top = padding.top + _margin;
    final bottom = math.max(
      top,
      size.height - padding.bottom - _margin - child.height,
    );
    final above = anchor.top - _gap - child.height;
    final below = anchor.bottom + _gap;
    final y = above >= top
        ? above
        : below <= bottom
        ? below
        : below.clamp(top, bottom).toDouble();
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout old) =>
      old.anchor != anchor ||
      old.alignEnd != alignEnd ||
      old.padding != padding;
}

/// The reactions themselves: six quick ones and "More" for the rest.
class _ReactionTray extends StatefulWidget {
  const _ReactionTray({required this.current, required this.autofocus});

  final ChatReaction? current;
  final bool autofocus;

  @override
  State<_ReactionTray> createState() => _ReactionTrayState();
}

class _ReactionTrayState extends State<_ReactionTray>
    with SingleTickerProviderStateMixin {
  // Open on "More" straight away when your reaction is one of those.
  late bool _more = widget.current != null && !widget.current!.quick;

  /// The reaction being picked, while its little pop plays.
  ChatReaction? _picked;

  // Made in initState, not lazily: a lazy controller would first be created
  // in dispose() when the tray closes without a pick, which throws.
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  Future<void> _pick(ChatReaction r) async {
    if (_picked != null) return; // one choice per opening
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    if (!motionOff(context)) {
      setState(() => _picked = r);
      _pop.forward();
      // Close part-way through: the pop finishes during the fade-out, so
      // the tap feels immediate.
      await Future<void>.delayed(const Duration(milliseconds: 170));
    }
    // Only if the tray is still the top route (an action row may have
    // closed it meanwhile; popping again would close the chat).
    if (mounted && route != null && route.isCurrent) {
      navigator.pop(MessageMenuChoice.react(r));
    }
  }

  void _toggleMore() {
    setState(() => _more = !_more);
    if (_more) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        '${ChatReaction.moreReactions.length} more reactions: '
        '${ChatReaction.moreReactions.map((r) => r.label).join(', ')}',
        Directionality.of(context),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final still = motionOff(context);

    return PopScope(
      // While the pick plays, a stray barrier tap or Back must not close
      // the tray without the reaction.
      canPop: _picked == null,
      child: IgnorePointer(
        ignoring: _picked != null,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xs + 2),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.hero),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
            boxShadow: AppShadows.raised(scheme),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              // Seven cells in one row (six reactions + More) when they fit
              // at a comfortable size; on narrow phones, rows of four so
              // every cell stays a good touch target with its name.
              final oneRow = box.maxWidth / 7 >= 52;
              final perRow = oneRow ? 7 : 4;
              final cell = math.min(
                oneRow ? 60.0 : 72.0,
                box.maxWidth / perRow,
              );
              final quick = ChatReaction.quickReactions;
              final focusFirst = widget.current ?? quick.first;
              Widget item(ChatReaction r) => _TrayItem(
                reaction: r,
                cell: cell,
                selected: r == widget.current,
                autofocus: widget.autofocus && r == focusFirst,
                pop: r == _picked ? _pop : null,
                onTap: () => _pick(r),
              );
              final cells = [
                for (final r in quick) item(r),
                _MoreButton(cell: cell, expanded: _more, onTap: _toggleMore),
                if (_more)
                  for (final r in ChatReaction.moreReactions) item(r),
              ];
              // The "More" reactions start on a fresh row.
              final firstRows = [
                for (var i = 0; i < quick.length + 1; i += perRow)
                  cells.sublist(i, math.min(i + perRow, quick.length + 1)),
              ];
              final moreCells = cells.sublist(quick.length + 1);
              final moreRows = [
                for (var i = 0; i < moreCells.length; i += perRow)
                  moreCells.sublist(i, math.min(i + perRow, moreCells.length)),
              ];
              return AnimatedSize(
                // AnimatedSize must not get a zero duration (it asserts).
                duration: still
                    ? const Duration(milliseconds: 1)
                    : AppMotion.quick,
                curve: AppMotion.enter,
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final row in [...firstRows, ...moreRows])
                      Row(mainAxisSize: MainAxisSize.min, children: row),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One round cell in the tray: art (or the More icon) with its name under
/// it, a clear rose ring when it has keyboard focus.
class _TrayCell extends StatelessWidget {
  const _TrayCell({
    required this.cell,
    required this.label,
    required this.onTap,
    required this.disc,
    this.selected = false,
    this.autofocus = false,
  });

  final double cell;
  final String label;
  final VoidCallback onTap;
  final Widget disc;
  final bool selected;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkResponse(
      onTap: onTap,
      // Focus a reaction for keyboard users only: on touch, taking focus
      // would close the on-screen keyboard behind the tray.
      autofocus:
          autofocus &&
          FocusManager.instance.highlightMode == FocusHighlightMode.traditional,
      radius: cell / 2,
      highlightShape: BoxShape.circle,
      child: Builder(
        builder: (context) {
          final focused =
              Focus.of(context).hasPrimaryFocus &&
              FocusManager.instance.highlightMode ==
                  FocusHighlightMode.traditional;
          return SizedBox(
            width: cell,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: focused
                          ? Border.all(color: scheme.primary, width: 2)
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: disc,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FitLabel(
                    label,
                    maxWidth: cell - 2,
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrayItem extends StatelessWidget {
  const _TrayItem({
    required this.reaction,
    required this.cell,
    required this.selected,
    required this.autofocus,
    required this.pop,
    required this.onTap,
  });

  final ChatReaction reaction;
  final double cell;
  final bool selected;
  final bool autofocus;

  /// Drives the pick animation when this is the reaction being picked.
  final Animation<double>? pop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final artSize = math.min(36.0, cell * 0.62);

    Widget art = ReactionArt.of(reaction, size: artSize);
    final pop = this.pop;
    if (pop != null) {
      art = _PickPop(animation: pop, reaction: reaction, child: art);
    }

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: reaction.label,
      hint: selected ? 'Your reaction. Activate to remove it' : null,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: reaction.label,
        excludeFromSemantics: true,
        child: _TrayCell(
          cell: cell,
          label: reaction.label,
          onTap: onTap,
          selected: selected,
          autofocus: autofocus,
          disc: Container(
            width: artSize + 8,
            height: artSize + 8,
            alignment: Alignment.center,
            decoration: selected
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primaryContainer,
                    border: Border.all(color: scheme.primary, width: 1.5),
                  )
                : null,
            child: art,
          ),
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({
    required this.cell,
    required this.expanded,
    required this.onTap,
  });

  final double cell;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final artSize = math.min(36.0, cell * 0.62);
    final name = expanded ? 'Fewer reactions' : 'More reactions';
    return Semantics(
      container: true,
      button: true,
      expanded: expanded,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: name,
        excludeFromSemantics: true,
        child: _TrayCell(
          cell: cell,
          label: expanded ? 'Less' : 'More',
          onTap: onTap,
          disc: Container(
            width: artSize + 8,
            height: artSize + 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer.withValues(alpha: 0.6),
            ),
            child: Icon(
              expanded ? Icons.expand_less_rounded : Icons.add_rounded,
              size: artSize * 0.6,
              color: scheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The pick: a quick scale up, a soft springy settle, and for the warm
/// reactions a tiny burst of hearts (sparkles for the happy ones).
class _PickPop extends StatelessWidget {
  const _PickPop({
    required this.animation,
    required this.reaction,
    required this.child,
  });

  final Animation<double> animation;
  final ChatReaction reaction;
  final Widget child;

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.18,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.18,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 60,
    ),
  ]);

  _Burst? get _burst => switch (reaction) {
    ChatReaction.love ||
    ChatReaction.inLove ||
    ChatReaction.kiss ||
    ChatReaction.hug ||
    ChatReaction.aww ||
    ChatReaction.hereForYou => _Burst.hearts,
    ChatReaction.laugh ||
    ChatReaction.puppyEyes ||
    ChatReaction.proudOfYou => _Burst.sparkles,
    // Sad and Upset: no confetti, just the gentle pop.
    ChatReaction.sad || ChatReaction.upset => null,
  };

  @override
  Widget build(BuildContext context) {
    final burst = _burst;
    final color = Theme.of(context).colorScheme.primary;
    // Its own layer, so the tray's shadowed card isn't repainted each frame.
    return RepaintBoundary(
      child: CustomPaint(
        foregroundPainter: burst == null
            ? null
            : _BurstPainter(animation: animation, kind: burst, color: color),
        child: ScaleTransition(scale: _scale.animate(animation), child: child),
      ),
    );
  }
}

enum _Burst { hearts, sparkles }

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.animation,
    required this.kind,
    required this.color,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final _Burst kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t == 0 || t == 1) return;
    final center = size.center(Offset.zero);
    final reach = size.width * (0.55 + 0.35 * Curves.easeOut.transform(t));
    final opacity = (1 - t).clamp(0.0, 1.0);
    final paint = Paint()..color = color.withValues(alpha: 0.8 * opacity);
    const count = 6;
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / count;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * reach;
      final s = size.width * 0.16;
      if (kind == _Burst.hearts) {
        canvas.drawPath(
          heartPath(Rect.fromCenter(center: p, width: s, height: s)),
          paint,
        );
      } else {
        canvas.drawCircle(p, s * 0.28, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.kind != kind || old.color != color || old.animation != animation;
}

/// Remove / copy / edit / delete, under the tray.
class _ActionsCard extends StatelessWidget {
  const _ActionsCard({required this.actions});

  final List<MessageAction> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
        boxShadow: AppShadows.raised(scheme),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in actions)
            _ActionRow(
              action: a,
              onTap: () =>
                  Navigator.of(context).pop(MessageMenuChoice.action(a)),
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action, required this.onTap});

  final MessageAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, label) = switch (action) {
      MessageAction.removeReaction => (
        Icons.remove_circle_outline,
        'Remove my reaction',
      ),
      MessageAction.copy => (Icons.copy_outlined, 'Copy text'),
      MessageAction.edit => (Icons.edit_outlined, 'Edit'),
      MessageAction.delete => (Icons.delete_outline, 'Delete for both of us'),
    };
    final color = action == MessageAction.delete
        ? scheme.error
        : scheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
