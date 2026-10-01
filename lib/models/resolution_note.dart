/// One person's "Let's work it out" note. Mirrors `resolution_notes`.
/// A note kept private is visible only to its author (the database
/// enforces it); a shared one is visible to both partners.
class ResolutionNote {
  const ResolutionNote({
    required this.id,
    required this.authorId,
    required this.need,
    required this.status,
    required this.isShared,
    required this.updatedAt,
    this.whatHappened,
    this.howItFelt,
    this.whatWeNeed,
    this.nextTime,
    this.apologyOrClarify,
    this.reconnect,
  });

  final String id;
  final String authorId;
  final String need; // solution, comfort, affection, listen
  final String status; // paused or done
  final bool isShared;
  final DateTime updatedAt;
  final String? whatHappened;
  final String? howItFelt;
  final String? whatWeNeed;
  final String? nextTime;
  final String? apologyOrClarify;
  final String? reconnect;

  bool get isDone => status == 'done';

  factory ResolutionNote.fromMap(Map<String, dynamic> row) => ResolutionNote(
        id: row['id'] as String,
        authorId: row['author_id'] as String,
        need: row['need'] as String,
        status: row['status'] as String,
        isShared: (row['is_shared'] as bool?) ?? true,
        updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
        whatHappened: row['what_happened'] as String?,
        howItFelt: row['how_it_felt'] as String?,
        whatWeNeed: row['what_we_need'] as String?,
        nextTime: row['next_time'] as String?,
        apologyOrClarify: row['apology_or_clarify'] as String?,
        reconnect: row['reconnect'] as String?,
      );

  /// The six resolution questions, in order, with this note's answers.
  List<(String, String?)> get answers => [
        (resolutionQuestions[0], whatHappened),
        (resolutionQuestions[1], howItFelt),
        (resolutionQuestions[2], whatWeNeed),
        (resolutionQuestions[3], nextTime),
        (resolutionQuestions[4], apologyOrClarify),
        (resolutionQuestions[5], reconnect),
      ];
}

/// The six questions of the resolution flow, matching the six columns.
const resolutionQuestions = [
  'What happened, from your perspective?',
  'How did it make you feel?',
  'What do you need from each other?',
  'What can we do differently next time?',
  'Is there anything you want to apologise for or clarify?',
  'What is one small thing we can do to reconnect?',
];

const resolutionColumns = [
  'what_happened',
  'how_it_felt',
  'what_we_need',
  'next_time',
  'apology_or_clarify',
  'reconnect',
];
