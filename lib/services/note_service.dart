import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/love_note.dart';
import 'memory_service.dart';
import 'couple_sync.dart';

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
    final notes = rows.map(LoveNote.fromMap).toList();
    final paths = notes.map((n) => n.photoPath).whereType<String>().toList();
    if (paths.isEmpty) return notes;
    try {
      final urls = await MemoryService.signedUrls(paths);
      return [
        for (final n in notes)
          n.photoPath == null ? n : n.withPhotoUrl(urls[n.photoPath]),
      ];
    } catch (_) {
      return notes; // show them without photos rather than not at all
    }
  }

  /// Capsules that opened between [since] and [until], for Notifications.
  /// Only the envelope, never the message.
  static Future<
    List<({String id, String authorId, DateTime openedAt, String? title})>
  >
  openedCapsules(String coupleId, DateTime since, DateTime until) async {
    final rows = await _db
        .from('notes')
        .select('id, author_id, unlock_at, capsule_title')
        .eq('couple_id', coupleId)
        .not('unlock_at', 'is', null)
        .gte('unlock_at', since.toUtc().toIso8601String())
        .lte('unlock_at', until.toUtc().toIso8601String());
    return [
      for (final r in rows)
        (
          id: r['id'] as String,
          authorId: r['author_id'] as String,
          openedAt: DateTime.parse(r['unlock_at'] as String).toLocal(),
          title: r['capsule_title'] as String?,
        ),
    ];
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
  /// An ordinary note's [title] goes in capsule_title. A [photo] is uploaded
  /// first, and removed again if the note can't be saved.
  static Future<void> send({
    required String coupleId,
    required String body,
    DateTime? unlockAt,
    String? capsuleTitle,
    String? title,
    NoteCategory? category,
    NewPhoto? photo,
  }) async {
    final heading = (unlockAt == null ? title : capsuleTitle)?.trim() ?? '';
    final path = photo == null
        ? null
        : await MemoryService.uploadNotePhoto(coupleId, photo);
    try {
      await _db.from('notes').insert({
        'couple_id': coupleId,
        'body': body.trim(),
        'unlock_at': unlockAt?.toUtc().toIso8601String(),
        'capsule_title': heading.isEmpty ? null : heading,
        'category': category?.key,
        'photo_path': path,
      });
    } catch (_) {
      if (path != null) await MemoryService.removeFiles([path]);
      rethrow;
    }
  }

  /// Either partner can favourite a note they can read.
  static Future<void> setFavorite(String id, bool value) async {
    await _db.from('notes').update({'is_favorite': value}).eq('id', id);
  }

  /// Only the author can delete a note (the database enforces it).
  static Future<void> delete(String id, {String? photoPath}) async {
    await _db.from('notes').delete().eq('id', id);
    CoupleSync.announce('notes');
    if (photoPath != null) await MemoryService.removeFiles([photoPath]);
  }

  /// Only the author, only while still sealed.
  static Future<void> cancelCapsule(String id) async {
    await _db.rpc('cancel_capsule', params: {'note_id': id});
  }
}
