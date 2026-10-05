import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../effects/motion.dart';
import '../notes/note_style.dart';

/// An opened capsule as the reader sees it: the photo first, large and
/// glowing, its caption, a quiet heart divider, then the letter on blush
/// paper with a small signature. With [reveal] they arrive in that order;
/// with reduce motion, or without [reveal], they are simply there.
///
/// Only the opened view uses this; the composer's preview keeps
/// CapsuleLetter.
class OpenedCapsule extends StatefulWidget {
  const OpenedCapsule({
    super.key,
    required this.letter,
    required this.signature,
    this.title,
    this.caption,
    this.hasPhoto = false,
    this.photo,
    this.photoFailed = false,
    this.onRetryPhoto,
    this.reveal = false,
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

  /// The small sign-off at the end of the letter: who wrote it and when.
  final ({String name, DateTime written})? signature;

  @override
  State<OpenedCapsule> createState() => _OpenedCapsuleState();
}

class _OpenedCapsuleState extends State<OpenedCapsule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _started = false;

  /// The photo's width / height, so it is shown whole, never cropped.
  double? _aspect;
  Uint8List? _measured;

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
  void didUpdateWidget(OpenedCapsule old) {
    super.didUpdateWidget(old);
    _measure();
  }

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    final bytes = widget.photo;
    if (bytes == null || identical(bytes, _measured)) return;
    _measured = bytes;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final aspect = image.width / image.height;
      image.dispose();
      codec.dispose();
      if (mounted && identical(bytes, widget.photo)) {
        setState(() => _aspect = aspect);
      }
    } catch (_) {
      // Shown at a pleasant default shape instead.
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
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo(BuildContext context) {
    final bytes = widget.photo;
    const frame = 7.0;
    const radius = 26.0;
    return LayoutBuilder(
      builder: (context, box) {
        final maxHeight = MediaQuery.sizeOf(context).height * 0.6;
        final aspect = (_aspect ?? 4 / 3).clamp(0.5, 2.4);
        // Full width unless that would make it too tall; then narrower,
        // still whole.
        final inner = box.maxWidth - frame * 2;
        final width = (inner / aspect > maxHeight ? maxHeight * aspect : inner)
            .clamp(120.0, inner);

        final Widget content;
        if (bytes != null) {
          content = Semantics(
            button: true,
            label: 'Photo. Open it full size',
            child: GestureDetector(
              onTap: () => _openPhoto(bytes),
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          );
        } else if (widget.photoFailed) {
          content = ColoredBox(
            color: NotePalette.card,
            child: Center(
              child: TextButton.icon(
                onPressed: widget.onRetryPhoto,
                style: TextButton.styleFrom(foregroundColor: NotePalette.pink),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Couldn't load the photo. Try again"),
              ),
            ),
          );
        } else {
          content = const ColoredBox(
            color: NotePalette.card,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: NotePalette.pink,
              ),
            ),
          );
        }

        return Center(
          child: Container(
            width: width + frame * 2,
            padding: const EdgeInsets.all(frame),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1EC),
              borderRadius: BorderRadius.circular(radius + frame),
              boxShadow: [
                BoxShadow(
                  color: NotePalette.rose.withValues(alpha: 0.30),
                  blurRadius: 30,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: AspectRatio(aspectRatio: aspect, child: content),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoAnim = _part(0.0, 0.4);
    final captionAnim = _part(0.25, 0.55);
    final letterAnim = _part(0.45, 1.0);
    final caption = widget.caption?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.hasPhoto) ...[
          const SizedBox(height: AppSpacing.md),
          FadeTransition(
            opacity: photoAnim,
            child: ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.0).animate(photoAnim),
              child: _photo(context),
            ),
          ),
          FadeTransition(
            opacity: captionAnim,
            child: Column(
              children: [
                if (caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      0,
                    ),
                    child: Text(
                      caption,
                      textAlign: TextAlign.center,
                      style: NotePalette.letter(
                        color: NotePalette.muted,
                      ).copyWith(fontStyle: FontStyle.italic, fontSize: 17),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                const _HeartRule(
                  color: NotePalette.pink,
                  lineAlpha: 0.35,
                  filled: false,
                  maxWidth: 260,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
        FadeTransition(
          opacity: letterAnim,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(letterAnim),
            child: _Paper(
              title: widget.title,
              letter: widget.letter,
              signature: widget.signature,
            ),
          ),
        ),
      ],
    );
  }
}

/// A thin line, a small heart, a thin line: a quiet pause.
class _HeartRule extends StatelessWidget {
  const _HeartRule({
    required this.color,
    required this.lineAlpha,
    required this.filled,
    this.maxWidth = double.infinity,
  });

  final Color color;
  final double lineAlpha;
  final bool filled;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    Widget line(bool toRight) => Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: toRight ? 0 : lineAlpha),
              color.withValues(alpha: toRight ? lineAlpha : 0),
            ],
          ),
        ),
      ),
    );
    return ExcludeSemantics(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Row(
            children: [
              line(true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Icon(
                  filled
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 16,
                  color: color.withValues(alpha: 0.9),
                ),
              ),
              line(false),
            ],
          ),
        ),
      ),
    );
  }
}

/// The letter on blush paper: a second sheet peeking out behind, a thin
/// inner border, a small heart at the top and a faint flower in the corner.
class _Paper extends StatelessWidget {
  const _Paper({
    required this.title,
    required this.letter,
    required this.signature,
  });

  final String? title;
  final String letter;
  final ({String name, DateTime written})? signature;

  static const _paperTop = Color(0xFFFCF1EC);
  static const _paperBottom = Color(0xFFF6E2DD);
  static const _sheetBehind = Color(0xFFE3C3BC);
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final pad = narrow ? 22.0 : 30.0;
    final heading = title?.trim() ?? '';
    final sign = signature;
    const radius = 22.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The sheet behind, peeking out by a fixed few pixels (a turn
          // would grow into a wedge on long letters).
          Positioned(
            left: -6,
            right: 4,
            top: 7,
            bottom: -7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _sheetBehind,
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_paperTop, _paperBottom],
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: NotePalette.paperEdge),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.40),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Stack(
              children: [
                // A thin inner border, like printed stationery.
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius - 8),
                        border: Border.all(
                          color: NotePalette.rose.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                  ),
                ),
                // A faint flower in the lower corner.
                Positioned(
                  right: 18,
                  bottom: 16,
                  child: ExcludeSemantics(
                    child: Icon(
                      Icons.local_florist_outlined,
                      size: 44,
                      color: NotePalette.rose.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _HeartRule(
                        color: NotePalette.rose,
                        lineAlpha: 0.4,
                        filled: true,
                        maxWidth: 220,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (heading.isNotEmpty) ...[
                        Text(
                          heading,
                          style: NotePalette.display(
                            narrow ? 25 : 28,
                            color: NotePalette.ink,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      SelectableText(
                        letter,
                        style: NotePalette.letter().copyWith(
                          fontSize: 17.5,
                          height: 1.75,
                        ),
                      ),
                      if (sign != null) ...[
                        const SizedBox(height: AppSpacing.xxl),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 40),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'With love,',
                                  style:
                                      NotePalette.letter(
                                        color: NotePalette.inkSoft,
                                      ).copyWith(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 15,
                                      ),
                                ),
                                Text(
                                  sign.name,
                                  style: NotePalette.letter(
                                    color: NotePalette.ink,
                                  ).copyWith(fontSize: 16),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_months[sign.written.month - 1]} '
                                  '${sign.written.day}, ${sign.written.year}',
                                  style: NotePalette.letter(
                                    color: NotePalette.inkSoft,
                                  ).copyWith(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
