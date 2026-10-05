import 'package:flutter/material.dart';

import '../../theme/app_effects.dart';
import '../../theme/app_spacing.dart';
import '../effects/motion.dart';

/// A round header button (Chat, Notifications) with an optional unread
/// marker: a small dot, or a count when [count] is given. Screen readers
/// hear the unread state as part of the label.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.showDot = false,
    this.count,
  });

  static const double _iconSize = 22;

  final IconData icon;

  /// What the button does, e.g. "Chat", "Notifications".
  final String label;
  final VoidCallback? onPressed;

  /// Unread marker without a number.
  final bool showDot;

  /// Unread count. Shown instead of the dot when above zero.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = count ?? 0;
    final unread = n > 0 || showDot;
    final semantic = n > 0
        ? '$label, $n new'
        : (showDot ? '$label, new' : label);

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semantic,
      // excludeSemantics hides the InkWell's own tap action, so it is
      // provided here; otherwise TalkBack cannot activate the button.
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: semantic,
        // The filled circle carries the shadow, behind the ink.
        child: PressScale(
          enabled: onPressed != null,
          scale: 0.94,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              boxShadow: AppShadows.soft(scheme),
            ),
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: AppSpacing.touchTarget,
                  child: Center(
                    // The marker hugs the icon, not the corner of the
                    // touch target, so it reads as part of the bell/bubble.
                    child: Badge(
                      isLabelVisible: unread,
                      backgroundColor: scheme.primary,
                      textColor: scheme.onPrimary,
                      label: n > 0 ? Text(n > 99 ? '99+' : '$n') : null,
                      child: Icon(
                        icon,
                        size: _iconSize,
                        color: onPressed == null
                            ? scheme.outline
                            : scheme.onSurface,
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
