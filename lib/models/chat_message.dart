/// One chat message. Mirrors a row in `messages`.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.createdAt,
    this.body,
    this.photoPath,
    this.photoUrl,
    this.editedAt,
    this.deletedAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String? body;
  final String? photoPath;
  final String? photoUrl; // signed link, not stored
  final DateTime createdAt; // local time
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final DateTime? readAt;

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null && !isDeleted;

  static DateTime? _time(Object? v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();

  factory ChatMessage.fromMap(Map<String, dynamic> row) => ChatMessage(
        id: row['id'] as String,
        senderId: row['sender_id'] as String,
        body: row['body'] as String?,
        photoPath: row['photo_path'] as String?,
        createdAt: _time(row['created_at'])!,
        editedAt: _time(row['edited_at']),
        deletedAt: _time(row['deleted_at']),
        readAt: _time(row['read_at']),
      );

  ChatMessage withPhotoUrl(String? url) => ChatMessage(
        id: id,
        senderId: senderId,
        body: body,
        photoPath: photoPath,
        photoUrl: url,
        createdAt: createdAt,
        editedAt: editedAt,
        deletedAt: deletedAt,
        readAt: readAt,
      );
}

/// The six reactions the database allows.
const chatReactions = ['❤️', '😂', '😮', '😢', '🥰', '👍'];

/// Whether two messages belong in one visual group: same sender, within
/// five minutes, same day. Grouped messages sit closer together.
bool sameGroup(ChatMessage a, ChatMessage b) =>
    a.senderId == b.senderId &&
    b.createdAt.difference(a.createdAt).inMinutes.abs() < 5 &&
    a.createdAt.day == b.createdAt.day &&
    a.createdAt.month == b.createdAt.month &&
    a.createdAt.year == b.createdAt.year;

/// "Today", "Yesterday", or "Mon, 29 Sep" for date separators.
String dayLabel(DateTime day, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final d = DateTime(day.year, day.month, day.day);
  final t = DateTime(today.year, today.month, today.day);
  final diff = t.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
    'Sep', 'Oct', 'Nov', 'Dec'];
  final label = '${weekdays[day.weekday - 1]}, ${day.day} ${months[day.month - 1]}';
  return day.year == today.year ? label : '$label ${day.year}';
}
