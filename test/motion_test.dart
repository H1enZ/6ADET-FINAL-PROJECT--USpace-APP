import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/widgets/atoms/us_icon.dart';
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
    // FadeSlideIn fades with a FadeTransition (not an Opacity widget), so
    // focus inside the card survives and the child isn't repainted.
    double opacity() => tester
        .widget<FadeTransition>(find
            .descendant(of: find.byType(FadeSlideIn), matching: find.byType(FadeTransition))
            .first)
        .opacity
        .value;

    // The third card waits its turn in the stagger (2 x 55 ms) before
    // fading. That wait is a timer, not a frame, so step the clock past it
    // first; pumpAndSettle alone would return before the fade even starts.
    expect(opacity(), 0.0);
    await tester.pump(const Duration(milliseconds: 2 * 55));
    await tester.pumpAndSettle();
    expect(opacity(), 1.0);
  });

  testWidgets('the heart fills in and pops back to normal size', (tester) async {
    await tester.pumpWidget(app(const AnimatedHeartIcon(filled: false)));
    expect(usIcon(UsIcons.heart), findsOneWidget);
    await tester.pumpWidget(app(const AnimatedHeartIcon(filled: true)));
    await tester.pumpAndSettle();
    expect(usIcon(UsIcons.heartFilled), findsOneWidget);
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

Finder usIcon(UsIconData icon) =>
    find.byWidgetPredicate((w) => w is UsIcon && w.icon == icon);
