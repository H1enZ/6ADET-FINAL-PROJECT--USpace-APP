import 'package:flutter/material.dart';

import '../../models/memory.dart';
import '../../theme/app_effects.dart';
import '../../theme/app_spacing.dart';
import '../atoms/us_icon.dart';
import '../effects/motion.dart';

/// [selected] plus whatever is still typed in [typed] (not yet added with
/// Enter or +), so pressing Save never loses a typed tag.
List<String> withPendingTag(List<String> selected, String typed) {
  final tag = normalizeTag(typed);
  if (tag == null || selected.length >= maxTags) return selected;
  return withTag(selected, tag);
}

/// Pick categories for a memory: tap a built-in or one of your own, or
/// type a new one and press Enter (or +). Up to [maxTags].
class TagPicker extends StatefulWidget {
  const TagPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.known = const [],
    this.enabled = true,
    this.controller,
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  /// Your own tags already used on other memories, offered as chips.
  final List<String> known;
  final bool enabled;

  /// The "type your own" box. Pass one in so the screen can include
  /// text that was typed but not yet added when it saves
  /// (see [withPendingTag]).
  final TextEditingController? controller;

  @override
  State<TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<TagPicker> {
  late final TextEditingController _typed =
      widget.controller ?? TextEditingController();
  final _typedFocus = FocusNode();
  String? _error;

  /// The "your own" field shows only after tapping "+ Your own" (or while
  /// it still holds text), so the picker stays a calm set of pills.
  late bool _typing = _typed.text.isNotEmpty;

  @override
  void dispose() {
    if (widget.controller == null) _typed.dispose();
    _typedFocus.dispose();
    super.dispose();
  }

  bool _isOn(String tag) =>
      widget.selected.any((t) => t.toLowerCase() == tag.toLowerCase());

  void _toggle(String tag) {
    if (_isOn(tag)) {
      widget.onChanged(
          widget.selected.where((t) => t.toLowerCase() != tag.toLowerCase()).toList());
      setState(() => _error = null);
    } else if (widget.selected.length >= maxTags) {
      setState(() => _error = 'A memory can have up to $maxTags tags.');
    } else {
      widget.onChanged(withTag(widget.selected, tag));
      setState(() => _error = null);
    }
  }

  void _addTyped() {
    final tag = normalizeTag(_typed.text);
    if (tag == null) return;
    if (!_isOn(tag)) _toggle(tag);
    _typed.clear();
    setState(() => _typing = false);
  }

  void _startTyping() {
    setState(() => _typing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _typedFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final builtIns = [for (final t in MemoryTag.values) t.dbName];
    // your own: ones already used elsewhere, plus any selected here
    final own = <String>[];
    for (final t in [...widget.known, ...widget.selected]) {
      if (MemoryTag.fromDb(t) == null &&
          !own.any((o) => o.toLowerCase() == t.toLowerCase())) {
        own.add(t);
      }
    }
    own.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in [...builtIns, ...own])
              _TagPill(
                label: tagLabel(t),
                selected: _isOn(t),
                onTap: widget.enabled ? () => _toggle(t) : null,
              ),
            if (!_typing)
              _TagPill(
                label: 'Your own',
                leading: UsIcons.plus,
                outlined: true,
                onTap: widget.enabled ? _startTyping : null,
              ),
          ],
        ),
        AnimatedSize(
          duration: motionOff(context)
              ? const Duration(milliseconds: 1) // AnimatedSize asserts on zero
              : AppMotion.quick,
          curve: AppMotion.snappy,
          alignment: Alignment.topCenter,
          child: !_typing
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _typed,
                          focusNode: _typedFocus,
                          enabled: widget.enabled,
                          maxLength: maxTagLength,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addTyped(),
                          decoration: const InputDecoration(
                            hintText: 'Your own tag, e.g. Monthsary',
                            isDense: true,
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TextButton(
                        onPressed: widget.enabled ? _addTyped : null,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(_error!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ),
      ],
    );
  }
}

/// One quiet tag: a soft rose-tinted pill with just its name; picked, it
/// fills dusty rose and shows a check (so the state is not colour alone).
class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.leading,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final UsIconData? leading;

  /// A plain outline instead of a fill (the "+ Your own" pill).
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    final icon = selected ? UsIcons.check : leading;
    return Semantics(
      button: true,
      selected: outlined ? null : selected,
      child: AnimatedContainer(
        duration: motionOff(context) ? Duration.zero : AppMotion.quick,
        curve: AppMotion.snappy,
        decoration: ShapeDecoration(
          color: outlined
              ? Colors.transparent
              : selected
              ? scheme.primary
              : scheme.primary.withValues(alpha: 0.12),
          shape: StadiumBorder(
            side: outlined
                ? BorderSide(color: scheme.outline)
                : BorderSide.none,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: ConstrainedBox(
              // Comfortable to tap without looking chunky.
              constraints: const BoxConstraints(minHeight: 36),
              child: Padding(
                padding: EdgeInsets.fromLTRB(icon == null ? 14 : 10, 6, 14, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      UsIcon(icon, size: 14, color: fg),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
