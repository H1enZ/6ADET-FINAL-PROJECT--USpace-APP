import 'package:flutter/material.dart';

import '../../theme/app_effects.dart';
import '../../theme/app_spacing.dart';
import '../effects/motion.dart';

enum AppButtonVariant { filled, outlined }

/// Filled, outlined and disabled button in one widget.
/// Passing null to [onPressed] shows the disabled style.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final action = isLoading ? null : onPressed;
    // The label and the spinner cross-fade instead of swapping in one
    // frame, so a save that starts loading doesn't flicker.
    final Widget content = AnimatedSwitcher(
      duration: motionOff(context) ? Duration.zero : AppMotion.quick,
      switchInCurve: AppMotion.snappy,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: isLoading
          ? const SizedBox(
              key: ValueKey('loading'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Text(label, key: const ValueKey('label')),
    );

    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(64, AppSpacing.touchTarget),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
      ),
    );

    final Widget button;
    if (variant == AppButtonVariant.filled) {
      button = icon == null || isLoading
          ? FilledButton(onPressed: action, style: style, child: content)
          : FilledButton.icon(
              onPressed: action,
              style: style,
              icon: Icon(icon),
              label: content,
            );
    } else {
      button = icon == null || isLoading
          ? OutlinedButton(onPressed: action, style: style, child: content)
          : OutlinedButton.icon(
              onPressed: action,
              style: style,
              icon: Icon(icon),
              label: content,
            );
    }

    return PressScale(
      enabled: action != null,
      child: fullWidth
          ? SizedBox(width: double.infinity, child: button)
          : button,
    );
  }
}
