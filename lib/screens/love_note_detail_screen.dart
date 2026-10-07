import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/love_note.dart';
import '../services/auth_service.dart';
import '../services/note_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../theme/us_palette.dart';
import '../widgets/atoms/avatar_circle.dart';
import '../widgets/atoms/us_icon.dart';
import '../widgets/effects/floating_hearts.dart';
import '../widgets/effects/motion.dart';
import '../widgets/molecules/us_confirm.dart';
import '../widgets/notes/note_style.dart';
import '../widgets/molecules/us_states.dart';

/// One love note, opened: its photo, then the letter on paper. Closes with
/// `true` when something changed (favourite or deleted), so the list reloads.
///
/// Actions follow the existing rules: either partner can favourite a note,
/// only its author can delete it, and notes can't be edited.
class LoveNoteDetailScreen extends StatefulWidget {
  const LoveNoteDetailScreen({
    super.key,
    required this.note,
    required this.authorName,
    required this.isMine,
    this.authorAvatarUrl,
  });

  final LoveNote note;
  final String authorName;
  final String? authorAvatarUrl;
  final bool isMine;

  @override
  State<LoveNoteDetailScreen> createState() => _LoveNoteDetailScreenState();
}

class _LoveNoteDetailScreenState extends State<LoveNoteDetailScreen> {
  late LoveNote _note = widget.note;
  bool _changed = false;
  bool _busy = false;

  /// A favourite change still saving; further taps wait for it, so saves
  /// can't overlap or roll back to an old state.
  bool _savingFavorite = false;

  void _showMessage(String text, {bool error = false}) =>
      showUsMessage(context, text, error: error);

  Future<void> _toggleFavorite() async {
    if (_savingFavorite || _busy) return;
    final before = _note;
    final value = !before.isFavorite;
    setState(() {
      _note = before.withFavorite(value);
      _changed = true;
      _savingFavorite = true;
    });
    if (value) showFloatingHearts(context);
    try {
      await NoteService.setFavorite(before.id, value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _note = before);
      _showMessage(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _savingFavorite = false);
    }
  }

  Future<void> _delete() async {
    // Only the author deletes (the database enforces it too).
    if (!widget.isMine || _busy) return;
    final ok = await showUsConfirm(
      context,
      title: 'Delete this note?',
      message: 'It will be removed for both of you.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await NoteService.delete(_note.id, photoPath: _note.photoPath);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final note = _note;
    final when = note.unlockAt ?? note.sentAt;
    final hasPhoto = note.photoPath != null;

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: NotePalette.background,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: NotePalette.backgroundTop.withValues(alpha: 0.92),
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'Back',
            icon: const UsIcon(UsIcons.back),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          actions: [
            // Either of you can keep a note as a favourite.
            Semantics(
              toggled: note.isFavorite,
              child: IconButton(
                tooltip: note.isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                onPressed: _busy ? null : _toggleFavorite,
                icon: AnimatedHeartIcon(filled: note.isFavorite),
              ),
            ),
            // Only the author can delete; notes can't be edited.
            if (widget.isMine)
              PopupMenuButton<String>(
                tooltip: 'More',
                enabled: !_busy,
                icon: const UsIcon(UsIcons.more, size: 22),
                onSelected: (_) => _delete(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        UsIcon(UsIcons.trash, size: 20, color: scheme.error),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          'Delete note',
                          style: TextStyle(color: scheme.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        body: NotesBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final photoWidth = math.min(250.0, box.maxWidth * 0.66);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenMargin,
                    AppSpacing.huge,
                    AppSpacing.screenMargin,
                    AppSpacing.xxl,
                  ),
                  children: [
                    if (hasPhoto) ...[
                      Center(
                        child: NotePolaroid(
                          url: note.photoUrl,
                          width: photoWidth,
                          turn: -2.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ] else
                      const SizedBox(height: AppSpacing.md),
                    _Letter(
                      note: note,
                      authorName: widget.authorName,
                      authorAvatarUrl: widget.authorAvatarUrl,
                      when: when,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The note on a sheet of cream / blush paper.
class _Letter extends StatelessWidget {
  const _Letter({
    required this.note,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.when,
  });

  final LoveNote note;
  final String authorName;
  final String? authorAvatarUrl;
  final DateTime when;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = note.title;
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipPath(
        clipper: _PaperEdge(),
        child: CustomPaint(
          painter: _PaperGrain(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.xxl,
              AppSpacing.xxl,
              AppSpacing.xxxl,
            ),
            child: Column(
              children: [
                NoteCategoryBadge(
                  category: note.category,
                  capsule: note.wasCapsule,
                  onPaper: true,
                ),
                if (title != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: NotePalette.display(25, color: NotePalette.ink),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AvatarCircle(
                      name: authorName,
                      imageUrl: authorAvatarUrl,
                      size: 38,
                      background: NotePalette.pink.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From $authorName',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: NotePalette.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            longDate(when),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: NotePalette.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const _Flourish(),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: SelectableText(note.body, style: NotePalette.letter()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin line with two linked hearts in the middle.
class _Flourish extends StatelessWidget {
  const _Flourish();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(
        height: 1,
        color: NotePalette.inkSoft.withValues(alpha: 0.35),
      ),
    );
    return ExcludeSemantics(
      child: Row(
        children: [
          const Spacer(),
          line,
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: NoteCategoryIcon(NoteCategory.love, size: 18),
          ),
          line,
          const Spacer(),
        ],
      ),
    );
  }
}

/// Paper with a slightly uneven edge (fixed, so it never jumps).
class _PaperEdge extends CustomClipper<Path> {
  static const _wobble = [0.0, 1.4, 0.4, 1.8, 0.8, 0.2, 1.6, 0.6, 1.2, 0.0];

  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final p = Path()..moveTo(0, _wobble[0]);
    for (var i = 1; i < _wobble.length; i++) {
      p.lineTo(w * i / (_wobble.length - 1), _wobble[i]);
    }
    for (var i = 1; i < _wobble.length; i++) {
      p.lineTo(w - _wobble[i], h * i / (_wobble.length - 1));
    }
    for (var i = 1; i < _wobble.length; i++) {
      p.lineTo(w - w * i / (_wobble.length - 1), h - _wobble[i]);
    }
    for (var i = 1; i < _wobble.length; i++) {
      p.lineTo(_wobble[i], h - h * i / (_wobble.length - 1));
    }
    return p..close();
  }

  @override
  bool shouldReclip(_PaperEdge old) => false;
}

/// Warm paper: a soft cream-to-blush wash with faint fibres and a darker
/// edge, drawn once (fixed seed).
class _PaperGrain extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [UsPalette.paperLight, UsPalette.paper, UsPalette.paperEdge],
        ).createShader(rect),
    );
    final rnd = math.Random(7);
    final fibre = Paint()
      ..color = NotePalette.paperEdge.withValues(alpha: 0.55)
      ..strokeWidth = 0.8;
    for (var i = 0; i < 70; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final len = 3 + rnd.nextDouble() * 7;
      final a = rnd.nextDouble() * math.pi;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + math.cos(a) * len, y + math.sin(a) * len),
        fibre,
      );
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.1,
          colors: [
            Colors.transparent,
            UsPalette.paperInkSoft.withValues(alpha: 0.14),
          ],
          stops: const [0.75, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_PaperGrain old) => false;
}
