import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../utils/anniversary.dart';
import 'auth_service.dart';
import 'storage_links.dart';
import 'couple_service.dart';

/// Your own profile: name, birthday and photo. The database only lets you
/// change your own row and your own photo folder.
class ProfileService {
  ProfileService._();

  static SupabaseClient get _db => Supabase.instance.client;
  static const _bucket = 'avatars';
  static const maxPhotoBytes = 5 * 1024 * 1024; // 5 MB
  static const _types = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static String get _userId {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw const AppException('Sign in again to continue.');
    return id;
  }

  /// Adds a one-hour link to each person's photo (the bucket is private).
  static Future<List<Profile>> withPhotos(List<Profile> people) async {
    final paths = people.map((p) => p.avatarPath).whereType<String>().toList();
    if (paths.isEmpty) return people;
    try {
      final urls = await StorageLinks.signed(_bucket, paths);
      return [
        for (final p in people)
          p.avatarPath == null ? p : p.withAvatarUrl(urls[p.avatarPath]),
      ];
    } catch (_) {
      return people; // initials instead of photos
    }
  }

  static Future<void> updateName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 40) {
      throw const AppException('Your name must be 1 to 40 characters.');
    }
    await _db
        .from('profiles')
        .update({'display_name': trimmed}).eq('user_id', _userId);
    CoupleService.forget();
  }

  /// Null removes it.
  static Future<void> updateBirthday(DateTime? birthday) async {
    await _db.from('profiles').update({
      'birthday': birthday == null ? null : isoDate(birthday),
    }).eq('user_id', _userId);
    CoupleService.forget();
  }

  /// Uploads a new photo into your own folder, points your profile at it,
  /// then removes the old one.
  static Future<void> uploadPhoto(
    Uint8List bytes,
    String extension, {
    String? oldPath,
  }) async {
    final ext = extension.toLowerCase();
    final type = _types[ext];
    if (type == null) {
      throw const AppException('Choose a JPG, PNG or WebP photo.');
    }
    if (bytes.lengthInBytes > maxPhotoBytes) {
      throw const AppException('That photo is over 5 MB. Choose a smaller one.');
    }

    final path = '$_userId/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await _db.storage
        .from(_bucket)
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: type));
    await _db
        .from('profiles')
        .update({'avatar_path': path}).eq('user_id', _userId);
    CoupleService.forget();

    if (oldPath != null) {
      try {
        await _db.storage.from(_bucket).remove([oldPath]);
      } catch (_) {}
    }
  }

  static Future<void> removePhoto(String path) async {
    await _db
        .from('profiles')
        .update({'avatar_path': null}).eq('user_id', _userId);
    CoupleService.forget();
    try {
      await _db.storage.from(_bucket).remove([path]);
    } catch (_) {}
  }
}
