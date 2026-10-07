import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../models/activity.dart';
import '../models/app_notification.dart';
import '../models/couple.dart';
import '../models/important_date.dart';
import '../models/mood.dart';
import '../models/profile.dart';
import '../models/question_answer.dart';
import '../services/activity_service.dart';
import '../services/affection_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/couple_service.dart';
import '../services/couple_sync.dart';
import '../services/dates_service.dart';
import '../services/memory_service.dart';
import '../services/mood_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../services/question_service.dart';
import '../theme/app_effects.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../utils/daily_content.dart';
import '../utils/special_events.dart';
import '../widgets/atoms/header_icon_button.dart';
import '../widgets/effects/floating_hearts.dart';
import '../widgets/effects/motion.dart';
import '../widgets/home/therabot_card.dart';
import '../widgets/home/mood_card.dart';
import '../widgets/home/quick_actions.dart';
import '../widgets/molecules/special_event_card.dart';
import 'add_memory_sheet.dart';
import 'bucket_list_screen.dart';
import 'therabot/therabot_tab.dart';
import 'important_dates_screen.dart';
import 'memory_detail_screen.dart';
import 'mood_history_screen.dart';
import 'mood_sheet.dart';
import 'notifications_screen.dart';
import 'question_archive_screen.dart';
import 'question_sheet.dart';
import 'time_capsules/time_capsule_screen.dart';
import '../widgets/effects/smooth_scroll.dart';
import '../widgets/atoms/us_icon.dart';
import '../widgets/molecules/us_states.dart';

/// Home: how you are feeling today, front and centre, then shortcuts and
/// the next special day. Recent activity lives behind the bell.
/// Updates live when your partner does something; pull down to refresh.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    this.onOpenTab,
    this.refresh,
    this.onUnreadChanged,
  });

  final Profile profile;

  /// Switches the bottom tab (1 Chat, 2 Timeline, 3 Love Notes), so a
  /// notification or a shortcut can open the right place. From MainShell.
  final ValueChanged<int>? onOpenTab;

  /// Bumped by MainShell when you leave Chat, so Home recounts unread.
  final ValueListenable<int>? refresh;

  /// Unread chat messages, for the badge on the Chat tab.
  final ValueChanged<int>? onUnreadChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Mouse-wheel scrolling glides instead of jumping.
  final _scroll = SmoothScrollController();

  Couple? _couple;
  List<Profile> _members = [];
  List<MoodEntry> _moods = [];
  List<QuestionAnswer> _answers = [];
  List<ImportantDate> _dates = [];
  bool _partnerAnswered = false;

  /// New notifications: the bell's count.
  int _newNotifications = 0;
  bool _loading = true;
  bool _busy = false;
  bool _celebrated = false;
  String? _error;
  CoupleSyncHandle? _live;
  int _loadGeneration = 0;

  /// A mood you just tapped, shown straight away while it saves. Cleared
  /// when the save finishes (it is then today's saved mood) or fails (the
  /// card falls back to the previous mood).
  Mood? _pending;
  bool _savingMood = false;

  /// On the anniversary countdown, so a notification can scroll to it.
  final _countdownKey = GlobalKey();

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

  /// Today's saved mood, from the database.
  Mood? get _savedMood => latestMoodOn(_moods, _myId, _today)?.mood;

  /// The newest note someone shared today, even if they changed their
  /// mood after writing it.
  String? _noteToday(String userId) {
    final note = latestMoodOn(_moods, userId, _today)?.note?.trim() ?? '';
    return note.isEmpty ? null : note;
  }

  @override
  void initState() {
    super.initState();
    widget.refresh?.addListener(_load);
    _load();
    try {
      // Every shared action writes an activity row (a memory, mood, note,
      // answer, goal or date), so that alone covers most of Home. Names,
      // photos, the anniversary and edited or removed dates don't, so
      // those tables are listened to directly. One action can write
      // several rows: CoupleSync waits for the burst, then reloads once.
      _live = CoupleSync.listen(
        _coupleId,
        const {
          'activities',
          'affections',
          'profiles',
          'couples',
          'important_dates',
        },
        () {
          if (mounted) _load();
        },
        settle: const Duration(milliseconds: 300),
      );
    } catch (_) {
      // Live updates are a bonus; pull to refresh still works.
    }
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_load);
    _scroll.dispose();
    _live?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    // Loads can overlap (live update + pull to refresh + after an action).
    // Only the newest one may update the screen.
    final generation = ++_loadGeneration;
    try {
      final today = _today;
      // Wave 1: everything that doesn't depend on anything else, at once.
      final first = await Future.wait<Object?>([
        CoupleService.couple(_coupleId),
        CoupleService.members(_coupleId).then(ProfileService.withPhotos),
        MoodService.recent(_coupleId, days: 8),
        QuestionService.answersFor(_coupleId, today),
        DatesService.list(_coupleId),
        ActivityService.recent(_coupleId, limit: 40),
      ]);
      final couple = first[0] as Couple?;
      final members = first[1] as List<Profile>;
      final moods = first[2] as List<MoodEntry>;
      final answers = first[3] as List<QuestionAnswer>;
      final dates = first[4] as List<ImportantDate>;
      final activities = first[5] as List<Activity>;

      String? partnerId;
      for (final m in members) {
        if (m.userId != _myId) partnerId = m.userId;
      }

      // Wave 2: needs the partner. The badge and the bell's count are a
      // bonus: if either fails, Home still loads without it.
      Future<int> orZero(Future<int> Function() f) async {
        try {
          return await f();
        } catch (_) {
          return 0;
        }
      }

      final second = await Future.wait<Object>([
        partnerId == null
            ? Future.value(false)
            : QuestionService.partnerAnswered(_coupleId, partnerId, today),
        orZero(
          () async =>
              partnerId == null ? 0 : await ChatService.unreadCount(_coupleId),
        ),
        orZero(
          () async => NotificationService.unreadCount(
            await _loadNotifications(
              couple: couple,
              members: members,
              answers: answers,
              activities: activities,
              dates: dates,
            ),
          ),
        ),
      ]);
      final partnerAnswered = second[0] as bool;
      final unread = second[1] as int;
      final newNotifications = second[2] as int;

      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _couple = couple;
        _members = members;
        _moods = moods;
        _answers = answers;
        _dates = dates;
        _partnerAnswered = partnerAnswered;
        _newNotifications = newNotifications;
        _error = null;
        _loading = false;
      });
      widget.onUnreadChanged?.call(unread);
      _celebrateIfToday();
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
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
      showConfetti(context);
      showFloatingHearts(context);
    }
  }

  void _showMessage(String text, {bool error = false}) =>
      showUsMessage(context, text, error: error);

  // ---------------------------------------------------------------- mood

  /// Tapping a mood shares it at once: the card shows it immediately, the
  /// save runs, and if it fails the previous mood comes back with the usual
  /// short error. While a save is in flight further taps are ignored, so a
  /// double tap can never write twice.
  Future<bool> _pickMood(Mood mood) async {
    if (_savingMood) return false;
    // The note belongs with how you feel today, so it carries over to the
    // new mood instead of vanishing (moods are new rows; rows can't change).
    final note = _noteToday(_myId);
    HapticFeedback.selectionClick();
    setState(() {
      _pending = mood;
      _savingMood = true;
    });
    try {
      await MoodService.checkIn(coupleId: _coupleId, mood: mood, note: note);
      if (!mounted) return true;
      SemanticsService.sendAnnouncement(
        View.of(context),
        _partner == null
            ? '${mood.label}, saved as your mood today'
            : '${mood.label}, shared with $_partnerName',
        Directionality.of(context),
      );
      // Saved: keep it as today's mood even if the reload below fails.
      setState(() {
        _moods = [
          MoodEntry(
            id: 'just-shared',
            userId: _myId,
            mood: mood,
            note: note,
            createdAt: DateTime.now(),
          ),
          ..._moods,
        ];
        _pending = null;
      });
      await _load();
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _pending = null); // back to the previous mood
      _showMessage(friendlyError(e), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _savingMood = false);
    }
  }

  /// Add, edit or remove today's note. Moods tapped in the sheet share at
  /// once (same as the card); the button saves only the note: one new
  /// check-in with your current mood and the text (or no text, to remove
  /// it). Shared like every check-in now.
  Future<void> _checkMood() async {
    final current = _pending ?? _savedMood;
    final saved = await _sheet(
      MoodSheet(
        // A history-only mood is never preselected: it cannot be picked again.
        current: current != null && current.selectable ? current : null,
        currentNote: _noteToday(_myId),
        onPick: _pickMood,
        onSaveNote: (mood, note) =>
            MoodService.checkIn(coupleId: _coupleId, mood: mood, note: note),
      ),
    );
    if (saved != true) return;
    await _load();
  }

  /// Both of today's notes, opened from the small note marker on the card.
  Future<void> _showNotes() async {
    final partner = _partner;
    final mine = _noteToday(_myId);
    final theirs = partner == null ? null : _noteToday(partner.userId);
    final edit = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => MoodNotesSheet(
        notes: [
          (name: 'You', note: mine),
          if (partner != null)
            (name: _first(partner.displayName), note: theirs),
        ],
        hasMine: mine != null,
      ),
    );
    if (edit == true && mounted) await _checkMood();
  }

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
  }

  Future<void> _answerQuestion() async {
    String? mine;
    for (final a in _answers) {
      if (a.userId == _myId) mine = a.answer;
    }
    final saved = await _sheet(
      QuestionSheet(
        coupleId: _coupleId,
        day: _today,
        question: questionFor(_today),
        currentAnswer: mine,
      ),
    );
    if (saved != true) return;
    await _load();
    if (!mounted) return;
    showFloatingHearts(context, icon: UsIcons.loveNotes);
  }

  /// Chat is a tab: switching to it is what opening it means now.
  Future<void> _openChat() async {
    if (_partner == null) return;
    widget.onOpenTab?.call(1);
  }

  /// Therabot is no longer a tab: it opens as its own page from Home.
  Future<void> _openTherabot() => _push(TherabotTab(profile: widget.profile));

  /// Builds the notifications. Home passes what it already loaded; the
  /// Notifications screen calls it without, so it fetches fresh data.
  Future<List<AppNotification>> _loadNotifications({
    Couple? couple,
    List<Profile>? members,
    List<QuestionAnswer>? answers,
    List<Activity>? activities,
    List<ImportantDate>? dates,
  }) {
    final people = members ?? _members;
    String partner = 'Your partner';
    for (final m in people) {
      if (m.userId != _myId) partner = m.displayName.split(' ').first;
    }
    return NotificationService.load(
      coupleId: _coupleId,
      myId: _myId,
      partnerName: partner,
      answeredToday: (answers ?? _answers).any((a) => a.userId == _myId),
      anniversary: (couple ?? _couple)?.anniversaryDate,
      activities: activities,
      dates: dates,
    );
  }

  /// Keys that were new on the last visit to Notifications. If you follow
  /// one and come straight back, the others are still highlighted.
  Set<String> _recentlyNew = {};
  DateTime? _recentlyNewAt;

  /// The bell: opens Notifications, then follows whatever was tapped.
  Future<void> _openNotifications() async {
    final fresh =
        _recentlyNewAt != null &&
        DateTime.now().difference(_recentlyNewAt!) <
            const Duration(minutes: 10);
    final tapped = await Navigator.of(context).push<AppNotification>(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          myId: _myId,
          load: () => _loadNotifications(),
          keepNew: fresh ? _recentlyNew : const {},
          onNewKeys: (keys) {
            _recentlyNew = keys;
            _recentlyNewAt = DateTime.now();
          },
        ),
      ),
    );
    if (!mounted) return;
    if (tapped != null) await _follow(tapped);
    // Recounts the bell from what is now remembered as seen.
    if (mounted) await _load();
  }

  /// Opens the place a notification is about.
  Future<void> _follow(AppNotification n) async {
    // Tabs opened from a notification reload, so the new item is there.
    void tab(int i) => widget.onOpenTab?.call(i);
    switch (n.target) {
      case NotificationTarget.memory:
        final hint = n.targetHint;
        final author = n.targetId;
        if (hint != null && author != null) {
          try {
            final memory = await MemoryService.findByCaption(
              _coupleId,
              author,
              hint,
            );
            if (!mounted) return;
            if (memory != null) {
              await _push(
                MemoryDetailScreen(
                  memory: memory,
                  authorName: memory.authorId == _myId ? 'you' : _partnerName,
                  isMine: memory.authorId == _myId,
                ),
              );
              return;
            }
          } catch (_) {
            // fall back to the timeline
          }
        }
        tab(2);
      case NotificationTarget.timeline:
        tab(2);
      case NotificationTarget.moodHistory:
        await _openMoodHistory();
      case NotificationTarget.loveNotes:
        tab(3);
      case NotificationTarget.timeCapsules:
        // A "ready" reminder opens Ready, pointing at that capsule; other
        // capsule news opens the screen as you left it.
        final ready = n.key.startsWith('time-capsule-ready:');
        await _push(
          TimeCapsuleScreen(
            profile: widget.profile,
            openReady: ready,
            highlightId: ready ? n.targetId : null,
          ),
          reload: true,
        );
      case NotificationTarget.importantDates:
        await _push(ImportantDatesScreen(coupleId: _coupleId));
      case NotificationTarget.bucketList:
        // _openNotifications reloads Home afterwards anyway.
        await _push(BucketListScreen(profile: widget.profile));
      case NotificationTarget.questions:
        await _push(
          QuestionArchiveScreen(
            coupleId: _coupleId,
            myUserId: _myId,
            partnerName: _partnerName,
          ),
        );
      case NotificationTarget.answerQuestion:
        await _answerQuestion();
      case NotificationTarget.therabot:
        await _openTherabot();
      case NotificationTarget.chat:
        await _openChat();
      case NotificationTarget.sendHugBack:
        // Never sends on its own: offer it, so a stray tap can't send a hug.
        if (_partner == null) return;
        showUsMessage(
          context,
          'Send $_partnerName a hug back?',
          action: SnackBarAction(label: 'Send a hug', onPressed: _sendHug),
        );
      case NotificationTarget.countdown:
        final target = _countdownKey.currentContext;
        if (target != null && target.mounted) {
          await Scrollable.ensureVisible(
            target,
            duration: motionOff(target) ? Duration.zero : AppMotion.medium,
            curve: AppMotion.enter,
          );
        }
      case NotificationTarget.home:
        break; // nothing more to open
    }
  }

  /// True when the hug was sent.
  Future<bool> _sendHug() async {
    if (_partner == null || _busy) return false;
    setState(() => _busy = true);
    try {
      await AffectionService.send(coupleId: _coupleId, kind: 'hug');
      if (!mounted) return true;
      showGesturePulse(context, UsIcons.hug);
      return true;
    } catch (e) {
      if (!mounted) return false;
      _showMessage(friendlyError(e), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _push(Widget screen, {bool reload = false}) async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => screen));
    if (reload || changed == true) await _load();
  }

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
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e), error: true);
    }
  }

  // ---------------------------------------------------------------- build

  static const _needsPartner = 'Available once your partner joins';

  static String _first(String name) => name.split(' ').first;

  /// The card for whichever special day comes first.
  Widget _specialEventCard(DateTime today) {
    final together = _couple?.anniversaryDate;
    final partner = _partner;
    final event = nearestEvent(
      today: today,
      together: together,
      myBirthday: _me.birthday,
      partnerBirthday: partner?.birthday,
      custom: [
        for (final d in _dates)
          CustomDate(
            title: d.title,
            date: d.eventDate,
            repeatsYearly: d.repeatsYearly,
            createdAt: d.createdAt,
          ),
      ],
    );
    final aboutUs =
        event.kind == SpecialEventKind.anniversary ||
        event.kind == SpecialEventKind.monthsary;
    return SpecialEventCard(
      event: event,
      myName: _first(_me.displayName),
      myPhoto: _me.avatarUrl,
      partnerName: partner == null ? null : _first(partner.displayName),
      partnerPhoto: partner?.avatarUrl,
      together: together,
      hint: together == null ? 'Tap to add your anniversary' : null,
      // Anniversary days (or a missing anniversary) edit the date; the
      // couple's own dates open where they are managed.
      onTap: together == null || aboutUs
          ? _setAnniversary
          : event.kind == SpecialEventKind.custom
          ? () => _push(ImportantDatesScreen(coupleId: _coupleId))
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_loading) {
      return const Scaffold(body: SafeArea(child: SkeletonList(count: 5)));
    }

    final couple = _couple;
    final partner = _partner;
    final partnerFirst = partner == null ? null : _first(partner.displayName);
    final today = _today;
    final saved = _savedMood;
    final shown = _pending ?? saved;
    final myAnswered = _answers.any((a) => a.userId == _myId);
    const gap = AppSpacing.xl;

    // Each section is keyed, so when something appears above it after a
    // live update (an error, a hug) it keeps its state instead of rebuilding.
    Widget section(String key, Widget child, {double after = gap}) => Padding(
      key: ValueKey(key),
      padding: EdgeInsets.only(bottom: after),
      child: child,
    );

    final sections = <Widget>[
      if (_error != null)
        section('error', UsErrorNotice(message: _error!, onRetry: _load)),
      // Loaded without an error but no space came back (for example the
      // pairing changed elsewhere): say so plainly and offer a reload.
      if (couple == null && _error == null)
        section(
          'no-couple',
          UsErrorNotice(
            message: "Your space isn't showing right now.",
            onRetry: _load,
          ),
        ),
      if (couple != null) ...[
        // What matters to us today: the next special day first.
        section(
          'countdown',
          KeyedSubtree(key: _countdownKey, child: _specialEventCard(today)),
          after: AppSpacing.md,
        ),
        if (partner == null)
          section(
            'invite',
            _InviteBanner(code: couple.pairingCode),
            after: AppSpacing.md,
          ),
        const SizedBox(key: ValueKey('event-gap'), height: gap - AppSpacing.md),

        // Today's mood: both of you, or one of you; then the picker.
        section(
          'moods',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTitle(
                "Today's mood",
                actionLabel: 'History',
                onAction: _openMoodHistory,
              ),
              MoodCard(
                me: MoodPerson(
                  name: _first(_me.displayName),
                  avatarUrl: _me.avatarUrl,
                  mood: shown,
                  note: _noteToday(_myId),
                ),
                partner: partner == null
                    ? null
                    : MoodPerson(
                        name: partnerFirst!,
                        avatarUrl: partner.avatarUrl,
                        mood: latestMoodOn(_moods, partner.userId, today)?.mood,
                        note: _noteToday(partner.userId),
                      ),
                busy: _savingMood,
                onPick: _pickMood,
                onAddNote: _checkMood,
                onShowNotes: _showNotes,
              ),
            ],
          ),
        ),

        section(
          'for-us',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionTitle('For us'),
              QuickActions(
                actions: [
                  QuickAction(
                    title: 'Add memory',
                    subtitle: 'Save this moment',
                    art: QuickActionArt.memory,
                    onTap: _addMemory,
                  ),
                  // There is no separate date planner: the bucket list is
                  // where the two of you keep the things you want to do.
                  QuickAction(
                    title: 'Plan a date',
                    subtitle: 'Make time together',
                    art: QuickActionArt.date,
                    onTap: () => _push(
                      BucketListScreen(profile: widget.profile),
                      reload: true,
                    ),
                  ),
                  QuickAction(
                    title: 'Time capsule',
                    subtitle: 'Send something for later',
                    art: QuickActionArt.capsule,
                    onTap: partner == null
                        ? null
                        : () => _push(
                            TimeCapsuleScreen(
                              profile: widget.profile,
                              startComposing: true,
                            ),
                            reload: true,
                          ),
                    disabledReason: _needsPartner,
                  ),
                ],
                more: [
                  MoreAction(
                    'Daily question',
                    UsIcons.question,
                    _answerQuestion,
                    // A dot when your partner has answered and you haven't.
                    badge: _partnerAnswered && !myAnswered
                        ? '$partnerFirst answered'
                        : null,
                  ),
                  MoreAction(
                    'Our questions',
                    UsIcons.history,
                    () => _push(
                      QuestionArchiveScreen(
                        coupleId: _coupleId,
                        myUserId: _myId,
                        partnerName: _partnerName,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        section('therabot', TherabotCard(onTap: _openTherabot), after: 0),
      ],
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.md,
              AppSpacing.screenMargin,
              AppSpacing.xxl,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.homeMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header: today's date and a greeting, then the bell.
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _dateLine(today),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Semantics(
                                  header: true,
                                  child: Text(
                                    '${_greeting(today)}, ${_first(_me.displayName)}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          HeaderIconButton(
                            icon: UsIcons.bell,
                            label: 'Notifications',
                            count: _newNotifications,
                            onPressed: _openNotifications,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ...staggered(sections),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Both partners' moods over the last weeks. Reachable with or without a
  /// partner, from "Mood today" and from the partner's mood chip.
  Future<void> _openMoodHistory() => _push(
    MoodHistoryScreen(
      coupleId: _coupleId,
      myUserId: _myId,
      partnerId: _partner?.userId,
      partnerName: _partnerName,
    ),
  );
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday', //
];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "Tuesday, 6 October"
String _dateLine(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

/// Good morning until noon, good afternoon until six, then good evening.
String _greeting(DateTime d) => d.hour < 12
    ? 'Good morning'
    : d.hour < 18
    ? 'Good afternoon'
    : 'Good evening';

/// A quiet section heading on Home ("Mood today", "Quick actions"), with an
/// optional small action on the right.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.touchTarget),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                textStyle: theme.textTheme.bodySmall,
              ),
              child: Text(actionLabel!),
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
    ScaffoldMessenger.of(context);
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
          Text(
            'Waiting for your partner',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Send them this code so they can join. Pull down to refresh '
            'once they have.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
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
                icon: const UsIcon(UsIcons.copy),
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
