import 'package:flutter/material.dart';

import '../../theme/app_effects.dart';
import '../../theme/app_spacing.dart';
import '../effects/motion.dart';

/// A soft rounded card with a gentle shadow and an optional selected
/// outline that animates in. Used for the mood tiles and quick actions.
/// Screen readers hear it as a button, and as selected when it is.
class SoftTile extends StatelessWidget {
  /// Border width, the same selected or not, so nothing shifts.
  static const double borderWidth = 2;

  const SoftTile({
    super.key,
    required this.child,
    required this.semanticLabel,
    this.onTap,
    this.selected = false,
    this.selectedColor,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
    this.radius = AppRadius.tile,
    this.exclusiveGroup = false,
    this.semanticHint,
    this.semanticValue,
  });

  final Widget child;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool selected;

  /// True when exactly one tile in a group can be selected (the mood grid),
  /// so screen readers announce it like a radio choice.
  final bool exclusiveGroup;

  /// What tapping does, e.g. "Preview" or why it is unavailable.
  final String? semanticHint;

  /// Extra state read after the label, e.g. "shared today".
  final String? semanticValue;

  /// The outline colour when selected. Defaults to the theme's rose.
  final Color? selectedColor;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ring = selectedColor ?? scheme.primary;
    final shape = BorderRadius.circular(radius);
    final duration = motionOff(context) ? Duration.zero : AppMotion.quick;

    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      inMutuallyExclusiveGroup: exclusiveGroup,
      // checked (with the group flag) is what makes screen readers announce
      // it as a single choice, like a radio button.
      checked: exclusiveGroup ? selected : null,
      label: semanticLabel,
      hint: semanticHint,
      value: semanticValue,
      // excludeSemantics hides the InkWell's own tap action, so it is
      // provided here; otherwise TalkBack cannot activate the tile.
      onTap: onTap,
      excludeSemantics: true,
      child: PressScale(
        enabled: onTap != null,
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.enter,
          decoration: BoxDecoration(
            // A light tint as well as the ring, so selection does not rely
            // on the outline colour alone.
            color: selected
                ? Color.alphaBlend(
                    ring.withValues(alpha: 0.08),
                    scheme.surfaceContainerHighest,
                  )
                : scheme.surfaceContainerHighest,
            borderRadius: shape,
            // Same width selected or not, so nothing shifts when it animates.
            border: Border.all(
              color: selected ? ring : scheme.outline.withValues(alpha: 0.6),
              width: borderWidth,
            ),
            boxShadow: selected
                ? AppShadows.glow(ring)
                : AppShadows.soft(scheme),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: shape,
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
