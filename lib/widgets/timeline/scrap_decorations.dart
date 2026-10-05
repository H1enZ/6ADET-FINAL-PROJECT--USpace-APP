import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/scrap_decoration.dart';
import '../notes/note_style.dart';
import 'scrap_frames.dart';

// ------------------------------------------------------------- catalogues

/// A sticker: an icon on a white die-cut, or a short word badge.
class StickerDef {
  const StickerDef(
    this.id,
    this.label, {
    this.icon,
    this.word,
    required this.color,
  });

  final String id;
  final String label;
  final IconData? icon;
  final String? word;
  final Color color;
}

const stickers = [
  StickerDef(
    'heart',
    'Heart',
    icon: Icons.favorite_rounded,
    color: Color(0xFFEF6F98),
  ),
  StickerDef(
    'star',
    'Star',
    icon: Icons.star_rounded,
    color: Color(0xFFF2B84B),
  ),
  StickerDef(
    'sparkle',
    'Sparkle',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFFE7A6D8),
  ),
  StickerDef(
    'flower',
    'Flower',
    icon: Icons.local_florist_rounded,
    color: Color(0xFFF28DB2),
  ),
  StickerDef(
    'sun',
    'Sun',
    icon: Icons.wb_sunny_rounded,
    color: Color(0xFFF5B342),
  ),
  StickerDef(
    'moon',
    'Moon',
    icon: Icons.nightlight_round,
    color: Color(0xFFB9A4F0),
  ),
  StickerDef(
    'music',
    'Music',
    icon: Icons.music_note_rounded,
    color: Color(0xFF9C7BE3),
  ),
  StickerDef(
    'camera',
    'Camera',
    icon: Icons.photo_camera_rounded,
    color: Color(0xFF8C6E7E),
  ),
  StickerDef(
    'plane',
    'Plane',
    icon: Icons.flight_rounded,
    color: Color(0xFF6FA8DC),
  ),
  StickerDef(
    'coffee',
    'Coffee',
    icon: Icons.coffee_rounded,
    color: Color(0xFFB07A5A),
  ),
  StickerDef(
    'cake',
    'Cake',
    icon: Icons.cake_rounded,
    color: Color(0xFFF08FA8),
  ),
  StickerDef(
    'ring',
    'Ring',
    icon: Icons.diamond_rounded,
    color: Color(0xFF7EC8E3),
  ),
  StickerDef(
    'letter',
    'Letter',
    icon: Icons.mail_rounded,
    color: Color(0xFFE88AA6),
  ),
  StickerDef('xo', 'XO', word: 'XO', color: Color(0xFFC23F66)),
  StickerDef(
    'love_you',
    'Love you',
    word: 'love you',
    color: Color(0xFFEF6F98),
  ),
  StickerDef('us', 'Us', word: 'us', color: Color(0xFF9C5BA8)),
];

StickerDef stickerOf(String id) =>
    stickers.firstWhere((s) => s.id == id, orElse: () => stickers.first);

/// Washi tape patterns.
const tapePatterns = [
  ('solid', 'Plain'),
  ('stripes', 'Stripes'),
  ('dots', 'Dots'),
  ('hearts', 'Hearts'),
  ('gingham', 'Gingham'),
];

/// Tape colours: the USpace pinks, creams and lavenders.
const tapeColors = [
  Color(0xFFF2C4CF),
  Color(0xFFEFA3B8),
  Color(0xFFE9D6C4),
  Color(0xFFD7C6F0),
  Color(0xFFBFE3D2),
  Color(0xFFF6DDA0),
];

/// Pre-made doodle shapes.
const doodles = [
  ('heart', 'Heart'),
  ('hearts', 'Little hearts'),
  ('arrow', 'Arrow'),
  ('swirl', 'Swirl'),
  ('star', 'Star'),
  ('sparkles', 'Sparkles'),
  ('underline', 'Underline'),
  ('circle', 'Circle'),
];

/// Doodle ink colours.
const doodleColors = [
  Color(0xFFF6A9C1),
  Color(0xFFEF6F98),
  Color(0xFFFFF3EC),
  Color(0xFFF2B84B),
  Color(0xFFB9A4F0),
];

/// The colours offered when recolouring a decoration of [kind].
List<Color> colorsFor(DecoKind kind) => switch (kind) {
  DecoKind.stickyNote => stickyColors,
  DecoKind.tape => tapeColors,
  DecoKind.doodle => doodleColors,
  DecoKind.sticker => const [],
};

// ------------------------------------------------------------- drawing

/// One decoration, drawn to fill [size].
class DecorationView extends StatelessWidget {
  const DecorationView({
    super.key,
    required this.decoration,
    required this.size,
  });

  final ScrapDecoration decoration;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final d = decoration;
    final child = switch (d.kind) {
      DecoKind.stickyNote => StickyPaper(
        color: d.color ?? stickyColors.first,
        size: size,
        child: Text(
          d.body ?? '',
          overflow: TextOverflow.fade,
          style: scrapHand(19 * (size.width / 150).clamp(0.85, 1.5)),
        ),
      ),
      DecoKind.sticker => _Sticker(def: stickerOf(d.variant), size: size),
      DecoKind.tape => CustomPaint(
        size: size,
        painter: _TapePainter(d.variant, d.color ?? tapeColors.first),
      ),
      DecoKind.doodle => CustomPaint(
        size: size,
        painter: _DoodlePainter(d.variant, d.color ?? doodleColors.first),
      ),
    };
    return SizedBox.fromSize(size: size, child: child);
  }
}

class _Sticker extends StatelessWidget {
  const _Sticker({required this.def, required this.size});

  final StickerDef def;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final s = math.min(size.width, size.height);
    final word = def.word;
    if (word != null) {
      // A word badge: white die-cut edge around a coloured pill, always
      // on one line, shrunk to fit the sticker.
      return Center(
        child: FittedBox(
          child: Container(
            padding: EdgeInsets.all(s * 0.05),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(s),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: s * 0.16,
                vertical: s * 0.04,
              ),
              decoration: BoxDecoration(
                color: def.color,
                borderRadius: BorderRadius.circular(s),
              ),
              child: Text(
                word,
                maxLines: 1,
                softWrap: false,
                style: GoogleFonts.caveat(
                  fontSize: s * 0.42,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }
    // An icon with a thick white die-cut outline and a soft shadow.
    final outline = s * 0.05;
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            def.icon,
            size: s * 0.86,
            color: Colors.white,
            shadows: [
              for (var a = 0; a < 8; a++)
                Shadow(
                  color: Colors.white,
                  offset: Offset(
                    math.cos(a * math.pi / 4) * outline,
                    math.sin(a * math.pi / 4) * outline,
                  ),
                ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: s * 0.08,
                offset: Offset(0, s * 0.05),
              ),
            ],
          ),
          Icon(def.icon, size: s * 0.8, color: def.color),
        ],
      ),
    );
  }
}

class _TapePainter extends CustomPainter {
  _TapePainter(this.pattern, this.color);

  final String pattern;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Torn, zigzag ends.
    final tooth = math.min(4.0, h / 5);
    final path = Path()..moveTo(tooth, 0);
    path.lineTo(w - tooth, 0);
    for (var y = 0.0; y < h; y += tooth * 2) {
      path.lineTo(w, y + tooth);
      path.lineTo(w - tooth, math.min(y + tooth * 2, h));
    }
    path.lineTo(tooth, h);
    for (var y = h; y > 0; y -= tooth * 2) {
      path.lineTo(0, y - tooth);
      path.lineTo(tooth, math.max(y - tooth * 2, 0));
    }
    path.close();
    canvas.drawShadow(path, Colors.black, 2, false);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: 0.88),
    );
    final ink = Paint()
      ..color = Color.lerp(color, Colors.white, 0.55)!.withValues(alpha: 0.85);
    final dark = Paint()
      ..color = Color.lerp(
        color,
        const Color(0xFF7A3550),
        0.35,
      )!.withValues(alpha: 0.55);
    switch (pattern) {
      case 'stripes':
        ink.strokeWidth = h * 0.18;
        for (var x = -h; x < w + h; x += h * 0.55) {
          canvas.drawLine(Offset(x, h), Offset(x + h, 0), ink);
        }
      case 'dots':
        for (var x = h * 0.3; x < w; x += h * 0.6) {
          for (var y = h * 0.25; y < h; y += h * 0.5) {
            final offset = ((y / (h * 0.5)).round().isOdd) ? h * 0.3 : 0.0;
            canvas.drawCircle(Offset(x + offset, y), h * 0.09, dark);
          }
        }
      case 'hearts':
        for (var x = h * 0.4; x < w; x += h * 0.9) {
          canvas.drawPath(
            _heart(
              Rect.fromCenter(
                center: Offset(x, h / 2),
                width: h * 0.42,
                height: h * 0.42,
              ),
            ),
            dark,
          );
        }
      case 'gingham':
        final band = h / 4;
        final g = Paint()..color = Colors.white.withValues(alpha: 0.32);
        for (var x = 0.0; x < w; x += band * 2) {
          canvas.drawRect(Rect.fromLTWH(x, 0, band, h), g);
        }
        for (var y = 0.0; y < h; y += band * 2) {
          canvas.drawRect(Rect.fromLTWH(0, y, w, band), g);
        }
    }
    // A soft sheen along the top.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.35),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TapePainter old) =>
      old.pattern != pattern || old.color != color;
}

class _DoodlePainter extends CustomPainter {
  _DoodlePainter(this.shape, this.color);

  final String shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final s = math.min(w, h);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, s * 0.035)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final fill = Paint()..color = color;
    final c = Offset(w / 2, h / 2);
    switch (shape) {
      case 'heart':
        // Drawn twice, slightly offset: a hand-drawn line.
        final r = Rect.fromCenter(center: c, width: s * 0.82, height: s * 0.82);
        canvas.drawPath(_heart(r), pen);
        canvas.drawPath(
          _heart(r.shift(Offset(s * 0.02, -s * 0.015)).deflate(s * 0.01)),
          pen..strokeWidth *= 0.6,
        );
      case 'hearts':
        for (final (dx, dy, k) in [
          (0.28, 0.6, 0.34),
          (0.62, 0.36, 0.26),
          (0.74, 0.74, 0.18),
        ]) {
          canvas.drawPath(
            _heart(
              Rect.fromCenter(
                center: Offset(w * dx, h * dy),
                width: s * k,
                height: s * k,
              ),
            ),
            fill,
          );
        }
      case 'arrow':
        final path = Path()
          ..moveTo(w * 0.1, h * 0.75)
          ..cubicTo(w * 0.3, h * 0.2, w * 0.6, h * 0.95, w * 0.88, h * 0.3);
        canvas.drawPath(path, pen);
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.7, h * 0.27)
            ..lineTo(w * 0.88, h * 0.3)
            ..lineTo(w * 0.86, h * 0.48),
          pen,
        );
      case 'swirl':
        final path = Path();
        for (var t = 0.0; t <= math.pi * 5; t += 0.08) {
          final r = s * 0.04 * t;
          final p = c + Offset(math.cos(t) * r, math.sin(t) * r * 0.9);
          t == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, pen);
      case 'star':
        final path = Path();
        for (var i = 0; i <= 10; i++) {
          final r = i.isEven ? s * 0.42 : s * 0.18;
          final a = -math.pi / 2 + i * math.pi / 5;
          final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, pen);
      case 'sparkles':
        for (final (dx, dy, k) in [
          (0.35, 0.45, 0.32),
          (0.72, 0.28, 0.2),
          (0.7, 0.72, 0.16),
        ]) {
          final at = Offset(w * dx, h * dy);
          final r = s * k;
          canvas.drawPath(
            Path()
              ..moveTo(at.dx, at.dy - r)
              ..quadraticBezierTo(at.dx, at.dy, at.dx + r, at.dy)
              ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + r)
              ..quadraticBezierTo(at.dx, at.dy, at.dx - r, at.dy)
              ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - r)
              ..close(),
            fill,
          );
        }
      case 'underline':
        final path = Path()..moveTo(w * 0.06, h * 0.55);
        for (var i = 1; i <= 6; i++) {
          path.quadraticBezierTo(
            w * (0.06 + (i - 0.5) * 0.147),
            h * (i.isOdd ? 0.35 : 0.75),
            w * (0.06 + i * 0.147),
            h * 0.55,
          );
        }
        canvas.drawPath(path, pen);
      case 'circle':
        final path = Path();
        for (var t = 0.0; t <= math.pi * 2.25; t += 0.06) {
          final wobble = 1 + 0.04 * math.sin(t * 3);
          final p =
              c +
              Offset(
                math.cos(t) * w * 0.44 * wobble,
                math.sin(t) * h * 0.4 * wobble,
              );
          t == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, pen);
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter old) =>
      old.shape != shape || old.color != color;
}

Path _heart(Rect r) {
  final w = r.width, h = r.height, x = r.left, y = r.top;
  return Path()
    ..moveTo(x + w / 2, y + h * 0.92)
    ..cubicTo(
      x - w * 0.1,
      y + h * 0.52,
      x + w * 0.06,
      y - h * 0.06,
      x + w / 2,
      y + h * 0.24,
    )
    ..cubicTo(
      x + w * 0.94,
      y - h * 0.06,
      x + w * 1.1,
      y + h * 0.52,
      x + w / 2,
      y + h * 0.92,
    )
    ..close();
}

// ------------------------------------------------------------- pickers

Future<T?> _sheet<T>(BuildContext context, String title, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      backgroundColor: NotePalette.card,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: NotePalette.display(20)),
              const SizedBox(height: 16),
              Flexible(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
      ),
    );

/// What can be added from edit mode.
enum AddChoice { memory, stickyNote, sticker, tape, doodle }

Future<AddChoice?> pickAdd(BuildContext context, {required bool decorations}) =>
    _sheet<AddChoice>(
      context,
      'Add to the scrapbook',
      Column(
        children: [
          for (final (choice, label, sub, icon) in [
            (
              AddChoice.memory,
              'Memory',
              'A new memory, placed where you are looking',
              Icons.add_photo_alternate_outlined,
            ),
            if (decorations) ...[
              (
                AddChoice.stickyNote,
                'Sticky note',
                'A little handwritten note',
                Icons.sticky_note_2_outlined,
              ),
              (
                AddChoice.sticker,
                'Sticker',
                'Hearts, stars, little words',
                Icons.emoji_symbols_rounded,
              ),
              (
                AddChoice.tape,
                'Washi tape',
                'A strip of patterned tape',
                Icons.straighten_rounded,
              ),
              (
                AddChoice.doodle,
                'Doodle',
                'Hearts, arrows, swirls',
                Icons.gesture_rounded,
              ),
            ],
          ])
            ListTile(
              leading: Icon(icon, color: NotePalette.pink),
              title: Text(
                label,
                style: const TextStyle(color: NotePalette.cream),
              ),
              subtitle: Text(
                sub,
                style: const TextStyle(color: NotePalette.muted, fontSize: 12),
              ),
              onTap: () => Navigator.of(context).pop(choice),
            ),
        ],
      ),
    );

Widget _tile(
  BuildContext context, {
  required String label,
  required Widget preview,
  required VoidCallback onTap,
  bool selected = false,
}) => Semantics(
  button: true,
  selected: selected,
  label: label,
  excludeSemantics: true,
  child: InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Container(
      width: 84,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: selected ? NotePalette.rose.withValues(alpha: 0.16) : null,
        border: Border.all(
          color: selected
              ? NotePalette.rose
              : NotePalette.pink.withValues(alpha: 0.2),
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: 60, child: Center(child: preview)),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: NotePalette.cream),
          ),
        ],
      ),
    ),
  ),
);

Future<String?> pickSticker(BuildContext context) => _sheet<String>(
  context,
  'Choose a sticker',
  Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: [
      for (final s in stickers)
        _tile(
          context,
          label: s.label,
          preview: _Sticker(def: s, size: const Size(52, 52)),
          onTap: () => Navigator.of(context).pop(s.id),
        ),
    ],
  ),
);

/// Pattern and colour; resolves with both.
Future<(String, Color)?> pickTape(BuildContext context) {
  var color = tapeColors.first;
  return _sheet<(String, Color)>(
    context,
    'Choose washi tape',
    StatefulBuilder(
      builder: (context, set) => Column(
        children: [
          _Swatches(
            colors: tapeColors,
            selected: color,
            onPick: (c) => set(() => color = c),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final (id, label) in tapePatterns)
                _tile(
                  context,
                  label: label,
                  preview: CustomPaint(
                    size: const Size(70, 22),
                    painter: _TapePainter(id, color),
                  ),
                  onTap: () => Navigator.of(context).pop((id, color)),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<(String, Color)?> pickDoodle(BuildContext context) {
  var color = doodleColors.first;
  return _sheet<(String, Color)>(
    context,
    'Choose a doodle',
    StatefulBuilder(
      builder: (context, set) => Column(
        children: [
          _Swatches(
            colors: doodleColors,
            selected: color,
            onPick: (c) => set(() => color = c),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final (id, label) in doodles)
                _tile(
                  context,
                  label: label,
                  preview: CustomPaint(
                    size: const Size(54, 54),
                    painter: _DoodlePainter(id, color),
                  ),
                  onTap: () => Navigator.of(context).pop((id, color)),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<Color?> pickColor(BuildContext context, DecoKind kind, Color? current) =>
    _sheet<Color>(
      context,
      'Colour',
      _Swatches(
        colors: colorsFor(kind),
        selected: current,
        onPick: (c) => Navigator.of(context).pop(c),
      ),
    );

class _Swatches extends StatelessWidget {
  const _Swatches({
    required this.colors,
    required this.selected,
    required this.onPick,
  });

  final List<Color> colors;
  final Color? selected;
  final void Function(Color) onPick;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    alignment: WrapAlignment.center,
    children: [
      for (final c in colors)
        Semantics(
          button: true,
          selected: c == selected,
          label: 'Colour',
          child: GestureDetector(
            onTap: () => onPick(c),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: c == selected ? NotePalette.rose : Colors.white24,
                  width: c == selected ? 3 : 1,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// Writing (or rewriting) a sticky note: the words and a colour. Resolves
/// with both, or null when cancelled.
Future<(String, Color)?> writeStickyNote(
  BuildContext context, {
  String? text,
  Color? color,
}) => showDialog<(String, Color)>(
  context: context,
  builder: (_) => _NoteDialog(text: text, color: color),
);

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({this.text, this.color});

  final String? text;
  final Color? color;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _c = TextEditingController(text: widget.text ?? '');
  late Color _color = widget.color ?? stickyColors.first;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.text == null ? 'Sticky note' : 'Edit sticky note'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Swatches(
          colors: stickyColors,
          selected: _color,
          onPick: (c) => setState(() => _color = c),
        ),
        const SizedBox(height: 14),
        Container(
          color: _color,
          padding: const EdgeInsets.all(10),
          child: TextField(
            controller: _c,
            autofocus: true,
            maxLength: 200,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            style: scrapHand(20),
            decoration: const InputDecoration(
              hintText: 'Write something…',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              counterStyle: TextStyle(color: NotePalette.inkSoft),
            ),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final t = _c.text.trim();
          if (t.isEmpty) return;
          Navigator.of(context).pop((t, _color));
        },
        child: const Text('Save'),
      ),
    ],
  );
}
