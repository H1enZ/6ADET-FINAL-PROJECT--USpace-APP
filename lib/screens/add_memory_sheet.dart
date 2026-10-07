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
import '../widgets/atoms/us_icon.dart';
import '../widgets/molecules/us_field_button.dart';
import '../widgets/molecules/tag_picker.dart';

/// One photo in the editor: either already saved, or newly picked.
class _EditorPhoto {
  _EditorPhoto.saved(PhotoRef this.saved) : bytes = null, extension = null;
  _EditorPhoto.picked(Uint8List this.bytes, String this.extension)
    : saved = null;

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
    for (final p in widget.memory?.photos ?? const <PhotoRef>[])
      _EditorPhoto.saved(p),
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
      setState(
        () => _error =
            'A memory can have up to ${MemoryService.maxPhotos} photos.',
      );
      return;
    }
    try {
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 1600,
        imageQuality: 85,
      );
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
    final tags = withPendingTag(
      _tags,
      _typedTag.text,
    ); // keep a typed-but-not-added tag
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
          keep: [
            for (final p in _photos)
              if (p.saved != null) p.saved!,
          ],
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

  /// One photo's image, saved or just picked.
  Widget _image(_EditorPhoto p) {
    final scheme = Theme.of(context).colorScheme;
    return p.bytes != null
        ? Image.memory(p.bytes!, fit: BoxFit.cover)
        : (p.saved!.url == null
              ? ColoredBox(color: scheme.surfaceContainerLow)
              : Image.network(p.saved!.url!, fit: BoxFit.cover));
  }

  /// A small round button laid over a photo.
  Widget _overlayButton({
    required String tooltip,
    required UsIconData icon,
    required VoidCallback? onPressed,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: UsIcon(icon, size: 18, color: Colors.white),
    style: IconButton.styleFrom(
      backgroundColor: Colors.black.withValues(alpha: 0.45),
      minimumSize: const Size.square(36),
      fixedSize: const Size.square(36),
    ),
  );

  /// Photos first: a big cover, then the rest in a strip with an add tile.
  Widget _photoSection(ThemeData theme) {
    final scheme = theme.colorScheme;
    final canAdd = _photos.length < MemoryService.maxPhotos && !_saving;

    if (_photos.isEmpty) {
      return Semantics(
        button: true,
        label: 'Add photos, optional, up to ${MemoryService.maxPhotos}',
        excludeSemantics: true,
        child: InkWell(
          onTap: _saving ? null : _pickPhotos,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: CustomPaint(
            painter: _DashedBorder(
              color: scheme.primary.withValues(alpha: 0.5),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary.withValues(alpha: 0.14),
                    ),
                    alignment: Alignment.center,
                    child: UsIcon(
                      UsIcons.addMemory,
                      size: 24,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Add photos', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Optional · up to ${MemoryService.maxPhotos} · the first is the cover',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The cover, large.
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _image(_photos.first),
                Positioned(
                  left: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Cover',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: AppSpacing.xs,
                  top: AppSpacing.xs,
                  child: _overlayButton(
                    tooltip: 'Remove photo',
                    icon: UsIcons.close,
                    onPressed: _saving
                        ? null
                        : () => setState(() => _photos.removeAt(0)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length - 1 + (canAdd ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, j) {
              final i = j + 1;
              if (i >= _photos.length) return _addTile(scheme);
              return SizedBox(
                width: 72,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _image(_photos[i]),
                      Positioned(
                        left: -4,
                        bottom: -4,
                        child: Transform.scale(
                          scale: 0.8,
                          child: _overlayButton(
                            tooltip: 'Make cover',
                            icon: UsIcons.star,
                            onPressed: _saving ? null : () => _makeCover(i),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Transform.scale(
                          scale: 0.8,
                          child: _overlayButton(
                            tooltip: 'Remove photo',
                            icon: UsIcons.close,
                            onPressed: _saving
                                ? null
                                : () => setState(() => _photos.removeAt(i)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _addTile(ColorScheme scheme) => Semantics(
    button: true,
    label: 'Add more photos',
    excludeSemantics: true,
    child: InkWell(
      onTap: _saving ? null : _pickPhotos,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: CustomPaint(
        painter: _DashedBorder(
          color: scheme.primary.withValues(alpha: 0.5),
          radius: AppRadius.input,
        ),
        child: SizedBox(
          width: 72,
          child: Center(
            child: UsIcon(UsIcons.plus, size: 22, color: scheme.primary),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

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
              Text(
                _editing ? 'Edit memory' : 'New memory',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                _editing
                    ? 'Changes show for both of you.'
                    : 'Save a moment you both want to keep.',
                style: muted,
              ),
              const SizedBox(height: AppSpacing.lg),

              _photoSection(theme),
              if (_photos.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${_photos.length} of ${MemoryService.maxPhotos} photos · tap the star to make one the cover',
                  style: muted,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),

              AppTextField(
                label: 'Title',
                controller: _title,
                hintText: 'e.g. The day we first met',
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Our story (optional)',
                controller: _story,
                hintText: 'What happened? What do you want to remember?',
                maxLength: 4000,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.lg),
              UsFieldButton(
                label: 'When',
                value: longDate(_date),
                icon: UsIcons.calendar,
                onTap: _saving ? null : _pickDate,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Where (optional)',
                controller: _location,
                hintText: 'e.g. Zambales',
                usIcon: UsIcons.pin,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
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
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.error,
                  ),
                ),
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

/// Looks like a text field, opens a picker: the memory's date.

/// A soft dashed outline for the empty photo area and the add tile.
class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, this.radius = AppRadius.card});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.75),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}
