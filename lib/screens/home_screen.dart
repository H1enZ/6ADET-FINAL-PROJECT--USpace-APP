import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../models/activity.dart';
import '../models/couple.dart';
import '../models/important_date.dart';
import '../models/memory.dart';
import '../models/mood.dart';
import '../models/profile.dart';
import '../models/question_answer.dart';
import '../services/activity_service.dart';
import '../services/affection_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/couple_service.dart';
import '../services/dates_service.dart';
import '../services/memory_service.dart';
import '../services/mood_service.dart';
import '../services/profile_service.dart';
import '../services/question_service.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../utils/daily_content.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/effects/floating_hearts.dart';
import '../widgets/home/activity_feed.dart';
import '../widgets/home/home_card.dart';
import '../widgets/home/mood_card.dart';
import '../widgets/home/question_card.dart';
import '../widgets/home/quick_actions.dart';
import '../widgets/home/welcome_card.dart';
import '../widgets/molecules/countdown_card.dart';
import '../widgets/molecules/memory_card.dart';
import 'add_memory_sheet.dart';
import 'chat_screen.dart';
import 'important_dates_screen.dart';
import 'memory_detail_screen.dart';
import 'mood_history_screen.dart';
import 'mood_sheet.dart';
import 'question_archive_screen.dart';
import 'question_sheet.dart';
import 'work_it_out_screen.dart';
import 'write_note_sheet.dart';

/// Home: the couple's shared space. A greeting, today's mood and question,
/// countdowns, what you have both been up to, and quick shortcuts.
/// Updates live when your partner does something; pull down to refresh.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.profile, this.onOpenTab});

  final Profile profile;

  /// Switches the bottom tab (1 = Timeline), provided by MainShell.
  final ValueChanged<int>? onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Couple? _couple;
  List<Profile> _members = [];
  Memory? _latest;
  List<MoodEntry> _moods = [];
  List<QuestionAnswer> _answers = [];
  bool _partnerAnswered = false;
  List<ImportantDate> _dates = [];
  List<Activity> _activities = [];
  List<Map<String, dynamic>> _unseen = [];
  int _unread = 0;
  bool _loading = true;
  bool _busy = false;
  bool _celebrated = false;
  String? _error;
  RealtimeChannel? _live;

  String get _coupleId => widget.profile.coupleId!;
  String get _myId => widget.profile.userId;
  DateTime get _today => DateTime.now();

  Profile get _me {
    for (final m in _members) {
      if (m.userId == _myId) return m;
    }
    return widget.profile;
  }

  Profile? get _partner {
    for (final m in _members) {
      if (m.userId != _myId) return m;
    }
    return null;
  }

  String get _partnerName => _partner?.displayName ?? 'your partner';

  @override
  void initState() {
    super.initState();
    _load();
    try {
      _live = ActivityService.listen(_coupleId, () {
        if (mounted) _load();
      });
    } catch (_) {
      // Live updates are a bonus; pull to refresh still works.
    }
  }

  @override
  void dispose() {
    final live = _live;
    if (live != null) ActivityService.stopListening(live);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final today = _today;
      final couple = await CoupleService.couple(_coupleId);
      final members =
          await ProfileService.withPhotos(await CoupleService.members(_coupleId));
      final latest = await MemoryService.list(_coupleId, limit: 1);
      final moods = await MoodService.recent(_coupleId, days: 8);
      final answers = await QuestionService.answersFor(_coupleId, today);
      final dates = await DatesService.list(_coupleId);
      final activities = await ActivityService.recent(_coupleId);
      final unseen = await AffectionService.unseenFromPartner(_coupleId, _myId);

      String? partnerId;
      for (final m in members) {
        if (m.userId != _myId) partnerId = m.userId;
      }
      final partnerAnswered = partnerId == null
          ? false
          : await QuestionService.partnerAnswered(_coupleId, partnerId, today);
      int unread = 0;
      try {
        unread = partnerId == null ? 0 : await ChatService.unreadCount(_coupleId);
      } catch (_) {
        // the badge is a bonus; Home still loads without it
      }

      if (!mounted) return;
      final newAffection = unseen.length > _unseen.length;
      setState(() {
        _couple = couple;
        _members = members;
        _latest = latest.isEmpty ? null : latest.first;
        _moods = moods;
        _answers = answers;
        _dates = dates;
        _activities = activities;
        _unseen = unseen;
        _partnerAnswered = partnerAnswered;
        _unread = unread;
        _error = null;
        _loading = false;
      });
      if (newAffection) showFloatingHearts(context, emoji: '💗');
      _celebrateIfToday();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  /// A little celebration on your anniversary (once per visit).
  void _celebrateIfToday() {
    final date = _couple?.anniversaryDate;
    if (_celebrated || date == null) return;
    final info = AnniversaryInfo.from(date);
    if (info.isToday && info.yearsAtNext > 0) {
      _celebrated = true;
      showFloatingHearts(context);
    }
  }

  void _showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  // ---------------------------------------------------------------- actions

  Future<bool?> _sheet(Widget child) => showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => child,
      );

  Future<void> _addMemory() async {
    final saved = await _sheet(AddMemorySheet(coupleId: _coupleId));
    if (saved != true) return;
    await _load();
    if (!mounted) return;
    _showMessage('Memory saved');
  }

  Future<void> _checkMood() async {
    final current = latestMoodOn(_moods, _myId, _today)?.mood;
    final saved = await _sheet(MoodSheet(
      coupleId: _coupleId,
      partnerName: _partnerName,
      current: current,
    ));
    if (saved != true) return;
    await _load();
    if (!mounted) return;
    _showMessage('Mood saved');
  }

  Future<void> _answerQuestion() async {
    String? mine;
    for (final a in _answers) {
      if (a.userId == _myId) mine = a.answer;
    }
    final saved = await _sheet(QuestionSheet(
      coupleId: _coupleId,
      day: _today,
      question: questionFor(_today),
      currentAnswer: mine,
    ));
    if (saved != true) return;
    await _load();
    if (!mounted) return;
    showFloatingHearts(context, emoji: '💌');
    _showMessage('Answer saved');
  }

  Future<void> _writeNote({bool sealed = false}) async {
    if (_partner == null) return;
    final sent = await _sheet(WriteNoteSheet(
      coupleId: _coupleId,
      partnerName: _partnerName,
      anniversary: _couple?.anniversaryDate,
      startSealed: sealed,
    ));
    if (sent != true) return;
    await _load();
    if (!mounted) return;
    showFloatingHearts(context, emoji: sealed ? '🔒' : '💌');
    _showMessage(sealed ? 'Time capsule sealed 🔒' : 'Love note sent to $_partnerName 💌');
  }

  Future<void> _openChat() async {
    final partner = _partner;
    if (partner == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChatScreen(coupleId: _coupleId, me: _me, partner: partner),
    ));
    await _load(); // clears the unread badge
  }

  Future<void> _openWorkItOut() async {
    if (_partner == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => WorkItOutScreen(
        coupleId: _coupleId,
        myUserId: _myId,
        partnerName: _partnerName,
      ),
    ));
    await _load();
  }

  Future<void> _sendHug() async {
    if (_partner == null || _busy) return;
    setState(() => _busy = true);
    try {
      await AffectionService.send(coupleId: _coupleId, kind: 'hug');
      if (!mounted) return;
      showFloatingHearts(context, emoji: '🫂');
      _showMessage('Hug sent to $_partnerName 🫂');
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismissAffection() async {
    try {
      await AffectionService.markSeen();
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    }
  }

  Future<void> _sendBack() async {
    await _sendHug();
    await _dismissAffection();
  }

  Future<void> _push(Widget screen, {bool reload = false}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => screen),
    );
    if (reload || changed == true) await _load();
  }

  String _authorName(Memory m) {
    if (m.authorId == _myId) return 'you';
    return _partner?.displayName ?? 'your partner';
  }

  Future<void> _openLatest(Memory memory) => _push(
        MemoryDetailScreen(
          memory: memory,
          authorName: _authorName(memory),
          isMine: memory.authorId == _myId,
        ),
      );

  Future<void> _setAnniversary() async {
    final couple = _couple;
    if (couple == null) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: couple.anniversaryDate ?? now,
      firstDate: DateTime(1970),
      lastDate: now,
      helpText: 'The day you got together',
    );
    if (picked == null) return;
    try {
      await CoupleService.setAnniversary(couple.id, picked);
      await _load();
      if (!mounted) return;
      _showMessage('Anniversary saved');
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted =
        theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final couple = _couple;
    final partner = _partner;
    final today = _today;
    String? myAnswer;
    String? partnerAnswer;
    for (final a in _answers) {
      if (a.userId == _myId) {
        myAnswer = a.answer;
      } else {
        partnerAnswer = a.answer;
      }
    }
    final upcoming = _dates.where((d) => d.daysUntil() != null).take(3).toList();
    final names = {for (final m in _members) m.userId: m.displayName};
    const gap = SizedBox(height: AppSpacing.lg);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: _unread > 0 ? 'Chat ($_unread unread)' : 'Chat',
            onPressed: partner == null ? null : _openChat,
            icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text(_unread > 99 ? '99+' : '$_unread'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Text(_error!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: scheme.error)),
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AppButton(
                          label: 'Try again',
                          variant: AppButtonVariant.outlined,
                          onPressed: _load,
                        ),
                      ),
                      gap,
                    ],
                    if (couple != null) ...[
                      // A. Welcome
                      WelcomeCard(
                        me: _me,
                        partner: partner,
                        now: today,
                        unseenAffection: _unseen,
                        onSendBack: _sendBack,
                        onDismissAffection: _dismissAffection,
                      ),
                      gap,
                      if (partner == null) ...[
                        _InviteBanner(code: couple.pairingCode),
                        gap,
                      ],

                      // F. Quick actions
                      QuickActions(actions: [
                        QuickAction('Add a memory',
                            Icons.add_photo_alternate_outlined, _addMemory),
                        QuickAction('Chat', Icons.chat_bubble_outline,
                            partner == null ? null : _openChat),
                        QuickAction("Let's work it out", Icons.handshake_outlined,
                            partner == null ? null : _openWorkItOut),
                        QuickAction('Our timeline', Icons.photo_library_outlined,
                            widget.onOpenTab == null
                                ? null
                                : () => widget.onOpenTab!(1)),
                        QuickAction("Today's mood", Icons.mood, _checkMood),
                        QuickAction('Daily question', Icons.forum_outlined,
                            _answerQuestion),
                        QuickAction('Special dates', Icons.event_outlined,
                            () => _push(
                                ImportantDatesScreen(coupleId: _coupleId))),
                        QuickAction('Send a hug', Icons.volunteer_activism_outlined,
                            partner == null ? null : _sendHug),
                        QuickAction('Love note', Icons.mail_outline,
                            partner == null ? null : _writeNote),
                        QuickAction('Time capsule', Icons.lock_clock_outlined,
                            partner == null ? null : () => _writeNote(sealed: true)),
                      ]),
                      gap,

                      // B. Mood
                      MoodCard(
                        entries: _moods,
                        myUserId: _myId,
                        partnerId: partner?.userId,
                        partnerName: _partnerName,
                        today: today,
                        onCheckIn: _checkMood,
                        onHistory: () => _push(MoodHistoryScreen(
                          coupleId: _coupleId,
                          myUserId: _myId,
                          partnerId: partner?.userId,
                          partnerName: _partnerName,
                        )),
                      ),
                      gap,

                      // C. Daily question
                      QuestionCard(
                        question: questionFor(today),
                        myAnswer: myAnswer,
                        partnerAnswer: partnerAnswer,
                        partnerAnswered: _partnerAnswered,
                        partnerName: _partnerName,
                        hasPartner: partner != null,
                        onAnswer: _answerQuestion,
                        onArchive: () => _push(QuestionArchiveScreen(
                          coupleId: _coupleId,
                          myUserId: _myId,
                          partnerName: _partnerName,
                        )),
                      ),
                      gap,

                      // D. Countdowns
                      CountdownCard(
                        anniversary: couple.anniversaryDate,
                        onTap: _setAnniversary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      HomeCard(
                        title: 'Countdowns',
                        actionLabel: 'Manage',
                        onAction: () =>
                            _push(ImportantDatesScreen(coupleId: _coupleId)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final d in upcoming)
                              _CountdownRow(
                                emoji: '📅',
                                title: d.title,
                                days: d.daysUntil()!,
                                date: d.nextOccurrence()!,
                              ),
                            for (final m in _members)
                              if (m.birthday != null)
                                _CountdownRow(
                                  emoji: '🎂',
                                  title: m.userId == _myId
                                      ? 'Your birthday'
                                      : "${m.displayName}'s birthday",
                                  days: AnniversaryInfo.from(m.birthday!)
                                      .daysUntilNext,
                                  date: AnniversaryInfo.from(m.birthday!).nextDate,
                                ),
                            if (upcoming.isEmpty &&
                                !_members.any((m) => m.birthday != null))
                              Text(
                                'Save your first date, a monthsary or a trip, '
                                'and it will count down here.',
                                style: muted,
                              ),
                          ],
                        ),
                      ),
                      gap,

                      // E. Recent activity
                      ActivityFeed(
                        activities: _activities,
                        myUserId: _myId,
                        names: names,
                      ),
                      gap,

                      // Latest memory
                      HomeCard(
                        title: 'Latest memory',
                        actionLabel: widget.onOpenTab == null ? null : 'Timeline',
                        onAction: widget.onOpenTab == null
                            ? null
                            : () => widget.onOpenTab!(1),
                        child: _latest == null
                            ? Text('No memories yet. Add your first one above.',
                                style: muted)
                            : MemoryCard(
                                memory: _latest!,
                                authorName: _authorName(_latest!),
                                onTap: () => _openLatest(_latest!),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownRow extends StatelessWidget {
  const _CountdownRow({
    required this.emoji,
    required this.title,
    required this.days,
    required this.date,
  });

  final String emoji;
  final String title;
  final int days;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final when = days == 0
        ? 'Today! 🎉'
        : days == 1
            ? 'Tomorrow'
            : 'in $days days';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(when,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: scheme.primary)),
              Text(shortDate(date),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown until the partner joins: the code, with a copy button.
class _InviteBanner extends StatelessWidget {
  const _InviteBanner({required this.code});

  final String code;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Code copied')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Waiting for your partner',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: scheme.onPrimaryContainer)),
          const SizedBox(height: AppSpacing.xs),
          Text('Send them this code so they can join. Pull down to refresh '
              'once they have.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onPrimaryContainer)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  code,
                  style: theme.textTheme.titleLarge?.copyWith(
                    letterSpacing: 6,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy code',
                icon: const Icon(Icons.copy_rounded),
                color: scheme.onPrimaryContainer,
                onPressed: () => _copy(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
