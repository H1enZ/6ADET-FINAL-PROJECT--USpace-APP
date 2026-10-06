import 'package:final_project/models/mood.dart';
import 'package:final_project/screens/mood_sheet.dart';
import 'package:final_project/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Calls {
  final picks = <Mood>[];
  final saves = <(Mood, String?)>[];
  bool pickOk = true;
}

Widget _sheet(_Calls calls, {Mood? current, String? note}) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: MoodSheet(
      current: current,
      currentNote: note,
      onPick: (m) async {
        calls.picks.add(m);
        return calls.pickOk;
      },
      onSaveNote: (m, n) async => calls.saves.add((m, n)),
    ),
  ),
);

ChoiceChip _chip(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(
      find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)),
    );

FilledButton _button(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  testWidgets('no share switch, note wording, current mood selected', (
    tester,
  ) async {
    await tester.pumpWidget(_sheet(_Calls(), current: Mood.happy));
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.textContaining('Share with'), findsNothing);
    expect(find.textContaining('WHY'), findsNothing);
    expect(find.text('Add a note'), findsOneWidget);
    expect(find.text('Optional'), findsOneWidget);
    expect(find.text('What’s behind this feeling?'), findsOneWidget);
    expect(_chip(tester, 'Happy').selected, isTrue);
    expect(find.text('Save note'), findsOneWidget);
    // Nothing typed yet: nothing to save.
    expect(_button(tester).onPressed, isNull);
  });

  testWidgets('saving a new note writes the note once, never a mood pick', (
    tester,
  ) async {
    final calls = _Calls();
    await tester.pumpWidget(_sheet(calls, current: Mood.happy));
    await tester.enterText(find.byType(TextField), 'Finished my exams.');
    await tester.pump();
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    expect(calls.saves, [(Mood.happy, 'Finished my exams.')]);
    expect(calls.picks, isEmpty);
  });

  testWidgets('an existing note is preloaded and updated', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(
      _sheet(calls, current: Mood.happy, note: 'Finished my exams.'),
    );
    expect(find.text('Finished my exams.'), findsOneWidget);
    // Unchanged: no write.
    expect(_button(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Finished ALL my exams.');
    await tester.pump();
    expect(find.text('Update note'), findsOneWidget);
    await tester.tap(find.text('Update note'));
    await tester.pumpAndSettle();
    expect(calls.saves, [(Mood.happy, 'Finished ALL my exams.')]);
  });

  testWidgets('clearing the note removes the note, keeps the mood', (
    tester,
  ) async {
    final calls = _Calls();
    await tester.pumpWidget(
      _sheet(calls, current: Mood.happy, note: 'Finished my exams.'),
    );
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('Remove note'), findsOneWidget);
    await tester.tap(find.text('Remove note'));
    await tester.pumpAndSettle();
    expect(calls.saves, [(Mood.happy, null)]);
    expect(calls.picks, isEmpty);
  });

  testWidgets('tapping another mood shares it at once, without saving', (
    tester,
  ) async {
    final calls = _Calls();
    await tester.pumpWidget(_sheet(calls, current: Mood.happy));
    await tester.tap(find.text('Excited'));
    await tester.pumpAndSettle();
    expect(calls.picks, [Mood.excited]);
    expect(calls.saves, isEmpty);
    expect(_chip(tester, 'Excited').selected, isTrue);
  });

  testWidgets('a failed mood share puts the previous mood back', (
    tester,
  ) async {
    final calls = _Calls()..pickOk = false;
    await tester.pumpWidget(_sheet(calls, current: Mood.happy));
    await tester.tap(find.text('Calm'));
    await tester.pumpAndSettle();
    expect(_chip(tester, 'Happy').selected, isTrue);
    expect(_chip(tester, 'Calm').selected, isFalse);
  });

  testWidgets('notes viewer lists each person under their own name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: MoodNotesSheet(
            notes: [
              (name: 'You', note: 'Finished my exams.'),
              (name: 'Ana', note: 'Had a good day at work.'),
            ],
            hasMine: true,
          ),
        ),
      ),
    );
    expect(find.text('“Finished my exams.”'), findsOneWidget);
    expect(find.text('“Had a good day at work.”'), findsOneWidget);
    expect(find.text('Edit my note'), findsOneWidget);
  });
}
