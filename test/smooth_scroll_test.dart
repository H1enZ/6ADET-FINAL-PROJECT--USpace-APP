import 'package:final_project/widgets/effects/smooth_scroll.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SmoothScrollController controller;

  Future<void> pumpList(WidgetTester tester) async {
    controller = SmoothScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          controller: controller,
          children: [
            for (var i = 0; i < 100; i++)
              SizedBox(height: 50, child: Text('$i')),
          ],
        ),
      ),
    );
  }

  Future<void> wheel(WidgetTester tester, double dy) async {
    final at = tester.getCenter(find.byType(ListView));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(at));
    await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
  }

  testWidgets('a wheel notch glides to its place instead of jumping', (
    tester,
  ) async {
    await pumpList(tester);
    await wheel(tester, 100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final mid = controller.offset;
    expect(mid, greaterThan(0));
    expect(mid, lessThan(100));
    await tester.pumpAndSettle();
    expect(controller.offset, 100);
  });

  testWidgets('quick notches add up', (tester) async {
    await pumpList(tester);
    await wheel(tester, 100);
    await tester.pump(const Duration(milliseconds: 30));
    await wheel(tester, 100);
    await tester.pump(const Duration(milliseconds: 30));
    await wheel(tester, 100);
    await tester.pumpAndSettle();
    expect(controller.offset, 300);
  });

  testWidgets('stops at the ends', (tester) async {
    await pumpList(tester);
    await wheel(tester, -100);
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
  });
}
