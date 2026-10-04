import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/memory.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../services/memory_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/effects/floating_hearts.dart';
import '../widgets/effects/motion.dart';
import '../widgets/home/quick_actions.dart';
import '../widgets/notes/note_style.dart';
import '../widgets/timeline/scrapbook_canvas.dart';
import '../widgets/timeline/scrapbook_layout.dart';
import 'add_memory_sheet.dart';
import 'memory_detail_screen.dart';

/// The couple's story as one big scrapbook: newest month at the top, each
/// month a cluster of taped Polaroids, paper notes and date cards. Pinch,
/// scroll-wheel or the controls zoom it; drag to move around. Zoomed far
/// out, it reads as the whole story from above, with month labels on top.
///
/// Only the scrapbook zooms: the header, Add, zoom controls and the
/// minimap stay normal size.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen>
    with SingleTickerProviderStateMixin {
  List<Memory> _memories = [];
  Map<String, String> _names = {};
  bool _searching = false;
  final _search = TextEditingController();
  String _query = '';
  bool _loading = true;
  String? _error;

  /// Worked out only when the memories or the search change, never while
  /// zooming, so pieces never move under your fingers.
  ScrapbookLayout? _layout;

  final _view = TransformationController();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..addListener(_step);
  Animation<Matrix4>? _tween;
  Size? _viewport;

  String get _coupleId => widget.profile.coupleId!;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() {
      final q = _search.text.trim().toLowerCase();
      if (q == _query) return;
      setState(() {
        _query = q;
        _relayout();
      });
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _view.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Your own tags (not built-ins), offered as chips when tagging.
  List<String> get _knownTags {
    final own = <String>{
      for (final m in _memories)
        for (final t in m.tags)
          if (MemoryTag.fromDb(t) == null) t,
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return own;
  }

  bool _matches(Memory m) {
    if (_query.isEmpty) return true;
    return [
      m.title,
      m.description ?? '',
      m.location ?? '',
      for (final t in m.tags) tagLabel(t),
    ].any((field) => field.toLowerCase().contains(_query));
  }

  void _relayout() {
    _layout = ScrapbookLayout.build(_memories.where(_matches).toList());
  }

  Future<void> _load() async {
    try {
      final members = await CoupleService.members(_coupleId);
      final memories = await MemoryService.list(_coupleId);
      if (!mounted) return;
      setState(() {
        _names = {for (final m in members) m.userId: m.displayName};
        _memories = memories;
        _relayout();
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  String _authorName(Memory m) => m.authorId == widget.profile.userId
      ? 'you'
      : (_names[m.authorId] ?? 'your partner');

  void _showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _add() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          AddMemorySheet(coupleId: _coupleId, knownTags: _knownTags),
    );
    if (saved != true) return;
    await _load();
    if (!mounted) return;
    showFloatingHearts(context);
    _showMessage('Memory saved');
  }

  Future<void> _open(Memory memory) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MemoryDetailScreen(
          memory: memory,
          authorName: _authorName(memory),
          isMine: memory.authorId == widget.profile.userId,
          knownTags: _knownTags,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  // ------------------------------------------------------------ zooming

  double get _defaultScale =>
      (_viewport?.width ?? ScrapbookLayout.canvasWidth) /
      ScrapbookLayout.canvasWidth;

  /// Far enough out to see many months as small collages; not so far that
  /// they turn into dots.
  double get _minScale => _defaultScale * 0.16;

  /// Close enough to study a photo, not so close it's just blur.
  double get _maxScale => _defaultScale * 3;

  double get _scale => _view.value.getMaxScaleOnAxis();

  /// Zoomed out past this, a tap zooms in first instead of opening, and
  /// the month labels float on top.
  bool get _farOut => _scale < _defaultScale * 0.6;

  Offset get _translation {
    final t = _view.value.getTranslation();
    return Offset(t.x, t.y);
  }

  static Matrix4 _matrix(double s, Offset t) =>
      Matrix4.diagonal3Values(s, s, s)..setTranslationRaw(t.dx, t.dy, 0);

  /// Keeps the scrapbook on screen: centred when it is narrower than the
  /// screen, otherwise no further than its edges.
  Offset _clamp(double s, Offset t) {
    final layout = _layout, vp = _viewport;
    if (layout == null || vp == null) return t;
    final w = layout.width * s, h = layout.height * s;
    final dx = w <= vp.width
        ? (vp.width - w) / 2
        : t.dx.clamp(vp.width - w, 0.0);
    final dy = h <= vp.height ? 0.0 : t.dy.clamp(vp.height - h, 0.0);
    return Offset(dx.toDouble(), dy.toDouble());
  }

  void _step() {
    final tween = _tween;
    if (tween != null) _view.value = tween.value;
  }

  /// Moves to [s] / [t] with a short ease-out, or at once with reduced
  /// motion on.
  void _animateTo(double s, Offset t) {
    s = s.clamp(_minScale, _maxScale);
    final target = _matrix(s, _clamp(s, t));
    if (motionOff(context)) {
      _anim.stop();
      _view.value = target;
      return;
    }
    _tween = Matrix4Tween(
      begin: _view.value.clone(),
      end: target,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward(from: 0);
  }

  /// Zoom in or out by [factor] around the middle of the screen.
  void _zoomBy(double factor) {
    final vp = _viewport;
    if (vp == null) return;
    final s = _scale, t = _translation;
    final focal = Offset(vp.width / 2, vp.height / 2);
    final point = (focal - t) / s; // the canvas spot under the middle
    final next = (s * factor).clamp(_minScale, _maxScale);
    _animateTo(next, focal - point * next);
  }

  /// See all: as much of the story as fits, newest at the top.
  void _seeAll() {
    final layout = _layout, vp = _viewport;
    if (layout == null || vp == null) return;
    final fit = math.min(vp.width / layout.width, vp.height / layout.height);
    _animateTo(fit.clamp(_minScale, _defaultScale), Offset.zero);
  }

  /// Back to the normal browsing size, with [rect] (canvas units) in view.
  void _zoomToRect(Rect rect, {bool alignTop = false}) {
    final vp = _viewport;
    if (vp == null) return;
    final s = _defaultScale;
    final x = vp.width / 2 - rect.center.dx * s;
    final y = alignTop ? 12 - rect.top * s : vp.height / 2 - rect.center.dy * s;
    _animateTo(s, Offset(x, y));
  }

  /// After a pinch or drag: when the page is narrower than the screen,
  /// glide it back to the middle (the viewer alone would leave it at an
  /// edge), and keep it from being left past its ends.
  void _settle() {
    final s = _scale, t = _translation;
    final c = _clamp(s, t);
    if ((c - t).distance > 1) _animateTo(s, c);
  }

  void _tapPiece(ScrapPiece piece) {
    if (_anim.isAnimating) return;
    if (_farOut) {
      _zoomToRect(piece.rect);
    } else {
      _open(piece.memory);
    }
  }

  // -------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = _layout;

    final Widget content;
    if (_loading) {
      content = const SkeletonList();
    } else if (_error != null) {
      content = Padding(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Try again',
              variant: AppButtonVariant.outlined,
              onPressed: _load,
            ),
          ],
        ),
      );
    } else if (_memories.isEmpty) {
      content = _EmptyTimeline(onAdd: _add);
    } else if (layout == null || layout.pieces.isEmpty) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.huge),
          child: Text(
            'Nothing matches "${_search.text.trim()}".',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: NotePalette.muted,
            ),
          ),
        ),
      );
    } else {
      content = LayoutBuilder(
        builder: (context, box) {
          final vp = box.biggest;
          final first = _viewport == null;
          final widthChanged = !first && _viewport!.width != vp.width;
          _viewport = vp;
          if (first || widthChanged) {
            // Start at the normal browsing size, at the newest month.
            // (Nothing listens yet on the first build, so this is safe.)
            final value = _matrix(_defaultScale, Offset.zero);
            if (first) {
              _view.value = value;
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _view.value = value;
              });
            }
          }
          return _ScrapbookViewport(
            layout: layout,
            view: _view,
            viewport: vp,
            minScale: _minScale,
            maxScale: _maxScale,
            defaultScale: _defaultScale,
            photoScale:
                MediaQuery.devicePixelRatioOf(context) * _defaultScale * 1.6,
            onTapPiece: _tapPiece,
            onInteractionStart: _anim.stop,
            onInteractionEnd: _settle,
            onMonth: (m) => _zoomToRect(
              Rect.fromLTRB(0, m.top, layout.width, m.bottom),
              alignTop: true,
            ),
            onJump: (s, t) => _view.value = _matrix(s, _clamp(s, t)),
            onJumpAnimated: _animateTo,
            onZoomIn: () => _zoomBy(1.6),
            onZoomOut: () => _zoomBy(1 / 1.6),
            onSeeAll: _seeAll,
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: NotePalette.background,
      body: NotesBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                searching: _searching,
                onSearch: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _search.clear();
                }),
                onAdd: _loading ? null : _add,
              ),
              if (_searching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenMargin,
                    0,
                    AppSpacing.screenMargin,
                    AppSpacing.sm,
                  ),
                  child: TextField(
                    controller: _search,
                    autofocus: true,
                    style: const TextStyle(color: NotePalette.cream),
                    decoration: InputDecoration(
                      hintText: 'Find a memory: title, story, place or tag',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              onPressed: _search.clear,
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
              Expanded(child: ClipRect(child: content)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.searching,
    required this.onSearch,
    required this.onAdd,
  });

  final bool searching;
  final VoidCallback onSearch;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Our Timeline',
                          style: NotePalette.display(
                            MediaQuery.sizeOf(context).width < 360 ? 24 : 30,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.favorite_border_rounded,
                      size: 20,
                      color: NotePalette.rose,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'The little moments that became us.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NotePalette.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: searching ? 'Close search' : 'Find a memory',
            onPressed: onSearch,
            icon: Icon(
              searching ? Icons.search_off_rounded : Icons.search_rounded,
              color: NotePalette.cream,
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Add a memory',
            child: Semantics(
              button: true,
              label: 'Add a memory',
              excludeSemantics: true,
              child: Material(
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: Ink(
                  decoration: const BoxDecoration(
                    gradient: NotePalette.buttonGradient,
                  ),
                  child: InkWell(
                    onTap: onAdd,
                    child: const SizedBox.square(
                      dimension: 48,
                      child: Icon(
                        Icons.add_rounded,
                        color: Color(0xFF3A0A19),
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The zoomable scrapbook plus the controls that sit on top of it at
/// normal size: month labels when far out, the minimap, and zoom buttons.
class _ScrapbookViewport extends StatelessWidget {
  const _ScrapbookViewport({
    required this.layout,
    required this.view,
    required this.viewport,
    required this.minScale,
    required this.maxScale,
    required this.defaultScale,
    required this.photoScale,
    required this.onTapPiece,
    required this.onInteractionStart,
    required this.onInteractionEnd,
    required this.onMonth,
    required this.onJump,
    required this.onJumpAnimated,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onSeeAll,
  });

  final ScrapbookLayout layout;
  final TransformationController view;
  final Size viewport;
  final double minScale;
  final double maxScale;
  final double defaultScale;
  final double photoScale;
  final void Function(ScrapPiece) onTapPiece;
  final VoidCallback onInteractionStart;
  final VoidCallback onInteractionEnd;
  final void Function(ScrapMonth) onMonth;
  final void Function(double s, Offset t) onJump;
  final void Function(double s, Offset t) onJumpAnimated;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InteractiveViewer(
          transformationController: view,
          constrained: false,
          minScale: minScale,
          maxScale: maxScale,
          // Room to pull past the edges a little, never to lose the page.
          boundaryMargin: EdgeInsets.symmetric(
            horizontal: viewport.width * 0.5,
            vertical: viewport.height * 0.3,
          ),
          clipBehavior: Clip.none,
          onInteractionStart: (_) => onInteractionStart(),
          onInteractionEnd: (_) => onInteractionEnd(),
          child: RepaintBoundary(
            child: ScrapbookCanvas(
              layout: layout,
              onTapPiece: onTapPiece,
              photoScale: photoScale,
            ),
          ),
        ),
        // Everything below listens to the view and redraws on its own;
        // the scrapbook itself is never rebuilt while you zoom.
        Positioned.fill(
          child: _MonthLabels(
            layout: layout,
            view: view,
            viewport: viewport,
            defaultScale: defaultScale,
            onMonth: onMonth,
          ),
        ),
        Positioned(
          right: 2,
          top: 12,
          bottom: 84,
          child: _Minimap(
            layout: layout,
            view: view,
            viewport: viewport,
            onJump: onJump,
            onJumpAnimated: onJumpAnimated,
          ),
        ),
        Positioned(
          right: 12,
          bottom: 16,
          child: _ZoomControls(
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onSeeAll: onSeeAll,
          ),
        ),
      ],
    );
  }
}

/// Far out, month names at readable size over each chapter. Tap one to
/// zoom into that month.
class _MonthLabels extends StatelessWidget {
  const _MonthLabels({
    required this.layout,
    required this.view,
    required this.viewport,
    required this.defaultScale,
    required this.onMonth,
  });

  final ScrapbookLayout layout;
  final TransformationController view;
  final Size viewport;
  final double defaultScale;
  final void Function(ScrapMonth) onMonth;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: view,
      builder: (context, _) {
        final m = view.value;
        final s = m.getMaxScaleOnAxis();
        // Fade in between 60% and 45% of the normal size.
        final t = ((defaultScale * 0.6 - s) / (defaultScale * 0.15)).clamp(
          0.0,
          1.0,
        );
        if (t == 0) return const SizedBox.shrink();
        final tr = m.getTranslation();
        return Stack(
          children: [
            for (final month in layout.months)
              if (month.top * s + tr.y > -30 &&
                  month.top * s + tr.y < viewport.height)
                Positioned(
                  left: math.max(8, tr.x + 6),
                  top: month.top * s + tr.y,
                  child: Opacity(
                    opacity: t,
                    child: _MonthChip(
                      month: month,
                      onTap: () => onMonth(month),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.month, required this.onTap});

  final ScrapMonth month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${monthLabel(month.year, month.month)}, ${month.count} memories. Zoom in',
      excludeSemantics: true,
      child: Material(
        color: const Color(0xEE2A1426),
        shape: StadiumBorder(
          side: BorderSide(color: NotePalette.pink.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              shortMonthLabel(month.year, month.month),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: NotePalette.cream,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A slim track on the right: month marks, and a highlight for the part on
/// screen. Tap or drag it to travel through the story.
class _Minimap extends StatelessWidget {
  const _Minimap({
    required this.layout,
    required this.view,
    required this.viewport,
    required this.onJump,
    required this.onJumpAnimated,
  });

  final ScrapbookLayout layout;
  final TransformationController view;
  final Size viewport;
  final void Function(double s, Offset t) onJump;
  final void Function(double s, Offset t) onJumpAnimated;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final track = box.maxHeight;
        void go(double dy, {required bool animate}) {
          final m = view.value;
          final s = m.getMaxScaleOnAxis();
          final tr = m.getTranslation();
          final canvasY = (dy / track).clamp(0.0, 1.0) * layout.height;
          final t = Offset(tr.x, viewport.height / 2 - canvasY * s);
          animate ? onJumpAnimated(s, t) : onJump(s, t);
        }

        return AnimatedBuilder(
          animation: view,
          builder: (context, _) {
            final m = view.value;
            final s = m.getMaxScaleOnAxis();
            final tr = m.getTranslation();
            // Nothing to travel when the whole story already fits.
            if (layout.height * s <= viewport.height + 1) {
              return const SizedBox.shrink();
            }
            final top = ((-tr.y / s) / layout.height).clamp(0.0, 1.0) * track;
            final size =
                ((viewport.height / s) / layout.height).clamp(0.04, 1.0) *
                track;
            return Semantics(
              label: 'Timeline position',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => go(d.localPosition.dy, animate: true),
                onVerticalDragUpdate: (d) =>
                    go(d.localPosition.dy, animate: false),
                child: SizedBox(
                  width: 22,
                  child: CustomPaint(
                    painter: _MinimapPainter(
                      months: [
                        for (final mo in layout.months) mo.top / layout.height,
                      ],
                      top: top,
                      size: size,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({
    required this.months,
    required this.top,
    required this.size,
  });

  final List<double> months;
  final double top;
  final double size;

  @override
  void paint(Canvas canvas, Size box) {
    final x = box.width / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 1.5, 0, 3, box.height),
        const Radius.circular(2),
      ),
      Paint()..color = NotePalette.pink.withValues(alpha: 0.14),
    );
    final mark = Paint()..color = NotePalette.pink.withValues(alpha: 0.45);
    for (final f in months) {
      canvas.drawCircle(Offset(x, f * box.height), 2, mark);
    }
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - 4, top, 8, math.min(size, box.height - top)),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..color = NotePalette.rose.withValues(alpha: 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
  }

  @override
  bool shouldRepaint(_MinimapPainter old) =>
      old.top != top || old.size != size || old.months.length != months.length;
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onSeeAll,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    Widget button(String tip, IconData icon, VoidCallback onTap) => IconButton(
      tooltip: tip,
      onPressed: onTap,
      icon: Icon(icon, color: NotePalette.cream, size: 22),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE62A1426),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NotePalette.pink.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button('Zoom out', Icons.remove_rounded, onZoomOut),
          // Narrow phones: just the icon, so the bar covers less.
          if (MediaQuery.sizeOf(context).width < 360)
            IconButton(
              tooltip: 'See all',
              onPressed: onSeeAll,
              icon: const Icon(
                Icons.zoom_out_map_rounded,
                color: NotePalette.pink,
                size: 20,
              ),
            )
          else
            TextButton.icon(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(foregroundColor: NotePalette.pink),
              icon: const Icon(Icons.zoom_out_map_rounded, size: 18),
              label: const Text('See all'),
            ),
          button('Zoom in', Icons.add_rounded, onZoomIn),
        ],
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const QuickActionArtView(QuickActionArt.memory, size: 110),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Our story starts here.',
              textAlign: TextAlign.center,
              style: NotePalette.display(24),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add your first memory together.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: NotePalette.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            NotePrimaryButton(
              label: 'Add a memory',
              icon: Icons.add_rounded,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}
