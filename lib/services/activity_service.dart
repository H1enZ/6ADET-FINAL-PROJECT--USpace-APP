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

  /// Calls [onChange] whenever a new activity or affection arrives for this
  /// couple. Realtime still applies the database's security rules.
  /// Close it with [stopListening] when the screen goes away.
  static RealtimeChannel listen(String coupleId, void Function() onChange) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'couple_id',
      value: coupleId,
    );
    return _db
        .channel('home-$coupleId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'activities',
          filter: filter,
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'affections',
          filter: filter,
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  static Future<void> stopListening(RealtimeChannel channel) async {
    await _db.removeChannel(channel);
  }
}
