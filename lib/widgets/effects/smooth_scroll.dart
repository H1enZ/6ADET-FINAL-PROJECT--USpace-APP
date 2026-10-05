import 'package:flutter/widgets.dart';

/// Mouse-wheel scrolling that glides instead of jumping a notch at a time
/// (Flutter on the web jumps by default, which feels choppy). Touch, drag
/// and trackpad scrolling, the scrollbar and keyboard scrolling are
/// unchanged. With reduce motion on, the wheel jumps as before.
class SmoothScrollController extends ScrollController {
  SmoothScrollController({super.debugLabel});

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _SmoothScrollPosition(
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );
}

class _SmoothScrollPosition extends ScrollPositionWithSingleContext {
  _SmoothScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  static const _glide = Duration(milliseconds: 220);

  /// Where the current glide is heading, so quick notches add up instead
  /// of each starting from wherever the last one had got to.
  double? _target;

  @override
  void pointerScroll(double delta) {
    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (delta == 0 || reduceMotion || !physics.shouldAcceptUserOffset(this)) {
      super.pointerScroll(delta);
      return;
    }
    final from = _target != null && activity is DrivenScrollActivity
        ? _target!
        : pixels;
    final target = (from + delta).clamp(minScrollExtent, maxScrollExtent);
    if (target == pixels) return;
    _target = target;
    animateTo(
      target,
      duration: _glide,
      curve: Curves.easeOutCubic,
    ).whenComplete(() {
      if (_target == target) _target = null;
    });
  }
}

/// Gives [builder] a [SmoothScrollController] for the screen's main list,
/// and disposes of it.
class SmoothScroll extends StatefulWidget {
  const SmoothScroll({super.key, required this.builder});

  final Widget Function(ScrollController controller) builder;

  @override
  State<SmoothScroll> createState() => _SmoothScrollState();
}

class _SmoothScrollState extends State<SmoothScroll> {
  final _controller = SmoothScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}
