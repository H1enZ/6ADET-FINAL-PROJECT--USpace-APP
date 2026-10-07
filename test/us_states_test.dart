// Shared state widgets (empty, error, loading, snackbar) and the error
// wording that reaches them.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:final_project/services/auth_service.dart';
import 'package:final_project/theme/app_theme.dart';
import 'package:final_project/widgets/atoms/us_icon.dart';
import 'package:final_project/widgets/molecules/us_states.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );

void main() {
  group('UsEmptyState', () {
    testWidgets('shows the title, the line and a working action',
        (tester) async {
      var added = 0;
      await tester.pumpWidget(_app(UsEmptyState(
        icon: UsIcons.star,
        title: 'Nothing on your list yet',
        message: 'Add something you both want to experience together.',
        actionLabel: 'Add your first goal',
        onAction: () => added++,
      )));

      expect(find.text('Nothing on your list yet'), findsOneWidget);
      expect(find.text('Add something you both want to experience together.'),
          findsOneWidget);
      expect(find.byType(UsIcon), findsWidgets);

      await tester.tap(find.text('Add your first goal'));
      expect(added, 1);
    });

    testWidgets('has no button without an action', (tester) async {
      await tester.pumpWidget(_app(const UsEmptyState(title: 'All quiet')));
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('the title is a heading for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(const UsEmptyState(title: 'All quiet')));
      expect(
        tester.getSemantics(find.text('All quiet')),
        matchesSemantics(label: 'All quiet', isHeader: true),
      );
      semantics.dispose();
    });
  });

  group('UsErrorNotice', () {
    for (final centered in [false, true]) {
      testWidgets('shows the message and retries (centered: $centered)',
          (tester) async {
        var tries = 0;
        await tester.pumpWidget(_app(UsErrorNotice(
          message: "Couldn't reach USpace just now.",
          onRetry: () => tries++,
          centered: centered,
        )));

        expect(find.text("Couldn't reach USpace just now."), findsOneWidget);
        await tester.tap(find.text('Try again'));
        expect(tries, 1);
      });
    }

    testWidgets('is announced as a live region', (tester) async {
      await tester.pumpWidget(_app(const UsErrorNotice(message: 'Oops.')));
      final live = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      );
      expect(live, findsOneWidget);
    });

    testWidgets('has no Try again without a retry', (tester) async {
      await tester.pumpWidget(_app(const UsErrorNotice(message: 'Oops.')));
      expect(find.text('Try again'), findsNothing);
    });
  });

  group('showUsMessage', () {
    testWidgets('shows the text, with an alert icon only for errors',
        (tester) async {
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Column(children: [
          TextButton(
            onPressed: () => showUsMessage(context, 'Saved.'),
            child: const Text('ok'),
          ),
          TextButton(
            onPressed: () =>
                showUsMessage(context, "Couldn't save.", error: true),
            child: const Text('fail'),
          ),
        ]),
      )));

      await tester.tap(find.text('ok'));
      await tester.pump();
      expect(find.text('Saved.'), findsOneWidget);
      expect(
        find.descendant(
            of: find.byType(SnackBar), matching: find.byType(SvgPicture)),
        findsNothing,
      );

      // A new message replaces the one showing.
      await tester.tap(find.text('fail'));
      await tester.pumpAndSettle();
      expect(find.text('Saved.'), findsNothing);
      expect(find.text("Couldn't save."), findsOneWidget);
      expect(
        find.descendant(
            of: find.byType(SnackBar), matching: find.byType(SvgPicture)),
        findsOneWidget,
      );
    });
  });

  group('friendlyError', () {
    test("keeps the database's own sentences", () {
      expect(
        friendlyError(const PostgrestException(
          message: 'No couple matches that code. Check it with your partner.',
          code: 'P0001',
        )),
        'No couple matches that code. Check it with your partner.',
      );
    });

    test('never shows raw policy, constraint or token errors', () {
      const raw = [
        ('new row violates row-level security policy for table "moods"',
            '42501'),
        ('duplicate key value violates unique constraint "x_pkey"', '23505'),
        ('value too long for type character varying(280)', '22001'),
        ('JWT expired', 'PGRST301'),
        ('relation "public.nope" does not exist', '42P01'),
      ];
      for (final (message, code) in raw) {
        final shown =
            friendlyError(PostgrestException(message: message, code: code));
        expect(shown, isNot(contains(message)), reason: code);
        expect(shown, isNotEmpty);
      }
    });

    test('a session that ended asks you to sign in again', () {
      expect(
        friendlyError(
            const PostgrestException(message: 'JWT expired', code: 'PGRST301')),
        contains('Sign in again'),
      );
    });

    test('storage errors talk about the photo, not the bucket', () {
      final shown = friendlyError(const StorageException(
          'The resource was not found',
          statusCode: '404'));
      expect(shown, isNot(contains('resource')));
      expect(shown, contains('photo'));
      expect(
        friendlyError(
            const StorageException('Payload too large', statusCode: '413')),
        contains('too large'),
      );
    });

    test('our own messages pass through', () {
      expect(friendlyError(const AppException('Give the date a name.')),
          'Give the date a name.');
    });

    test('anything else gets the connection line', () {
      expect(friendlyError(Exception('socket closed')),
          contains('Check your connection'));
    });
  });
}
