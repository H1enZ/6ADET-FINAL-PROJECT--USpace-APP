import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/memory_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/app_text_field.dart';

/// The Add memory sheet: photo (optional), caption and date.
/// Closes with `true` once the memory is saved.
class AddMemorySheet extends StatefulWidget {
  const AddMemorySheet({super.key, required this.coupleId});

  final String coupleId;

  @override
  State<AddMemorySheet> createState() => _AddMemorySheetState();
}

class _AddMemorySheetState extends State<AddMemorySheet> {
  final _caption = TextEditingController();
  DateTime _date = DateTime.now();
  Uint8List? _photo;
  String _extension = 'jpg';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final dot = file.name.lastIndexOf('.');
      final ext =
          dot == -1 ? 'jpg' : file.name.substring(dot + 1).toLowerCase();
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _extension = ext;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'That photo could not be opened. Try another one.');
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1970),
      lastDate: now,
      helpText: 'When did it happen?',
    );
    if (!mounted || picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _save() async {
    final caption = _caption.text.trim();
    if (caption.isEmpty) {
      setState(() => _error = 'Add a caption so you both know what this was.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await MemoryService.add(
        coupleId: widget.coupleId,
        caption: caption,
        date: _date,
        photo: _photo,
        photoExtension: _extension,
      );
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
    final scheme = theme.colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        0,
        AppSpacing.screenMargin,
        keyboard + AppSpacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.formMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add a memory', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),

              // Photo
              Material(
                color: scheme.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _saving ? null : _pickPhoto,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _photo == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 40, color: scheme.primary),
                              const SizedBox(height: AppSpacing.sm),
                              Text('Add a photo (optional)',
                                  style: theme.textTheme.labelLarge
                                      ?.copyWith(color: scheme.primary)),
                            ],
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(_photo!, fit: BoxFit.cover),
                              Positioned(
                                top: AppSpacing.sm,
                                right: AppSpacing.sm,
                                child: IconButton.filledTonal(
                                  tooltip: 'Remove photo',
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() => _photo = null),
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                label: 'Caption',
                controller: _caption,
                hintText: 'e.g. Beach day in Zambales',
                maxLength: 500,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Date: ${longDate(_date)}',
                icon: Icons.event_outlined,
                variant: AppButtonVariant.outlined,
                onPressed: _saving ? null : _pickDate,
                fullWidth: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Save memory',
                onPressed: _save,
                isLoading: _saving,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
