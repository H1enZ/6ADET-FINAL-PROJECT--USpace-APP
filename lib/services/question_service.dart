import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/question_answer.dart';
import '../utils/anniversary.dart';

/// Today's Question. The database only shows your partner's answer after
/// you have answered the same day's question yourself.
class QuestionService {
  QuestionService._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// Answers for [day] that you are allowed to see (yours, and your
  /// partner's once you have answered).
  static Future<List<QuestionAnswer>> answersFor(String coupleId, DateTime day) async {
    final rows = await _db
        .from('question_answers')
        .select()
        .eq('couple_id', coupleId)
        .eq('question_date', isoDate(day));
    return rows.map(QuestionAnswer.fromMap).toList();
  }

  /// Whether your partner answered [day]'s question, without revealing the
  /// answer. Uses the activity feed.
  static Future<bool> partnerAnswered(
    String coupleId,
    String partnerId,
    DateTime day,
  ) async {
    final start = DateTime(day.year, day.month, day.day);
    final rows = await _db
        .from('activities')
        .select('id')
        .eq('couple_id', coupleId)
        .eq('actor_id', partnerId)
        .eq('kind', 'question_answered')
        .gte('created_at', start.toUtc().toIso8601String())
        .limit(1);
    return rows.isNotEmpty;
  }

  /// Saves or updates your answer for [day].
  static Future<void> answer({
    required String coupleId,
    required DateTime day,
    required String question,
    required String answer,
  }) async {
    await _db.from('question_answers').upsert(
      {
        'couple_id': coupleId,
        'user_id': _db.auth.currentUser!.id,
        'question_date': isoDate(day),
        'question': question,
        'answer': answer.trim(),
      },
      onConflict: 'user_id,question_date',
    );
  }

  /// Past questions and answers you can see, newest first.
  static Future<List<QuestionAnswer>> archive(String coupleId) async {
    final rows = await _db
        .from('question_answers')
        .select()
        .eq('couple_id', coupleId)
        .order('question_date', ascending: false)
        .limit(120);
    return rows.map(QuestionAnswer.fromMap).toList();
  }
}
