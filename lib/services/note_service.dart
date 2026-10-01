import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/love_note.dart';

/// Love notes and Time Capsules. The database hides a sealed capsule's text
/// from both partners until it opens; only its envelope (who, when, teaser)
/// is available through sealed_notes().
class NoteService {
  NoteService._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// Notes you can read: ordinary ones and opened capsules. Newest first.
  static Future<List<LoveNote>> list(String coupleId) async {
    final rows = await _db
        .from('notes')
        .select()
        .eq('couple_id', coupleId)
        .order('sent_at', ascending: false);
    return rows.map(LoveNote.fromMap).toList();
  }

  /// Capsules still sealed, soonest first. Never includes the message.
  static Future<List<SealedNote>> sealed() async {
    final result = await _db.rpc('sealed_notes');
    return (result as List)
        .cast<Map<String, dynamic>>()
        .map(SealedNote.fromMap)
        .toList();
  }

  /// Sends a note, or seals a capsule when [unlockAt] is given.
  /// The insert deliberately does NOT ask for the row back: a sealed capsule
  /// is invisible even to its author, so asking would be refused.
  static Future<void> send({
    required String coupleId,
    required String body,
    DateTime? unlockAt,
    String? capsuleTitle,
  }) async {
    final teaser = capsuleTitle?.trim() ?? '';
    await _db.from('notes').insert({
      'couple_id': coupleId,
      'body': body.trim(),
      'unlock_at': unlockAt?.toUtc().toIso8601String(),
      'capsule_title': unlockAt == null || teaser.isEmpty ? null : teaser,
    });
  }

  /// Either partner can favourite a note they can read.
  static Future<void> setFavorite(String id, bool value) async {
    await _db.from('notes').update({'is_favorite': value}).eq('id', id);
  }

  /// Only the author can delete a note (the database enforces it).
  static Future<void> delete(String id) async {
    await _db.from('notes').delete().eq('id', id);
  }

  /// Only the author, only while still sealed.
  static Future<void> cancelCapsule(String id) async {
    await _db.rpc('cancel_capsule', params: {'note_id': id});
  }

  /// Calls [onChange] when a new note arrives for this couple.
  static RealtimeChannel listen(String coupleId, void Function() onChange) {
    return _db
        .channel('notes-$coupleId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'couple_id',
            value: coupleId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  static Future<void> stopListening(RealtimeChannel channel) async {
    await _db.removeChannel(channel);
  }
}
