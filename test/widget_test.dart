// Widget tests: build a widget in memory and check what is on screen.
// Run them all with: flutter test
//
// These use Flutter's default theme on purpose. The app theme loads
// Google Fonts over the network, which tests should not depend on.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/widgets/atoms/app_button.dart';
import 'package:final_project/utils/special_events.dart';
import 'package:final_project/widgets/molecules/special_event_card.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AppButton', () {
    testWidgets('shows its label and runs onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(AppButton(label: 'Save memory', onPressed: () => taps++)),
      );

      expect(find.text('Save memory'), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 1);
    });

    testWidgets('null onPressed means disabled', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppButton(label: 'Save memory', onPressed: null)),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('loading shows a spinner and blocks taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          AppButton(label: 'Save', onPressed: () => taps++, isLoading: true),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 0);
    });
  });

  group('SpecialEventCard', () {
    testWidgets('counts down to the nearest special day', (tester) async {
      final event = nearestEvent(
        today: DateTime(2027, 2, 4),
        together: DateTime(2024, 2, 14),
      );
      await tester.pumpWidget(
        _wrap(
          SpecialEventCard(
            event: event,
            myName: 'Mikko',
            partnerName: 'Ana',
            together: DateTime(2024, 2, 14),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget); // days to go
      expect(find.text('days until your 3rd anniversary'), findsOneWidget);
      expect(find.text('February 14, 2027'), findsOneWidget);
    });

    testWidgets('celebrates on the day instead of counting zero', (
      tester,
    ) async {
      final event = nearestEvent(
        today: DateTime(2027, 2, 14),
        together: DateTime(2024, 2, 14),
      );
      await tester.pumpWidget(
        _wrap(
          SpecialEventCard(
            event: event,
            myName: 'Mikko',
            partnerName: 'Ana',
            together: DateTime(2024, 2, 14),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Happy 3rd Anniversary ♥'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });
}
