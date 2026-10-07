import 'dart:math' as math;

import '../utils/money.dart';

/// One shared bucket-list item. Mirrors a row in the `bucket_items` table,
/// plus [saved], the total of its savings log (worked out by BucketService).
class BucketItem {
  const BucketItem({
    required this.id,
    required this.coupleId,
    required this.title,
    this.targetDate,
    this.isDone = false,
    this.completedAt,
    this.locationArea,
    this.locationSpot,
    this.budget,
    this.saved = 0,
  });

  final String id;
  final String coupleId;
  final String title;
  final DateTime? targetDate;
  final bool isDone;
  final DateTime? completedAt;

  /// Country / State, e.g. "Kyoto, Japan".
  final String? locationArea;

  /// The specific spot, e.g. "Arashiyama Bamboo Grove".
  final String? locationSpot;

  /// The sinking-fund goal in pesos. Null means no budget.
  final double? budget;

  /// Total put aside so far, from the savings log.
  final double saved;

  factory BucketItem.fromMap(Map<String, dynamic> row) {
    final targetDate = row['target_date'] as String?;
    final completedAt = row['completed_at'] as String?;

    return BucketItem(
      id: row['id'] as String,
      coupleId: row['couple_id'] as String,
      title: row['title'] as String,
      targetDate: targetDate == null ? null : DateTime.parse(targetDate),
      isDone: (row['is_done'] as bool?) ?? false,
      completedAt: completedAt == null
          ? null
          : DateTime.parse(completedAt).toLocal(),
      locationArea: row['location_area'] as String?,
      locationSpot: row['location_spot'] as String?,
      budget: readAmount(row['budget']),
    );
  }

  /// "Kyoto, Japan (Arashiyama Bamboo Grove)", either part alone, or null.
  String? get locationLabel {
    final area = locationArea;
    final spot = locationSpot;
    if (area != null && spot != null) return '$area ($spot)';
    return area ?? spot;
  }

  /// 0.0 to 1.0 of the budget saved, or null when there is no budget.
  double? get progress {
    final goal = budget;
    if (goal == null || goal <= 0) return null;
    return (saved / goal).clamp(0.0, 1.0).toDouble();
  }

  /// What is still needed, never below zero. Null when there is no budget.
  double? get remaining {
    final goal = budget;
    if (goal == null) return null;
    return math.max(0, goal - saved).toDouble();
  }

  bool get isFunded => budget != null && saved >= budget!;

  /// How much to save each month to reach the budget by the target date.
  /// Null without a budget or target date, once funded, or when the date
  /// has passed.
  double? monthlyNeeded({DateTime? today}) {
    final left = remaining;
    final target = targetDate;
    if (left == null || left <= 0 || target == null) return null;
    final now = today ?? DateTime.now();
    final days = DateTime.utc(target.year, target.month, target.day)
        .difference(DateTime.utc(now.year, now.month, now.day))
        .inDays;
    if (days <= 0) return null;
    final months = math.max(1, (days / 30.44).ceil());
    return left / months;
  }

  /// A copy ticked or unticked. Unticking clears completedAt, which a
  /// normal copyWith using `??` cannot do (null would keep the old date).
  BucketItem withDone(bool done) => _copy(
        isDone: done,
        completedAt: done ? DateTime.now() : null,
      );

  /// A copy with a new savings total.
  BucketItem withSaved(double total) =>
      _copy(isDone: isDone, completedAt: completedAt, saved: total);

  BucketItem _copy({
    required bool isDone,
    required DateTime? completedAt,
    double? saved,
  }) {
    return BucketItem(
      id: id,
      coupleId: coupleId,
      title: title,
      targetDate: targetDate,
      isDone: isDone,
      completedAt: completedAt,
      locationArea: locationArea,
      locationSpot: locationSpot,
      budget: budget,
      saved: saved ?? this.saved,
    );
  }
}
