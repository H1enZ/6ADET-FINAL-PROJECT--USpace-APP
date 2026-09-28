/// One shared bucket-list item. Mirrors a row in the `bucket_items` table.
class BucketItem {
  const BucketItem({
    required this.id,
    required this.coupleId,
    required this.title,
    this.targetDate,
    this.isDone = false,
    this.completedAt,
  });

  final String id;
  final String coupleId;
  final String title;
  final DateTime? targetDate;
  final bool isDone;
  final DateTime? completedAt;

  factory BucketItem.fromMap(Map<String, dynamic> row) {
    final targetDate = row['target_date'] as String?;
    final completedAt = row['completed_at'] as String?;

    return BucketItem(
      id: row['id'] as String,
      coupleId: row['couple_id'] as String,
      title: row['title'] as String,
      targetDate: targetDate == null ? null : DateTime.parse(targetDate),
      isDone: (row['is_done'] as bool?) ?? false,
      completedAt:
          completedAt == null ? null : DateTime.parse(completedAt),
    );
  }

  /// A copy ticked or unticked. Unticking clears completedAt, which a
  /// normal copyWith using `??` cannot do (null would keep the old date).
  BucketItem withDone(bool done) {
    return BucketItem(
      id: id,
      coupleId: coupleId,
      title: title,
      targetDate: targetDate,
      isDone: done,
      completedAt: done ? DateTime.now() : null,
    );
  }
}
