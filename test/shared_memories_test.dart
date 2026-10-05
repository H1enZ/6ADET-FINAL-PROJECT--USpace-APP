import 'dart:math';

import 'package:final_project/models/memory.dart';
import 'package:final_project/screens/therabot/shared_memories_page.dart';
import 'package:flutter_test/flutter_test.dart';

Memory memory(String id, DateTime date, {bool favourite = false}) => Memory(
  id: id,
  coupleId: 'c',
  authorId: 'a',
  caption: id,
  memoryDate: date,
  isFavorite: favourite,
);

void main() {
  final today = DateTime(2026, 10, 5);

  test('on this day first, then favourites, then the rest', () {
    final all = [
      memory('plain', DateTime(2026, 3, 1)),
      memory('fav', DateTime(2025, 1, 2), favourite: true),
      memory('anniv', DateTime(2024, 10, 5)),
      memory('today', DateTime(2026, 10, 5)), // this year: not "on this day"
    ];
    final order = memoriesToRevisit(all, today, Random(1));
    expect(order.map((m) => m.id).take(2), ['anniv', 'fav']);
    expect(order.map((m) => m.id).toSet(), {'plain', 'fav', 'anniv', 'today'});
  });

  test('how long ago', () {
    expect(howLongAgo(DateTime(2026, 10, 5), today), 'Today');
    expect(howLongAgo(DateTime(2026, 10, 4), today), 'Yesterday');
    expect(howLongAgo(DateTime(2026, 9, 20), today), '15 days ago');
    expect(howLongAgo(DateTime(2026, 9, 5), today), 'A month ago');
    expect(howLongAgo(DateTime(2026, 5, 6), today), '4 months ago');
    expect(howLongAgo(DateTime(2025, 10, 5), today), 'A year ago');
    expect(howLongAgo(DateTime(2023, 10, 6), today), '2 years ago');
  });
}
