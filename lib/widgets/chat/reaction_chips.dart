import 'package:flutter/material.dart';

import '../../models/chat_reaction.dart';
import '../../theme/app_spacing.dart';
import '../effects/motion.dart';
import 'reaction_art.dart';

/// The reactions on one message, as small chips tucked under the bubble.
/// There are only two of you, so at most two chips (or one with "2" when
/// you both chose the same). Your own chip is outlined in rose. Tapping a
/// chip opens the tray to change or remove your reaction.
class ReactionChips extends StatelessWidget {
  const ReactionChips({
    super.key,
    required this.reactions,
    required this.myId,
    required this.partnerName,
    required this.onTap,
  });

  /// user id -> stored value (a reaction key, or one of the original emoji).
  final Map<String, String> reactions;
  final String myId;
  final String partnerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Group what looks the same on screen into one chip.
    final groups = <String, _Group>{};
    for (final e in reactions.entries) {
      final view = ReactionView.of(e.value);
      if (view == null) continue; // not a value this app knows
      final g = groups.putIfAbsent(view.identity, () => _Group(view));
      if (e.key == myId) {
        g.mine = true;
      } else {
        g.partner = true;
      }
    }
    final chips = groups.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    // A small pop whenever the reactions change (not on first load).
    return PopOnChange(
      trigger: chips
          .map((g) => '${g.view.identity}:${g.mine}:${g.partner}')
          .join(','),
      scale: 1.15,
      child: chips.isEmpty
          ? const SizedBox.shrink()
          : Transform.translate(
              // Tucked slightly under the bubble's edge.
              offset: const Offset(0, -8),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final g in chips)
                    _Chip(group: g, partnerName: partnerName, onTap: onTap),
                ],
              ),
            ),
    );
  }
}

class _Group {
  _Group(this.view);

  final ReactionView view;
  bool mine = false;
  bool partner = false;

  int get count => (mine ? 1 : 0) + (partner ? 1 : 0);

  // USpace reactions in tray order, then the legacy Wow / Like.
  int get order => view.reaction?.index ?? 100;
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.group,
    required this.partnerName,
    required this.onTap,
  });

  final _Group group;
  final String partnerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final g = group;
    final who = g.mine && g.partner
        ? 'both of you'
        : g.mine
        ? 'you'
        : partnerName;
    final name = g.view.legacy ? '${g.view.label} (older style)' : g.view.label;

    return Semantics(
      // Its own node: never merged into the message text above it.
      container: true,
      button: true,
      label: '$name, from $who',
      hint: g.mine ? 'Change or remove your reaction' : 'React to this message',
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: '$name · $who',
        excludeFromSemantics: true,
        // The visible chip stays small; the area you can tap is at least
        // 40×40 around it.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: PressScale(
                scale: 0.9,
                child: Material(
                color: g.mine
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: g.mine ? scheme.primary : scheme.outline,
                    width: g.mine ? 1.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      4,
                      3,
                      g.count > 1 || g.mine ? 7 : 4,
                      3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReactionArt(view: g.view, size: 20),
                        // Yours is marked with a check, not only by colour.
                        if (g.mine) ...[
                          const SizedBox(width: 2),
                          Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: scheme.onPrimaryContainer,
                          ),
                        ],
                        if (g.count > 1) ...[
                          const SizedBox(width: 3),
                          Text(
                            '${g.count}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: g.mine
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurface,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
