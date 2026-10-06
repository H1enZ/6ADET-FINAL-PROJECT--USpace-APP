import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../models/memory.dart';
import '../models/profile.dart';
import '../models/scrap_decoration.dart';
import '../models/scrapbook.dart';
import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../services/memory_service.dart';
import '../services/scrapbook_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/us_icon.dart';
import '../widgets/effects/floating_hearts.dart';
import '../widgets/effects/motion.dart';
import '../widgets/home/quick_actions.dart';
import '../widgets/notes/note_style.dart';
import '../widgets/timeline/scrap_decorations.dart';
import '../widgets/timeline/scrapbook_canvas.dart';
import '../widgets/timeline/scrapbook_editor.dart';
import '../widgets/timeline/scrapbook_layout.dart';
import 'add_memory_sheet.dart';
import 'memory_detail_screen.dart';
import '../theme/us_palette.dart';

/// The couple's story as one big scrapbook: newest month at the top, each
/// month a cluster of framed photos, paper notes and tickets. Pinch,
/// scroll-wheel or the controls zoom it; drag to move around. Zoomed far
/// out, it reads as the whole story from above, with month labels on top.
///
/// Edit turns it into a scrapbook you arrange yourselves: move, resize and
/// tilt memories, choose their frames and layers, and join them with little
/// lines. That arrangement is shared by both of you and saved separately
/// from the memories (a memory's date and content never change).
///
/// Only the scrapbook zooms (pinch, or the mouse wheel / trackpad): the
/// header, Add and the editing toolbar stay normal size.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

/// One step that Undo can take back.
class _Undo {
  _Undo({
    this.items = const {},
    this.decos = const {},
    this.addedLinkId,
    this.removedLink,
    this.restyled,
  });

  /// Each changed memory's placement before the step (null = none saved).
  final Map<String, LayoutItem?> items;

  /// Each changed decoration before the step (null = it did not exist).
  final Map<String, ScrapDecoration?> decos;
  final String? addedLinkId;
  final ScrapConnection? removedLink;
  final ScrapConnection? restyled;
}

class _TimelineScreenState extends State<TimelineScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  List<Memory> _memories = [];
  Map<String, String> _names = {};
  bool _searching = false;
  final _search = TextEditingController();
  String _query = '';
  bool _loading = true;
  String? _error;

  /// Worked out only when the memories, search or arrangement change, never
  /// while zooming, so pieces never move under your fingers.
  ScrapbookLayout? _layout;

  final _view = TransformationController();

  /// How visible the board's own month tags are; they hand over to the
  /// floating tags as you zoom out (see [boardTagOpacity]).
  final _tagOpacity = ValueNotifier<double>(1);
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..addListener(_step);
  Animation<Matrix4>? _tween;
  Size? _viewport;
  bool _lowRes = false;

  /// Dates (month labels and headings) hidden, so the board shows on its
  /// own. A choice for this phone, remembered.
  bool _hideDates = false;
  static const _hideDatesKey = 'timeline_hide_dates';

  // ------------------------------------------------ the shared arrangement

  /// Saved placements (what both of you see). Empty = never arranged by
  /// hand: the automatic date layout.
  Map<String, LayoutItem> _saved = {};
  List<ScrapConnection> _links = [];

  /// False when the arrangement can't be loaded (e.g. a database without
  /// migration 018): the Timeline works as before, without Edit.
  bool _layoutReady = false;
  bool get _customized => _saved.isNotEmpty;

  bool _editing = false;
  String? _selected;
  String? _connectFrom;

  /// The memory being moved / resized / turned right now.
  final _live = ValueNotifier<ScrapLive?>(null);
  ({ScrapPiece piece, ScrapGesture kind, LayoutItem start, Offset from})?
  _gesture;

  // Decorations (migration 019): sticky notes, stickers, tape, doodles.
  List<ScrapDecoration> _decos = [];

  /// False on a database without 019: the scrapbook works without them.
  bool _decosReady = false;
  String? _selectedDeco;
  final _decoLive = ValueNotifier<ScrapDecoration?>(null);
  ({ScrapDecoration start, ScrapGesture kind, Offset from})? _decoGesture;
  final _dirtyDecos = <String>{};
  final _removedDecos = <String>{};

  final _undo = <_Undo>[];
  static const _undoLimit = 30;

  // Saving: changes collect here and go out in one request.
  final _dirty = <String>{};
  final _removed = <String>{};
  Timer? _saveTimer;
  bool _saving = false;

  RealtimeChannel? _channel;
  Timer? _remoteTimer;

  // Organize / reset: everything glides to its new place.
  late final AnimationController _arrange = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..addListener(_arrangeStep);
  Map<String, LayoutItem>? _arrangeFrom;
  Map<String, LayoutItem>? _arrangeTo;

  String get _coupleId => widget.profile.coupleId!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _view.addListener(_watchZoom);
    _load();
    _loadDatesChoice();
    try {
      _channel = ScrapbookService.listen(_coupleId, _remoteChanged);
    } catch (_) {
      // Live updates are a bonus.
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _flush(); // anything not saved yet goes now
    _saveTimer?.cancel();
    _remoteTimer?.cancel();
    final channel = _channel;
    if (channel != null) ScrapbookService.stopListening(channel);
    _anim.dispose();
    _arrange.dispose();
    _view.dispose();
    _tagOpacity.dispose();
    _live.dispose();
    _decoLive.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _flush();
    }
  }

  Future<void> _loadDatesChoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hide = prefs.getBool(_hideDatesKey) ?? false;
      if (mounted && hide != _hideDates) setState(() => _hideDates = hide);
    } catch (_) {
      // Only a preference: the dates simply show.
    }
  }

  void _toggleDates() {
    setState(() => _hideDates = !_hideDates);
    final hide = _hideDates;
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_hideDatesKey, hide))
        .catchError((_) => false);
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

  void _relayout({Map<String, LayoutItem>? saved}) {
    final s = saved ?? _saved;
    _layout = ScrapbookLayout.compose(
      memories: _memories.where(_matches).toList(),
      saved: s,
      customized: s.isNotEmpty,
      extra: [for (final d in _decos) d.rect],
    );
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        CoupleService.members(_coupleId),
        MemoryService.list(_coupleId),
        ScrapbookService.load(
          _coupleId,
        ).then<Object?>((v) => v, onError: (_) => null),
        ScrapbookService.decorations(
          _coupleId,
        ).then<Object?>((v) => v, onError: (_) => null),
      ]);
      if (!mounted) return;
      final members = results[0] as List<Profile>;
      final memories = results[1] as List<Memory>;
      final scrap =
          results[2]
              as ({
                Map<String, LayoutItem> items,
                List<ScrapConnection> links,
              })?;
      setState(() {
        _names = {for (final m in members) m.userId: m.displayName};
        _memories = memories;
        if (scrap != null) {
          _layoutReady = true;
          _mergeRemote(scrap.items, scrap.links);
        }
        if (results[3] case final List<ScrapDecoration> decos) {
          _decosReady = true;
          _mergeDecos(decos);
        }
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

  /// Takes the saved arrangement, except for anything changed here and not
  /// saved yet (that wins until it is saved).
  void _mergeRemote(
    Map<String, LayoutItem> items,
    List<ScrapConnection> links,
  ) {
    final liveId = _live.value?.item.memoryId;
    final merged = <String, LayoutItem>{
      for (final e in items.entries)
        if (!_removed.contains(e.key)) e.key: e.value,
    };
    for (final id in _dirty) {
      final mine = _saved[id];
      if (mine != null) merged[id] = mine;
    }
    if (liveId != null) {
      if (_saved[liveId] case final mine?) merged[liveId] = mine;
    }
    _saved = merged;
    _links = links;
  }

  /// Takes the saved decorations, except ones changed or removed here and
  /// not saved yet, and the one being moved.
  void _mergeDecos(List<ScrapDecoration> remote) {
    final local = {for (final d in _decos) d.id: d};
    final liveId = _decoLive.value?.id;
    final out = <ScrapDecoration>[
      for (final d in remote)
        if (!_removedDecos.contains(d.id))
          (_dirtyDecos.contains(d.id) || d.id == liveId)
              ? (local[d.id] ?? d)
              : d,
    ];
    final ids = {for (final d in out) d.id};
    for (final id in _dirtyDecos) {
      if (!ids.contains(id) && local[id] != null) out.add(local[id]!);
    }
    _decos = out;
  }

  void _remoteChanged() {
    _remoteTimer?.cancel();
    _remoteTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted || _gesture != null || _arrange.isAnimating) return;
      try {
        final scrap = await ScrapbookService.load(_coupleId);
        final decos = _decosReady
            ? await ScrapbookService.decorations(_coupleId)
            : null;
        if (!mounted || _gesture != null || _decoGesture != null) return;
        setState(() {
          _mergeRemote(scrap.items, scrap.links);
          if (decos != null) _mergeDecos(decos);
          _relayout();
        });
      } catch (_) {}
    });
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

  /// The normal reading zoom: a memory is comfortably big and the rest of
  /// the board is a swipe away in any direction.
  double get _defaultScale =>
      (_viewport?.width ?? ScrapbookLayout.readingWidth) /
      ScrapbookLayout.readingWidth;

  /// As far out as the board still fills the screen from side to side, so
  /// no wall shows beside it; further back in time is a scroll down.
  double get _minScale {
    final layout = _layout, vp = _viewport;
    if (layout == null || vp == null) return _defaultScale;
    return math.min(_defaultScale, vp.width / boardRect(layout).width);
  }

  /// Close enough to study a photo, not so close it's just blur.
  double get _maxScale => _defaultScale * 3;

  double get _scale => _view.value.getMaxScaleOnAxis();

  /// Zoomed out past this, a tap zooms in first instead of opening, and
  /// the month labels float on top.
  bool get _farOut => _scale < _defaultScale * 0.6;

  /// Zoomed far out, photos are decoded small. Only crossing this point
  /// rebuilds the scrapbook, never zooming itself.
  void _watchZoom() {
    final low = _scale < _defaultScale * 0.35;
    if (low != _lowRes) setState(() => _lowRes = low);
    _tagOpacity.value = boardTagOpacity(
      farOutProgress(_scale, _defaultScale),
      still: motionOff(context),
    );
  }

  Offset get _translation {
    final t = _view.value.getTranslation();
    return Offset(t.x, t.y);
  }

  static Matrix4 _matrix(double s, Offset t) =>
      Matrix4.diagonal3Values(s, s, s)..setTranslationRaw(t.dx, t.dy, 0);

  /// Keeps the board on screen in both directions: the screen may not go
  /// past the board's frame, and a board smaller than the screen (along
  /// either axis) is centred. So you can explore the
  /// whole board sideways and down, but never get lost in empty space.
  Offset _clamp(double s, Offset t) {
    final layout = _layout, vp = _viewport;
    if (layout == null || vp == null) return t;
    final c = boardRect(layout);
    double axis(double lo, double hi, double screen, double value) {
      final size = (hi - lo) * s;
      if (size <= screen) return screen / 2 - (lo + hi) / 2 * s;
      return value.clamp(screen - hi * s, -lo * s);
    }

    return Offset(
      axis(c.left, c.right, vp.width, t.dx),
      axis(c.top, c.bottom, vp.height, t.dy),
    );
  }

  /// Where the Timeline opens: the normal zoom, at the top of the story,
  /// with the newest month's cluster in the middle of the screen.
  Matrix4 _startView() {
    final layout = _layout, vp = _viewport;
    final s = _defaultScale;
    if (layout == null || vp == null) return _matrix(s, Offset.zero);
    final strip = layout.newStripRect;
    final newest = layout.months.isEmpty ? null : layout.months.first;
    // What to open on: the New memories strip, else the newest month's tag
    // (it sits above that month's highest memory), else everything.
    final Rect area;
    final Rect anchor;
    if (strip != null) {
      area = anchor = strip;
    } else if (newest != null) {
      area = newest.area;
      anchor = newest.headingRect;
    } else {
      area = anchor = layout.contentRect;
    }
    // Centre the month when it fits across the screen; otherwise start at
    // its tag, so the month's name is the first thing you see.
    final x = area.width * s <= vp.width
        ? vp.width / 2 - area.center.dx * s
        : AppSpacing.lg - (anchor.left - 8) * s;
    final t = Offset(x, 12 - (anchor.top - 8) * s);
    return _matrix(s, _clamp(s, t));
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
    if (_editing) {
      if (_connectFrom != null) {
        _finishConnect(piece);
      } else {
        setState(() {
          _selected = _selected == piece.memory.id ? null : piece.memory.id;
          _selectedDeco = null;
        });
      }
      return;
    }
    if (_farOut) {
      _zoomToRect(piece.rect);
    } else {
      _open(piece.memory);
    }
  }

  void _tapDeco(ScrapDecoration deco) {
    if (!_editing || _anim.isAnimating) return;
    setState(() {
      _selectedDeco = _selectedDeco == deco.id ? null : deco.id;
      _selected = null;
      _connectFrom = null;
    });
  }

  // ------------------------------------------------------------ editing

  void _startEditing() {
    setState(() {
      _editing = true;
      _selected = null;
      _connectFrom = null;
      if (_searching) {
        _searching = false;
        _search.clear();
      }
    });
  }

  Future<void> _done() async {
    setState(() {
      _editing = false;
      _selected = null;
      _selectedDeco = null;
      _connectFrom = null;
      _undo.clear();
    });
    await _flush();
  }

  /// Every memory's placement as drawn right now (saved, automatic or
  /// waiting in the New strip).
  Map<String, LayoutItem> get _drawn => {
    for (final p in _layout?.pieces ?? const <ScrapPiece>[])
      p.memory.id: p.item,
  };

  int get _topZ => _saved.values.fold<int>(0, (z, i) => math.max(z, i.z));

  /// Every layer on the board (placed memories and decorations; not the
  /// waiting New strip), lowest first.
  List<int> get _allZ => [
    for (final p in _layout?.pieces ?? const <ScrapPiece>[])
      if (!p.isNew) p.item.z,
    for (final d in _decos) d.z,
  ]..sort();

  int get _frontZ => _allZ.isEmpty ? 0 : _allZ.last + 1;
  int get _backZ => _allZ.isEmpty ? 0 : _allZ.first - 1;

  ScrapDecoration? get _selectedDecoration {
    final id = _selectedDeco;
    if (id == null) return null;
    return _decos.where((d) => d.id == id).firstOrNull;
  }

  /// Applies decoration changes (null = remove it), remembers how to undo
  /// them, and saves them shortly (removals go at once).
  void _applyDeco(Map<String, ScrapDecoration?> changes, {bool record = true}) {
    if (changes.isEmpty) return;
    final current = {for (final d in _decos) d.id: d};
    final before = {for (final id in changes.keys) id: current[id]};
    final removed = <String>[];
    for (final e in changes.entries) {
      final v = e.value;
      if (v == null) {
        current.remove(e.key);
        _dirtyDecos.remove(e.key);
        _removedDecos.add(e.key);
        removed.add(e.key);
      } else {
        current[e.key] = v;
        _dirtyDecos.add(e.key);
        _removedDecos.remove(e.key);
      }
    }
    _decos = current.values.toList();
    if (record) {
      _undo.add(_Undo(decos: before));
      if (_undo.length > _undoLimit) _undo.removeAt(0);
    }
    if (_selectedDeco != null && !current.containsKey(_selectedDeco)) {
      _selectedDeco = null;
    }
    setState(_relayout);
    if (removed.isNotEmpty) {
      ScrapbookService.removeDecorations(removed).catchError((_) {
        if (mounted) _showMessage("Couldn't remove that just now.");
      });
    }
    _scheduleSave();
  }

  /// The board point in the middle of the screen (where new things go).
  ({double x, double y}) get _viewCenter {
    final vp = _viewport, layout = _layout;
    if (vp == null || layout == null) return (x: 200, y: 200);
    final s = _scale, t = _translation;
    final canvas = (Offset(vp.width / 2, vp.height / 2) - t) / s;
    final board = canvas + layout.origin;
    return (x: board.dx, y: board.dy);
  }

  Future<void> _addMenu() async {
    final choice = await pickAdd(context, decorations: _decosReady);
    if (choice == null || !mounted) return;
    final center = _viewCenter;
    ScrapDecoration? made;
    switch (choice) {
      case AddChoice.memory:
        await _addMemoryHere();
        return;
      case AddChoice.stickyNote:
        final note = await writeStickyNote(context);
        if (note == null) return;
        made = ScrapDecoration.create(
          kind: DecoKind.stickyNote,
          variant: 'square',
          center: center,
          z: _frontZ,
          body: note.$1,
          color: note.$2,
        );
      case AddChoice.sticker:
        final id = await pickSticker(context);
        if (id == null) return;
        made = ScrapDecoration.create(
          kind: DecoKind.sticker,
          variant: id,
          center: center,
          z: _frontZ,
        );
      case AddChoice.tape:
        final tape = await pickTape(context);
        if (tape == null) return;
        made = ScrapDecoration.create(
          kind: DecoKind.tape,
          variant: tape.$1,
          center: center,
          z: _frontZ,
          color: tape.$2,
        );
      case AddChoice.doodle:
        final doodle = await pickDoodle(context);
        if (doodle == null) return;
        made = ScrapDecoration.create(
          kind: DecoKind.doodle,
          variant: doodle.$1,
          center: center,
          z: _frontZ,
          color: doodle.$2,
        );
    }
    if (!mounted) return;
    _applyDeco({made.id: made});
    setState(() {
      _selectedDeco = made!.id;
      _selected = null;
    });
  }

  /// A new memory from edit mode: on an arranged board it lands where you
  /// are looking (instead of waiting in the New strip).
  Future<void> _addMemoryHere() async {
    final center = _viewCenter;
    final before = {for (final m in _memories) m.id};
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          AddMemorySheet(coupleId: _coupleId, knownTags: _knownTags),
    );
    if (saved != true || !mounted) return;
    await _load();
    if (!mounted) return;
    final fresh = _memories.where((m) => !before.contains(m.id)).toList();
    if (fresh.isEmpty) return;
    if (_customized) {
      final changes = <String, LayoutItem>{};
      var z = _frontZ;
      for (final (i, m) in fresh.indexed) {
        final kind = contentKindOf(m);
        final w = ScrapbookLayout.presetWidths(kind)[1];
        final frame = autoFrameOf(m, ScrapbookLayout.seedOf(m.id));
        final h = ScrapbookLayout.frameHeight(frame, w, m);
        changes[m.id] = LayoutItem(
          memoryId: m.id,
          x: center.x - w / 2 + i * 24,
          y: center.y - h / 2 + i * 24,
          width: w,
          z: z++,
        );
      }
      _apply(changes);
    }
    setState(() {
      _selected = fresh.first.id;
      _selectedDeco = null;
    });
    showFloatingHearts(context);
  }

  /// The selected memory's own editor (title, story, date, photos).
  Future<void> _editMemory() async {
    final p = _selectedPiece;
    if (p == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AddMemorySheet(
        coupleId: _coupleId,
        memory: p.memory,
        knownTags: _knownTags,
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _editNote() async {
    final d = _selectedDecoration;
    if (d == null || d.kind != DecoKind.stickyNote) return;
    final note = await writeStickyNote(context, text: d.body, color: d.color);
    if (note == null || !mounted) return;
    _applyDeco({d.id: d.copyWith(body: note.$1, color: note.$2)});
  }

  Future<void> _recolor() async {
    final d = _selectedDecoration;
    if (d == null) return;
    final c = await pickColor(context, d.kind, d.color);
    if (c == null || !mounted) return;
    _applyDeco({d.id: d.copyWith(color: c)});
  }

  void _deleteDeco() {
    final d = _selectedDecoration;
    if (d == null) return;
    _applyDeco({d.id: null});
  }

  Future<void> _turnDeco() async {
    final d = _selectedDecoration;
    if (d == null) return;
    final angle = await pickTurn(
      context,
      d.rotation,
      (v) => _decoLive.value = d.copyWith(rotation: v),
      limit: d.kind.maxTurn,
    );
    _decoLive.value = null;
    if (angle == null || !mounted || angle == d.rotation) return;
    _applyDeco({d.id: d.copyWith(rotation: angle)});
  }

  Future<void> _layerDeco() async {
    final d = _selectedDecoration;
    if (d == null) return;
    final action = await pickLayer(context);
    if (action == null || !mounted) return;
    final others = _allZ..remove(d.z);
    // Forward / backward: just past the next layer above / below.
    final above = others.where((z) => z >= d.z).firstOrNull;
    final below = others.reversed.where((z) => z <= d.z).firstOrNull;
    final z = switch (action) {
      LayerAction.front => others.isEmpty ? d.z : others.last + 1,
      LayerAction.back => others.isEmpty ? d.z : others.first - 1,
      LayerAction.forward => above == null ? d.z : above + 1,
      LayerAction.backward => below == null ? d.z : below - 1,
    };
    if (z == d.z) return;
    _applyDeco({d.id: d.copyWith(z: z)});
  }

  void _decoGestureStart(ScrapDecoration deco, ScrapGesture kind, Offset at) {
    if (_arrange.isAnimating) return;
    _decoGesture = (start: deco, kind: kind, from: at);
    _decoLive.value = deco;
    if (_selectedDeco != deco.id) {
      setState(() {
        _selectedDeco = deco.id;
        _selected = null;
        _connectFrom = null;
      });
    }
  }

  void _decoGestureUpdate(Offset at) {
    final g = _decoGesture!;
    final s = g.start;
    final d = at - g.from;
    switch (g.kind) {
      case ScrapGesture.move:
        _decoLive.value = s.copyWith(
          x: (s.x + d.dx).clamp(ScrapbookLayout.minX, ScrapbookLayout.maxX),
          y: (s.y + d.dy).clamp(-1900.0, 199000.0),
        );
      case ScrapGesture.resize:
        final (lo, hi) = s.kind.widthRange;
        final w = (s.width + d.dx).clamp(lo, hi).toDouble();
        final h = s.kind.keepsHeight
            ? s.height
            : (s.height * w / s.width).clamp(12.0, 380.0);
        _decoLive.value = s.copyWith(width: w, height: h);
      case ScrapGesture.rotate:
        final origin = _layout?.origin ?? Offset.zero;
        final c = s.rect.shift(-origin).center;
        final v = at - c;
        var deg = math.atan2(v.dx, -v.dy) * 180 / math.pi;
        deg = deg.clamp(-s.kind.maxTurn, s.kind.maxTurn);
        if (deg.abs() < 1) deg = 0;
        _decoLive.value = s.copyWith(rotation: deg);
    }
  }

  /// Applies placement changes (null = forget the placement), remembers
  /// how to undo them, and saves them shortly.
  void _apply(Map<String, LayoutItem?> changes, {bool record = true}) {
    if (changes.isEmpty) return;
    final before = <String, LayoutItem?>{};
    // The first change to an automatic scrapbook pins every memory where it
    // is, so nothing else moves by itself afterwards.
    if (!_customized && changes.values.any((v) => v != null)) {
      final drawn = _drawn;
      for (final e in drawn.entries) {
        before[e.key] = null;
        _saved[e.key] = e.value;
        _dirty.add(e.key);
        _removed.remove(e.key);
      }
    }
    for (final e in changes.entries) {
      before.putIfAbsent(e.key, () => _saved[e.key]);
      final v = e.value;
      if (v == null) {
        _saved.remove(e.key);
        _dirty.remove(e.key);
        _removed.add(e.key);
      } else {
        _saved[e.key] = v;
        _dirty.add(e.key);
        _removed.remove(e.key);
      }
    }
    if (record) {
      _undo.add(_Undo(items: before));
      if (_undo.length > _undoLimit) _undo.removeAt(0);
    }
    setState(_relayout);
    _scheduleSave();
  }

  ScrapPiece? get _selectedPiece {
    final id = _selected;
    return id == null ? null : _layout?.pieceOf(id);
  }

  void _gestureStart(ScrapPiece piece, ScrapGesture kind, Offset at) {
    if (_arrange.isAnimating || _connectFrom != null) return;
    _gesture = (piece: piece, kind: kind, start: piece.item, from: at);
    _live.value = ScrapLive(piece.item);
    if (_selected != piece.memory.id) {
      setState(() => _selected = piece.memory.id);
    }
  }

  void _gestureUpdate(Offset at) {
    if (_decoGesture != null) {
      _decoGestureUpdate(at);
      return;
    }
    final g = _gesture;
    if (g == null) return;
    final s = g.start;
    final d = at - g.from;
    switch (g.kind) {
      case ScrapGesture.move:
        var x = s.x + d.dx;
        final y = (s.y + d.dy).clamp(-1900.0, 199000.0);
        // Gentle guides: line up with another memory's left edge, right
        // edge or middle when close. Nothing is ever pushed into columns.
        double? guide;
        final layout = _layout;
        if (layout != null) {
          var best = 7.0;
          for (final other in layout.pieces) {
            if (other.memory.id == s.memoryId) continue;
            final o = other.item;
            final ow = other.rect.width;
            for (final (mine, theirs) in [
              (x, o.x),
              (x + s.width, o.x + ow),
              (x + s.width / 2, o.x + ow / 2),
            ]) {
              final gap = (mine - theirs).abs();
              if (gap < best) {
                best = gap;
                x += theirs - mine;
                guide = theirs - layout.originX;
              }
            }
          }
        }
        x = x.clamp(ScrapbookLayout.minX, ScrapbookLayout.maxX);
        _live.value = ScrapLive(
          s.copyWith(x: x, y: y),
          guideX: guide,
        );
      case ScrapGesture.resize:
        final width = (s.width + d.dx).clamp(
          ScrapbookLayout.minWidth(g.piece.kind),
          ScrapbookLayout.maxWidth,
        );
        _live.value = ScrapLive(s.copyWith(width: width.toDouble()));
      case ScrapGesture.rotate:
        final c = g.piece.rect.center;
        final v = at - c;
        var deg = math.atan2(v.dx, -v.dy) * 180 / math.pi;
        deg = deg.clamp(LayoutItem.minRotation, LayoutItem.maxRotation);
        if (deg.abs() < 0.75) deg = 0;
        _live.value = ScrapLive(s.copyWith(rotation: deg));
    }
  }

  void _gestureEnd() {
    if (_decoGesture case final dg?) {
      final now = _decoLive.value;
      _decoGesture = null;
      if (now != null && now != dg.start) _applyDeco({now.id: now});
      _decoLive.value = null;
      return;
    }
    final g = _gesture;
    final l = _live.value;
    _gesture = null;
    if (g == null || l == null) {
      _live.value = null;
      return;
    }
    var item = l.item;
    if (item != g.start) {
      // A memory placed from the New strip comes to the top.
      if (g.piece.isNew) item = item.copyWith(z: _topZ + 1);
      _apply({item.memoryId: item});
    }
    _live.value = null;
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    final step = _undo.removeLast();
    if (step.items.isNotEmpty) _apply(step.items, record: false);
    if (step.decos.isNotEmpty) _applyDeco(step.decos, record: false);
    if (step.addedLinkId case final id?) {
      setState(
        () => _links = [
          for (final l in _links)
            if (l.id != id) l,
        ],
      );
      ScrapbookService.disconnect(id).catchError((_) {});
    }
    if (step.removedLink case final link?) {
      ScrapbookService.connect(
            _coupleId,
            link.sourceId,
            link.targetId,
            link.style,
          )
          .then((made) {
            if (mounted) setState(() => _links = [..._links, made]);
          })
          .catchError((_) {});
    }
    if (step.restyled case final link?) {
      setState(
        () => _links = [for (final l in _links) l.id == link.id ? link : l],
      );
      ScrapbookService.restyle(link.id, link.style).catchError((_) {});
    }
    setState(() {});
  }

  Future<void> _frame() async {
    final p = _selectedPiece;
    if (p == null) return;
    final pick = await pickFrame(context, p);
    if (pick == null || !mounted) return;
    final f = pick.frame;
    _apply({
      p.memory.id: f == null
          ? p.item.copyWith(clearFrame: true)
          : p.item.copyWith(frame: f),
    });
  }

  Future<void> _size() async {
    final p = _selectedPiece;
    if (p == null) return;
    final w = await pickSize(context, p);
    if (w == null || !mounted) return;
    _apply({p.memory.id: p.item.copyWith(width: w)});
  }

  Future<void> _turn() async {
    final p = _selectedPiece;
    if (p == null) return;
    final angle = await pickTurn(
      context,
      p.item.rotation,
      (v) => _live.value = ScrapLive(p.item.copyWith(rotation: v)),
    );
    _live.value = null;
    if (angle == null || !mounted || angle == p.item.rotation) return;
    _apply({p.memory.id: p.item.copyWith(rotation: angle)});
  }

  Future<void> _layer() async {
    final p = _selectedPiece;
    if (p == null) return;
    final action = await pickLayer(context);
    if (action == null || !mounted) return;
    final drawn = _drawn;
    final order = drawn.values.toList()..sort((a, b) => a.z.compareTo(b.z));
    final me = drawn[p.memory.id]!;
    final i = order.indexWhere((x) => x.memoryId == me.memoryId);
    final changes = <String, LayoutItem>{};
    switch (action) {
      case LayerAction.front:
        changes[me.memoryId] = me.copyWith(
          z: math.max(order.last.z + 1, _frontZ),
        );
      case LayerAction.back:
        changes[me.memoryId] = me.copyWith(
          z: math.min(order.first.z - 1, _backZ),
        );
      case LayerAction.forward when i < order.length - 1:
        final other = order[i + 1];
        changes[me.memoryId] = me.copyWith(z: other.z);
        changes[other.memoryId] = other.copyWith(
          z: me.z == other.z ? me.z - 1 : me.z,
        );
      case LayerAction.backward when i > 0:
        final other = order[i - 1];
        changes[me.memoryId] = me.copyWith(z: other.z);
        changes[other.memoryId] = other.copyWith(
          z: me.z == other.z ? me.z + 1 : me.z,
        );
      default:
        return;
    }
    _apply(changes);
  }

  void _toggleConnect() {
    setState(() => _connectFrom = _connectFrom != null ? null : _selected);
  }

  Future<void> _finishConnect(ScrapPiece target) async {
    final from = _connectFrom;
    setState(() {
      _connectFrom = null;
      _selected = target.memory.id;
    });
    if (from == null || from == target.memory.id) return;
    if (_links.any((l) => l.joins(from, target.memory.id))) {
      _showMessage('These two are already connected');
      return;
    }
    try {
      final link = await ScrapbookService.connect(
        _coupleId,
        from,
        target.memory.id,
        ConnectionStyle.dotted,
      );
      if (!mounted) return;
      setState(() {
        _links = [..._links, link];
        _undo.add(_Undo(addedLinkId: link.id));
      });
    } catch (e) {
      if (mounted) _showMessage(friendlyError(e));
    }
  }

  Future<void> _tapLink(ScrapConnection link) async {
    final pick = await pickLink(context, link);
    if (pick == null || !mounted) return;
    try {
      if (pick.remove) {
        await ScrapbookService.disconnect(link.id);
        if (!mounted) return;
        setState(() {
          _links = [
            for (final l in _links)
              if (l.id != link.id) l,
          ];
          _undo.add(_Undo(removedLink: link));
        });
      } else if (pick.style case final style? when style != link.style) {
        await ScrapbookService.restyle(link.id, style);
        if (!mounted) return;
        setState(() {
          _links = [
            for (final l in _links)
              l.id == link.id ? l.copyWith(style: style) : l,
          ];
          _undo.add(_Undo(restyled: link));
        });
      }
    } catch (e) {
      if (mounted) _showMessage(friendlyError(e));
    }
  }

  Future<void> _arrangeMenu() async {
    final action = await pickArrange(context, hasSelection: _selected != null);
    if (action == null || !mounted) return;
    if (!await confirmArrange(context, action) || !mounted) return;
    final frames = {for (final e in _saved.entries) e.key: e.value.frame};
    switch (action) {
      case ArrangeAction.organize:
      case ArrangeAction.resetPositions:
        // Date order with each memory's chosen frame kept.
        final org = ScrapbookLayout.organize(_memories, frames: frames);
        _arrangeInto(org.items);
      case ArrangeAction.resetAll:
        // Back to the automatic scrapbook: frames forgotten too.
        final org = ScrapbookLayout.organize(_memories);
        _arrangeInto(org.items, forgetAll: true);
      case ArrangeAction.resetItem:
        final id = _selected;
        if (id == null) return;
        final org = ScrapbookLayout.organize(
          _memories,
          frames: {...frames, id: null},
        );
        final item = org.items[id];
        if (item == null) return;
        _apply({id: item.copyWith(z: _saved[id]?.z ?? item.z)});
    }
  }

  /// Everything glides from where it is to [target]; then it is saved.
  void _arrangeInto(Map<String, LayoutItem> target, {bool forgetAll = false}) {
    if (_query.isNotEmpty) _search.clear();
    final from = _drawn;
    void finish() {
      if (forgetAll) {
        _apply({
          for (final id in {..._saved.keys}) id: null,
        });
      } else {
        _apply(target);
      }
    }

    if (motionOff(context)) {
      finish();
      return;
    }
    _arrangeFrom = from;
    _arrangeTo = target;
    _arrange.forward(from: 0).whenComplete(() {
      _arrangeFrom = _arrangeTo = null;
      if (mounted) finish();
    });
  }

  void _arrangeStep() {
    final from = _arrangeFrom, to = _arrangeTo;
    if (from == null || to == null) return;
    final t = Curves.easeInOutCubic.transform(_arrange.value);
    double lerp(double a, double b) => a + (b - a) * t;
    final mid = <String, LayoutItem>{
      for (final e in to.entries)
        e.key: from[e.key] == null
            ? e.value
            : LayoutItem(
                memoryId: e.key,
                x: lerp(from[e.key]!.x, e.value.x),
                y: lerp(from[e.key]!.y, e.value.y),
                width: lerp(from[e.key]!.width, e.value.width),
                rotation: lerp(from[e.key]!.rotation, e.value.rotation),
                frame: e.value.frame,
                z: e.value.z,
              ),
    };
    setState(() => _relayout(saved: mid));
  }

  // ------------------------------------------------------------ saving

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 1500), _flush);
  }

  /// Sends what changed, in as few requests as possible.
  Future<void> _flush() async {
    _saveTimer?.cancel();
    if (_saving ||
        (_dirty.isEmpty && _removed.isEmpty && _dirtyDecos.isEmpty)) {
      return;
    }
    final decosToSave = [
      for (final d in _decos)
        if (_dirtyDecos.contains(d.id)) d,
    ];
    final toSave = [for (final id in _dirty) ?_saved[id]];
    final toRemove = {..._removed};
    _saving = true;
    if (mounted) setState(() {});
    try {
      if (toRemove.isNotEmpty) {
        if (_saved.isEmpty) {
          await ScrapbookService.removeAllItems(_coupleId);
        } else {
          await ScrapbookService.removeItems(_coupleId, toRemove);
        }
      }
      await ScrapbookService.saveItems(_coupleId, toSave);
      await ScrapbookService.saveDecorations(_coupleId, decosToSave);
      for (final d in decosToSave) {
        if (_decos.contains(d)) _dirtyDecos.remove(d.id);
      }
      _removed.removeAll(toRemove);
      for (final i in toSave) {
        if (_saved[i.memoryId] == i) _dirty.remove(i.memoryId);
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          "Couldn't save the scrapbook just now. It will try again.",
        );
      }
    } finally {
      _saving = false;
      if (mounted) {
        setState(() {});
        if (_dirty.isNotEmpty ||
            _removed.isNotEmpty ||
            _dirtyDecos.isNotEmpty) {
          _scheduleSave();
        }
      }
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
            final value = _startView();
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
            editing: _editing,
            canvas: ScrapbookCanvas(
              layout: layout,
              links: _links,
              photoScale:
                  MediaQuery.devicePixelRatioOf(context) * _defaultScale * 1.6,
              lowRes: _lowRes,
              onTapPiece: _tapPiece,
              editing: _editing,
              selectedId: _selected,
              connectFromId: _connectFrom,
              live: _live,
              view: _view,
              onTapEmpty: () => setState(() {
                _selected = null;
                _selectedDeco = null;
                _connectFrom = null;
              }),
              onTapLink: _tapLink,
              onGestureStart: _gestureStart,
              onGestureUpdate: _gestureUpdate,
              onGestureEnd: _gestureEnd,
              decorations: _decos,
              decoLive: _decoLive,
              selectedDecoId: _selectedDeco,
              onTapDeco: _tapDeco,
              onDecoGestureStart: _decoGestureStart,
              showDates: !_hideDates,
              tagOpacity: _tagOpacity,
            ),
            onInteractionStart: _anim.stop,
            onInteractionEnd: _settle,
            onMonth: (m) => _zoomToRect(
              Rect.fromLTRB(0, m.top, layout.width, m.bottom),
              alignTop: true,
            ),
            hideDates: _hideDates,
            onToggleDates: _toggleDates,
            overlay: !_editing
                ? null
                : Stack(
                    children: [
                      if (_connectFrom != null)
                        Positioned(
                          top: 10,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: _ConnectBanner(
                              onCancel: () =>
                                  setState(() => _connectFrom = null),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 12,
                        child: ScrapEditToolbar(
                          hasSelection: _selected != null,
                          connecting: _connectFrom != null,
                          saving: _saving,
                          onFrame: _frame,
                          onSize: _size,
                          onTurn: _selectedDeco != null ? _turnDeco : _turn,
                          onLayer: _selectedDeco != null ? _layerDeco : _layer,
                          onConnect: _toggleConnect,
                          onDone: _done,
                          onAdd: _addMenu,
                          onEditMemory: _selected == null ? null : _editMemory,
                          deco: _selectedDeco != null,
                          onEditNote:
                              _selectedDecoration?.kind == DecoKind.stickyNote
                              ? _editNote
                              : null,
                          onColor:
                              _selectedDecoration != null &&
                                  colorsFor(
                                    _selectedDecoration!.kind,
                                  ).isNotEmpty
                              ? _recolor
                              : null,
                          onDelete: _deleteDeco,
                        ),
                      ),
                    ],
                  ),
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
                editing: _editing,
                canEdit: _layoutReady && _memories.isNotEmpty && !_loading,
                onSearch: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _search.clear();
                }),
                onEdit: _startEditing,
                onAdd: _loading ? null : _add,
                onUndo: _undo.isEmpty ? null : _undoLast,
                onArrange: _arrangeMenu,
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

class _ConnectBanner extends StatelessWidget {
  const _ConnectBanner({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: 14, right: 4),
    decoration: BoxDecoration(
      color: UsPalette.card.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: NotePalette.rose.withValues(alpha: 0.6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timeline_rounded, size: 16, color: NotePalette.rose),
        const SizedBox(width: 8),
        Text(
          'Tap another memory to connect',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: NotePalette.cream),
        ),
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(foregroundColor: NotePalette.pink),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.searching,
    required this.editing,
    required this.canEdit,
    required this.onSearch,
    required this.onEdit,
    required this.onAdd,
    this.onUndo,
    this.onArrange,
  });

  final bool searching;
  final bool editing;
  final bool canEdit;
  final VoidCallback onSearch;
  final VoidCallback onEdit;
  final VoidCallback? onAdd;

  /// While editing: Undo (null when there is nothing to undo) and Arrange.
  final VoidCallback? onUndo;
  final VoidCallback? onArrange;

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
                            MediaQuery.sizeOf(context).width < 360 || editing
                                ? 24
                                : 30,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // The heart makes room for the title on narrow phones.
                    if (!editing &&
                        MediaQuery.sizeOf(context).width >= 360) ...[
                      const SizedBox(width: 6),
                      const UsIcon(
                        UsIcons.heart,
                        size: 20,
                        color: NotePalette.rose,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  editing
                      ? 'Tap to select, hold to move.'
                      : 'The little moments that became us.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NotePalette.muted,
                  ),
                ),
              ],
            ),
          ),
          if (editing) ...[
            IconButton(
              tooltip: 'Undo',
              onPressed: onUndo,
              icon: UsIcon(
                UsIcons.undo,
                color: onUndo == null
                    ? NotePalette.muted.withValues(alpha: 0.35)
                    : NotePalette.cream,
              ),
            ),
            // Narrow phones: just the icon, so the title keeps its room.
            if (MediaQuery.sizeOf(context).width < 360)
              IconButton(
                tooltip: 'Arrange',
                onPressed: onArrange,
                icon: const UsIcon(UsIcons.arrange, color: NotePalette.cream),
              )
            else
              OutlinedButton.icon(
                onPressed: onArrange,
                style: OutlinedButton.styleFrom(
                  foregroundColor: NotePalette.cream,
                  side: BorderSide(
                    color: NotePalette.pink.withValues(alpha: 0.45),
                  ),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const UsIcon(UsIcons.arrange, size: 18),
                label: const Text('Arrange'),
              ),
          ] else ...[
            if (canEdit)
              IconButton(
                tooltip: 'Edit scrapbook',
                onPressed: onEdit,
                icon: const UsIcon(UsIcons.edit, color: NotePalette.cream),
              ),
            IconButton(
              tooltip: searching ? 'Close search' : 'Find a memory',
              onPressed: onSearch,
              icon: UsIcon(
                searching ? UsIcons.close : UsIcons.search,
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
                        child: Center(
                          child: UsIcon(
                            UsIcons.plus,
                            color: UsPalette.onRose,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The zoomable scrapbook plus what sits on top of it at normal size: month
/// labels when far out, and the Hide / Show dates button.
class _ScrapbookViewport extends StatelessWidget {
  const _ScrapbookViewport({
    required this.layout,
    required this.view,
    required this.viewport,
    required this.minScale,
    required this.maxScale,
    required this.defaultScale,
    required this.editing,
    required this.canvas,
    required this.onInteractionStart,
    required this.onInteractionEnd,
    required this.onMonth,
    required this.hideDates,
    required this.onToggleDates,
    this.overlay,
  });

  final bool hideDates;
  final VoidCallback onToggleDates;

  final ScrapbookLayout layout;
  final TransformationController view;
  final Size viewport;
  final double minScale;
  final double maxScale;
  final double defaultScale;
  final bool editing;
  final Widget canvas;
  final VoidCallback onInteractionStart;
  final VoidCallback onInteractionEnd;
  final void Function(ScrapMonth) onMonth;

  /// The editing toolbar and banners, on top of everything.
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The wall the framed board hangs on: soft plum, seen only above or
        // below a board shorter than the screen.
        const Positioned.fill(child: ColoredBox(color: UsPalette.surface)),
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
          child: RepaintBoundary(child: canvas),
        ),
        // Everything below listens to the view and redraws on its own;
        // the scrapbook itself is never rebuilt while you zoom.
        if (!hideDates)
          Positioned.fill(
            child: _MonthLabels(
              layout: layout,
              view: view,
              viewport: viewport,
              defaultScale: defaultScale,
              onMonth: onMonth,
            ),
          ),
        // Zoomed out: hide or show the dates (above the editing toolbar
        // while editing).
        Positioned(
          right: 12,
          bottom: editing ? 96 : 16,
          child: _DatesToggle(
            view: view,
            defaultScale: defaultScale,
            hidden: hideDates,
            onTap: onToggleDates,
          ),
        ),
        ?overlay,
      ],
    );
  }
}

/// "Hide dates" / "Show dates", only while zoomed out (where the month
/// labels float over the board).
class _DatesToggle extends StatelessWidget {
  const _DatesToggle({
    required this.view,
    required this.defaultScale,
    required this.hidden,
    required this.onTap,
  });

  final TransformationController view;
  final double defaultScale;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: view,
      builder: (context, _) {
        final far = view.value.getMaxScaleOnAxis() < defaultScale * 0.6;
        return IgnorePointer(
          ignoring: !far,
          child: AnimatedOpacity(
            opacity: far ? 1 : 0,
            duration: motionOff(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            child: Material(
              color: UsPalette.card.withValues(alpha: 0.9),
              shape: StadiumBorder(
                side: BorderSide(
                  color: NotePalette.pink.withValues(alpha: 0.35),
                ),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const UsIcon(
                        UsIcons.calendar,
                        size: 18,
                        color: NotePalette.pink,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hidden ? 'Show dates' : 'Hide dates',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: NotePalette.cream,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Far out, each month's paper tag at readable size over its chapter
/// (taking over from the board's own tags, which fade out first). Tap one
/// to zoom into that month. Tags never overlap: crowded ones move down,
/// and any that would fall off screen wait until you zoom in.
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

  /// Lettering size of a floating tag (screen pixels).
  static const _size = 16.0;

  /// Room above and below a tag so it is easy to tap.
  static const _pad = 10.0;

  /// A tag's on-screen size, from its text.
  static Size _measure(String label) {
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: AppTypography.monthTag(size: _size),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final size = Size(
      text.width + _size * 1.8 + 4,
      text.height + _size * 0.2 + _pad * 2,
    );
    text.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final still = motionOff(context);
    final sizes = {
      for (final m in layout.months)
        (m.year, m.month): _measure(monthTitle(m.year, m.month)),
    };
    return AnimatedBuilder(
      animation: view,
      builder: (context, _) {
        final m = view.value;
        final s = m.getMaxScaleOnAxis();
        final opacity = floatingTagOpacity(
          farOutProgress(s, defaultScale),
          still: still,
        );
        if (opacity == 0) return const SizedBox.shrink();
        final tr = m.getTranslation();
        final shown = <ScrapMonth>[];
        final boxes = <Rect>[];
        for (final month in layout.months) {
          final size = sizes[(month.year, month.month)]!;
          final top = month.headingRect.top * s + tr.y - _pad;
          if (top < -size.height || top > viewport.height) continue;
          final left = (month.headingRect.left * s + tr.x).clamp(
            8.0,
            math.max(8.0, viewport.width - size.width - 8),
          ).toDouble();
          shown.add(month);
          boxes.add(Offset(left, top) & size);
        }
        final spots = spreadTags(boxes, maxBottom: viewport.height);
        return Opacity(
          opacity: opacity,
          child: Stack(
            children: [
              for (var i = 0; i < shown.length; i++)
                if (spots[i] case final spot?)
                  Positioned.fromRect(
                    rect: spot,
                    child: _FloatingTag(
                      month: shown[i],
                      onTap: () => onMonth(shown[i]),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _FloatingTag extends StatelessWidget {
  const _FloatingTag({required this.month, required this.onTap});

  final ScrapMonth month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${monthTitle(month.year, month.month)}, ${month.count} memories. Zoom in',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: _MonthLabels._pad),
          child: MonthTag(
            label: monthTitle(month.year, month.month),
            size: _MonthLabels._size,
          ),
        ),
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
