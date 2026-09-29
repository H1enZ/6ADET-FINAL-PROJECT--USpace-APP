import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/important_date.dart';
import '../utils/anniversary.dart';

/// Important dates the couple counts down to. Either partner can add or
/// remove them.
class DatesService {
  DatesService._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// Soonest first; one-off dates that have passed go last.
  static Future<List<ImportantDate>> list(String coupleId) async {
    final rows = await _db
        .from('important_dates')
        .select()
        .eq('couple_id', coupleId);
    final dates = rows.map(ImportantDate.fromMap).toList();
    dates.sort((a, b) =>
        (a.daysUntil() ?? 1 << 30).compareTo(b.daysUntil() ?? 1 << 30));
    return dates;
  }

  static Future<void> add({
    required String coupleId,
    required String title,
    required DateTime date,
    bool repeatsYearly = true,
  }) async {
    await _db.from('important_dates').insert({
      'couple_id': coupleId,
      'title': title.trim(),
      'event_date': isoDate(date),
      'repeats_yearly': repeatsYearly,
    });
  }

  static Future<void> delete(String id) async {
    await _db.from('important_dates').delete().eq('id', id);
  }
}
