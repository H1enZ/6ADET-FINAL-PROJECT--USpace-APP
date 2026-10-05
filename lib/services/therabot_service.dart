import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models/therabot.dart';
import '../models/therabot_chat.dart';

/// Therabot: "A private relationship reflection assistant".
///
/// Everything goes through the database functions of migration 011 or the
/// `therabot` Edge Function. The app never writes Therabot tables directly
/// and never sends an id other than the session id: who you are always
/// comes from your sign-in. Your answers are only ever read back as your
/// own row (row-level security), and nothing here logs them.
class TherabotService {
  TherabotService._();

  static SupabaseClient get _db => Supabase.instance.client;

  // ------------------------------------------------------------- sessions

  /// The couple's current session (open, or finished in the last 24 hours),
  /// or null when there is none.
  static Future<TherabotSession?> current() => _guard(() async {
    final rows = await _db.rpc('therabot_current');
    if (rows is! List || rows.isEmpty) return null;
    final row = rows.first;
    return row is Map<String, dynamic> ? TherabotSession.fromMap(row) : null;
  });

  /// Your own submission in [sessionId], or null if you haven't saved yet.
  static Future<MySubmission?> mySubmission(String sessionId) =>
      _guard(() async {
        final userId = _db.auth.currentUser?.id;
        if (userId == null) {
          throw const TherabotException('not_signed_in', _signIn);
        }
        final row = await _db
            .from('therabot_submissions')
            .select(
              'status, what_happened, feelings, wish_understood, need_now, '
              'private_summary, approved_summary, ai_attempts',
            )
            .eq('session_id', sessionId)
            .eq('user_id', userId)
            .maybeSingle();
        return row == null ? null : MySubmission.fromMap(row);
      });

  /// Starts a session for both of you. Returns its id.
  static Future<String> start() => _guard(() async {
    final id = await _db.rpc('therabot_start');
    if (id is! String) throw const TherabotException('internal', _generic);
    return id;
  });

  /// Saves (or replaces) your four answers. Any earlier summary is cleared,
  /// because it no longer matches what you wrote.
  static Future<void> saveAnswers(String sessionId, List<String> answers) =>
      _guard(() async {
        String at(int i) => i < answers.length ? answers[i].trim() : '';
        await _db.rpc(
          'therabot_save_answers',
          params: {
            'p_session_id': sessionId,
            'p_what_happened': at(0),
            'p_feelings': at(1),
            'p_wish_understood': at(2),
            'p_need_now': at(3),
          },
        );
      });

  /// Approves your summary, as written or as you corrected it. Returns true
  /// when this was the second approval.
  static Future<bool> approve(String sessionId, String text) =>
      _guard(() async {
        final both = await _db.rpc(
          'therabot_approve',
          params: {'p_session_id': sessionId, 'p_summary': text.trim()},
        );
        return both == true;
      });

  /// Your own next step. Your partner chooses theirs separately.
  static Future<void> choose(String sessionId, TherabotChoice choice) =>
      _guard(() async {
        await _db.rpc(
          'therabot_choose',
          params: {'p_session_id': sessionId, 'p_choice': choice.value},
        );
      });

  /// Ends a session that has no reflection yet. No reason is stored.
  static Future<void> end(String sessionId) => _guard(() async {
    await _db.rpc('therabot_end', params: {'p_session_id': sessionId});
  });

  /// Deletes your answers and summary now. An unfinished session closes.
  static Future<void> deleteMyAnswers(String sessionId) => _guard(() async {
    await _db.rpc(
      'therabot_delete_my_answers',
      params: {'p_session_id': sessionId},
    );
  });

  /// An optional title, only while the session is open.
  static Future<void> setTitle(String sessionId, String title) =>
      _guard(() async {
        await _db.rpc(
          'therabot_set_title',
          params: {'p_session_id': sessionId, 'p_title': title.trim()},
        );
      });

  // ------------------------------------------------------- the AI (Edge Function)

  /// Asks Therabot for your private summary. Only the session id is sent.
  static Future<SummarizeResult> summarize(String sessionId) =>
      _guard(() async {
        final data = await _invoke({
          'action': 'summarize',
          'session_id': sessionId,
        });
        if (data['status'] == 'safety') {
          final safety = data['safety'];
          final message = safety is Map && safety['message'] is String
              ? (safety['message'] as String).trim()
              : '';
          return SummarySafety(
            message.isEmpty ? therabotSafetyFallback : message,
          );
        }
        final reflection = data['reflection'];
        final parsed = reflection is Map<String, dynamic>
            ? PrivateReflection.fromMap(reflection)
            : null;
        if (data['status'] != 'summary_ready' || parsed == null) {
          throw const TherabotException('bad_output', _badOutput);
        }
        final left = data['summaries_left'];
        return SummaryReady(parsed, left is num ? left.toInt() : 0);
      });

  /// Asks for the shared reflection once both of you approved. Returns the
  /// session status afterwards (reflection_ready, completed or closed).
  static Future<String> reflect(String sessionId) => _guard(() async {
    final data = await _invoke({'action': 'reflect', 'session_id': sessionId});
    final status = data['status'];
    return status is String ? status : 'unknown';
  });

  // ------------------------------------------------------- guided chat (016)

  static ChatResult _chatResult(Map<String, dynamic> data, {String? talkId}) {
    if (data['status'] == 'safety') {
      final safety = data['safety'];
      final message = safety is Map ? safety['message'] : null;
      return ChatSafety(
        message is String && message.isNotEmpty
            ? message
            : therabotSafetyFallback,
      );
    }
    if (data['stage'] == 'done' && data.containsKey('both_finished')) {
      return ChatFinished(bothFinished: data['both_finished'] == true);
    }
    return ChatUpdated(ChatView.fromResponse(data, talkId: talkId));
  }

  /// Starts a Private Talk. [reasonText] only with the key "custom".
  static Future<ChatResult> talkStart(String reasonKey, {String? reasonText}) =>
      _guard(() async {
        final data = await _invoke({
          'action': 'talk_start',
          'reason_key': reasonKey,
          'reason_text': ?reasonText,
        });
        return _chatResult(data);
      });

  static Future<ChatResult> talkMessage(String talkId, String text) =>
      _guard(() async {
        final data = await _invoke({
          'action': 'talk_message',
          'talk_id': talkId,
          'text': text,
        });
        return _chatResult(data, talkId: talkId);
      });

  static Future<ChatResult> talkGoal(String talkId, String goal) =>
      _guard(() async {
        final data = await _invoke({
          'action': 'talk_goal',
          'talk_id': talkId,
          'goal': goal,
        });
        return _chatResult(data, talkId: talkId);
      });

  static Future<ChatResult> talkSummary(String talkId) => _guard(() async {
    final data = await _invoke({'action': 'talk_summary', 'talk_id': talkId});
    return _chatResult(data, talkId: talkId);
  });

  /// Your edit of a Private Talk summary (kept privately).
  static Future<void> talkSaveSummary(String talkId, String text) =>
      _guard(() async {
        await _db.rpc(
          'therabot_talk_save_summary',
          params: {'p_talk_id': talkId, 'p_summary': text.trim()},
        );
      });

  static Future<void> talkFinish(String talkId) => _guard(() async {
    await _db.rpc('therabot_talk_finish', params: {'p_talk_id': talkId});
  });

  static Future<void> talkDelete(String talkId) => _guard(() async {
    await _db.rpc('therabot_talk_delete', params: {'p_talk_id': talkId});
  });

  /// Your newest Private Talk still open (under 24 hours, not finished).
  static Future<ChatView?> openTalk() => _guard(() async {
    final rows = await _db
        .from('therabot_private_talks')
        .select('id, goal, stage, messages, summary, ai_turns')
        .neq('stage', 'done')
        .neq('stage', 'safety')
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return ChatView.fromRow(r, stageKey: 'stage', talkId: r['id'] as String);
  });

  /// Opens your part of a Couple Reflection after you agreed (consent).
  /// The partner who started passes the reason; the one who joins doesn't.
  static Future<ChatResult> chatOpen(
    String sessionId, {
    String? reasonKey,
    String? reasonText,
  }) => _guard(() async {
    final data = await _invoke({
      'action': 'chat_open',
      'session_id': sessionId,
      'reason_key': ?reasonKey,
      'reason_text': ?reasonText,
    });
    return _chatResult(data);
  });

  static Future<ChatResult> chatPick(
    String sessionId,
    String key, {
    String? text,
  }) => _guard(() async {
    final data = await _invoke({
      'action': 'chat_pick',
      'session_id': sessionId,
      'reason_key': key,
      'reason_text': ?text,
    });
    return _chatResult(data);
  });

  static Future<ChatResult> chatMessage(String sessionId, String text) =>
      _guard(() async {
        final data = await _invoke({
          'action': 'chat_message',
          'session_id': sessionId,
          'text': text,
        });
        return _chatResult(data);
      });

  static Future<ChatResult> chatGoal(String sessionId, String goal) =>
      _guard(() async {
        final data = await _invoke({
          'action': 'chat_goal',
          'session_id': sessionId,
          'goal': goal,
        });
        return _chatResult(data);
      });

  static Future<ChatResult> chatFinish(String sessionId) => _guard(() async {
    final data = await _invoke({
      'action': 'chat_finish',
      'session_id': sessionId,
    });
    return _chatResult(data);
  });

  /// Your own Couple Reflection chat in [sessionId] (null before you agreed).
  static Future<ChatView?> myChat(String sessionId) => _guard(() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw const TherabotException('not_signed_in', _signIn);
    final row = await _db
        .from('therabot_submissions')
        .select('chat_stage, goal, messages, chat_turns, consented_at')
        .eq('session_id', sessionId)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null || row['consented_at'] == null) return null;
    return ChatView.fromRow(row, stageKey: 'chat_stage');
  });

  /// The function's AI calls time out after 20 to 25 seconds and retry at
  /// most once, so a reply later than this is a connection that went quiet.
  static const _invokeTimeout = Duration(seconds: 75);

  /// Development only: a client for the local Therabot server, made once.
  /// See [AppConfig.localTherabotUrl] for when it is allowed.
  static FunctionsClient? _localFunctions;

  static FunctionsClient _functions() {
    if (!AppConfig.wantsLocalTherabot) return _db.functions;
    final url = AppConfig.localTherabotUrl;
    if (url == null) {
      // Refuse rather than fall back, so a test never silently reaches the
      // deployed function, and never send the token to a host not allowed.
      throw const TherabotException(
        'internal',
        'THERABOT_FUNCTIONS_URL must be http://localhost, 127.0.0.1 or '
            '10.0.2.2 (debug builds only).',
      );
    }
    final token = _db.auth.currentSession?.accessToken;
    if (token == null) throw const TherabotException('not_signed_in', _signIn);
    final client = _localFunctions ??= FunctionsClient(url, {
      'apikey': AppConfig.supabaseKey,
    });
    return client..setAuth(token);
  }

  static Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final FunctionResponse response;
    try {
      response = await _functions()
          .invoke('therabot', body: body)
          .timeout(_invokeTimeout);
    } on TimeoutException {
      throw const TherabotException(
        'offline',
        'Therabot is taking longer than usual. Check your connection and '
            'try again.',
      );
    }
    final json = response.data;
    if (json is Map<String, dynamic> &&
        json['ok'] == true &&
        json['data'] is Map<String, dynamic>) {
      return json['data'] as Map<String, dynamic>;
    }
    throw const TherabotException('internal', _generic);
  }

  // -------------------------------------------------------------- history

  /// Finished sessions, newest first. No private answers or summaries.
  static Future<List<TherabotHistoryEntry>> history({
    bool includeHidden = false,
  }) => _guard(() async {
    final rows = await _db.rpc(
      'therabot_history',
      params: {'include_hidden': includeHidden},
    );
    if (rows is! List) return const [];
    return [
      for (final r in rows)
        if (r is Map<String, dynamic>) ?TherabotHistoryEntry.fromMap(r),
    ];
  });

  /// Hides (or shows again) a finished session in YOUR history only.
  static Future<void> setHidden(String sessionId, bool hidden) =>
      _guard(() async {
        await _db.rpc(
          'therabot_set_hidden',
          params: {'p_session_id': sessionId, 'p_hidden': hidden},
        );
      });

  /// Asks to delete a finished session for good (or withdraws the request).
  /// It is deleted only once both of you confirmed; returns true then.
  static Future<bool> requestDelete(String sessionId, bool confirm) =>
      _guard(() async {
        final deleted = await _db.rpc(
          'therabot_request_delete',
          params: {'p_session_id': sessionId, 'p_confirm': confirm},
        );
        return deleted == true;
      });

  // ------------------------------------------------------------- insights

  /// Your saved insights, newest first. Only you can see them.
  static Future<List<({String id, String body, DateTime createdAt})>>
  insights() => _guard(() async {
    final rows = await _db
        .from('therabot_insights')
        .select('id, body, created_at')
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        (
          id: r['id'] as String,
          body: r['body'] as String,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        ),
    ];
  });

  /// Saves an insight you chose to keep. Never called without your tap.
  static Future<void> saveInsight(String body, {String? sessionId}) =>
      _guard(() async {
        await _db.from('therabot_insights').insert({
          'body': body.trim(),
          'source_session': ?sessionId,
        });
      });

  static Future<void> deleteInsight(String id) => _guard(() async {
    await _db.from('therabot_insights').delete().eq('id', id);
  });

  // --------------------------------------------------------------- errors

  static Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw therabotError(e);
    }
  }
}

/// A Therabot error with a code from the Edge Function contract and a
/// message written for people. It never carries SQL, stack traces or
/// provider details.
class TherabotException implements Exception {
  const TherabotException(this.code, this.message);

  /// expired, not_allowed, invalid_state, bad_input, ai_unavailable,
  /// bad_output, rate_limited, not_signed_in, offline or internal.
  final String code;
  final String message;

  @override
  String toString() => message;
}

const _generic = 'Something went wrong. Please try again in a moment.';
const _signIn = 'Please sign in again to use Therabot.';
const _badOutput =
    "Therabot couldn't put this into words properly. Please try again.";

/// Shown when the server's safety message is missing. Same resources as the
/// Edge Function's own message for an unknown category.
const therabotSafetyFallback =
    "Some of what you shared touches on safety, so we'll pause here. Your "
    'safety matters more than this reflection.\n\n'
    'If you are in immediate danger, call 911. For abuse or violence by a '
    'partner, you can call the PNP Women and Children Protection Center at '
    '0919 777 7377. If you are thinking about hurting yourself, you can call '
    'the NCMH crisis line at 1553 or 0917 899 8727, any time.\n\n'
    'You do not have to work this out with your partner here, and nothing '
    'about this is shared with them.';

/// Friendly, USpace-voiced messages for each Edge Function code.
const therabotMessages = {
  'expired':
      'This Therabot session has ended after 24 hours. You can start a new one any time.',
  'not_allowed':
      "This Therabot session isn't available any more. It may have ended.",
  'bad_input': "That didn't quite work. Please try again.",
  'invalid_state':
      "That step isn't available right now. Please go back and try again.",
  'ai_unavailable':
      'Therabot is resting for a moment. Your answers are saved, so try again shortly.',
  'bad_output': _badOutput,
  'rate_limited': 'Therabot has reached its limit for this session.',
  'not_signed_in': _signIn,
  'offline': "Couldn't reach USpace. Check your connection and try again.",
  'internal': _generic,
};

/// Turns any error into a [TherabotException] that is safe to show.
TherabotException therabotError(Object error) {
  if (error is TherabotException) return error;

  if (error is FunctionException) {
    if (error.status == 0) {
      return TherabotException('offline', therabotMessages['offline']!);
    }
    final details = error.details;
    final code = details is Map && details['code'] is String
        ? details['code'] as String
        : null;
    final serverMessage = details is Map && details['message'] is String
        ? details['message'] as String
        : null;
    if (code != null && therabotMessages.containsKey(code)) {
      // invalid_state and rate_limited messages from the function are
      // already written for people and say exactly what to do next.
      final specific =
          (code == 'invalid_state' || code == 'rate_limited') &&
          serverMessage != null &&
          serverMessage.length <= 200;
      return TherabotException(
        code,
        specific ? serverMessage : therabotMessages[code]!,
      );
    }
    if (error.status == 401) return TherabotException('not_signed_in', _signIn);
    return const TherabotException('internal', _generic);
  }

  if (error is PostgrestException) {
    // P0001 is a message we raised ourselves in migration 011 ("Pair with
    // your partner first."). Anything else may be technical: hide it.
    if (error.code == 'P0001' && error.message == 'Sign in first.') {
      return TherabotException('not_signed_in', _signIn);
    }
    if (error.code == 'P0001' && error.message.length <= 200) {
      return TherabotException('invalid_state', error.message);
    }
    if (error.code == 'PGRST301' ||
        error.code == 'PGRST303' ||
        error.code == '401') {
      return TherabotException('not_signed_in', _signIn);
    }
    return const TherabotException('internal', _generic);
  }

  if (error is AuthException) {
    return TherabotException('not_signed_in', _signIn);
  }
  // Usually a dropped connection; never shows the error itself.
  return const TherabotException(
    'internal',
    'Something went wrong. Check your connection and try again.',
  );
}
