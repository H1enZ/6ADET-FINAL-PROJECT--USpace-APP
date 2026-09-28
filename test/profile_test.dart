// Profile helpers: the birthday countdown text and avatar initials.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/utils/anniversary.dart';
import 'package:final_project/widgets/atoms/avatar_circle.dart';

void main() {
  group('birthdayLine', () {
    final birthday = DateTime(2003, 2, 14);

    test('counts down to your next birthday and says the age', () {
      expect(
        birthdayLine(
            birthday: birthday,
            isMe: true,
            name: 'Ana',
            today: DateTime(2027, 2, 4)),
        'Your birthday is in 10 days (turning 24)',
      );
    });

    test("names your partner, and says tomorrow", () {
      expect(
        birthdayLine(
            birthday: birthday,
            isMe: false,
            name: 'Ana',
            today: DateTime(2027, 2, 13)),
        "Ana's birthday is tomorrow (turning 24)",
      );
    });

    test('on the day itself', () {
      expect(
        birthdayLine(
            birthday: birthday,
            isMe: true,
            name: 'Ana',
            today: DateTime(2027, 2, 14)),
        "Happy birthday! You're 24 today.",
      );
      expect(
        birthdayLine(
            birthday: birthday,
            isMe: false,
            name: 'Ana',
            today: DateTime(2027, 2, 14)),
        "It's Ana's birthday today! 24 years old.",
      );
    });

    test('already passed this year rolls to next year', () {
      expect(
        birthdayLine(
            birthday: birthday,
            isMe: true,
            name: 'Ana',
            today: DateTime(2026, 9, 29)),
        'Your birthday is in 138 days (turning 24)',
      );
    });
  });

  group('AvatarCircle', () {
    test('initials from one or two words', () {
      expect(AvatarCircle.initialsOf('Ana Reyes'), 'AR');
      expect(AvatarCircle.initialsOf('mikko'), 'M');
      expect(AvatarCircle.initialsOf('  Ben  Cruz  Jr '), 'BC');
    });

    testWidgets('shows initials when there is no photo', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: AvatarCircle(name: 'Ana Reyes'))),
      ));
      expect(find.text('AR'), findsOneWidget);
    });
  });
}
