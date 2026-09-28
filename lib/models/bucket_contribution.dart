import '../utils/money.dart';

/// One entry in an item's savings log: someone put money aside for it.
/// Mirrors a row in the `bucket_contributions` table.
class BucketContribution {
  const BucketContribution({
    required this.id,
    required this.itemId,
    required this.authorId,
    required this.amount,
    required this.savedOn,
    this.note,
  });

  final String id;
  final String itemId;
  final String authorId;
  final double amount;
  final DateTime savedOn;
  final String? note;

  factory BucketContribution.fromMap(Map<String, dynamic> row) {
    return BucketContribution(
      id: row['id'] as String,
      itemId: row['item_id'] as String,
      authorId: row['author_id'] as String,
      amount: readAmount(row['amount']) ?? 0,
      savedOn: DateTime.parse(row['saved_on'] as String),
      note: row['note'] as String?,
    );
  }
}
