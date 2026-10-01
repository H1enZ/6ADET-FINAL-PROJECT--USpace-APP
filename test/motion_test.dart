import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/widgets/effects/motion.dart';

Widget app(Widget child, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  testWidgets('the countdown number rolls up to the real value', (tester) async {
    await tester.pumpWidget(app(const CountUpText('262')));
    await tester.pumpAndSettle();
    expect(find.text('262'), findsOneWidget);
  });

  testWidgets('with reduced motion the number shows straight away', (tester) async {
    await tester.pumpWidget(app(const CountUpText('262'), reduceMotion: true));
    expect(find.text('262'), findsOneWidget);
  });

  testWidgets('words are not counted, just shown', (tester) async {
    await tester.pumpWidget(app(const CountUpText('Today')));
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('cards that fade in end up fully visible', (tester) async {
    await tester.pumpWidget(app(const FadeSlideIn(index: 2, child: Text('Hello'))));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    final opacity = tester.widget<Opacity>(find.ancestor(
        of: find.text('Hello'), matching: find.byType(Opacity)).first);
    expect(opacity.opacity, 1.0);
  });

  testWidgets('the heart fills in and pops back to normal size', (tester) async {
    await tester.pumpWidget(app(const AnimatedHeartIcon(filled: false)));
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await tester.pumpWidget(app(const AnimatedHeartIcon(filled: true)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('the loading skeleton says it is loading', (tester) async {
    await tester.pumpWidget(app(const SizedBox(height: 400, child: SkeletonList())));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
  });

  testWidgets('the savings bar fills to its value', (tester) async {
    await tester.pumpWidget(app(const SizedBox(
        width: 200,
        child: AnimatedProgressBar(value: 0.25, color: Colors.pink, backgroundColor: Colors.white))));
    await tester.pumpAndSettle();
    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, closeTo(0.25, 0.001));
  });
}
