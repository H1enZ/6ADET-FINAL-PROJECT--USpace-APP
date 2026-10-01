import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/resolution_note.dart';

/// "Let's work it out" notes. You can only write and edit your own; your
/// partner only sees the ones you choose to share.
class SupportService {
  SupportService._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// Your notes and your partner's shared ones, newest first.
  static Future<List<ResolutionNote>> notes(String coupleId) async {
    final rows = await _db
        .from('resolution_notes')
        .select()
        .eq('couple_id', coupleId)
        .order('updated_at', ascending: false);
    return rows.map(ResolutionNote.fromMap).toList();
  }

  /// Creates a note, or updates [id] when given. [answers] are matched to
  /// the six questions in order; blank answers are saved as empty (null).
  static Future<void> save({
    required String coupleId,
    required String need,
    required List<String> answers,
    required bool shared,
    required bool done,
    String? id,
  }) async {
    final fields = <String, dynamic>{
      'need': need,
      'is_shared': shared,
      'status': done ? 'done' : 'paused',
      for (var i = 0; i < resolutionColumns.length; i++)
        resolutionColumns[i]:
            i < answers.length && answers[i].trim().isNotEmpty ? answers[i].trim() : null,
    };
    if (id == null) {
      await _db.from('resolution_notes').insert({'couple_id': coupleId, ...fields});
    } else {
      await _db.from('resolution_notes').update(fields).eq('id', id);
    }
  }

  static Future<void> delete(String id) async {
    await _db.from('resolution_notes').delete().eq('id', id);
  }
}
