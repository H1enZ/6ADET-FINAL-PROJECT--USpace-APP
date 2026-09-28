import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bucket_contribution.dart';
import '../models/bucket_item.dart';
import '../utils/anniversary.dart';
import '../utils/money.dart';

/// Shared bucket-list items and their savings logs. Both partners can add,
/// edit, complete and delete items, and log savings. Row-level security in
/// Supabase limits every call to the user's own couple.
///
/// No real money moves through the app: the savings log is a shared record
/// of money the couple keeps elsewhere (a bank or e-wallet savings account).
class BucketService {
  BucketService._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// Items with their savings totals. Not-done first, newest first.
  static Future<List<BucketItem>> list(String coupleId) async {
    final rows = await _db
        .from('bucket_items')
        .select()
        .eq('couple_id', coupleId)
        .order('is_done', ascending: true)
        .order('created_at', ascending: false);

    final entries = await _db
        .from('bucket_contributions')
        .select('item_id, amount')
        .eq('couple_id', coupleId);

    final totals = <String, double>{};
    for (final entry in entries) {
      final id = entry['item_id'] as String;
      totals[id] = (totals[id] ?? 0) + (readAmount(entry['amount']) ?? 0);
    }

    return [
      for (final row in rows)
        BucketItem.fromMap(row).withSaved(totals[row['id']] ?? 0),
    ];
  }

  /// One item with its savings total, e.g. after editing it.
  static Future<BucketItem> item(String id) async {
    final row = await _db.from('bucket_items').select().eq('id', id).single();
    final saved = (await contributions(id))
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    return BucketItem.fromMap(row).withSaved(saved);
  }

  static Future<void> add({
    required String coupleId,
    required String title,
    DateTime? targetDate,
    String? locationArea,
    String? locationSpot,
    double? budget,
  }) async {
    await _db.from('bucket_items').insert({
      'couple_id': coupleId,
      ..._fields(title, targetDate, locationArea, locationSpot, budget),
    });
  }

  /// Saves every field, so clearing one (e.g. removing the budget) works.
  static Future<void> update(
    String id, {
    required String title,
    DateTime? targetDate,
    String? locationArea,
    String? locationSpot,
    double? budget,
  }) async {
    await _db
        .from('bucket_items')
        .update(_fields(title, targetDate, locationArea, locationSpot, budget))
        .eq('id', id);
  }

  static Map<String, dynamic> _fields(
    String title,
    DateTime? targetDate,
    String? locationArea,
    String? locationSpot,
    double? budget,
  ) {
    return {
      'title': title.trim(),
      'target_date': targetDate == null ? null : isoDate(targetDate),
      'location_area': _clean(locationArea),
      'location_spot': _clean(locationSpot),
      'budget': budget,
    };
  }

  /// Empty text is stored as "not set" (null), not as "".
  static String? _clean(String? text) {
    final trimmed = text?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static Future<void> setDone(String id, bool done) async {
    await _db.from('bucket_items').update({
      'is_done': done,
      'completed_at': done ? DateTime.now().toIso8601String() : null,
    }).eq('id', id);
  }

  /// Also deletes its savings log (the database cascades it).
  static Future<void> delete(String id) async {
    await _db.from('bucket_items').delete().eq('id', id);
  }

  // ---------------------------------------------------------------------
  // Savings log
  // ---------------------------------------------------------------------

  /// Newest first.
  static Future<List<BucketContribution>> contributions(String itemId) async {
    final rows = await _db
        .from('bucket_contributions')
        .select()
        .eq('item_id', itemId)
        .order('saved_on', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(BucketContribution.fromMap).toList();
  }

  static Future<void> addContribution({
    required String itemId,
    required String coupleId,
    required double amount,
    required DateTime savedOn,
    String? note,
  }) async {
    await _db.from('bucket_contributions').insert({
      'item_id': itemId,
      'couple_id': coupleId,
      'amount': amount,
      'saved_on': isoDate(savedOn),
      'note': _clean(note),
    });
  }

  /// Only your own entries (the database enforces it).
  static Future<void> deleteContribution(String id) async {
    await _db.from('bucket_contributions').delete().eq('id', id);
  }
}
