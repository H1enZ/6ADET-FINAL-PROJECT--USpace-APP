/// Therabot's guided chat (migration 016): Private Talk, and your own
/// private part of a Couple Reflection. Only ever your own messages; the
/// server never sends its private working notes or your partner's chat.
library;

/// A quick reply Therabot offers: what to send, and what it says.
class ChatChip {
  const ChatChip(this.key, this.label);

  final String key;
  final String label;
}

class ChatMsg {
  const ChatMsg({
    required this.fromTherabot,
    required this.text,
    this.chips = const [],
  });

  final bool fromTherabot;
  final String text;
  final List<ChatChip> chips;

  factory ChatMsg.fromMap(Map<String, dynamic> m) {
    final raw = m['chips'];
    return ChatMsg(
      fromTherabot: m['role'] != 'user',
      text: (m['text'] as String?) ?? '',
      chips: raw is List
          ? [
              for (final c in raw)
                if (c is List && c.length == 2) ChatChip('${c[0]}', '${c[1]}'),
            ]
          : const [],
    );
  }
}

/// Where a chat is:
/// open    the partner who joined a Couple Reflection, before choosing how to start;
/// chat    talking;
/// goal    choosing what would help;
/// wrap    ready to finish (or add something);
/// summary a Private Talk summary to review;
/// done    finished; safety: stopped for safety.
class ChatView {
  const ChatView({
    required this.messages,
    required this.stage,
    this.goal,
    this.turnsLeft = 0,
    this.summary,
    this.talkId,
  });

  final List<ChatMsg> messages;
  final String stage;
  final String? goal;
  final int turnsLeft;
  final String? summary;
  final String? talkId;

  /// Quick replies to show now: those on the newest Therabot message.
  List<ChatChip> get chips {
    if (messages.isEmpty || !messages.last.fromTherabot) return const [];
    return messages.last.chips;
  }

  ChatView copyWith({String? stage, String? summary}) => ChatView(
    messages: messages,
    stage: stage ?? this.stage,
    goal: goal,
    turnsLeft: turnsLeft,
    summary: summary ?? this.summary,
    talkId: talkId,
  );

  static List<ChatMsg> _messages(Object? raw) => raw is List
      ? [
          for (final m in raw)
            if (m is Map<String, dynamic>) ChatMsg.fromMap(m),
        ]
      : const [];

  /// From an Edge Function answer.
  factory ChatView.fromResponse(Map<String, dynamic> d, {String? talkId}) =>
      ChatView(
        messages: _messages(d['messages']),
        stage: (d['stage'] as String?) ?? 'chat',
        goal: d['goal'] as String?,
        turnsLeft: (d['turns_left'] as num?)?.toInt() ?? 0,
        summary: d['summary'] as String?,
        talkId: (d['talk_id'] as String?) ?? talkId,
      );

  /// From your own row, read back directly (row-level security).
  factory ChatView.fromRow(
    Map<String, dynamic> r, {
    required String stageKey,
    String? talkId,
  }) => ChatView(
    messages: _messages(r['messages']),
    stage: (r[stageKey] as String?) ?? 'chat',
    goal: r['goal'] as String?,
    turnsLeft: 5 - (((r['ai_turns'] ?? r['chat_turns']) as num?)?.toInt() ?? 0),
    summary: r['summary'] as String?,
    talkId: talkId,
  );
}

/// What a chat request returned: the chat, or a safety stop.
sealed class ChatResult {
  const ChatResult();
}

class ChatUpdated extends ChatResult {
  const ChatUpdated(this.view);
  final ChatView view;
}

class ChatSafety extends ChatResult {
  const ChatSafety(this.message);
  final String message;
}

/// A Couple Reflection part was finished.
class ChatFinished extends ChatResult {
  const ChatFinished({required this.bothFinished});
  final bool bothFinished;
}

/// The fixed opening choices. The labels match the server's (which is what
/// is stored and shown); the keys are what the app sends.
const talkReasons = [
  ChatChip('bothering', 'Something is bothering me'),
  ChatChip('advice', 'I want advice'),
  ChatChip('feelings', "I want to understand what I'm feeling"),
  ChatChip('chest', 'I need to get something off my chest'),
  ChatChip('good', 'Something good happened'),
  ChatChip('think', 'I want to think something through'),
];

const coupleReasons = [
  ChatChip('argument', 'We had an argument'),
  ChatChip('misunderstood', 'We misunderstood each other'),
  ChatChip('off', 'Something feels off'),
  ChatChip('decision', 'We need to make a decision'),
  ChatChip('understand', 'I want us to understand each other better'),
  ChatChip('check_in', 'We want to check in on us'),
];

const talkGreeting =
    "Hi, I'm Therabot. This is your private space: nothing here goes to your partner.\n\nWhat would you like to talk about?";
const coupleGreeting =
    "Hi, I'm Therabot.\n\nWhat would you like to reflect on together?";
