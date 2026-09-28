import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bucket_item.dart';
import '../utils/anniversary.dart';

/// Shared bucket-list items. Both partners can add, complete and delete items.
/// Row-level security in Supabase limits every call to the user's own couple.
class BucketService {
  BucketService._();

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<List<BucketItem>> list(String coupleId) async {
    final rows = await _db
        .from('bucket_items')
        .select()
        .eq('couple_id', coupleId)
        .order('is_done', ascending: true)
        .order('created_at', ascending: false);

    return rows.map(BucketItem.fromMap).toList();
  }

  static Future<void> add({
    required String coupleId,
    required String title,
    DateTime? targetDate,
  }) async {
    await _db.from('bucket_items').insert({
      'couple_id': coupleId,
      'title': title.trim(),
      'target_date': targetDate == null ? null : isoDate(targetDate),
    });
  }

  static Future<void> setDone(String id, bool done) async {
    await _db.from('bucket_items').update({
      'is_done': done,
      'completed_at': done ? DateTime.now().toIso8601String() : null,
    }).eq('id', id);
  }

  static Future<void> delete(String id) async {
    await _db.from('bucket_items').delete().eq('id', id);
  }
}
