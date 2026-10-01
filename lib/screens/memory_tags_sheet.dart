import 'package:flutter/material.dart';

import '../models/memory.dart';
import '../services/auth_service.dart';
import '../services/memory_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/molecules/tag_picker.dart';

/// "Move to a category": change a memory's tags. Either partner can do
/// this (the database checks it). Closes with `true` once saved.
class MemoryTagsSheet extends StatefulWidget {
  const MemoryTagsSheet({super.key, required this.memory, this.known = const []});

  final Memory memory;
  final List<String> known;

  @override
  State<MemoryTagsSheet> createState() => _MemoryTagsSheetState();
}

class _MemoryTagsSheetState extends State<MemoryTagsSheet> {
  late List<String> _tags = [...widget.memory.tags];
  final _typed = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _tags = withPendingTag(_tags, _typed.text); // keep a typed-but-not-added tag
      _typed.clear();
      _saving = true;
      _error = null;
    });
    try {
      await MemoryService.setTags(widget.memory.id, _tags);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        0,
        AppSpacing.screenMargin,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Move to a category', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '"${widget.memory.title}" will show under every category you pick.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              TagPicker(
                selected: _tags,
                known: widget.known,
                enabled: !_saving,
                controller: _typed,
                onChanged: (t) => setState(() => _tags = t),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(label: 'Save', onPressed: _save, isLoading: _saving, fullWidth: true),
            ],
          ),
        ),
      ),
    );
  }
}
