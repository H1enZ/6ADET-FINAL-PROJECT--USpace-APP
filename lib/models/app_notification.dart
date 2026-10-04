/// What a notification is about: its icon, colour and the screen it opens.
enum NotificationKind {
  memory,
  mood,
  loveNote,
  capsule,
  hug,
  date,
  anniversary,
  bucket,
  question,
  therabot,
}

/// Where tapping a notification goes.
enum NotificationTarget {
  memory, // the memory itself when found, else the Timeline tab
  timeline,
  moodHistory,
  loveNotes,
  timeCapsules,
  importantDates,
  bucketList,
  questions, // the archive of past answers
  answerQuestion, // today's question sheet, when your partner answered first
  therabot,
  chat, // "wants to talk"
  sendHugBack, // a hug, kiss or cuddle: offer to send one back
  countdown, // the anniversary: scroll Home to its countdown
  home, // nothing more to open
}

/// One entry on the Notifications screen. Built on the device from data the
/// app already reads (the activity feed, dates, notes, bucket list and the
/// current Therabot session); nothing new is stored in the database.
class AppNotification {
  const AppNotification({
    required this.key,
    required this.kind,
    required this.title,
    required this.body,
    required this.target,
    this.time,
    this.fromPartner = true,
    this.isReminder = false,
    this.targetId,
    this.targetHint,
    this.unread = false,
  });

  /// Stable identity, used for unread state (`activity:<id>`,
  /// `date:<id>:2026-10-10`, ...).
  final String key;
  final NotificationKind kind;
  final String title;
  final String body;

  /// When it happened. Null for current states with no event time
  /// (a reflection being ready).
  final DateTime? time;

  /// False for your own actions: listed, but never "new".
  final bool fromPartner;

  /// A reminder about now or the coming days (a date, a capsule that just
  /// opened, a Therabot step), shown above the timeline of events.
  final bool isReminder;

  final NotificationTarget target;

  /// An id for the target (a bucket item, a memory author) when useful.
  final String? targetId;

  /// Extra text for finding the target (a memory's caption).
  final String? targetHint;

  final bool unread;

  AppNotification withUnread(bool value) => AppNotification(
    key: key,
    kind: kind,
    title: title,
    body: body,
    target: target,
    time: time,
    fromPartner: fromPartner,
    isReminder: isReminder,
    targetId: targetId,
    targetHint: targetHint,
    unread: value,
  );
}
