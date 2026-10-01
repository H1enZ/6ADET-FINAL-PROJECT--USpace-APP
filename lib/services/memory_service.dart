import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/memory.dart';
import '../utils/anniversary.dart';
import 'auth_service.dart';

/// A photo picked on this device, not uploaded yet.
class NewPhoto {
  const NewPhoto(this.bytes, this.extension);
  final Uint8List bytes;
  final String extension;
}

/// Timeline memories and their photos. Row-level security limits every call
/// to the user's own couple, and only the author can change a memory.
class MemoryService {
  MemoryService._();

  static SupabaseClient get _db => Supabase.instance.client;
  static const _bucket = 'memory-photos';
  static const maxPhotos = 10;
  static const maxPhotoBytes = 5 * 1024 * 1024; // 5 MB, also enforced by Storage
  static const _types = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
  };

  /// Newest first, with all photos signed for an hour.
  static Future<List<Memory>> list(String coupleId, {int? limit}) async {
    final query = _db
        .from('memories')
        .select()
        .eq('couple_id', coupleId)
        .order('memory_date', ascending: false)
        .order('created_at', ascending: false);
    final rows = limit == null ? await query : await query.limit(limit);
    return _withPhotos(rows);
  }

  static Future<Memory> get(String id) async {
    final row = await _db.from('memories').select().eq('id', id).single();
    return (await _withPhotos([row])).first;
  }

  /// Attaches each memory's photos (from memory_photos, or the old single
  /// cover) and signs every link in one request.
  static Future<List<Memory>> _withPhotos(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    final ids = [for (final r in rows) r['id'] as String];
    final photoRows = await _db
        .from('memory_photos')
        .select('memory_id, path, position')
        .inFilter('memory_id', ids)
        .order('position');

    final byMemory = <String, List<String>>{};
    for (final p in photoRows) {
      byMemory.putIfAbsent(p['memory_id'] as String, () => []).add(p['path'] as String);
    }
    final memories = [
      for (final r in rows)
        Memory.fromMap(r, photoPaths: byMemory[r['id']] ?? const []),
    ];

    final paths = {for (final m in memories) ...m.photos.map((p) => p.path)}.toList();
    if (paths.isEmpty) return memories;
    try {
      final signed = await _db.storage.from(_bucket).createSignedUrls(paths, 60 * 60);
      final urls = {for (final s in signed) s.path: s.signedUrl};
      return [
        for (final m in memories)
          m.copyWith(photos: [for (final p in m.photos) p.withUrl(urls[p.path])]),
      ];
    } catch (_) {
      return memories; // show them without photos rather than not at all
    }
  }

  static Future<String> _upload(String coupleId, NewPhoto photo, int index) async {
    final ext = photo.extension.toLowerCase();
    final type = _types[ext];
    if (type == null) {
      throw const AppException('Choose JPG, PNG, WebP or GIF photos.');
    }
    if (photo.bytes.lengthInBytes > maxPhotoBytes) {
      throw const AppException('One photo is over 5 MB. Choose a smaller one.');
    }
    final path = '$coupleId/${DateTime.now().microsecondsSinceEpoch}-$index.$ext';
    await _db.storage.from(_bucket).uploadBinary(
          path,
          photo.bytes,
          fileOptions: FileOptions(contentType: type),
        );
    return path;
  }

  static Future<void> _removeFiles(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _db.storage.from(_bucket).remove(paths);
    } catch (_) {}
  }

  static Map<String, dynamic> _fields({
    required String title,
    required DateTime date,
    String? description,
    String? location,
    List<String> tags = const [],
  }) {
    String? clean(String? s) {
      final t = s?.trim() ?? '';
      return t.isEmpty ? null : t;
    }

    return {
      'caption': title.trim(),
      'memory_date': isoDate(date),
      'description': clean(description),
      'location': clean(location),
      'tags': tags,
    };
  }

  static Future<void> _savePhotoRows(
      String memoryId, String coupleId, List<String> paths) async {
    if (paths.isEmpty) return;
    await _db.from('memory_photos').insert([
      for (var i = 0; i < paths.length; i++)
        {'memory_id': memoryId, 'couple_id': coupleId, 'path': paths[i], 'position': i},
    ]);
  }

  /// Uploads the photos, saves the memory, then records the photos in order.
  /// If anything fails, the uploaded files are removed again.
  static Future<void> add({
    required String coupleId,
    required String title,
    required DateTime date,
    String? description,
    String? location,
    List<String> tags = const [],
    List<NewPhoto> photos = const [],
  }) async {
    if (photos.length > maxPhotos) {
      throw const AppException('A memory can have up to $maxPhotos photos.');
    }
    final uploaded = <String>[];
    try {
      for (var i = 0; i < photos.length; i++) {
        uploaded.add(await _upload(coupleId, photos[i], i));
      }
      final row = await _db
          .from('memories')
          .insert({
            'couple_id': coupleId,
            ..._fields(
                title: title,
                date: date,
                description: description,
                location: location,
                tags: tags),
            'photo_path': uploaded.isEmpty ? null : uploaded.first,
          })
          .select('id')
          .single();
      await _savePhotoRows(row['id'] as String, coupleId, uploaded);
    } catch (_) {
      await _removeFiles(uploaded);
      rethrow;
    }
  }

  /// Saves an edited memory. [keep] are the existing photos still wanted,
  /// in order; [added] are new ones to append. The photo list is rebuilt in
  /// the new order and removed photos are deleted from Storage.
  static Future<void> update(
    Memory memory, {
    required String title,
    required DateTime date,
    String? description,
    String? location,
    List<String> tags = const [],
    List<PhotoRef> keep = const [],
    List<NewPhoto> added = const [],
  }) async {
    if (keep.length + added.length > maxPhotos) {
      throw const AppException('A memory can have up to $maxPhotos photos.');
    }
    final uploaded = <String>[];
    try {
      for (var i = 0; i < added.length; i++) {
        uploaded.add(await _upload(memory.coupleId, added[i], keep.length + i));
      }
    } catch (_) {
      await _removeFiles(uploaded);
      rethrow;
    }

    final order = [...keep.map((p) => p.path), ...uploaded];
    await _db.from('memories').update({
      ..._fields(
          title: title,
          date: date,
          description: description,
          location: location,
          tags: tags),
      'photo_path': order.isEmpty ? null : order.first,
    }).eq('id', memory.id);

    await _db.from('memory_photos').delete().eq('memory_id', memory.id);
    await _savePhotoRows(memory.id, memory.coupleId, order);

    final removed = memory.photos
        .map((p) => p.path)
        .where((p) => !order.contains(p))
        .toList();
    await _removeFiles(removed);
  }

  /// Only the author can delete (enforced by the database). Photos go too.
  static Future<void> delete(Memory memory) async {
    await _db.from('memories').delete().eq('id', memory.id);
    await _removeFiles([for (final p in memory.photos) p.path]);
  }

  /// Either partner can move a memory into categories (its tags).
  static Future<void> setTags(String memoryId, List<String> tags) async {
    await _db.rpc('set_memory_tags',
        params: {'memory_id': memoryId, 'new_tags': tags});
  }

  /// Either partner can favourite. Returns the new value.
  static Future<bool> toggleFavorite(String memoryId) async {
    final result = await _db
        .rpc('toggle_memory_favorite', params: {'memory_id': memoryId});
    return result as bool;
  }
}
