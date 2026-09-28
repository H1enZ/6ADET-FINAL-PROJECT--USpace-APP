import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/models/bucket_item.dart';

void main() {
  test('BucketItem handles a null target date', () {
    final item = BucketItem.fromMap({
      'id': '1',
      'couple_id': 'couple-1',
      'title': 'Visit Japan',
      'target_date': null,
      'is_done': false,
      'completed_at': null,
    });

    expect(item.targetDate, isNull);
    expect(item.isDone, isFalse);
  });

  test('BucketItem reads completed items', () {
    final item = BucketItem.fromMap({
      'id': '2',
      'couple_id': 'couple-1',
      'title': 'Go to the beach',
      'target_date': '2026-12-25',
      'is_done': true,
      'completed_at': '2026-09-29T10:00:00.000Z',
    });

    expect(item.targetDate, DateTime.parse('2026-12-25'));
    expect(item.isDone, isTrue);
    expect(item.completedAt, isNotNull);
  });

  test('unticking clears completedAt; ticking sets it', () {
    final done = BucketItem.fromMap({
      'id': '3',
      'couple_id': 'couple-1',
      'title': 'Sunrise hike',
      'target_date': null,
      'is_done': true,
      'completed_at': '2026-09-29T10:00:00.000Z',
    });

    final undone = done.withDone(false);
    expect(undone.isDone, isFalse);
    expect(undone.completedAt, isNull);

    final again = undone.withDone(true);
    expect(again.isDone, isTrue);
    expect(again.completedAt, isNotNull);
  });
}
