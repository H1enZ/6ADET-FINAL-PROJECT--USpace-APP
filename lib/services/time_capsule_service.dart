import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/time_capsule.dart';
import 'auth_service.dart';

/// Time Capsules (migration 014). The database keeps them sealed: it hides a
/// capsule from the receiver during its ten-minute grace period, hides the
/// title, letter and photo from both of you once it is sealed for good, and
/// only lets the receiver open it, once its moment has come. Every change
/// goes through a database function; the app never writes the tables.
class TimeCapsuleService {
  TimeCapsuleService._();

  static SupabaseClient get _db => Supabase.instance.client;
  static const _bucket = 'capsule-photos'; // private
  static const _types = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static const letterMax = 10000;
  static const captionMax = 150;
  static const titleMax = 80;
  static const replyMax = 500;

  // ---------------------------------------------------------------- clock

  static Duration _skew = Duration.zero;

  /// Now, by the database's clock, so countdowns and "ready" agree with the
  /// server even when this device's clock is off.
  static DateTime now() => DateTime.now().add(_skew);

  static Future<void> syncClock() async {
    try {
      final before = DateTime.now();
      final server = DateTime.parse(
        await _db.rpc('capsule_server_time') as String,
      );
      final after = DateTime.now();
      final middle = before.add(after.difference(before) ~/ 2);
      _skew = server.difference(middle);
    } catch (_) {
      // Keep the last known difference.
    }
  }

  // ---------------------------------------------------------------- reading

  /// Every capsule you may see: your own in any state, and your partner's
  /// once their grace period is over.
  static Future<List<TimeCapsule>> list(String coupleId) async {
    final rows = await _db
        .from('time_capsules')
        .select()
        .eq('couple_id', coupleId)
        .order('created_at');
    return rows.map(TimeCapsule.fromMap).toList();
  }

  /// Contents of the capsules you may read right now (others are simply
  /// absent: the database doesn't return them).
  static Future<Map<String, CapsuleContents>> contents(List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _db
        .from('time_capsule_contents')
        .select()
        .inFilter('capsule_id', ids);
    return {
      for (final r in rows)
        r['capsule_id'] as String: CapsuleContents.fromMap(r),
    };
  }

  /// Replies on opened capsules, by capsule id.
  static Future<Map<String, List<CapsuleReply>>> replies(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final rows = await _db
        .from('time_capsule_replies')
        .select()
        .inFilter('capsule_id', ids)
        .order('created_at');
    final result = <String, List<CapsuleReply>>{};
    for (final r in rows) {
      result
          .putIfAbsent(r['capsule_id'] as String, () => [])
          .add(CapsuleReply.fromMap(r));
    }
    return result;
  }

  // ---------------------------------------------------------------- writing

  /// Saves (or starts) your one draft and returns its id.
  static Future<String> saveDraft({
    String? title,
    required String letter,
    DateTime? unlockAt,
    String? photoPath,
    String? caption,
  }) async {
    final id = await _db.rpc(
      'save_capsule_draft',
      params: {
        'p_title': title,
        'p_letter': letter,
        'p_unlock_at': unlockAt?.toUtc().toIso8601String(),
        'p_photo_path': photoPath,
        'p_photo_caption': caption,
      },
    );
    return id as String;
  }

  /// Saves changes to a capsule reopened during its ten minutes.
  static Future<void> saveEdit(
    String id, {
    String? title,
    required String letter,
    DateTime? unlockAt,
    String? photoPath,
    String? caption,
  }) async {
    await _db.rpc(
      'save_capsule_edit',
      params: {
        'p_id': id,
        'p_title': title,
        'p_letter': letter,
        'p_unlock_at': unlockAt?.toUtc().toIso8601String(),
        'p_photo_path': photoPath,
        'p_photo_caption': caption,
      },
    );
  }

  /// Seals a draft (or a capsule being edited). Returns when its ten
  /// minutes end.
  static Future<DateTime> seal(String id) async {
    final until = await _db.rpc('seal_time_capsule', params: {'p_id': id});
    return DateTime.parse(until as String).toLocal();
  }

  /// Reopens a capsule during its ten minutes.
  static Future<void> edit(String id) async {
    await _db.rpc('edit_time_capsule', params: {'p_id': id});
  }

  /// Deletes your draft and its photo.
  static Future<void> deleteDraft(String id) async {
    await _removeAllPhotosQuietly(id);
    await _db.rpc('delete_capsule_draft', params: {'p_id': id});
  }

  /// Withdraws a capsule during its ten minutes (or while editing it). A
  /// sealed one is reopened first: its photo can only be removed while it
  /// is being edited.
  static Future<void> cancel(String id, {bool sealed = false}) async {
    if (sealed) await edit(id);
    await _removeAllPhotosQuietly(id);
    await _db.rpc('cancel_time_capsule', params: {'p_id': id});
  }

  /// The receiver opens it. Safe to call again; returns the contents.
  static Future<CapsuleContents> open(String id) async {
    final rows =
        await _db.rpc('open_time_capsule', params: {'p_id': id}) as List;
    if (rows.isEmpty) {
      throw const AppException("This capsule couldn't be opened.");
    }
    return CapsuleContents.fromMap((rows.first as Map).cast<String, dynamic>());
  }

  /// Sends (or, while still allowed, changes) your one reply.
  static Future<void> reply(String id, String body) async {
    await _db.rpc(
      'reply_time_capsule',
      params: {'p_id': id, 'p_body': body.trim()},
    );
  }

  // ---------------------------------------------------------------- photos

  /// Uploads the capsule's photo to `capsule-photos/<couple>/<capsule>/`.
  static Future<String> uploadPhoto(
    String coupleId,
    String capsuleId,
    Uint8List bytes,
    String extension,
  ) async {
    final ext = extension.toLowerCase();
    final type = _types[ext];
    if (type == null) {
      throw const AppException('Choose a JPG, PNG or WebP photo.');
    }
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      throw const AppException(
        'That photo is over 5 MB. Choose a smaller one.',
      );
    }
    final path =
        '$coupleId/$capsuleId/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await _db.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          // Never cached (browser or CDN): a cached copy would outlive the
          // moment the capsule is sealed for good and its photo locked.
          fileOptions: FileOptions(contentType: type, cacheControl: '0'),
        );
    return path;
  }

  /// An opened capsule's photo, read with your session. Every download uses
  /// a new URL (a nonce), so no cached copy is ever served: the database
  /// checks each time that you may see it.
  static Future<Uint8List> downloadOpenedPhoto(String path) => _db.storage
      .from(_bucket)
      .download(path, cacheNonce: '${DateTime.now().microsecondsSinceEpoch}');

  // Before a capsule is opened nobody's session can read its photo (so
  // nobody can make a signed link to it). While it is yours to change, you
  // see and tidy it through the capsule-photo Edge Function, which checks
  // the capsule in the database and returns the bytes, never a link.

  /// Your draft's (or editable capsule's) photo, for previewing.
  static Future<Uint8List> previewPhoto(String capsuleId) async {
    final response = await _db.functions.invoke(
      'capsule-photo',
      body: {'action': 'preview', 'capsule_id': capsuleId},
    );
    final data = response.data;
    if (data is Uint8List) return data;
    throw const AppException("Couldn't load the photo.");
  }

  /// Removes photos the capsule no longer uses (after replacing or
  /// removing its photo).
  static Future<void> prunePhotos(String capsuleId) async {
    await _db.functions.invoke(
      'capsule-photo',
      body: {'action': 'prune', 'capsule_id': capsuleId},
    );
  }

  static Future<void> _removeAllPhotosQuietly(String capsuleId) async {
    try {
      await _db.functions.invoke(
        'capsule-photo',
        body: {'action': 'remove', 'capsule_id': capsuleId},
      );
    } catch (_) {
      // Unreadable to everyone once the capsule is gone anyway.
    }
  }

  // ---------------------------------------------------------------- live

  /// Calls [onChange] when one of your couple's capsules changes, or a
  /// capsule event (opened, replied) arrives. Filtered by couple: never
  /// subscribe without the filter (see migration 014).
  static RealtimeChannel listen(String coupleId, void Function() onChange) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'couple_id',
      value: coupleId,
    );
    return _db
        .channel('capsules-$coupleId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'time_capsules',
          filter: filter,
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'activities',
          filter: filter,
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  static Future<void> stopListening(RealtimeChannel channel) async {
    await _db.removeChannel(channel);
  }

  // ---------------------------------------------------------------- unread

  // Unread dots are remembered on this device, like Notifications: for each
  // capsule, the last step your partner took that you have seen.
  static String _seenKey(String myId) => 'capsules.seen.$myId';

  /// How far your partner has moved this capsule along: for the sender,
  /// 1 = opened, 2 = replied; for the receiver, 1 = answered your reply.
  static int partnerStep(
    TimeCapsule c,
    List<CapsuleReply> replies,
    String myId,
  ) {
    if (!c.isOpened) return 0;
    if (c.senderId == myId) {
      return replies.any((r) => r.authorId == c.receiverId) ? 2 : 1;
    }
    return replies.any((r) => r.authorId == c.senderId) ? 1 : 0;
  }

  static Future<Map<String, int>> seenSteps(String myId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_seenKey(myId));
      if (raw == null) return {};
      return (jsonDecode(raw) as Map).map(
        (k, v) => MapEntry(k as String, v as int),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> markSeen(String myId, String capsuleId, int step) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = await seenSteps(myId);
      seen[capsuleId] = step;
      await prefs.setString(_seenKey(myId), jsonEncode(seen));
    } catch (_) {
      // Not remembered this time.
    }
  }

  static const _filterKey = 'capsules.filter';

  static Future<String?> lastFilter(String myId) async {
    try {
      return (await SharedPreferences.getInstance()).getString(
        '$_filterKey.$myId',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> rememberFilter(String myId, String value) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        '$_filterKey.$myId',
        value,
      );
    } catch (_) {}
  }
}
