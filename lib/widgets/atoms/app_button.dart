import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

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
    final Widget content = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Text(label);

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

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
