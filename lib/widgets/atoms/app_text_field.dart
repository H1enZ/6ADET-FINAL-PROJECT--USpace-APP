import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import 'us_icon.dart';

/// Labelled input with the small-caps label above it.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.prefixIcon,
    this.usIcon,
    this.obscureText = false,
    this.suffix,
    this.validator,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
    this.focusNode,
    this.helperText,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final IconData? prefixIcon;

  /// A USpace icon before the text; wins over [prefixIcon].
  final UsIconData? usIcon;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final int maxLines;

  /// False while a form is submitting, so it can't be edited mid-request.
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  /// A short hint under the field (e.g. a password rule), read with it and
  /// replaced by the error when validation fails.
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The visible label is for sighted users; screen readers get the same
        // label on the field itself below, so it is read once, with the field.
        ExcludeSemantics(
          child: Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Semantics(
          // Names the field for screen readers ("Email, text field").
          label: label,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            onChanged: onChanged,
            obscureText: obscureText,
            validator: validator,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            textInputAction: textInputAction,
            onFieldSubmitted: onFieldSubmitted,
            textCapitalization: textCapitalization,
            maxLength: maxLength,
            maxLines: obscureText ? 1 : maxLines,
            decoration: InputDecoration(
              hintText: hintText,
              helperText: helperText,
              helperMaxLines: 2,
              prefixIcon: usIcon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: UsIcon(
                        usIcon!,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : prefixIcon == null
                  ? null
                  : Icon(prefixIcon),
              suffixIcon: suffix,
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }
}
