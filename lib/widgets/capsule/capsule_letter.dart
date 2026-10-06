import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/us_palette.dart';
import '../atoms/us_icon.dart';
import '../effects/motion.dart';
import '../notes/note_style.dart';
import 'vintage_parchment.dart';

/// A capsule's contents as the reader sees them: the photo first, its
/// caption right with it, then the letter on cream paper. With [reveal] it
/// arrives in that order (photo, caption, letter unfolding); with reduce
/// motion, or without [reveal], it is simply there.
class CapsuleLetter extends StatefulWidget {
  const CapsuleLetter({
    super.key,
    required this.letter,
    this.title,
    this.caption,
    this.hasPhoto = false,
    this.photo,
    this.photoFailed = false,
    this.onRetryPhoto,
    this.reveal = false,
    this.header,
  });

  final String letter;
  final String? title;
  final String? caption;
  final bool hasPhoto;

  /// The photo's bytes once downloaded (null while loading).
  final Uint8List? photo;
  final bool photoFailed;
  final VoidCallback? onRetryPhoto;
  final bool reveal;

  /// Shown above the photo (sender, dates).
  final Widget? header;

  @override
  State<CapsuleLetter> createState() => _CapsuleLetterState();
}

class _CapsuleLetterState extends State<CapsuleLetter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.reveal || motionOff(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _part(double from, double to) => CurvedAnimation(
    parent: _c,
    curve: Interval(from, to, curve: Curves.easeOutCubic),
  );

  void _openPhoto(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton.filledTonal(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const UsIcon(UsIcons.close, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final photoAnim = _part(0.0, 0.4);
    final captionAnim = _part(0.25, 0.55);
    final letterAnim = _part(0.45, 1.0);
    final hasPhoto = widget.hasPhoto;
    final bytes = widget.photo;

    Widget photo() {
      final Widget inner;
      if (bytes != null) {
        inner = Semantics(
          button: true,
          label: 'Photo. Open it full size',
          child: InkWell(
            onTap: () => _openPhoto(bytes),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        );
      } else if (widget.photoFailed) {
        inner = Center(
          child: TextButton(
            onPressed: widget.onRetryPhoto,
            child: const Text("Couldn't load the photo. Try again"),
          ),
        );
      } else {
        inner = const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: UsPalette.cream,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360, minHeight: 160),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: inner,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?widget.header,
        if (hasPhoto) ...[
          FadeTransition(
            opacity: photoAnim,
            child: ScaleTransition(
              scale: Tween(begin: 0.88, end: 1.0).animate(photoAnim),
              child: photo(),
            ),
          ),
          if (widget.caption != null)
            FadeTransition(
              opacity: captionAnim,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  widget.caption!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
        FadeTransition(
          opacity: letterAnim,
          child: SizeTransition(
            sizeFactor: letterAnim,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: double.infinity,
              // The same aged parchment and pen script as the opened letter.
              child: VintageParchment(
                seed: widget.letter.length,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.title != null) ...[
                      Text(
                        widget.title!,
                        style: NotePalette.display(24, color: UsPalette.sepia),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    SelectableText(
                      widget.letter,
                      style: AppTypography.capsuleHand(color: UsPalette.sepia),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
