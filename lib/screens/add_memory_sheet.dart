import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/memory.dart';
import '../services/auth_service.dart';
import '../services/memory_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/app_text_field.dart';
import '../widgets/atoms/section_label.dart';
import '../widgets/molecules/tag_picker.dart';

/// One photo in the editor: either already saved, or newly picked.
class _EditorPhoto {
  _EditorPhoto.saved(PhotoRef this.saved) : bytes = null, extension = null;
  _EditorPhoto.picked(Uint8List this.bytes, String this.extension) : saved = null;

  final PhotoRef? saved;
  final Uint8List? bytes;
  final String? extension;
}

/// Add a memory, or edit one of your own when [memory] is given.
/// Photos (up to 10), title, story, date, location and tags.
/// Closes with `true` once saved.
class AddMemorySheet extends StatefulWidget {
  const AddMemorySheet({
    super.key,
    required this.coupleId,
    this.memory,
    this.knownTags = const [],
  });

  final String coupleId;
  final Memory? memory;

  /// Your own tags used on other memories, offered as chips.
  final List<String> knownTags;

  @override
  State<AddMemorySheet> createState() => _AddMemorySheetState();
}

class _AddMemorySheetState extends State<AddMemorySheet> {
  late final _title = TextEditingController(text: widget.memory?.caption);
  late final _story = TextEditingController(text: widget.memory?.description);
  late final _location = TextEditingController(text: widget.memory?.location);
  late DateTime _date = widget.memory?.memoryDate ?? DateTime.now();
  late List<String> _tags = [...?widget.memory?.tags];
  final _typedTag = TextEditingController();
  late final List<_EditorPhoto> _photos = [
    for (final p in widget.memory?.photos ?? const <PhotoRef>[]) _EditorPhoto.saved(p),
  ];
  bool _saving = false;
  String? _error;

  bool get _editing => widget.memory != null;

  @override
  void dispose() {
    _title.dispose();
    _story.dispose();
    _location.dispose();
    _typedTag.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final room = MemoryService.maxPhotos - _photos.length;
    if (room <= 0) {
      setState(() => _error = 'A memory can have up to ${MemoryService.maxPhotos} photos.');
      return;
    }
    try {
      final files = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 85);
      if (files.isEmpty) return;
      final picked = <_EditorPhoto>[];
      for (final f in files.take(room)) {
        final dot = f.name.lastIndexOf('.');
        final ext = dot == -1 ? 'jpg' : f.name.substring(dot + 1).toLowerCase();
        picked.add(_EditorPhoto.picked(await f.readAsBytes(), ext));
      }
      if (!mounted) return;
      setState(() {
        _photos.addAll(picked);
        _error = files.length > room
            ? 'Only the first $room fitted. A memory can have up to ${MemoryService.maxPhotos} photos.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Those photos could not be opened. Try others.');
    }
  }

  void _makeCover(int index) {
    setState(() {
      final photo = _photos.removeAt(index);
      _photos.insert(0, photo);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      helpText: 'When did it happen?',
    );
    if (!mounted || picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give this memory a title.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final tags = withPendingTag(_tags, _typedTag.text); // keep a typed-but-not-added tag
    final added = [
      for (final p in _photos)
        if (p.bytes != null) NewPhoto(p.bytes!, p.extension!),
    ];
    try {
      if (_editing) {
        await MemoryService.update(
          widget.memory!,
          title: _title.text,
          date: _date,
          description: _story.text,
          location: _location.text,
          tags: tags,
          keep: [for (final p in _photos) if (p.saved != null) p.saved!],
          added: added,
        );
      } else {
        await MemoryService.add(
          coupleId: widget.coupleId,
          title: _title.text,
          date: _date,
          description: _story.text,
          location: _location.text,
          tags: tags,
          photos: added,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _thumb(int index) {
    final scheme = Theme.of(context).colorScheme;
    final p = _photos[index];
    final Widget image = p.bytes != null
        ? Image.memory(p.bytes!, fit: BoxFit.cover)
        : (p.saved!.url == null
            ? ColoredBox(color: scheme.primaryContainer)
            : Image.network(p.saved!.url!, fit: BoxFit.cover));
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(AppRadius.input), child: image),
          if (index == 0)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.chipBar),
                ),
                child: Text('Cover',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onPrimary)),
              ),
            )
          else
            Positioned(
              left: 0,
              bottom: 0,
              child: IconButton(
                tooltip: 'Make cover',
                visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : () => _makeCover(index),
                icon: const Icon(Icons.star_outline, color: Colors.white),
              ),
            ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              tooltip: 'Remove photo',
              visualDensity: VisualDensity.compact,
              onPressed: _saving ? null : () => setState(() => _photos.removeAt(index)),
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
              Text(_editing ? 'Edit memory' : 'Add a memory',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),

              SectionLabel(
                text: 'Photos (${_photos.length}/${MemoryService.maxPhotos})',
                actionLabel: _photos.length < MemoryService.maxPhotos ? 'Add photos' : null,
                onAction: _saving ? null : _pickPhotos,
              ),
              if (_photos.isEmpty)
                Material(
                  color: scheme.primaryContainer,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _saving ? null : _pickPhotos,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                      child: Column(
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 40, color: scheme.primary),
                          const SizedBox(height: AppSpacing.sm),
                          Text('Add photos (optional, up to 10)',
                              style: theme.textTheme.labelLarge
                                  ?.copyWith(color: scheme.primary)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (_, i) => _thumb(i),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),

              AppTextField(
                label: 'Title',
                controller: _title,
                hintText: 'e.g. The day we first met',
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Our story (optional)',
                controller: _story,
                hintText: 'What happened? What do you want to remember?',
                maxLength: 4000,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Where (optional)',
                controller: _location,
                hintText: 'e.g. Zambales',
                prefixIcon: Icons.place_outlined,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Date: ${longDate(_date)}',
                icon: Icons.event_outlined,
                variant: AppButtonVariant.outlined,
                onPressed: _saving ? null : _pickDate,
                fullWidth: true,
              ),
              const SizedBox(height: AppSpacing.xl),

              const SectionLabel(text: 'Tags (optional)'),
              TagPicker(
                selected: _tags,
                known: widget.knownTags,
                enabled: !_saving,
                controller: _typedTag,
                onChanged: (t) => setState(() => _tags = t),
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _editing ? 'Save changes' : 'Save memory',
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
