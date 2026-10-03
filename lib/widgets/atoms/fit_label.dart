import 'package:flutter/material.dart';

/// A short label for small spaces (mood grid, quick actions, the hero's
/// mood word). It wraps at spaces like normal text. When even one word is
/// wider than [maxWidth], or the label needs more than [maxLines] lines
/// (large text on a narrow phone), the whole label scales down to fit
/// instead of breaking in the middle of a word or being cut off.
///
/// [maxWidth] is passed in rather than measured with a LayoutBuilder, so the
/// label can sit inside IntrinsicHeight rows (equal-height tiles).
class FitLabel extends StatelessWidget {
  const FitLabel(
    this.text, {
    super.key,
    required this.maxWidth,
    this.style,
    this.maxLines = 2,
    this.textAlign = TextAlign.center,
    this.alignment = Alignment.center,
  });

  final String text;
  final double maxWidth;
  final TextStyle? style;
  final int maxLines;
  final TextAlign textAlign;

  /// Where the scaled-down label sits in [maxWidth].
  final Alignment alignment;

  // Measurements are cached: Home rebuilds on every mood tap and live
  // update, and the same labels come back each time.
  // (A map literal keeps insertion order, so the oldest entry goes first.)
  static final _cache = <String, double?>{};
  static const _cacheSize = 256;

  @override
  Widget build(BuildContext context) {
    // Measure with what Text will really use, including the bold-text
    // accessibility setting.
    var resolved = DefaultTextStyle.of(context).style.merge(style);
    if (MediaQuery.boldTextOf(context)) {
      resolved = resolved.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    final key =
        '$text|${resolved.hashCode}|${scaler.scale(100)}|'
        '${maxWidth.toStringAsFixed(1)}|$maxLines|$direction';
    final double? scaledWidth;
    if (_cache.containsKey(key)) {
      scaledWidth = _cache[key];
    } else {
      scaledWidth = _measure(resolved, scaler, direction);
      _cache[key] = scaledWidth;
      if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first);
    }

    final label = Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (scaledWidth == null) return label;
    // Lay it out at a width where it fits, then scale it down.
    return SizedBox(
      width: maxWidth,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: SizedBox(width: scaledWidth, child: label),
      ),
    );
  }

  /// Null when the label fits as it is; otherwise the narrowest width at
  /// which it fits in [maxLines] lines with no word broken.
  double? _measure(
    TextStyle resolved,
    TextScaler scaler,
    TextDirection direction,
  ) {
    TextPainter painter(int? lines) => TextPainter(
      text: TextSpan(text: text, style: resolved),
      textDirection: direction,
      textScaler: scaler,
      textAlign: textAlign,
      maxLines: lines,
    );

    var widest = 0.0;
    for (final word in text.split(' ')) {
      final p = TextPainter(
        text: TextSpan(text: word, style: resolved),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (p.width > widest) widest = p.width;
      p.dispose();
    }

    bool fitsAt(double width) {
      final p = painter(maxLines)..layout(maxWidth: width);
      final ok = !p.didExceedMaxLines;
      p.dispose();
      return ok;
    }

    if (widest <= maxWidth && fitsAt(maxWidth)) return null;

    // Grow from the widest word until the label fits in maxLines.
    final single = painter(1)..layout();
    final full = single.width;
    single.dispose();
    var width = widest.ceilToDouble() + 1;
    while (width < full + 1 && !fitsAt(width)) {
      width += 4;
    }
    return width;
  }
}
