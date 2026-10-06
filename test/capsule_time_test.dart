import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/models/activity.dart';
import 'package:final_project/models/love_note.dart';
import 'package:final_project/utils/capsule_time.dart';

void main() {
  final now = DateTime(2026, 9, 30, 10, 0);

  test('countdown text', () {
    expect(opensIn(now.add(const Duration(days: 42)), now: now), 'in 42 days');
    expect(opensIn(now.add(const Duration(hours: 27)), now: now), 'in 1 day 3h');
    expect(opensIn(now.add(const Duration(hours: 5, minutes: 20)), now: now), 'in 5h 20m');
    expect(opensIn(now.add(const Duration(minutes: 12)), now: now), 'in 12 min');
    expect(opensIn(now.add(const Duration(seconds: 20)), now: now), 'any moment now');
    expect(opensIn(now.subtract(const Duration(minutes: 1)), now: now), 'ready to open');
  });

  test('clock time', () {
    expect(clockTime(DateTime(2026, 1, 1, 8, 5)), '8:05 AM');
    expect(clockTime(DateTime(2026, 1, 1, 12, 0)), '12:00 PM');
    expect(clockTime(DateTime(2026, 1, 1, 0, 30)), '12:30 AM');
    expect(clockTime(DateTime(2026, 1, 1, 23, 45)), '11:45 PM');
  });

  test('presets are all in the future, at 8 AM', () {
    final presets = capsulePresets(now, anniversary: DateTime(2024, 2, 14));
    expect(presets.keys, contains('Our anniversary'));
    expect(presets['Our anniversary'], DateTime(2027, 2, 14, 8));
    expect(presets['Tomorrow morning'], DateTime(2026, 10, 1, 8));
    for (final t in presets.values) {
      expect(t.isAfter(now), isTrue);
      expect(t.hour, 8);
    }
  });

  test('no anniversary preset without an anniversary', () {
    expect(capsulePresets(now).keys, isNot(contains('Our anniversary')));
  });

  test('sealed capsule progress and readiness', () {
    final capsule = SealedNote(
      id: 'n1',
      authorId: 'u1',
      sentAt: DateTime(2026, 9, 1),
      unlockAt: DateTime(2026, 10, 1),
    );
    expect(capsule.isReady(now: DateTime(2026, 9, 16)), isFalse);
    expect(capsule.progress(now: DateTime(2026, 9, 16)), closeTo(0.5, 0.01));
    expect(capsule.isReady(now: DateTime(2026, 10, 1)), isTrue);
    expect(capsule.progress(now: DateTime(2026, 12, 1)), 1.0);
  });

  test('activity feed says when a capsule was sealed', () {
    Activity a(String? detail) => Activity(
        id: 'x', actorId: 'u', kind: 'note_sent', detail: detail, createdAt: now);
    expect(a('capsule').describe(name: 'Ana', isMe: false), 'Ana sealed a time capsule');
    expect(a(null).describe(name: 'Ana', isMe: false), 'Ana sent a love note');
  });
}
