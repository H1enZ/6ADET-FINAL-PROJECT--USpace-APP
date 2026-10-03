import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mood.dart';

/// Today's Mood. Each check-in is a new row, so you can update your mood
/// through the day and keep a history. The database hides check-ins you
/// marked as not shared from your partner.
class MoodService {
  MoodService._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// Both partners' check-ins you are allowed to see, newest first.
  static Future<List<MoodEntry>> recent(String coupleId, {int days = 35}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await _db
        .from('moods')
        .select()
        .eq('couple_id', coupleId)
        .gte('created_at', since.toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return rows.map(MoodEntry.fromMap).whereType<MoodEntry>().toList();
  }

  static Future<void> checkIn({
    required String coupleId,
    required Mood mood,
    String? note,
    bool shared = true,
  }) async {
    final text = note?.trim() ?? '';
    await _db.from('moods').insert({
      'couple_id': coupleId,
      'mood': mood.dbValue,
      'note': text.isEmpty ? null : text,
      'is_shared': shared,
    });
  }
}
