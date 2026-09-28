import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/memory.dart';
import '../utils/anniversary.dart';
import 'auth_service.dart';

/// Timeline memories and their photos. Row-level security in
/// supabase/schema.sql limits every call here to the user's own couple.
class MemoryService {
  MemoryService._();

  static SupabaseClient get _db => Supabase.instance.client;
  static const _bucket = 'memory-photos';
  static const maxPhotoBytes = 5 * 1024 * 1024; // 5 MB
  static const _types = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
  };

  /// Newest first. Photos come back with a signed link valid for one hour,
  /// because the bucket is private.
  static Future<List<Memory>> list(String coupleId, {int? limit}) async {
    final query = _db
        .from('memories')
        .select()
        .eq('couple_id', coupleId)
        .order('memory_date', ascending: false)
        .order('created_at', ascending: false);
    final rows = limit == null ? await query : await query.limit(limit);
    final memories = rows.map(Memory.fromMap).toList();

    final paths = memories.map((m) => m.photoPath).whereType<String>().toList();
    if (paths.isEmpty) return memories;

    try {
      final signed =
          await _db.storage.from(_bucket).createSignedUrls(paths, 60 * 60);
      final urls = {for (final s in signed) s.path: s.signedUrl};
      return [
        for (final m in memories)
          m.photoPath == null ? m : m.copyWith(photoUrl: urls[m.photoPath]),
      ];
    } catch (_) {
      // Show the memories without photos rather than nothing at all.
      return memories;
    }
  }

  /// Uploads the photo (if any) into this couple's folder, then saves the row.
  /// If saving the row fails, the uploaded photo is removed again.
  static Future<void> add({
    required String coupleId,
    required String caption,
    required DateTime date,
    Uint8List? photo,
    String photoExtension = 'jpg',
  }) async {
    String? path;
    if (photo != null) {
      final ext = photoExtension.toLowerCase();
      final type = _types[ext];
      if (type == null) {
        throw const AppException('Choose a JPG, PNG, WebP or GIF photo.');
      }
      if (photo.lengthInBytes > maxPhotoBytes) {
        throw const AppException('That photo is over 5 MB. Choose a smaller one.');
      }
      path = '$coupleId/${DateTime.now().microsecondsSinceEpoch}.$ext';
      await _db.storage.from(_bucket).uploadBinary(
            path,
            photo,
            fileOptions: FileOptions(contentType: type),
          );
    }

    try {
      await _db.from('memories').insert({
        'couple_id': coupleId,
        'caption': caption.trim(),
        'memory_date': isoDate(date),
        'photo_path': path,
      });
    } catch (_) {
      if (path != null) {
        try {
          await _db.storage.from(_bucket).remove([path]);
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Only the author can delete (enforced by the database).
  static Future<void> delete(Memory memory) async {
    await _db.from('memories').delete().eq('id', memory.id);
    final path = memory.photoPath;
    if (path != null) {
      try {
        await _db.storage.from(_bucket).remove([path]);
      } catch (_) {}
    }
  }

  /// Either partner can favourite. Returns the new value.
  static Future<bool> toggleFavorite(String memoryId) async {
    final result = await _db
        .rpc('toggle_memory_favorite', params: {'memory_id': memoryId});
    return result as bool;
  }
}
