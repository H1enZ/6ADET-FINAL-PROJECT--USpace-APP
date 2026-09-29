/// Things that change every day on Home: the greeting, a romantic line and
/// Today's Question. Both partners see the same line and question on the
/// same day, because both are picked from the date, not at random.
/// Pure Dart, unit tested in test/daily_content_test.dart.

/// A whole-day number for [day] (its local date), so everything picked from
/// it stays the same all day and changes at midnight.
int dayNumber(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// "Good morning", "Good afternoon", "Good evening" or "Good night".
String greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 18) return 'Good afternoon';
  if (hour >= 18 && hour < 22) return 'Good evening';
  return 'Good night';
}

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December',
];

/// "Tuesday, 29 September"
String fullDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

const dailyLines = [
  'Two hearts, one little space of your own.',
  'Every ordinary day is better with you in it.',
  'Distance means so little when someone means so much.',
  'Small moments, shared, become the biggest memories.',
  'You are my favourite notification.',
  'Home is wherever we are together, even on a screen.',
  'Thank you for choosing each other again today.',
  'Love is in the little things. Notice one today.',
  'Some days are for big plans. Today can just be for us.',
  'The best is still ahead of you both.',
  'A kind word today can carry someone all week.',
  'You make the everyday feel like a story worth keeping.',
];

String dailyLine(DateTime day) => dailyLines[dayNumber(day) % dailyLines.length];

const dailyQuestions = [
  'What made you smile today?',
  'What is something I did recently that made you feel loved?',
  'Is there anything on your mind that you want to share with me?',
  'What is one thing you want us to experience together?',
  'What can I do to make your day better?',
  'What is one memory of us that you will never forget?',
  'What is something you wish we did more often?',
  'When do you feel most loved by me?',
  'What is a small thing I do that you secretly love?',
  'What song reminds you of us, and why?',
  'What is one thing you are proud of this week?',
  'Where would you take me if we could go anywhere tomorrow?',
  'What is something new you want to try together?',
  'What do you need more of from me lately?',
  'What was your first impression of me?',
  'What is one way I can support your goals?',
  'What does a perfect lazy day with me look like?',
  'What is something you have never told me?',
  'Which of our inside jokes is your favourite?',
  'What is one thing you want us to be like in five years?',
];

String questionFor(DateTime day) =>
    dailyQuestions[dayNumber(day) % dailyQuestions.length];

/// "just now", "5m ago", "3h ago", "yesterday", "4d ago", or a date.
String timeAgo(DateTime then, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(then);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${then.day} ${_months[then.month - 1].substring(0, 3)}';
}
