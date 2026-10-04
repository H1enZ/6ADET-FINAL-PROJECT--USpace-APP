import 'package:final_project/widgets/organisms/phone_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // What the app inside the frame sees, and where it is drawn on screen.
  Future<(Size, Rect)> pump(WidgetTester tester, Size window) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Size seen;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => PhoneFrame(child: child!),
        home: Builder(
          builder: (context) {
            seen = MediaQuery.sizeOf(context);
            return const Scaffold(body: SizedBox.expand(key: Key('app')));
          },
        ),
      ),
    );
    final app = find.byKey(const Key('app'));
    final rect = Rect.fromPoints(
      tester.getTopLeft(app),
      tester.getBottomRight(app),
    );
    return (seen, rect);
  }

  testWidgets('a tall desktop window shows a full-size 390 x 844 phone', (
    tester,
  ) async {
    final (seen, rect) = await pump(tester, const Size(1920, 1080));
    expect(seen, PhoneFrame.screenSize);
    expect(rect.width, closeTo(390, 0.01));
    expect(rect.height, closeTo(844, 0.01));
    expect(rect.center.dx, closeTo(960, 0.01));
    expect(rect.center.dy, closeTo(540, 0.01));
  });

  testWidgets('a short desktop window scales the whole phone down', (
    tester,
  ) async {
    for (final window in const [
      Size(1440, 900),
      Size(1256, 800),
      Size(1366, 768),
    ]) {
      final (seen, rect) = await pump(tester, window);
      expect(seen, PhoneFrame.screenSize, reason: '$window');
      expect(rect.height, lessThan(844), reason: '$window');
      expect(rect.height, lessThan(window.height), reason: '$window');
      expect(
        rect.width / rect.height,
        closeTo(390 / 844, 0.001),
        reason: '$window',
      );
      expect(
        rect.center.dy,
        closeTo(window.height / 2, 0.01),
        reason: '$window',
      );
    }
  });

  testWidgets('a phone-width window fills the screen with no frame', (
    tester,
  ) async {
    final (seen, rect) = await pump(tester, const Size(390, 844));
    expect(seen, const Size(390, 844));
    expect(rect, const Rect.fromLTWH(0, 0, 390, 844));
  });
}
