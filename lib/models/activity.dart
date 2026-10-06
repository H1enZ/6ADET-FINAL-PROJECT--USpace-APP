import '../theme/us_icons.dart';
import 'mood.dart';

/// One entry in the couple's activity feed. Written only by the database.
class Activity {
  const Activity({
    required this.id,
    required this.actorId,
    required this.kind,
    required this.createdAt,
    this.detail,
  });

  final String id;
  final String actorId;
  final String kind;
  final String? detail;
  final DateTime createdAt; // local time

  factory Activity.fromMap(Map<String, dynamic> row) => Activity(
        id: row['id'] as String,
        actorId: row['actor_id'] as String,
        kind: row['kind'] as String,
        detail: row['detail'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      );

  /// A friendly sentence: "Ana added a memory: Beach day".
  String describe({required String name, required bool isMe}) {
    final who = isMe ? 'You' : name;
    final d = detail;
    switch (kind) {
      case 'memory_added':
        return d == null ? '$who added a memory' : '$who added a memory: $d';
      case 'question_answered':
        return "$who answered today's question";
      case 'mood_updated':
        final mood = Mood.fromName(d);
        return mood == null
            ? '$who updated ${isMe ? 'your' : 'their'} mood'
            : '$who ${isMe ? 'are' : 'is'} feeling ${mood.label.toLowerCase()}';
      case 'note_sent':
        return d == 'capsule'
            ? '$who sealed a time capsule'
            : '$who sent a love note';
      case 'affection_sent':
        final gesture = switch (d) {
          'hug' => 'a hug',
          'kiss' => 'a kiss',
          'cuddle' => 'a cuddle',
          'comfort' => 'some comfort',
          'listen' => 'something to listen to',
          _ => 'some love',
        };
        if (d == 'listen') return '$who wants to talk';
        return '$who sent $gesture';
      case 'date_added':
        return d == null ? '$who saved a special date' : '$who saved a date: $d';
      case 'bucket_added':
        return d == null
            ? '$who added to the bucket list'
            : '$who added to the bucket list: $d';
      default:
        return '$who did something sweet';
    }
  }

  /// The USpace icon for this kind of activity.
  UsIconData get icon => switch (kind) {
        'memory_added' => UsIcons.addMemory,
        'question_answered' => UsIcons.question,
        'mood_updated' => UsIcons.mood,
        'note_sent' => detail == 'capsule' ? UsIcons.lock : UsIcons.loveNotes,
        'affection_sent' => UsIcons.heart,
        'date_added' => UsIcons.planDate,
        'bucket_added' => UsIcons.sparkle,
        _ => UsIcons.sparkle,
      };
}
