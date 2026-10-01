import 'package:flutter/material.dart';

import '../../models/memory.dart';
import '../../theme/app_spacing.dart';

/// Pick categories for a memory: tap a built-in or one of your own, or
/// type a new one and press Enter (or +). Up to [maxTags].
class TagPicker extends StatefulWidget {
  const TagPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.known = const [],
    this.enabled = true,
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  /// Your own tags already used on other memories, offered as chips.
  final List<String> known;
  final bool enabled;

  @override
  State<TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<TagPicker> {
  final _typed = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _typed.dispose();
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
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final t in [...builtIns, ...own])
              FilterChip(
                label: Text(tagLabel(t)),
                selected: _isOn(t),
                onSelected: widget.enabled ? (_) => _toggle(t) : null,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _typed,
                enabled: widget.enabled,
                maxLength: maxTagLength,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addTyped(),
                decoration: const InputDecoration(
                  labelText: 'Type your own',
                  hintText: 'e.g. Special date, Monthsary',
                  prefixIcon: Icon(Icons.sell_outlined),
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filledTonal(
              tooltip: 'Add tag',
              onPressed: widget.enabled ? _addTyped : null,
              icon: const Icon(Icons.add),
            ),
          ],
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
