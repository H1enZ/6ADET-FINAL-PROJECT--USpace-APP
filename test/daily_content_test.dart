import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/models/activity.dart';
import 'package:final_project/models/important_date.dart';
import 'package:final_project/models/mood.dart';
import 'package:final_project/utils/daily_content.dart';

void main() {
  group('daily content', () {
    test('greeting follows the time of day', () {
      expect(greetingFor(DateTime(2026, 9, 29, 7)), 'Good morning');
      expect(greetingFor(DateTime(2026, 9, 29, 13)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 9, 29, 19)), 'Good evening');
      expect(greetingFor(DateTime(2026, 9, 29, 23)), 'Good night');
      expect(greetingFor(DateTime(2026, 9, 29, 3)), 'Good night');
    });

    test('same question and line all day, a new one tomorrow', () {
      final morning = DateTime(2026, 9, 29, 6);
      final night = DateTime(2026, 9, 29, 23, 59);
      final tomorrow = DateTime(2026, 9, 30, 6);
      expect(questionFor(morning), questionFor(night));
      expect(dailyLine(morning), dailyLine(night));
      expect(questionFor(tomorrow), isNot(questionFor(morning)));
    });

    test('every question comes round within the list length', () {
      final start = DateTime(2026, 1, 1);
      final seen = {
        for (var i = 0; i < dailyQuestions.length; i++)
          questionFor(start.add(Duration(days: i))),
      };
      expect(seen.length, dailyQuestions.length);
    });

    test('full date and time ago', () {
      expect(fullDate(DateTime(2026, 9, 29)), 'Tuesday, 29 September');
      final now = DateTime(2026, 9, 29, 12);
      expect(timeAgo(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
      expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
      expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
      expect(timeAgo(now.subtract(const Duration(days: 1)), now: now), 'yesterday');
    });
  });

  group('moods', () {
    test('every mood name matches the database list', () {
      // The database check after migration 012.
      expect(Mood.values.map((m) => m.dbValue).toList(), [
        'loved', 'happy', 'calm', 'emotional', 'need_a_hug', 'flirty', 'romantic', 'excited',
        'relaxed', 'tired', 'stressed', 'sad', 'anxious', 'lonely', 'upset',
      ]);
      expect(Mood.selectableMoods.length, 8);
      expect(Mood.fromName('need_a_hug'), Mood.needAHug);
      expect(Mood.fromName('hangry'), isNull);
    });

    test('latest check-in of the day wins', () {
      final day = DateTime(2026, 9, 29);
      final entries = [
        MoodEntry(id: '1', userId: 'me', mood: Mood.tired, createdAt: day.add(const Duration(hours: 8))),
        MoodEntry(id: '2', userId: 'me', mood: Mood.happy, createdAt: day.add(const Duration(hours: 18))),
        MoodEntry(id: '3', userId: 'you', mood: Mood.loved, createdAt: day.add(const Duration(hours: 20))),
        MoodEntry(id: '4', userId: 'me', mood: Mood.sad, createdAt: day.subtract(const Duration(hours: 2))),
      ];
      expect(latestMoodOn(entries, 'me', day)!.mood, Mood.happy);
      expect(latestMoodOn(entries, 'you', day)!.mood, Mood.loved);
      expect(latestMoodOn(entries, 'you', day.subtract(const Duration(days: 1))), isNull);
    });
  });

  group('important dates', () {
    final today = DateTime(2026, 9, 29);

    test('a yearly date counts down to its next occurrence', () {
      final d = ImportantDate(id: '1', title: 'First date', eventDate: DateTime(2023, 10, 9));
      expect(d.daysUntil(today: today), 10);
    });

    test('a one-off date that has passed has no countdown', () {
      final trip = ImportantDate(
          id: '2', title: 'Trip', eventDate: DateTime(2026, 5, 1), repeatsYearly: false);
      expect(trip.daysUntil(today: today), isNull);
      final soon = ImportantDate(
          id: '3', title: 'Concert', eventDate: DateTime(2026, 10, 1), repeatsYearly: false);
      expect(soon.daysUntil(today: today), 2);
    });
  });

  group('activity feed text', () {
    Activity a(String kind, [String? detail]) => Activity(
        id: 'x', actorId: 'u', kind: kind, detail: detail, createdAt: DateTime(2026));

    test('reads naturally for you and your partner', () {
      expect(a('memory_added', 'Beach day').describe(name: 'Ana', isMe: false),
          'Ana added a memory: Beach day');
      expect(a('question_answered').describe(name: 'Ana', isMe: true),
          "You answered today's question");
      expect(a('mood_updated', 'loved').describe(name: 'Ana', isMe: false),
          'Ana is feeling loved');
      expect(a('affection_sent', 'hug').describe(name: 'Ben', isMe: false),
          'Ben sent a hug');
    });
  });
}
