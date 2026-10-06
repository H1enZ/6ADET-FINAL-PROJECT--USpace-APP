// Therabot: "A private relationship reflection assistant".
//
// These mirror what the database functions in migration 011 and the
// therabot Edge Function return. Parsing is defensive: an unexpected shape
// becomes an empty list or null, never a crash, and never invented content.

import '../theme/us_icons.dart';

/// Session statuses from migration 011.
enum TherabotStatus {
  collecting,
  reflecting,
  reflectionReady,
  completed,
  closed,
  unknown,
}

TherabotStatus _status(Object? s) => switch (s) {
  'collecting' => TherabotStatus.collecting,
  'reflecting' => TherabotStatus.reflecting,
  'reflection_ready' => TherabotStatus.reflectionReady,
  'completed' => TherabotStatus.completed,
  'closed' => TherabotStatus.closed,
  _ => TherabotStatus.unknown,
};

/// A participant's progress. The partner's is couple-visible; it carries
/// no content.
enum TherabotProgress { pending, submitted, approved }

TherabotProgress _progress(Object? p) => switch (p) {
  'submitted' => TherabotProgress.submitted,
  'approved' => TherabotProgress.approved,
  _ => TherabotProgress.pending,
};

/// The four next steps. Shown equally; Therabot never ranks them.
enum TherabotChoice {
  comfort(
    'comfort',
    UsIcons.hug,
    'Comfort each other',
    'Feel held, or hold them. A little more warmth right now.',
  ),
  talk(
    'talk',
    UsIcons.chat,
    'Talk it through',
    "I'm ready to have a calm and honest conversation together.",
  ),
  space(
    'space',
    UsIcons.breathe,
    'Take a breather',
    'A little time apart, then check in again.',
  ),
  reconnect(
    'reconnect',
    UsIcons.heart,
    'Reconnect gently',
    'Small ways back to each other without reopening everything.',
  );

  const TherabotChoice(this.value, this.icon, this.label, this.blurb);
  final String value;
  final UsIconData icon;
  final String label;
  final String blurb;

  /// The steps offered now. Comfort is no longer offered, but it stays so
  /// past reflections that chose it still show it.
  static const offered = [talk, space, reconnect];

  static TherabotChoice? from(Object? v) {
    for (final c in values) {
      if (c.value == v) return c;
    }
    return null;
  }
}

List<String> _strings(Object? x) => x is List
    ? [
        for (final v in x)
          if (v is String && v.trim().isNotEmpty) v.trim(),
      ]
    : const [];

DateTime? _time(Object? x) =>
    x is String ? DateTime.tryParse(x)?.toLocal() : null;

/// The couple's current session, from the caller's side (therabot_current).
class TherabotSession {
  const TherabotSession({
    required this.id,
    required this.status,
    required this.iStarted,
    required this.myPartnerNumber,
    required this.myProgress,
    required this.partnerProgress,
    required this.myChoice,
    required this.partnerChoice,
    this.partnerHasChosen = false,
    required this.title,
    required this.reflection,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final TherabotStatus status;
  final bool iStarted;

  /// 1 for whoever started the session, 2 for the other. The shared
  /// reflection only ever says "Partner 1" and "Partner 2".
  final int myPartnerNumber;
  final TherabotProgress myProgress;
  final TherabotProgress partnerProgress;
  final TherabotChoice? myChoice;

  /// Only once you have BOTH chosen (migration 017); null before that.
  final TherabotChoice? partnerChoice;

  /// Whether your partner has chosen yet, without saying what.
  final bool partnerHasChosen;
  final String? title;
  final SharedReflection? reflection;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isOpen =>
      status == TherabotStatus.collecting ||
      status == TherabotStatus.reflecting ||
      status == TherabotStatus.reflectionReady;

  bool get hasReflection =>
      (status == TherabotStatus.reflectionReady ||
          status == TherabotStatus.completed) &&
      reflection != null;

  static TherabotSession? fromMap(Map<String, dynamic> row) {
    final id = row['session_id'];
    final created = _time(row['created_at']);
    final expires = _time(row['expires_at']);
    if (id is! String || created == null || expires == null) return null;
    final reflection = row['shared_reflection'];
    return TherabotSession(
      id: id,
      status: _status(row['status']),
      iStarted: row['i_started'] == true,
      myPartnerNumber: row['my_partner_number'] == 2 ? 2 : 1,
      myProgress: _progress(row['my_progress']),
      partnerProgress: _progress(row['partner_progress']),
      myChoice: TherabotChoice.from(row['my_choice']),
      partnerChoice: TherabotChoice.from(row['partner_choice']),
      partnerHasChosen:
          row['partner_has_chosen'] == true || row['partner_choice'] != null,
      title: row['title'] as String?,
      reflection: reflection is Map<String, dynamic>
          ? SharedReflection.fromMap(reflection)
          : null,
      createdAt: created,
      expiresAt: expires,
    );
  }
}

/// The signed-in person's OWN submission. Row-level security means this
/// can only ever be your own row, and only for 24 hours.
class MySubmission {
  const MySubmission({
    required this.status,
    required this.answers,
    required this.aiAttempts,
    this.summary,
    this.safetyMessage,
    this.approvedSummary,
  });

  /// draft, summary_ready, approved or safety.
  final String status;

  /// The four answers, in question order ('' when blank).
  final List<String> answers;
  final int aiAttempts;
  final PrivateReflection? summary;

  /// Set only when the safety check paused this session for you.
  final String? safetyMessage;
  final String? approvedSummary;

  bool get isSafety => status == 'safety';

  factory MySubmission.fromMap(Map<String, dynamic> row) {
    final private = row['private_summary'];
    PrivateReflection? summary;
    String? safetyMessage;
    if (private is Map<String, dynamic>) {
      final safety = private['safety'];
      if (row['status'] == 'safety') {
        final m = safety is Map ? safety['message'] : null;
        safetyMessage = m is String && m.trim().isNotEmpty ? m.trim() : null;
      } else {
        summary = PrivateReflection.fromMap(private);
      }
    }
    String a(String k) => (row[k] as String?) ?? '';
    return MySubmission(
      status: (row['status'] as String?) ?? 'draft',
      answers: [
        a('what_happened'),
        a('feelings'),
        a('wish_understood'),
        a('need_now'),
      ],
      aiAttempts: (row['ai_attempts'] as num?)?.toInt() ?? 0,
      summary: summary,
      safetyMessage: row['status'] == 'safety' ? safetyMessage : null,
      approvedSummary: row['approved_summary'] as String?,
    );
  }
}

/// One section of a private summary: a heading and the person's own
/// concrete details under it.
class SummarySection {
  const SummarySection(this.heading, this.text);
  final String heading;
  final String text;
}

/// One person's private AI summary. Only its owner ever sees it.
class PrivateReflection {
  const PrivateReflection({
    required this.summary,
    this.sections = const [],
    required this.needs,
    required this.uncertainPoints,
    required this.suggestedInsights,
  });

  /// The plain summary. Older summaries only have this.
  final String summary;

  /// Non-empty sections in display order. Empty for older summaries; a
  /// section the answers didn't support is simply not here.
  final List<SummarySection> sections;
  final List<String> needs;
  final List<String> uncertainPoints;
  final List<String> suggestedInsights;

  /// Section keys and headings, in order. The same as the Edge Function's
  /// SECTION_HEADINGS, so [approvalText] matches its `summary`.
  static const sectionHeadings = [
    ('what_happened', 'WHAT HAPPENED'),
    ('how_you_feel', 'HOW YOU FEEL'),
    ('what_matters_to_you', 'WHAT MATTERS TO YOU'),
    (
      'what_you_want_your_partner_to_understand',
      'WHAT YOU WANT YOUR PARTNER TO UNDERSTAND',
    ),
    ('what_you_need', 'WHAT YOU NEED'),
  ];

  static PrivateReflection? fromMap(Map<String, dynamic> m) {
    final raw = m['sections'];
    final sections = <SummarySection>[
      if (raw is Map)
        for (final (key, heading) in sectionHeadings)
          if (raw[key] is String && (raw[key] as String).trim().isNotEmpty)
            SummarySection(heading, (raw[key] as String).trim()),
    ];
    final summary = m['summary'];
    final plain = summary is String ? summary.trim() : '';
    if (sections.isEmpty && plain.isEmpty) return null;
    return PrivateReflection(
      summary: plain,
      sections: sections,
      needs: _strings(m['needs']),
      uncertainPoints: _strings(m['uncertain_points']),
      suggestedInsights: _strings(m['suggested_insights']),
    );
  }

  /// The text offered for approval. Only this approved text (never the
  /// answers) feeds the shared reflection.
  ///
  /// With sections: each under its heading, exactly as shown on screen.
  /// Older summaries: the summary plus what you need.
  String get approvalText {
    if (sections.isNotEmpty) {
      return sections.map((s) => '${s.heading}\n${s.text}').join('\n\n');
    }
    if (needs.isEmpty) return summary;
    final withNeeds = '$summary\n\nWhat I need: ${needs.join('; ')}.';
    return withNeeds.length <= maxApprovedLength ? withNeeds : summary;
  }

  static const maxApprovedLength = 1500;
}

class Perspective {
  const Perspective({
    required this.partner,
    required this.summary,
    required this.needs,
  });
  final int partner;
  final String summary;
  final List<String> needs;
}

/// The couple-visible reflection, written only from both approved summaries.
class SharedReflection {
  const SharedReflection({
    required this.perspectives,
    required this.differences,
    required this.possibleMisunderstandings,
    required this.commonGround,
    required this.discussionQuestions,
    this.somethingToTry = const [],
  });

  final List<Perspective> perspectives;
  final List<String> differences;
  final List<String> possibleMisunderstandings;

  /// Often empty. When it is, the screen shows nothing, never filler.
  final List<String> commonGround;
  final List<String> discussionQuestions;

  /// Gentle ideas to try together (newer reflections; older ones have none).
  final List<String> somethingToTry;

  Perspective? perspectiveOf(int partner) {
    for (final p in perspectives) {
      if (p.partner == partner) return p;
    }
    return null;
  }

  static SharedReflection? fromMap(Map<String, dynamic> m) {
    final raw = m['perspectives'];
    final perspectives = <Perspective>[
      if (raw is List)
        for (final p in raw)
          if (p is Map &&
              p['summary'] is String &&
              (p['partner'] == '1' || p['partner'] == '2'))
            Perspective(
              partner: p['partner'] == '2' ? 2 : 1,
              summary: (p['summary'] as String).trim(),
              needs: _strings(p['needs']),
            ),
    ];
    if (perspectives.isEmpty) return null;
    return SharedReflection(
      perspectives: perspectives,
      differences: _strings(m['differences']),
      possibleMisunderstandings: _strings(m['possible_misunderstandings']),
      commonGround: _strings(m['common_ground']),
      discussionQuestions: _strings(m['discussion_questions']),
      somethingToTry: _strings(m['something_to_try']),
    );
  }
}

/// Display only: who "Partner 1" and "Partner 2" are, by username. The AI
/// never sees these names; it is given and returns only "Partner 1" (who
/// started the session) and "Partner 2", and the stored reflection keeps
/// those labels. They become usernames here, at render time, and nowhere
/// else.
class TherabotNames {
  const TherabotNames({
    required this.myPartnerNumber,
    this.myName,
    this.partnerName,
  });

  /// 1 if the signed-in person started the session, 2 if their partner did.
  final int myPartnerNumber;
  final String? myName;
  final String? partnerName;

  /// The username for [partner], or "Partner 1" / "Partner 2" when unknown.
  String of(int partner) {
    final name = (partner == myPartnerNumber ? myName : partnerName)?.trim();
    return name == null || name.isEmpty ? 'Partner $partner' : name;
  }

  /// Exactly the labels the Edge Function uses. Word boundaries keep
  /// "Partner 12" or "partner 1" from matching.
  static final _label = RegExp(r'\bPartner ([12])\b');

  /// [text] split into plain runs and partner labels (partner set), so a
  /// label can be shown as a name without changing the text itself.
  List<({String text, int? partner})> segments(String text) {
    final out = <({String text, int? partner})>[];
    var at = 0;
    for (final m in _label.allMatches(text)) {
      if (m.start > at) {
        out.add((text: text.substring(at, m.start), partner: null));
      }
      final partner = m.group(1) == '2' ? 2 : 1;
      out.add((text: of(partner), partner: partner));
      at = m.end;
    }
    if (at < text.length) out.add((text: text.substring(at), partner: null));
    return out;
  }

  /// [text] as it reads on screen, for copying.
  String display(String text) => segments(text).map((s) => s.text).join();
}

/// A finished session in the caller's history (therabot_history). It holds
/// no private answers or summaries: those are gone after 24 hours.
class TherabotHistoryEntry {
  const TherabotHistoryEntry({
    required this.sessionId,
    required this.title,
    required this.reflection,
    required this.myPartnerNumber,
    required this.myChoice,
    required this.partnerChoice,
    required this.iRequestedDelete,
    required this.partnerRequestedDelete,
    required this.isHidden,
    required this.createdAt,
    required this.completedAt,
  });

  final String sessionId;
  final String? title;
  final SharedReflection? reflection;
  final int myPartnerNumber;
  final TherabotChoice? myChoice;
  final TherabotChoice? partnerChoice;
  final bool iRequestedDelete;
  final bool partnerRequestedDelete;
  final bool isHidden;
  final DateTime createdAt;
  final DateTime? completedAt;

  static TherabotHistoryEntry? fromMap(Map<String, dynamic> row) {
    final id = row['session_id'];
    final created = _time(row['created_at']);
    if (id is! String || created == null) return null;
    final reflection = row['shared_reflection'];
    return TherabotHistoryEntry(
      sessionId: id,
      title: row['title'] as String?,
      reflection: reflection is Map<String, dynamic>
          ? SharedReflection.fromMap(reflection)
          : null,
      myPartnerNumber: row['my_partner_number'] == 2 ? 2 : 1,
      myChoice: TherabotChoice.from(row['my_choice']),
      partnerChoice: TherabotChoice.from(row['partner_choice']),
      iRequestedDelete: row['i_requested_delete'] == true,
      partnerRequestedDelete: row['partner_requested_delete'] == true,
      isHidden: row['is_hidden'] == true,
      createdAt: created,
      completedAt: _time(row['completed_at']),
    );
  }
}

/// What a summarize call returned.
sealed class SummarizeResult {
  const SummarizeResult();
}

class SummaryReady extends SummarizeResult {
  const SummaryReady(this.reflection, this.summariesLeft);
  final PrivateReflection reflection;
  final int summariesLeft;
}

/// The safety check paused the session. [message] is the server's fixed,
/// human-written message, for the owner only.
class SummarySafety extends SummarizeResult {
  const SummarySafety(this.message);
  final String message;
}

/// The four private questions, in the order the database stores them.
const therabotQuestions = [
  'What happened from your perspective?',
  'How are you feeling?',
  'What do you wish your partner understood?',
  'What do you need right now?',
];

/// Hints under each question: gentle, never leading.
const therabotQuestionHints = [
  'Just your side, in your own words. There are no wrong answers.',
  'Any feelings are welcome here, even mixed or messy ones.',
  'What would you want them to really get about this?',
  'Something small is fine: rest, a hug, time, a talk later.',
];

const therabotMaxAnswerLength = 2000;
const therabotMaxSummaries = 3;
const therabotMaxInsightLength = 300;

/// What the two private next-step choices add up to, once both are made.
/// Fixed, neutral wording (no AI): the same step becomes a shared next step,
/// two different ones get a gentle bridge that keeps something of each.
({String title, String body}) nextStepOutcome(
  TherabotChoice mine,
  TherabotChoice theirs,
) {
  if (mine == theirs) {
    return switch (mine) {
      TherabotChoice.comfort => (
        title: 'You both chose to comfort each other',
        body:
            'Take a few quiet minutes together today: a hug, sitting close, or a kind message. '
            'There is no need to talk it all through yet.',
      ),
      TherabotChoice.talk => (
        title: 'You both feel ready to talk it through',
        body:
            'Pick a calm moment today, start with one of your conversation starters, and take '
            'turns listening without interrupting.',
      ),
      TherabotChoice.space => (
        title: 'You both want a little breathing room',
        body:
            'Take some time apart, and agree on when you will check in again, for example '
            'later this evening.',
      ),
      TherabotChoice.reconnect => (
        title: 'You both want to reconnect gently',
        body:
            'Do one small, easy thing together today, like a walk, a meal or a song you both '
            'like, without reopening everything.',
      ),
    };
  }
  final pair = {mine, theirs};
  bool has(TherabotChoice a, TherabotChoice b) =>
      pair.contains(a) && pair.contains(b);
  final String bridge;
  if (has(TherabotChoice.comfort, TherabotChoice.talk)) {
    bridge =
        'Start close, then talk: begin with a hug or a quiet moment together, and talk it '
        'through once you both feel settled.';
  } else if (has(TherabotChoice.comfort, TherabotChoice.space)) {
    bridge =
        'Give a little space, with warmth: a kind word or a hug before some time apart, and '
        'a set time to check in.';
  } else if (has(TherabotChoice.comfort, TherabotChoice.reconnect)) {
    bridge =
        'Let closeness lead: sit together, share something small and easy, and let the '
        'warmth come back on its own.';
  } else if (has(TherabotChoice.talk, TherabotChoice.space)) {
    bridge =
        'A short breather first, then talk: agree on a time later today when you will both '
        'sit down calmly.';
  } else if (has(TherabotChoice.talk, TherabotChoice.reconnect)) {
    bridge =
        'Reconnect first, then talk: share something easy together, and when it feels '
        'lighter, open the conversation gently.';
  } else {
    bridge =
        'Some time apart, then a small way back: take a breather, then meet for something '
        'simple you both enjoy.';
  }
  return (
    title: "You need slightly different things right now, and that's okay",
    body: bridge,
  );
}
