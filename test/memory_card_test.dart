// Timeline widgets: MemoryCard and FilterPill. No network needed, because a
// memory without a photo shows the placeholder instead of loading an image.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/models/memory.dart';
import 'package:final_project/widgets/atoms/us_icon.dart';
import 'package:final_project/widgets/atoms/filter_pill.dart';
import 'package:final_project/widgets/molecules/memory_card.dart';

Memory _memory({bool favourite = false}) => Memory(
      id: 'm1',
      coupleId: 'c1',
      authorId: 'u1',
      caption: 'Beach day in Zambales',
      memoryDate: DateTime(2026, 7, 1),
      isFavorite: favourite,
    );

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    );

void main() {
  group('MemoryCard', () {
    testWidgets('shows caption, date and who added it', (tester) async {
      await tester.pumpWidget(_wrap(
        MemoryCard(memory: _memory(), authorName: 'Ana'),
      ));

      expect(find.text('Beach day in Zambales'), findsOneWidget);
      expect(find.text('1 Jul 2026 \u00B7 added by Ana'), findsOneWidget);
      expect(_usIcon(UsIcons.image), findsOneWidget); // no photo
    });

    testWidgets('heart reflects favourite and calls onFavourite',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(MemoryCard(
        memory: _memory(favourite: true),
        authorName: 'you',
        onFavourite: () => taps++,
      )));

      expect(_usIcon(UsIcons.heartFilled), findsOneWidget);
      await tester.tap(_usIcon(UsIcons.heartFilled));
      expect(taps, 1);
    });

    testWidgets('tapping the card calls onTap', (tester) async {
      var opened = false;
      await tester.pumpWidget(_wrap(MemoryCard(
        memory: _memory(),
        authorName: 'you',
        onTap: () => opened = true,
      )));

      await tester.tap(find.text('Beach day in Zambales'));
      expect(opened, isTrue);
    });
  });

  group('FilterPill', () {
    testWidgets('shows its label and count, and reports taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(FilterPill(
        label: '2026',
        selected: true,
        count: 4,
        onTap: () => taps++,
      )));

      expect(find.text('2026'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      await tester.tap(find.text('2026'));
      expect(taps, 1);
    });
  });
}

Finder _usIcon(UsIconData icon) =>
    find.byWidgetPredicate((w) => w is UsIcon && w.icon == icon);
