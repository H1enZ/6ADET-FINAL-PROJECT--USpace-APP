// Widget tests: build a widget in memory and check what is on screen.
// Run them all with: flutter test
//
// These use Flutter's default theme on purpose. The app theme loads
// Google Fonts over the network, which tests should not depend on.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/widgets/atoms/app_button.dart';
import 'package:final_project/widgets/molecules/countdown_card.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('AppButton', () {
    testWidgets('shows its label and runs onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        AppButton(label: 'Save memory', onPressed: () => taps++),
      ));

      expect(find.text('Save memory'), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 1);
    });

    testWidgets('null onPressed means disabled', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppButton(label: 'Save memory', onPressed: null),
      ));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('loading shows a spinner and blocks taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        AppButton(label: 'Save', onPressed: () => taps++, isLoading: true),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 0);
    });
  });

  group('CountdownCard', () {
    testWidgets('invites you to add an anniversary when there is none',
        (tester) async {
      await tester.pumpWidget(_wrap(const CountdownCard(anniversary: null)));
      expect(find.text('Tap to add it'), findsOneWidget);
    });

    testWidgets('counts down to the next anniversary', (tester) async {
      await tester.pumpWidget(_wrap(CountdownCard(
        anniversary: DateTime(2024, 2, 14),
        today: DateTime(2027, 2, 4),
      )));

      expect(find.text('10'), findsOneWidget); // days to go
      expect(find.text('3y'), findsOneWidget); // inside the ring
      expect(find.textContaining('3rd anniversary, 14 Feb'), findsOneWidget);
    });
  });
}
