import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/mood.dart';
import '../../models/mood_visual.dart';
import '../../theme/app_effects.dart';
import '../../theme/app_spacing.dart';
import '../../theme/us_palette.dart';
import '../atoms/avatar_circle.dart';
import '../atoms/fit_label.dart';
import '../atoms/us_icon.dart';
import '../effects/motion.dart';
import 'mood_art.dart';

part 'mood_card_parts.dart';

/// One person on the mood card: name, photo and today's mood (or null).
@immutable
class MoodPerson {
  const MoodPerson({required this.name, this.avatarUrl, this.mood, this.note});

  final String name;
  final String? avatarUrl;
  final Mood? mood;

  /// Today's note shared with the mood, if any.
  final String? note;
}

/// Today's mood on Home: ONE card that never gets swapped.
///
/// Inside its single rounded, clipped surface there are two layers in a
/// Stack: the picker ("How are you feeling?") and the couple state
/// ("you ♥ partner"). Both are always laid out, so the card keeps its height;
/// only opacity, position and scale change.
///
/// Tapping a mood shares it straight away ([onPick]): the tapped artwork
/// lifts out of its tile and travels to your side of the couple state while
/// the other options fade, the heart appears, and both settle with one soft
/// breath. Your partner's side animates on its own when their mood arrives
/// live. With reduced motion it is a quick crossfade.
class MoodCard extends StatefulWidget {
  const MoodCard({
    super.key,
    required this.me,
    required this.partner,
    required this.busy,
    required this.onPick,
    required this.onAddNote,
    required this.onShowNotes,
  });

  final MoodPerson me;

  /// Null before your partner joins.
  final MoodPerson? partner;

  /// True while a mood is being saved: taps on moods are ignored, so one
  /// tap can never write twice.
  final bool busy;

  /// Shares [Mood] as today's mood. The card animates optimistically; if the
  /// save fails, Home restores the previous mood and the card follows.
  final ValueChanged<Mood> onPick;

  /// Opens the note sheet (add, edit or remove today's note).
  final VoidCallback onAddNote;

  /// Shows both of today's notes in full.
  final VoidCallback onShowNotes;

  @override
  State<MoodCard> createState() => _MoodCardState();
}

class _MoodCardState extends State<MoodCard> with TickerProviderStateMixin {
  /// 1 = picker showing, 0 = couple state showing (plain crossfade).
  late final AnimationController _picker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: widget.me.mood == null ? 1 : 0,
  );

  /// The merge after a tap: 0 → 1 over about half a second.
  late final AnimationController _merge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  /// 0 = your two moods side by side, 1 = merged into one shared mood.
  /// Only ever 1 when both of you have the same mood.
  late final AnimationController _together = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: _matching ? 1 : 0,
  );

  /// You chose to change today's mood (the picker is open over it).
  bool _changing = false;

  /// The art in flight during a merge, and where it starts.
  Mood? _flying;
  Rect? _from;
  Rect? _to;

  final _stackKey = GlobalKey();
  final _mySlotKey = GlobalKey();
  final Map<Mood, GlobalKey> _tileKeys = {
    for (final m in Mood.selectableMoods) m: GlobalKey(),
  };

  bool get _pickerWanted => widget.me.mood == null || _changing;

  /// Both of you have shared the same mood today.
  bool get _matching {
    final mine = widget.me.mood;
    return mine != null && mine == widget.partner?.mood;
  }

  /// Merge when the moods match, separate when they don't. Gentle, both ways.
  void _syncTogether() {
    final target = _matching ? 1.0 : 0.0;
    if (_together.value == target) return;
    if (motionOff(context)) {
      _together.value = target;
    } else {
      _together.animateTo(target, curve: const Cubic(0.65, 0, 0.35, 1));
    }
  }

  @override
  void initState() {
    super.initState();
    // When a merge ends, land on whatever state is now true (it may have
    // rolled back while the art was travelling).
    _merge.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      _picker.value = _pickerWanted ? 1 : 0;
      setState(() => _flying = null);
      // The art has landed on your side; if your moods now match, the two
      // sides glide together.
      _syncTogether();
    });
  }

  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // Decode every mood at the couple-state size up front, so the art that
    // travels after a tap is ready on its first frame.
    final width = (_Side.artInner * MediaQuery.devicePixelRatioOf(context))
        .round();
    // The shared (matching) mood is drawn larger: decode that size too.
    final shared = (_Shared.artSize * MediaQuery.devicePixelRatioOf(context))
        .round();
    for (final m in Mood.selectableMoods) {
      for (final w in [width, shared]) {
        precacheImage(
          ResizeImage(AssetImage(MoodVisual.of(m).assetPath), width: w),
          context,
          onError: (_, _) {},
        );
      }
    }
  }

  @override
  void didUpdateWidget(MoodCard old) {
    super.didUpdateWidget(old);
    // Your mood changed from outside the card (first load, or a failed
    // save rolling back): follow it with a crossfade, never a merge replay.
    if (old.me.mood != widget.me.mood && !_merge.isAnimating) {
      _syncPicker();
    }
    // A realtime change from your partner (or a rollback): merge or
    // separate. During a tap's merge this waits until the art has landed.
    if (!_merge.isAnimating) _syncTogether();
  }

  @override
  void dispose() {
    _picker.dispose();
    _merge.dispose();
    _together.dispose();
    super.dispose();
  }

  void _syncPicker() {
    final still = motionOff(context);
    final target = _pickerWanted ? 1.0 : 0.0;
    if (still) {
      _picker.value = target;
    } else {
      _picker.animateTo(target, curve: AppMotion.enter);
    }
  }

  Rect? _rectOf(GlobalKey key) {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || box == null || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: stack);
    return topLeft & box.size;
  }

  void _pick(Mood mood) {
    if (widget.busy || _merge.isAnimating) return;
    // Picking the mood you already have just closes the picker.
    if (mood == widget.me.mood) {
      setState(() => _changing = false);
      _syncPicker();
      return;
    }
    final still = motionOff(context);
    final from = _rectOf(_tileKeys[mood]!);
    final slot = _rectOf(_mySlotKey);
    // Land on the artwork itself, centred in its slot.
    final to = slot == null
        ? null
        : Rect.fromCenter(
            center: slot.center,
            width: _Side.artInner,
            height: _Side.artInner,
          );
    setState(() => _changing = false);
    widget.onPick(mood);
    // Moving away from a shared mood: separate now, so your side is in
    // place for the art to land on.
    if (mood != widget.partner?.mood && _together.value > 0) {
      if (still) {
        _together.value = 0;
      } else {
        _together.animateTo(0, curve: const Cubic(0.65, 0, 0.35, 1));
      }
    }

    if (still || from == null || to == null) {
      _syncPicker();
      return;
    }
    setState(() {
      _flying = mood;
      _from = from;
      _to = to;
    });
    _merge.forward(from: 0);
  }

  void _openPicker() {
    if (widget.busy || _merge.isAnimating) return;
    setState(() => _changing = true);
    _syncPicker();
  }

  void _closePicker() {
    setState(() => _changing = false);
    _syncPicker();
  }

  // ---------------------------------------------------------------- timing

  static double _seg(double t, double a, double b, [Curve c = Curves.linear]) =>
      c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  static const _travel = Cubic(0.77, 0, 0.175, 1); // strong ease-in-out

  /// Keeps the mood's own two tones (inner and outer) so moods stay distinct.
  /// No mood: a plain plum glow.
  static List<Color> _glow(Mood? mood) {
    if (mood == null) {
      return const [Color(0xFF34182F), Color(0xE634182F), Color(0x0034182F)];
    }
    final c = MoodVisual.of(mood).gradientFor(Brightness.dark);
    final inner = Color.lerp(c.last, UsPalette.card, 0.05)!;
    final outer = Color.lerp(
      c.first,
      UsPalette.card,
      0.15,
    )!.withValues(alpha: 0.85);
    return [inner, outer, outer.withValues(alpha: 0)];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final still = motionOff(context);
    final mine = _glow(widget.me.mood);
    final theirs = _glow(widget.partner?.mood);
    final myAccent = widget.me.mood == null
        ? UsPalette.rose
        : MoodVisual.of(widget.me.mood!).accentFor(Brightness.dark);
    final partnerAccent = widget.partner?.mood == null
        ? UsPalette.rose
        : MoodVisual.of(widget.partner!.mood!).accentFor(Brightness.dark);
    final myHighlight = Color.lerp(
      mine[0],
      myAccent,
      0.25,
    )!.withValues(alpha: 0.45);
    final partnerHighlight = Color.lerp(
      theirs[0],
      partnerAccent,
      0.25,
    )!.withValues(alpha: 0.45);
    return DecoratedBox(
      // The shadow sits outside the clip, on the same rounded shape.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.hero),
        boxShadow: AppShadows.raised(scheme),
      ),
      // ONE permanent rounded surface. Everything that moves, including the
      // background colours, is inside this clip, so no frame can show a
      // square corner.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.hero),
        // The base keeps each side's own colour with a soft middle blend.
        // A small highlight glows behind each artwork; same mood = one colour.
        // Background colours tween over 360 ms.
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: UsPalette.card,
            borderRadius: BorderRadius.circular(AppRadius.hero),
          ),
          position: DecorationPosition.background,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedContainer(
                  key: const ValueKey('mood-base'),
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 360),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [mine[0], mine[0], theirs[0], theirs[0]],
                      stops: const [0.0, 0.28, 0.72, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: AnimatedContainer(
                  key: const ValueKey('mood-glow-me'),
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 360),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.5, -0.25),
                      radius: 0.6,
                      colors: [myHighlight, myHighlight.withValues(alpha: 0)],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: AnimatedContainer(
                  key: const ValueKey('mood-glow-partner'),
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 360),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.5, -0.25),
                      radius: 0.6,
                      colors: [
                        partnerHighlight,
                        partnerHighlight.withValues(alpha: 0),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  // A soft light from the top and a little depth at the bottom.
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x0FFFFFFF),
                        Color(0x00000000),
                        Color(0x29000000),
                      ],
                      stops: [0, 0.45, 1],
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: Listenable.merge([_picker, _merge, _together]),
                builder: (context, _) => _layers(context),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: UsPalette.line),
                      borderRadius: BorderRadius.circular(AppRadius.hero),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _layers(BuildContext context) {
    final flying = _flying != null;
    final s = _merge.value;

    // How visible each layer is.
    final pickerO = flying
        ? 1 - _seg(s, 0.15, 0.48, Curves.easeOut)
        : _picker.value;
    final coupleO = flying
        ? _seg(s, 0.32, 0.78, Curves.easeOut)
        : 1 - _picker.value;
    // One soft breath as both settle, then stop.
    final breathe = flying && s > 0.84
        ? 1 + 0.014 * math.sin(math.pi * _seg(s, 0.84, 1))
        : 1.0;

    // Both layers are laid out in the Stack, so the card's height is the
    // taller of the two at all times: no collapse between states.
    return Stack(
      key: _stackKey,
      alignment: Alignment.center,
      children: [
        // Soft glow in the middle: dusty rose between two moods, the shared
        // mood's own accent when you match.
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: coupleO,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.1),
                    radius: 0.75,
                    colors: [
                      Color.lerp(
                        UsPalette.rose,
                        widget.me.mood == null
                            ? UsPalette.rose
                            : MoodVisual.of(
                                widget.me.mood!,
                              ).accentFor(Brightness.dark),
                        _together.value,
                      )!.withValues(alpha: 0.2),
                      UsPalette.rose.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // The couple state. Always laid out (it holds your art's slot).
        IgnorePointer(
          ignoring: coupleO < 0.5,
          child: ExcludeSemantics(
            excluding: coupleO < 0.5,
            child: Opacity(
              opacity: coupleO,
              child: Transform.scale(
                scale: breathe,
                child: _couple(context, hideMyArt: flying && s < 0.86),
              ),
            ),
          ),
        ),
        // The picker, over the same space.
        IgnorePointer(
          ignoring: pickerO < 0.5,
          child: ExcludeSemantics(
            excluding: pickerO < 0.5,
            child: Opacity(
              opacity: pickerO,
              child: _pickerLayer(context, hiding: _flying),
            ),
          ),
        ),
        // The tapped art travelling to your side.
        if (flying && _from != null && _to != null && s < 0.86) _flight(s),
      ],
    );
  }

  Widget _flight(double s) {
    final t = _seg(s, 0.18, 0.86, _travel);
    final rect = Rect.lerp(_from, _to, t)!;
    // Press (down to 0.94), lift (up to 1.08), then settle to 1.
    final scale = s < 0.18
        ? 1 - 0.06 * _seg(s, 0, 0.18, Curves.easeOut)
        : s < 0.42
        ? 0.94 + 0.14 * _seg(s, 0.18, 0.42, Curves.easeOut)
        : 1.08 - 0.08 * _seg(s, 0.42, 0.86, Curves.easeInOut);
    return Positioned.fromRect(
      key: const ValueKey('mood-flight'),
      rect: rect,
      child: IgnorePointer(
        child: Transform.scale(
          scale: scale,
          // Always drawn at the slot's size and scaled to the rect: a
          // changing size would re-decode the image every frame (blank).
          child: FittedBox(
            child: MoodArt(
              visual: MoodVisual.of(_flying!),
              size: _Side.artInner,
              semantic: false,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- picker

  Widget _pickerLayer(BuildContext context, {Mood? hiding}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final partner = widget.partner;
    final s = _merge.value;
    // During a merge the other options fade a little ahead of the layer.
    final othersO = hiding == null ? 1.0 : 1 - _seg(s, 0.1, 0.35);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'How are you feeling?',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (_changing && widget.me.mood != null)
                TextButton(
                  onPressed: _closePicker,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    textStyle: theme.textTheme.bodySmall,
                  ),
                  child: Text('Keep ${widget.me.mood!.label.toLowerCase()}'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, box) {
              const gap = AppSpacing.sm;
              final tileW = (box.maxWidth - gap * 3) / 4;
              final art = (tileW * 0.6).clamp(30.0, 44.0);
              final moods = Mood.selectableMoods;
              Widget row(List<Mood> four) => Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: tileW,
                      child: Opacity(
                        opacity: four[i] == hiding ? 1 : othersO,
                        child: _tile(context, four[i], art, tileW, hiding),
                      ),
                    ),
                  ],
                ],
              );
              return Column(
                children: [
                  row(moods.sublist(0, 4)),
                  const SizedBox(height: gap),
                  row(moods.sublist(4, 8)),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (partner != null) ...[
                AvatarCircle(
                  name: partner.name,
                  imageUrl: partner.avatarUrl,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    partner.mood == null
                        ? '${partner.name} hasn\'t shared a mood yet'
                        : '${partner.name} feels ${partner.mood!.label.toLowerCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (partner.mood != null)
                  MoodArt(
                    visual: MoodVisual.of(partner.mood!),
                    size: 22,
                    semantic: false,
                  ),
              ] else
                Expanded(
                  child: Text(
                    'Your partner\'s mood shows here once they join.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (_changing && widget.me.mood != null) ...[
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: widget.onAddNote,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    textStyle: theme.textTheme.bodySmall,
                  ),
                  child: const Text('Add a note'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    Mood mood,
    double art,
    double width,
    Mood? hiding,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visual = MoodVisual.of(mood);
    final current = mood == widget.me.mood;
    final accent = visual.accentFor(theme.brightness);
    return Semantics(
      button: true,
      selected: current,
      label: mood.label,
      hint: current ? 'Your mood today' : 'Share as your mood',
      excludeSemantics: true,
      child: PressScale(
        enabled: !widget.busy,
        child: Material(
          color: current
              ? accent.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            side: BorderSide(
              color: current ? accent : scheme.outline,
              width: current ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.input),
            onTap: widget.busy ? null : () => _pick(mood),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: [
                  // The art you tap is the art that travels: while it is in
                  // flight, its tile shows an empty space.
                  SizedBox.square(
                    key: _tileKeys[mood],
                    dimension: art,
                    child: mood == hiding
                        ? const SizedBox.shrink()
                        : MoodArt(visual: visual, size: art, semantic: false),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FitLabel(
                    mood.label,
                    maxWidth: width - AppSpacing.xs * 2,
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 0,
                      color: current
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w500,
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

  // ---------------------------------------------------------------- couple

  Widget _couple(BuildContext context, {required bool hideMyArt}) {
    final still = motionOff(context);
    final me = widget.me;
    final partner = widget.partner;
    final connected = me.mood != null && partner?.mood != null;
    final s = _merge.value;
    final heartIn = _flying != null ? _seg(s, 0.55, 0.9, Curves.easeOut) : 1.0;
    final t = _together.value;
    final sideFade = 1 - _seg(t, 0.35, 0.75);
    final heartFade = 1 - _seg(t, 0, 0.35);
    final sharedIn = _seg(t, 0.45, 1, Curves.easeOut);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          const heartW = 34.0;
          // How far each side travels to meet in the middle.
          final shift =
              ((box.maxWidth - heartW) / 4 + heartW / 2) *
              Curves.easeInOut.transform(t);
          Widget toward(Widget child, double dx) => Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(scale: 1 - 0.1 * t, child: child),
          );
          return Stack(
            alignment: Alignment.center,
            children: [
              // Two moods side by side (always laid out: it holds your
              // art's landing spot).
              IgnorePointer(
                ignoring: t > 0.5,
                child: ExcludeSemantics(
                  excluding: t > 0.5,
                  child: Opacity(
                    opacity: sideFade,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: toward(
                            _Side(
                              person: me,
                              isMe: true,
                              slotKey: _mySlotKey,
                              hideArt: hideMyArt,
                              onTap: _openPicker,
                              onNote: widget.onAddNote,
                            ),
                            shift,
                          ),
                        ),
                        // The heart between you: faint until both moods
                        // are in, gone once you match.
                        Padding(
                          padding: const EdgeInsets.only(top: 72),
                          child: Opacity(
                            opacity: heartFade,
                            child: AnimatedOpacity(
                              duration: still ? Duration.zero : AppMotion.sheet,
                              opacity: (connected ? 1.0 : 0.3) * heartIn,
                              child: AnimatedScale(
                                duration: still
                                    ? Duration.zero
                                    : AppMotion.sheet,
                                curve: AppMotion.snappy,
                                scale:
                                    (connected ? 1.0 : 0.85) *
                                    (0.85 + 0.15 * heartIn),
                                child: Container(
                                  width: heartW,
                                  height: heartW,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: UsPalette.rose.withValues(
                                      alpha: 0.14,
                                    ),
                                    boxShadow: connected
                                        ? [
                                            BoxShadow(
                                              color: UsPalette.rose.withValues(
                                                alpha: 0.28,
                                              ),
                                              blurRadius: 14,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.favorite_rounded,
                                    size: 18,
                                    color: UsPalette.rose,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: toward(
                            partner == null
                                ? const _EmptySide(
                                    name: 'Your partner',
                                    line: 'Not joined yet',
                                  )
                                : _Side(
                                    person: partner,
                                    isMe: false,
                                    onNote: widget.onShowNotes,
                                  ),
                            -shift,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // The shared mood, when you match.
              if (t > 0 && me.mood != null && partner != null)
                IgnorePointer(
                  ignoring: t < 0.5,
                  child: Opacity(
                    opacity: sharedIn,
                    child: Transform.scale(
                      scale: 0.94 + 0.06 * sharedIn,
                      child: _Shared(
                        mood: me.mood!,
                        me: me,
                        partner: partner,
                        onTap: _openPicker,
                        onShowNotes: widget.onShowNotes,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
