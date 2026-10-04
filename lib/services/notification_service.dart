import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity.dart';
import '../models/app_notification.dart';
import '../models/important_date.dart';
import '../models/mood.dart';
import '../models/therabot.dart';
import '../models/time_capsule.dart';
import '../utils/anniversary.dart';
import 'activity_service.dart';
import 'bucket_service.dart';
import 'dates_service.dart';
import 'note_service.dart';
import 'therabot_service.dart';
import 'time_capsule_service.dart';

/// Notifications, built on the device from data the app already reads.
/// Nothing is written to the database: what you have seen is remembered
/// per person on this device (shared_preferences).
///
/// Unread rules:
///   * events (memories, moods, notes, hugs, ...) are new when your partner
///     did them after the moment your last Notifications list was loaded;
///   * reminders (a date coming up, a capsule that opened, a Therabot step)
///     have no event time, so each has a stable key and is new until you
///     have seen that exact key once. A date's key changes when it reaches
///     "today", so the day itself is new again.
///   * your own actions are listed but never new.
class NotificationService {
  NotificationService._();

  /// Reminders look this far ahead; events this far back.
  static const reminderDays = 7;
  static const historyDays = 30;

  // ------------------------------------------------------------------ load

  /// Everything for the Notifications screen with unread set: reminders
  /// first (soonest first), then events (newest first).
  ///
  /// [activities] and [dates] are passed in when the caller already has
  /// them (Home), to avoid fetching them twice. [answeredToday] says whether
  /// you have answered today's question (it changes where that item goes).
  static Future<List<AppNotification>> load({
    required String coupleId,
    required String myId,
    required String partnerName,
    required bool answeredToday,
    DateTime? anniversary,
    List<Activity>? activities,
    List<ImportantDate>? dates,
  }) async {
    final now = DateTime.now();
    // Each source is optional: if one fails, the rest still show.
    Future<T?> safe<T>(Future<T> Function() f) async {
      try {
        return await f();
      } catch (_) {
        return null;
      }
    }

    final since = now.subtract(const Duration(days: historyDays));
    final results = await Future.wait([
      activities != null
          ? Future.value(activities)
          : safe(() => ActivityService.recent(coupleId, limit: 40)),
      safe(() => BucketService.completedSince(coupleId, since)),
      safe(
        () => NoteService.openedCapsules(
          coupleId,
          now.subtract(const Duration(days: reminderDays)),
          now,
        ),
      ),
      safe(() => TherabotService.current()),
      dates != null
          ? Future.value(dates)
          : safe(() => DatesService.list(coupleId)),
      safe(() async {
        await TimeCapsuleService.syncClock();
        return TimeCapsuleService.list(coupleId);
      }),
    ]);
    final acts = (results[0] as List<Activity>?) ?? const <Activity>[];
    final done =
        (results[1]
            as List<({String id, String title, DateTime completedAt})>?) ??
        const [];
    final capsules =
        (results[2]
            as List<
              ({String id, String authorId, DateTime openedAt, String? title})
            >?) ??
        const [];
    final session = results[3] as TherabotSession?;
    final allDates = (results[4] as List<ImportantDate>?) ?? const [];
    final timeCapsules = (results[5] as List<TimeCapsule>?) ?? const [];

    final reminders = <AppNotification>[
      ..._fromCapsules(capsules, myId, partnerName),
      ..._fromReadyCapsules(timeCapsules, myId, partnerName),
      ..._fromDates(allDates, now),
      ?_fromAnniversary(anniversary, now),
      ?_fromTherabot(session, partnerName),
    ];
    final events = <AppNotification>[
      ..._fromActivities(acts, myId, partnerName, answeredToday, now),
      ..._fromBucket(done),
    ];
    // Reminders: soonest first. Events: newest first. Missing times last.
    int byTime(
      AppNotification a,
      AppNotification b, {
      required bool ascending,
    }) {
      final ta = a.time, tb = b.time;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return ascending ? ta.compareTo(tb) : tb.compareTo(ta);
    }

    reminders.sort((a, b) => byTime(a, b, ascending: true));
    events.sort((a, b) => byTime(a, b, ascending: false));
    return markUnread([...reminders, ...events], myId);
  }

  // ------------------------------------------------------------ read state

  static String _lastSeenKey(String myId) => 'notifications.lastSeen.$myId';
  static String _seenKeysKey(String myId) => 'notifications.seenKeys.$myId';
  static const _maxSeenKeys = 300;

  /// Sets [AppNotification.unread] from this person's saved read state.
  static Future<List<AppNotification>> markUnread(
    List<AppNotification> items,
    String myId,
  ) async {
    DateTime? lastSeen;
    Set<String> seen = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_lastSeenKey(myId));
      lastSeen = raw == null ? null : DateTime.tryParse(raw);
      seen = (prefs.getStringList(_seenKeysKey(myId)) ?? const []).toSet();
    } catch (_) {
      // Storage unavailable: everything recent from your partner is new.
    }
    final floor =
        lastSeen ?? DateTime.now().subtract(const Duration(days: reminderDays));
    return [
      for (final n in items)
        n.withUnread(
          n.fromPartner &&
              (n.isReminder
                  ? !seen.contains(n.key)
                  : (n.time != null && n.time!.isAfter(floor))),
        ),
    ];
  }

  /// How many items are new: the bell's count.
  static int unreadCount(List<AppNotification> items) =>
      items.where((n) => n.unread).length;

  /// Remembers that [items] have been seen. [loadedAt] is when that list was
  /// fetched: events after it (e.g. arriving while the screen was opening)
  /// stay new. Never moves backwards.
  static Future<void> markAllSeen(
    List<AppNotification> items,
    String myId, {
    required DateTime loadedAt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final previous = DateTime.tryParse(
        prefs.getString(_lastSeenKey(myId)) ?? '',
      );
      if (previous == null || loadedAt.isAfter(previous)) {
        await prefs.setString(_lastSeenKey(myId), loadedAt.toIso8601String());
      }
      final keys = [
        ...?prefs.getStringList(_seenKeysKey(myId)),
        for (final n in items)
          if (n.isReminder) n.key,
      ];
      // Keep the newest few hundred; old keys are for past dates anyway.
      final unique = keys.toSet().toList();
      await prefs.setStringList(
        _seenKeysKey(myId),
        unique.length > _maxSeenKeys
            ? unique.sublist(unique.length - _maxSeenKeys)
            : unique,
      );
    } catch (_) {
      // Not remembered this time; nothing else depends on it.
    }
  }

  // ------------------------------------------------------------ assembling

  /// "is feeling loved", "needs a hug": natural wording for each mood.
  static String _moodPhrase(Mood m, {required bool you}) => switch (m) {
    Mood.needAHug => you ? 'need a hug' : 'needs a hug',
    _ => '${you ? 'are' : 'is'} feeling ${m.label.toLowerCase()}',
  };

  static Iterable<AppNotification> _fromActivities(
    List<Activity> acts,
    String myId,
    String partner,
    bool answeredToday,
    DateTime now,
  ) sync* {
    final since = now.subtract(const Duration(days: historyDays));
    final today = DateTime(now.year, now.month, now.day);
    for (final a in acts) {
      if (a.createdAt.isBefore(since)) continue;
      final mine = a.actorId == myId;
      final d = a.detail;
      final answerNow = !mine && !answeredToday && !a.createdAt.isBefore(today);
      final (kind, title, body, target) = switch (a.kind) {
        'memory_added' => (
          NotificationKind.memory,
          mine ? 'You added a memory' : '$partner added a memory',
          d ?? 'A new moment on your timeline.',
          NotificationTarget.memory,
        ),
        'mood_updated' => (
          NotificationKind.mood,
          mine ? 'You shared your mood' : '$partner shared their mood',
          switch (Mood.fromName(d)) {
            final m? =>
              mine
                  ? 'You ${_moodPhrase(m, you: true)}.'
                  : '$partner ${_moodPhrase(m, you: false)}.',
            null => 'A new mood check-in.',
          },
          NotificationTarget.moodHistory,
        ),
        // Time Capsule events carry only the capsule's id, never its text.
        'capsule_opened' => (
          NotificationKind.capsule,
          mine ? 'You opened a time capsule' : 'Your Time Capsule was opened',
          mine ? 'Reply whenever you are ready.' : 'You can read it together now.',
          NotificationTarget.timeCapsules,
        ),
        'capsule_replied' => (
          NotificationKind.capsule,
          mine
              ? 'You replied to a time capsule'
              : 'Your partner replied to your Time Capsule',
          mine ? 'Waiting for their answer.' : 'Read it and answer once.',
          NotificationTarget.timeCapsules,
        ),
        'capsule_responded' => (
          NotificationKind.capsule,
          mine
              ? 'You answered their reply'
              : 'Your partner replied to your Time Capsule response',
          'You both replied.',
          NotificationTarget.timeCapsules,
        ),
        'note_sent' when d == 'capsule' => (
          NotificationKind.capsule,
          mine ? 'You sealed a time capsule' : '$partner sealed a time capsule',
          "It opens when it's time.",
          NotificationTarget.loveNotes,
        ),
        'note_sent' => (
          NotificationKind.loveNote,
          mine ? 'You sent a love note' : '$partner sent you a love note',
          mine ? 'Waiting to be read.' : 'Open it in Love Notes.',
          NotificationTarget.loveNotes,
        ),
        'affection_sent' when d == 'listen' => (
          NotificationKind.hug,
          mine ? 'You asked to talk' : '$partner wants to talk',
          mine ? 'They know you want to talk.' : 'Open your chat when you can.',
          mine ? NotificationTarget.home : NotificationTarget.chat,
        ),
        'affection_sent' => (
          NotificationKind.hug,
          switch (d) {
            'kiss' => mine ? 'You sent a kiss' : '$partner sent you a kiss',
            'cuddle' =>
              mine ? 'You sent a cuddle' : '$partner sent you a cuddle',
            'comfort' =>
              mine ? 'You sent comfort' : '$partner sent you comfort',
            _ => mine ? 'You sent a hug' : '$partner sent you a hug',
          },
          mine ? 'Sent with love.' : 'Tap to send one back.',
          mine ? NotificationTarget.home : NotificationTarget.sendHugBack,
        ),
        'date_added' => (
          NotificationKind.date,
          mine ? 'You saved a special date' : '$partner saved a special date',
          d ?? 'A new day to look forward to.',
          NotificationTarget.importantDates,
        ),
        'bucket_added' => (
          NotificationKind.bucket,
          mine
              ? 'You added to the bucket list'
              : '$partner added to the bucket list',
          d ?? 'Something new to do together.',
          NotificationTarget.bucketList,
        ),
        'question_answered' => (
          NotificationKind.question,
          mine
              ? "You answered the day's question"
              : "$partner answered the day's question",
          answerNow
              ? "Answer today's question to see theirs."
              : 'See both answers in Our questions.',
          answerNow
              ? NotificationTarget.answerQuestion
              : NotificationTarget.questions,
        ),
        _ => (
          NotificationKind.memory,
          mine ? 'You shared something' : '$partner shared something',
          'Have a look around Home.',
          NotificationTarget.home,
        ),
      };
      yield AppNotification(
        key: 'activity:${a.id}',
        kind: kind,
        title: title,
        body: body,
        time: a.createdAt,
        fromPartner: !mine,
        target: target,
        targetId: a.actorId,
        targetHint: a.kind == 'memory_added' ? d : null,
      );
    }
  }

  /// Bucket items ticked off recently. The database doesn't record who
  /// ticked them, so these are listed for both of you but never "new":
  /// otherwise your own tick would light up your own bell.
  static Iterable<AppNotification> _fromBucket(
    List<({String id, String title, DateTime completedAt})> done,
  ) sync* {
    for (final b in done) {
      yield AppNotification(
        key: 'bucket-done:${b.id}',
        kind: NotificationKind.bucket,
        title: 'Done: ${b.title}',
        body: 'Ticked off your bucket list.',
        time: b.completedAt,
        fromPartner: false,
        target: NotificationTarget.bucketList,
        targetId: b.id,
      );
    }
  }

  /// A capsule from your partner that opened in the last week.
  static Iterable<AppNotification> _fromCapsules(
    List<({String id, String authorId, DateTime openedAt, String? title})>
    capsules,
    String myId,
    String partner,
  ) sync* {
    for (final c in capsules) {
      if (c.authorId == myId) continue;
      yield AppNotification(
        key: 'capsule-open:${c.id}',
        kind: NotificationKind.capsule,
        title: 'A time capsule from $partner opened',
        body: c.title ?? 'Read it in Love Notes.',
        time: c.openedAt,
        isReminder: true,
        target: NotificationTarget.loveNotes,
      );
    }
  }

  /// A Time Capsule from your partner whose moment has come and that you
  /// haven't opened. Only for the receiver: the sender gets no reminder.
  /// Safe details only (who), never the title or letter.
  static Iterable<AppNotification> _fromReadyCapsules(
    List<TimeCapsule> capsules,
    String myId,
    String partner,
  ) sync* {
    final now = TimeCapsuleService.now();
    for (final c in capsules) {
      if (c.receiverId != myId || !c.isReady(now)) continue;
      yield AppNotification(
        key: 'time-capsule-ready:${c.id}',
        kind: NotificationKind.capsule,
        title: 'A time capsule from $partner is ready',
        body: 'Open it whenever you are ready.',
        time: c.readySince,
        isReminder: true,
        target: NotificationTarget.timeCapsules,
        targetId: c.id,
      );
    }
  }

  static Iterable<AppNotification> _fromDates(
    List<ImportantDate> dates,
    DateTime now,
  ) sync* {
    for (final d in dates) {
      final days = d.daysUntil(today: now);
      final next = d.nextOccurrence(today: now);
      if (days == null || next == null || days > reminderDays) continue;
      yield AppNotification(
        // "soon" then "today": the day itself is new again.
        key: 'date:${d.id}:${_day(next)}:${days == 0 ? 'today' : 'soon'}',
        kind: NotificationKind.date,
        title: d.title,
        body: _inDays(days),
        time: next,
        isReminder: true,
        target: NotificationTarget.importantDates,
      );
    }
  }

  static AppNotification? _fromAnniversary(DateTime? date, DateTime now) {
    if (date == null) return null;
    final info = AnniversaryInfo.from(date, today: now);
    if (info.daysUntilNext > reminderDays) return null;
    return AppNotification(
      key:
          'anniversary:${_day(info.nextDate)}:${info.isToday ? 'today' : 'soon'}',
      kind: NotificationKind.anniversary,
      title: info.isToday ? 'Happy anniversary!' : 'Your anniversary is coming',
      body: info.isToday
          ? 'Celebrate the two of you today'
          : _inDays(info.daysUntilNext),
      time: info.nextDate,
      isReminder: true,
      target: NotificationTarget.countdown,
    );
  }

  /// The one Therabot step that needs you, if any. Never the content.
  static AppNotification? _fromTherabot(TherabotSession? s, String partner) {
    if (s == null || !s.isOpen) return null;
    AppNotification make(String step, String title, String body) =>
        AppNotification(
          key: 'therabot:${s.id}:$step',
          kind: NotificationKind.therabot,
          title: title,
          body: body,
          time: s.createdAt,
          isReminder: true,
          target: NotificationTarget.therabot,
        );
    if (s.status == TherabotStatus.reflectionReady) {
      if (s.partnerChoice != null && s.myChoice == null) {
        return make(
          'partner-chose',
          '$partner chose a next step',
          "Choose yours when you're ready.",
        );
      }
      return make(
        'ready',
        'Your shared reflection is ready',
        'Read it together in Therabot.',
      );
    }
    if (s.status == TherabotStatus.collecting &&
        s.myProgress != TherabotProgress.approved) {
      if (s.partnerProgress == TherabotProgress.approved) {
        return make(
          'partner-approved',
          '$partner shared their side',
          "Add yours whenever you're ready.",
        );
      }
      if (!s.iStarted) {
        return make(
          'started',
          '$partner started a reflection',
          "Join whenever you're ready. There's no rush.",
        );
      }
    }
    return null;
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _inDays(int days) => switch (days) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => 'In $days days',
  };
}
