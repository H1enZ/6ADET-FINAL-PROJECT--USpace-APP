import 'package:flutter/material.dart';

import '../../models/scrapbook.dart';
import '../../theme/app_spacing.dart';
import '../notes/note_style.dart';
import 'scrap_frames.dart';
import 'scrapbook_layout.dart';
import '../../theme/us_palette.dart';
import '../atoms/us_icon.dart';

/// The compact editing toolbar shown while arranging the scrapbook (Undo
/// and Arrange sit in the header).
class ScrapEditToolbar extends StatelessWidget {
  const ScrapEditToolbar({
    super.key,
    required this.hasSelection,
    required this.connecting,
    required this.saving,
    required this.onFrame,
    required this.onSize,
    required this.onTurn,
    required this.onLayer,
    required this.onConnect,
    required this.onDone,
    required this.onAdd,
    this.onEditMemory,
    this.deco = false,
    this.onEditNote,
    this.onColor,
    this.onDelete,
  });

  /// Add a memory, sticky note, sticker, tape or doodle.
  final VoidCallback onAdd;

  /// The selected memory's own editor (null when none is selected).
  final VoidCallback? onEditMemory;

  /// A decoration is selected: its own tools replace the memory tools.
  final bool deco;
  final VoidCallback? onEditNote;
  final VoidCallback? onColor;
  final VoidCallback? onDelete;

  final bool hasSelection;
  final bool connecting;
  final bool saving;
  final VoidCallback onFrame;
  final VoidCallback onSize;
  final VoidCallback onTurn;
  final VoidCallback onLayer;
  final VoidCallback onConnect;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    Widget tool(
      String label,
      UsIconData icon,
      VoidCallback? onTap, {
      bool on = false,
    }) {
      final color = onTap == null
          ? NotePalette.muted.withValues(alpha: 0.35)
          : (on ? NotePalette.rose : NotePalette.cream);
      return Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: narrow ? 8 : 10,
              vertical: 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UsIcon(icon, size: 21, color: color),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: UsPalette.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NotePalette.pink.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  tool('Add', UsIcons.plus, onAdd),
                  if (deco) ...[
                    if (onEditNote != null)
                      tool('Write', UsIcons.note, onEditNote),
                    if (onColor != null)
                      tool('Colour', UsIcons.palette, onColor),
                    tool('Turn', UsIcons.rotate, onTurn),
                    tool('Layer', UsIcons.layers, onLayer),
                    tool('Delete', UsIcons.trash, onDelete),
                  ] else ...[
                    if (onEditMemory != null)
                      tool('Edit', UsIcons.edit, onEditMemory),
                    tool(
                      'Frame',
                      UsIcons.frame,
                      hasSelection ? onFrame : null,
                    ),
                    tool(
                      'Size',
                      UsIcons.resize,
                      hasSelection ? onSize : null,
                    ),
                    tool(
                      'Turn',
                      UsIcons.rotate,
                      hasSelection ? onTurn : null,
                    ),
                    tool(
                      'Layer',
                      UsIcons.layers,
                      hasSelection ? onLayer : null,
                    ),
                    tool(
                      'Connect',
                      UsIcons.link,
                      hasSelection || connecting ? onConnect : null,
                      on: connecting,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilledButton(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                backgroundColor: NotePalette.rose,
                foregroundColor: UsPalette.onRose,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: UsPalette.onRose,
                      ),
                    )
                  : const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<T?> _sheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
}) => showModalBottomSheet<T>(
  context: context,
  showDragHandle: true,
  backgroundColor: NotePalette.card,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        0,
        AppSpacing.screenMargin,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: NotePalette.display(20)),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    ),
  ),
);

/// The frame picker: the memory itself, drawn small in every frame that
/// suits it. Resolves with the chosen frame (null = automatic), or with
/// nothing when dismissed.
Future<({FrameStyle? frame})?> pickFrame(
  BuildContext context,
  ScrapPiece piece,
) {
  final options = FrameStyle.forKind(piece.kind);
  final auto = autoFrameOf(piece.memory, piece.seed);
  final current = piece.item.frame;
  return _sheet<({FrameStyle? frame})>(
    context,
    title: 'Choose a frame',
    child: Wrap(
      spacing: 10,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (final f in options)
          _FrameTile(
            piece: piece,
            frame: f,
            label: f == auto ? '${f.label} (auto)' : f.label,
            selected: (current ?? auto) == f,
            onTap: () =>
                Navigator.of(context).pop((frame: f == auto ? null : f)),
          ),
      ],
    ),
  );
}

class _FrameTile extends StatelessWidget {
  const _FrameTile({
    required this.piece,
    required this.frame,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ScrapPiece piece;
  final FrameStyle frame;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const previewWidth = 170.0;
    final h = ScrapbookLayout.frameHeight(frame, previewWidth, piece.memory);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label frame',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 100,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? NotePalette.rose.withValues(alpha: 0.16)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? NotePalette.rose
                  : NotePalette.pink.withValues(alpha: 0.2),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 108,
                child: Center(
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: IgnorePointer(
                        child: ScrapFrame(
                          memory: piece.memory,
                          frame: frame,
                          size: Size(previewWidth, h),
                          seed: piece.seed,
                          decodeWidth: 240,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: NotePalette.cream,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small / Medium / Large. Resolves with the new width.
Future<double?> pickSize(BuildContext context, ScrapPiece piece) {
  final presets = ScrapbookLayout.presetWidths(piece.kind);
  const names = ['Small', 'Medium', 'Large'];
  final now = piece.item.width;
  return _sheet<double>(
    context,
    title: 'Size',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(presets[i]),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NotePalette.cream,
                    backgroundColor: (now - presets[i]).abs() < 12
                        ? NotePalette.rose.withValues(alpha: 0.18)
                        : null,
                    side: BorderSide(
                      color: NotePalette.pink.withValues(alpha: 0.4),
                    ),
                    minimumSize: const Size(0, 48),
                  ),
                  child: Text(names[i]),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Or drag the corner handle for an exact size.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: NotePalette.muted),
        ),
      ],
    ),
  );
}

/// A gentle tilt, -6° to 6°. [onPreview] follows the slider; the sheet
/// resolves with the final angle.
Future<double?> pickTurn(
  BuildContext context,
  double start,
  void Function(double) onPreview, {
  double limit = LayoutItem.maxRotation,
}) {
  var value = start;
  return _sheet<double>(
    context,
    title: 'Turn',
    child: StatefulBuilder(
      builder: (context, setSheet) {
        void set(double v) {
          v = v.clamp(-limit, limit);
          if (v.abs() < 0.4) v = 0;
          setSheet(() => value = v);
          onPreview(v);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Turn left',
                  onPressed: () => set(value - 1),
                  icon: const Icon(
                    Icons.rotate_left_rounded,
                    color: NotePalette.cream,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: value,
                    min: -limit,
                    max: limit,
                    divisions: (limit * 4).round(),
                    label: '${value.toStringAsFixed(1)}°',
                    activeColor: NotePalette.rose,
                    onChanged: set,
                  ),
                ),
                IconButton(
                  tooltip: 'Turn right',
                  onPressed: () => set(value + 1),
                  icon: const Icon(
                    Icons.rotate_right_rounded,
                    color: NotePalette.cream,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => set(0),
                  style: TextButton.styleFrom(
                    foregroundColor: NotePalette.pink,
                  ),
                  child: const Text('Straighten'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(value),
                  style: FilledButton.styleFrom(
                    backgroundColor: NotePalette.rose,
                    foregroundColor: UsPalette.onRose,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

enum LayerAction { front, forward, backward, back }

Future<LayerAction?> pickLayer(BuildContext context) => _sheet<LayerAction>(
  context,
  title: 'Layer',
  child: Column(
    children: [
      for (final (a, label, icon) in const [
        (LayerAction.front, 'Bring to front', Icons.flip_to_front_rounded),
        (LayerAction.forward, 'Bring forward', Icons.arrow_upward_rounded),
        (LayerAction.backward, 'Send backward', Icons.arrow_downward_rounded),
        (LayerAction.back, 'Send to back', Icons.flip_to_back_rounded),
      ])
        ListTile(
          leading: Icon(icon, color: NotePalette.pink),
          title: Text(label, style: const TextStyle(color: NotePalette.cream)),
          onTap: () => Navigator.of(context).pop(a),
        ),
    ],
  ),
);

enum ArrangeAction { organize, resetItem, resetPositions, resetAll }

Future<ArrangeAction?> pickArrange(
  BuildContext context, {
  required bool hasSelection,
}) => _sheet<ArrangeAction>(
  context,
  title: 'Arrange',
  child: Column(
    children: [
      for (final (a, label, sub, icon) in [
        (
          ArrangeAction.organize,
          'Organize by date',
          'Newest first, grouped by year and month',
          Icons.event_note_rounded,
        ),
        if (hasSelection)
          (
            ArrangeAction.resetItem,
            'Reset this memory',
            'Back to its date spot, size, tilt and automatic frame',
            Icons.restart_alt_rounded,
          ),
        (
          ArrangeAction.resetPositions,
          'Reset positions',
          'Date order again; keeps chosen frames and connections',
          Icons.grid_view_rounded,
        ),
        (
          ArrangeAction.resetAll,
          'Reset all scrapbook styling',
          'Positions, sizes, tilts and frames back to automatic',
          Icons.layers_clear_outlined,
        ),
      ])
        ListTile(
          leading: Icon(icon, color: NotePalette.pink),
          title: Text(label, style: const TextStyle(color: NotePalette.cream)),
          subtitle: Text(
            sub,
            style: const TextStyle(color: NotePalette.muted, fontSize: 12),
          ),
          onTap: () => Navigator.of(context).pop(a),
        ),
    ],
  ),
);

/// A connection's heart was tapped: change its style or remove it.
Future<({ConnectionStyle? style, bool remove})?> pickLink(
  BuildContext context,
  ScrapConnection link,
) => _sheet<({ConnectionStyle? style, bool remove})>(
  context,
  title: 'Connection',
  child: Column(
    children: [
      for (final s in ConnectionStyle.values)
        ListTile(
          leading: SizedBox(
            width: 56,
            height: 24,
            child: CustomPaint(painter: _StyleSample(s)),
          ),
          title: Text(
            s.label,
            style: const TextStyle(color: NotePalette.cream),
          ),
          trailing: link.style == s
              ? const Icon(Icons.check_rounded, color: NotePalette.rose)
              : null,
          onTap: () => Navigator.of(context).pop((style: s, remove: false)),
        ),
      const Divider(color: NotePalette.border),
      ListTile(
        leading: const Icon(Icons.link_off_rounded, color: NotePalette.pink),
        title: const Text(
          'Remove connection',
          style: TextStyle(color: NotePalette.cream),
        ),
        onTap: () => Navigator.of(context).pop((style: null, remove: true)),
      ),
    ],
  ),
);

class _StyleSample extends CustomPainter {
  _StyleSample(this.style);

  final ConnectionStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    switch (style) {
      case ConnectionStyle.dotted:
        final p = Paint()
          ..color = NotePalette.rose
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        for (var x = 0.0; x < size.width; x += 8) {
          canvas.drawLine(Offset(x, y), Offset(x + 3, y), p);
        }
      case ConnectionStyle.ribbon:
        final path = Path()
          ..moveTo(0, y - 4)
          ..quadraticBezierTo(size.width / 2, y + 10, size.width, y - 4);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = NotePalette.deepRose,
        );
      case ConnectionStyle.hearts:
        final p = Paint()..color = NotePalette.rose;
        for (var x = 6.0; x < size.width; x += 14) {
          canvas.drawCircle(Offset(x - 2, y - 1), 2.6, p);
          canvas.drawCircle(Offset(x + 2, y - 1), 2.6, p);
          canvas.drawPath(
            Path()
              ..moveTo(x - 4.6, y)
              ..lineTo(x + 4.6, y)
              ..lineTo(x, y + 5)
              ..close(),
            p,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_StyleSample old) => old.style != style;
}

/// "Arrange your scrapbook by date?" and the two resets.
Future<bool> confirmArrange(BuildContext context, ArrangeAction action) async {
  final (title, body, ok) = switch (action) {
    ArrangeAction.organize => (
      'Arrange your scrapbook by date?',
      'Your frame styles, captions and memories will stay. Their positions will be reorganized chronologically.',
      'Organize',
    ),
    ArrangeAction.resetPositions => (
      'Reset positions?',
      'Memories go back to date order with their automatic size and tilt. Chosen frames, connections and memories stay.',
      'Reset positions',
    ),
    ArrangeAction.resetAll => (
      'Reset all scrapbook styling?',
      'Positions, sizes, tilts, layers and chosen frames go back to automatic. Your memories, photos, captions and connections stay.',
      'Reset styling',
    ),
    ArrangeAction.resetItem => (
      'Reset this memory?',
      'It goes back to its date spot, size, tilt and automatic frame.',
      'Reset',
    ),
  };
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return yes == true;
}
