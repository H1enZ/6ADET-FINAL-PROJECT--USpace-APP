import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/love_note.dart';
import '../services/auth_service.dart';
import '../services/memory_service.dart';
import '../services/note_service.dart';
import '../theme/app_effects.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/section_label.dart';
import '../widgets/atoms/us_icon.dart';
import '../widgets/effects/motion.dart';
import '../widgets/notes/note_style.dart';

/// Opens Write a Love Note. True once the note was sent.
Future<bool> openWriteLoveNote(
  BuildContext context, {
  required String coupleId,
  required String partnerName,
  NoteCategory initial = NoteCategory.justBecause,
}) async {
  final sent = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => WriteLoveNoteScreen(
        coupleId: coupleId,
        partnerName: partnerName,
        initial: initial,
      ),
    ),
  );
  return sent == true;
}

/// Write a love note: its type, an optional photo and title, and the note.
/// Closes with `true` once sent. (Time Capsules have their own screen.)
class WriteLoveNoteScreen extends StatefulWidget {
  const WriteLoveNoteScreen({
    super.key,
    required this.coupleId,
    required this.partnerName,
    this.initial = NoteCategory.justBecause,
  });

  final String coupleId;
  final String partnerName;
  final NoteCategory initial;

  @override
  State<WriteLoveNoteScreen> createState() => _WriteLoveNoteScreenState();
}

class _WriteLoveNoteScreenState extends State<WriteLoveNoteScreen> {
  static const _titleMax = 40;
  static const _bodyMax = 500;

  final _title = TextEditingController();
  final _body = TextEditingController();
  late NoteCategory _category = widget.initial;
  NewPhoto? _photo;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
    } catch (e) {
      setState(() => _error = friendlyError(e));
      return;
    }
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final dot = file.name.lastIndexOf('.');
    final ext = dot == -1 ? 'jpg' : file.name.substring(dot + 1);
    if (!mounted) return;
    setState(() {
      _photo = NewPhoto(bytes, ext);
      _error = null;
    });
  }

  Future<void> _send() async {
    if (_body.text.trim().isEmpty) {
      setState(() => _error = 'Write your note first.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await NoteService.send(
        coupleId: widget.coupleId,
        body: _body.text,
        title: _title.text,
        category: _category,
        photo: _photo,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: NotePalette.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // Solid enough that the form doesn't show through as it scrolls.
        backgroundColor: NotePalette.backgroundTop.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          icon: const UsIcon(UsIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: NotesBackground(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.huge,
              AppSpacing.screenMargin,
              MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xxl,
            ),
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Write a love note',
                  style: NotePalette.display(30),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                "Say what's on your heart.",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: NotePalette.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              const SectionLabel(text: 'Note type'),
              _TypePicker(
                selected: _category,
                onSelect: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: AppSpacing.xxl),

              const SectionLabel(text: 'Photo (optional)'),
              _PhotoPicker(
                bytes: _photo?.bytes,
                onPick: _sending ? null : _pickPhoto,
                onRemove: _sending ? null : () => setState(() => _photo = null),
              ),
              const SizedBox(height: AppSpacing.xxl),

              const SectionLabel(text: 'Title (optional)'),
              _NoteField(
                controller: _title,
                hint: 'Give your note a title...',
                maxLength: _titleMax,
                maxLines: 1,
              ),
              const SizedBox(height: AppSpacing.lg),

              const SectionLabel(text: 'Your note'),
              _NoteField(
                controller: _body,
                hint: 'Write your love note...',
                maxLength: _bodyMax,
                maxLines: 7,
                minLines: 6,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Send love note',
                usIcon: UsIcons.send,
                fullWidth: true,
                isLoading: _sending,
                onPressed: _send,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Only you and ${widget.partnerName} can see it.',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: NotePalette.muted,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The five note types as quiet pills that wrap, so all of them show at
/// once. The chosen one fills dusty rose and shows a check.
class _TypePicker extends StatelessWidget {
  const _TypePicker({required this.selected, required this.onSelect});

  final NoteCategory selected;
  final ValueChanged<NoteCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in NoteCategory.values)
          Builder(
            builder: (context) {
              final on = c == selected;
              final fg = on ? scheme.onPrimary : scheme.onSurface;
              return Semantics(
                button: true,
                selected: on,
                label: c.label,
                excludeSemantics: true,
                child: AnimatedContainer(
                  duration: motionOff(context) ? Duration.zero : AppMotion.quick,
                  curve: AppMotion.snappy,
                  decoration: ShapeDecoration(
                    color: on
                        ? scheme.primary
                        : scheme.primary.withValues(alpha: 0.12),
                    shape: const StadiumBorder(),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => onSelect(c),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(on ? 10 : 14, 8, 14, 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (on) ...[
                                UsIcon(UsIcons.check, size: 14, color: fg),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                c.label,
                                style: theme.textTheme.bodyMedium?.copyWith(
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
            },
          ),
      ],
    );
  }
}

/// A dashed drop area, or the chosen photo with a remove button.
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.bytes,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picked = bytes;
    if (picked != null) {
      return Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Image.memory(picked, height: 180, fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: NotePalette.card,
                shape: const CircleBorder(
                  side: BorderSide(color: NotePalette.borderBright),
                ),
                child: IconButton(
                  tooltip: 'Remove photo',
                  onPressed: onRemove,
                  icon: const UsIcon(
                    UsIcons.close,
                    color: NotePalette.cream,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Semantics(
      button: true,
      label: 'Add a photo. Make it more special',
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: _DashedBorder(),
        child: Material(
          color: NotePalette.card,
          borderRadius: BorderRadius.circular(AppRadius.panel),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.panel),
            onTap: onPick,
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const UsIcon(UsIcons.image, size: 32, color: NotePalette.pink),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Add a photo',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: NotePalette.pink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Make it more special',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: NotePalette.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          const Radius.circular(AppRadius.panel),
        ),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = NotePalette.rose.withValues(alpha: 0.7);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 13) {
        canvas.drawPath(metric.extractPath(d, d + 7), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => false;
}

/// A form field in the app's standard style. Its limit is always
/// enforced; the count only shows once you are near it (80%).
class _NoteField extends StatelessWidget {
  const _NoteField({
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.maxLines,
    this.minLines,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int maxLines;
  final int? minLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: minLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(hintText: hint),
      buildCounter:
          (context, {required currentLength, required isFocused, maxLength}) {
            final max = maxLength;
            if (max == null || currentLength < max * 0.8) return null;
            return Text(
              '$currentLength / $max',
              style: theme.textTheme.labelSmall?.copyWith(
                color: currentLength >= max
                    ? theme.colorScheme.error
                    : NotePalette.muted,
              ),
            );
          },
    );
  }
}
