import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/models/activity.dart';
import 'package:final_project/models/chat_message.dart';
import 'package:final_project/models/resolution_note.dart';

ChatMessage msg(String sender, DateTime at) =>
    ChatMessage(id: '$sender$at', senderId: sender, createdAt: at, body: 'hi');

void main() {
  final t = DateTime(2026, 10, 1, 20, 0);

  group('chat grouping', () {
    test('same sender within five minutes groups together', () {
      expect(sameGroup(msg('a', t), msg('a', t.add(const Duration(minutes: 3)))), isTrue);
    });
    test('a different sender or a long gap starts a new group', () {
      expect(sameGroup(msg('a', t), msg('b', t.add(const Duration(minutes: 1)))), isFalse);
      expect(sameGroup(msg('a', t), msg('a', t.add(const Duration(minutes: 9)))), isFalse);
    });
    test('never groups across midnight', () {
      final late = DateTime(2026, 10, 1, 23, 58);
      expect(sameGroup(msg('a', late), msg('a', late.add(const Duration(minutes: 3)))), isFalse);
    });
  });

  test('date separator labels', () {
    expect(dayLabel(t, now: t), 'Today');
    expect(dayLabel(t.subtract(const Duration(days: 1)), now: t), 'Yesterday');
    expect(dayLabel(DateTime(2026, 9, 28), now: t), 'Mon, 28 Sep');
    expect(dayLabel(DateTime(2025, 9, 28), now: t), 'Sun, 28 Sep 2025');
  });

  test('deleted and edited flags', () {
    final deleted = ChatMessage.fromMap({
      'id': '1', 'sender_id': 'a', 'body': null, 'photo_path': null,
      'created_at': '2026-10-01T12:00:00Z', 'edited_at': '2026-10-01T12:01:00Z',
      'deleted_at': '2026-10-01T12:02:00Z', 'read_at': null,
    });
    expect(deleted.isDeleted, isTrue);
    expect(deleted.isEdited, isFalse); // a deleted message no longer shows "edited"
  });

  test('the six reactions match the database list', () {
    expect(chatReactions, ['❤️', '😂', '😮', '😢', '🥰', '👍']);
  });

  test('resolution questions line up with the six columns', () {
    expect(resolutionQuestions.length, resolutionColumns.length);
    expect(resolutionColumns, [
      'what_happened', 'how_it_felt', 'what_we_need',
      'next_time', 'apology_or_clarify', 'reconnect',
    ]);
  });

  test('feed wording for affection and listening', () {
    Activity a(String d) => Activity(
        id: 'x', actorId: 'u', kind: 'affection_sent', detail: d, createdAt: t);
    expect(a('kiss').describe(name: 'Ana', isMe: false), 'Ana sent a kiss');
    expect(a('listen').describe(name: 'Ana', isMe: false), 'Ana wants to talk');
  });
}
