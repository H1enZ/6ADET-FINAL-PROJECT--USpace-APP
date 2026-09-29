import 'package:supabase_flutter/supabase_flutter.dart';

/// Hugs, kisses, cuddles, comfort and "please just listen", sent to your
/// partner. Only the receiver can mark them as seen.
class AffectionService {
  AffectionService._();

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<void> send({
    required String coupleId,
    required String kind, // hug, kiss, cuddle, comfort, listen
    String? message,
  }) async {
    final text = message?.trim() ?? '';
    await _db.from('affections').insert({
      'couple_id': coupleId,
      'kind': kind,
      'message': text.isEmpty ? null : text,
    });
  }

  /// Affection your partner sent that you have not seen yet, oldest first.
  static Future<List<Map<String, dynamic>>> unseenFromPartner(
    String coupleId,
    String myUserId,
  ) async {
    final rows = await _db
        .from('affections')
        .select()
        .eq('couple_id', coupleId)
        .neq('sender_id', myUserId)
        .isFilter('seen_at', null)
        .order('created_at');
    return rows;
  }

  static Future<void> markSeen() async {
    await _db.rpc('mark_affections_seen');
  }
}
