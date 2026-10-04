import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';
import '../models/chat_reaction.dart';
import 'auth_service.dart';

/// The couple's private chat. Row-level security means only the two
/// partners can read or post, nobody can send as the other, and edits,
/// deletes and read receipts go through database functions.
class ChatService {
  ChatService._();

  static SupabaseClient get _db => Supabase.instance.client;
  static const _bucket = 'memory-photos'; // private; chat photos go in <couple>/chat/
  static const _types = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
  };

  static String get _me => _db.auth.currentUser!.id;

  // Signed photo links, reused across reloads until they near expiry. A new
  // link on every reload made each photo download again and briefly lose
  // its height, which shifted the conversation.
  static final Map<String, ({String url, DateTime expires})> _signed = {};
  static const _linkLife = Duration(hours: 1);

  /// The latest [limit] messages, oldest first, with photo links signed.
  static Future<List<ChatMessage>> recent(String coupleId, {int limit = 300}) async {
    final rows = await _db
        .from('messages')
        .select()
        .eq('couple_id', coupleId)
        .order('created_at', ascending: false)
        .limit(limit);
    final messages = rows.map(ChatMessage.fromMap).toList().reversed.toList();

    final paths = messages.map((m) => m.photoPath).whereType<String>().toSet();
    if (paths.isEmpty) return messages;
    final now = DateTime.now();
    final unsigned = [
      for (final p in paths)
        if ((_signed[p]?.expires.difference(now) ?? Duration.zero) <
            const Duration(minutes: 10))
          p,
    ];
    if (unsigned.isNotEmpty) {
      try {
        final signed = await _db.storage
            .from(_bucket)
            .createSignedUrls(unsigned, _linkLife.inSeconds);
        final expires = now.add(_linkLife);
        for (final s in signed) {
          if (s.signedUrl.isNotEmpty) _signed[s.path] = (url: s.signedUrl, expires: expires);
        }
      } catch (_) {}
    }
    return [
      for (final m in messages)
        m.photoPath == null ? m : m.withPhotoUrl(_signed[m.photoPath]?.url),
    ];
  }

  /// Reactions for this couple: message id -> {user id: stored value}
  /// (a reaction key, or one of the original emoji in older rows).
  static Future<Map<String, Map<String, String>>> reactions(String coupleId) async {
    final rows = await _db
        .from('message_reactions')
        .select('message_id, user_id, emoji')
        .eq('couple_id', coupleId);
    final result = <String, Map<String, String>>{};
    for (final r in rows) {
      result.putIfAbsent(r['message_id'] as String, () => {})[r['user_id'] as String] =
          r['emoji'] as String;
    }
    return result;
  }

  static Future<void> send(String coupleId, String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    await _db.from('messages').insert({'couple_id': coupleId, 'body': text});
  }

  static Future<void> sendPhoto(
    String coupleId,
    Uint8List bytes,
    String extension, {
    String? caption,
  }) async {
    final ext = extension.toLowerCase();
    final type = _types[ext];
    if (type == null) throw const AppException('Choose a JPG, PNG, WebP or GIF photo.');
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      throw const AppException('That photo is over 5 MB. Choose a smaller one.');
    }
    final path = '$coupleId/chat/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await _db.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: type),
        );
    final text = caption?.trim() ?? '';
    try {
      await _db.from('messages').insert({
        'couple_id': coupleId,
        'photo_path': path,
        'body': text.isEmpty ? null : text,
      });
    } catch (_) {
      try {
        await _db.storage.from(_bucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  static Future<void> edit(String messageId, String body) async {
    await _db.rpc('edit_message', params: {'message_id': messageId, 'new_body': body});
  }

  /// Deletes your own message (text and photo). The bubble stays as
  /// "Message deleted" so the conversation still makes sense.
  static Future<void> delete(String messageId) async {
    final photo = await _db.rpc('delete_message', params: {'message_id': messageId});
    if (photo is String && photo.isNotEmpty) {
      try {
        await _db.storage.from(_bucket).remove([photo]);
      } catch (_) {}
    }
  }

  /// Marks your partner's messages to you as read.
  static Future<void> markRead() async {
    await _db.rpc('mark_messages_read');
  }

  /// One reaction per person per message; choosing again replaces it.
  /// Only the USpace reaction keys are written (never the original emoji).
  static Future<void> react(String coupleId, String messageId, ChatReaction reaction) async {
    await _db.from('message_reactions').upsert(
      {'message_id': messageId, 'couple_id': coupleId, 'user_id': _me, 'emoji': reaction.key},
      onConflict: 'message_id,user_id',
    );
  }

  static Future<void> removeReaction(String messageId) async {
    await _db
        .from('message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', _me);
  }

  /// Messages from your partner you have not read yet (for the badge).
  static Future<int> unreadCount(String coupleId) async {
    final rows = await _db
        .from('messages')
        .select('id')
        .eq('couple_id', coupleId)
        .neq('sender_id', _me)
        .isFilter('read_at', null)
        .isFilter('deleted_at', null);
    return rows.length;
  }

  /// Broadcast on the couple's chat channel after a reaction is removed.
  static const _reactionsChanged = 'reactions_changed';

  /// Calls [onChange] when a message is sent, edited, deleted or read, or
  /// a reaction is added, changed or removed.
  static RealtimeChannel listen(String coupleId, void Function() onChange) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'couple_id',
      value: coupleId,
    );
    return _db
        .channel('chat-$coupleId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: filter,
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_reactions',
          filter: filter,
          callback: (_) => onChange(),
        )
        // Realtime doesn't deliver DELETE events through a filtered
        // subscription, so a removed reaction is announced here instead.
        .onBroadcast(event: _reactionsChanged, callback: (_) => onChange())
        .subscribe();
  }

  /// Tells your partner's open chat to reload reactions after you removed
  /// one. The message carries nothing: they re-read reactions themselves,
  /// through the usual row-level security.
  static Future<void> announceReactionsChanged(RealtimeChannel channel) async {
    await channel.sendBroadcastMessage(event: _reactionsChanged, payload: {});
  }

  static Future<void> stopListening(RealtimeChannel channel) async {
    await _db.removeChannel(channel);
  }
}
