import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity.dart';

/// The couple's recent activity, and a live connection that tells the
/// screen when something new happens (a new activity or affection).
class ActivityService {
  ActivityService._();

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<List<Activity>> recent(String coupleId, {int limit = 8}) async {
    final rows = await _db
        .from('activities')
        .select()
        .eq('couple_id', coupleId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(Activity.fromMap).toList();
  }
}
