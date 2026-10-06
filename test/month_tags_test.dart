import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/widgets/timeline/scrapbook_canvas.dart';

void main() {
  group('month tag handoff', () {
    test('a month is never shown by both tags at once', () {
      for (var i = 0; i <= 100; i++) {
        final t = i / 100;
        final board = boardTagOpacity(t);
        final floating = floatingTagOpacity(t);
        expect(board == 0 || floating == 0, isTrue, reason: 't=$t');
      }
    });

    test('board tags at normal zoom, floating tags when far out', () {
      expect(boardTagOpacity(farOutProgress(1, 1)), 1);
      expect(floatingTagOpacity(farOutProgress(1, 1)), 0);
      expect(boardTagOpacity(farOutProgress(0.3, 1)), 0);
      expect(floatingTagOpacity(farOutProgress(0.3, 1)), 1);
    });

    test('reduced motion swaps at the midpoint with no fade', () {
      expect(boardTagOpacity(0.49, still: true), 1);
      expect(floatingTagOpacity(0.49, still: true), 0);
      expect(boardTagOpacity(0.5, still: true), 0);
      expect(floatingTagOpacity(0.5, still: true), 1);
    });
  });

  group('spreadTags', () {
    test('overlapping tags are moved apart, keeping their order', () {
      final out = spreadTags([
        const Rect.fromLTWH(10, 100, 120, 40),
        const Rect.fromLTWH(60, 110, 120, 40),
      ], maxBottom: 800);
      expect(out[0], const Rect.fromLTWH(10, 100, 120, 40));
      expect(out[1]!.top, greaterThanOrEqualTo(out[0]!.bottom));
      expect(out[1]!.left, 60);
    });

    test('tags that do not touch stay where they are', () {
      const a = Rect.fromLTWH(10, 100, 120, 40);
      const b = Rect.fromLTWH(200, 100, 120, 40);
      expect(spreadTags([a, b], maxBottom: 800), [a, b]);
    });

    test('a tag pushed off screen is dropped, not stacked below', () {
      final out = spreadTags([
        const Rect.fromLTWH(10, 100, 120, 40),
        const Rect.fromLTWH(10, 100, 120, 40),
      ], maxBottom: 160);
      expect(out[0], isNotNull);
      expect(out[1], isNull);
    });
  });

  test('month titles are written the way a person would', () {
    expect(monthTitle(2026, 10), 'October 2026');
    expect(monthTitle(2026, 9), 'September 2026');
  });
}
