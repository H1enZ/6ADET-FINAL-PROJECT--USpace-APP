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

  BucketItem trip({double? budget, DateTime? target}) => BucketItem(
        id: '4',
        coupleId: 'couple-1',
        title: 'See the bamboo forest',
        locationArea: 'Kyoto, Japan',
        locationSpot: 'Arashiyama Bamboo Grove',
        budget: budget,
        targetDate: target,
      );

  test('location reads as area (spot), or either part alone', () {
    expect(trip().locationLabel, 'Kyoto, Japan (Arashiyama Bamboo Grove)');
    const onlyArea = BucketItem(
        id: '5', coupleId: 'c', title: 't', locationArea: 'Batangas');
    expect(onlyArea.locationLabel, 'Batangas');
    const nowhere = BucketItem(id: '6', coupleId: 'c', title: 't');
    expect(nowhere.locationLabel, isNull);
  });

  test('savings progress against the budget', () {
    final item = trip(budget: 60000).withSaved(15000);
    expect(item.progress, 0.25);
    expect(item.remaining, 45000);
    expect(item.isFunded, isFalse);

    final over = trip(budget: 60000).withSaved(70000);
    expect(over.progress, 1.0);
    expect(over.remaining, 0);
    expect(over.isFunded, isTrue);

    expect(trip().withSaved(500).progress, isNull); // no budget
  });

  test('monthly amount needed to reach the goal by the target date', () {
    final item = trip(budget: 60000, target: DateTime(2027, 4, 1))
        .withSaved(12000);
    // 48,000 left over about 6 months from 1 Oct 2026
    final monthly = item.monthlyNeeded(today: DateTime(2026, 10, 1));
    expect(monthly, isNotNull);
    expect(monthly!, closeTo(8000, 0.01));

    // no target date, already funded, or date passed: nothing to show
    expect(trip(budget: 60000).monthlyNeeded(), isNull);
    expect(item.withSaved(60000).monthlyNeeded(today: DateTime(2026, 10, 1)),
        isNull);
    expect(item.monthlyNeeded(today: DateTime(2027, 5, 1)), isNull);
  });

  test('reads budget and location from a database row', () {
    final item = BucketItem.fromMap({
      'id': '7',
      'couple_id': 'couple-1',
      'title': 'Island hopping',
      'target_date': null,
      'is_done': false,
      'completed_at': null,
      'location_area': 'Palawan',
      'location_spot': 'El Nido',
      'budget': 25000,
    });
    expect(item.locationLabel, 'Palawan (El Nido)');
    expect(item.budget, 25000.0);
    expect(item.saved, 0);
  });
}

