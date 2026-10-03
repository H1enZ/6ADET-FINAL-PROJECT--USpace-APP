import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../models/activity.dart';
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
import '../services/dates_service.dart';
import '../services/mood_service.dart';
import '../services/profile_service.dart';
import '../services/question_service.dart';
import '../theme/app_effects.dart';
import '../theme/app_spacing.dart';
import '../utils/anniversary.dart';
import '../utils/daily_content.dart';
import '../widgets/atoms/app_button.dart';
import '../widgets/atoms/header_icon_button.dart';
import '../widgets/brand/uspace_wordmark.dart';
import '../widgets/effects/floating_hearts.dart';
import '../widgets/effects/motion.dart';
import '../widgets/home/activity_feed.dart';
import '../widgets/home/affection_banner.dart';
import '../widgets/home/home_card.dart';
import '../widgets/home/mood_grid.dart';
import '../widgets/home/mood_hero.dart';
import '../widgets/home/partner_mood_chip.dart';
import '../widgets/home/quick_actions.dart';
import '../widgets/molecules/countdown_card.dart';
import 'add_memory_sheet.dart';
import 'bucket_list_screen.dart';
import 'chat_screen.dart';
import 'important_dates_screen.dart';
import 'mood_history_screen.dart';
import 'mood_sheet.dart';
import 'question_archive_screen.dart';
import 'question_sheet.dart';
import 'work_it_out_screen.dart';
import 'write_note_sheet.dart';

/// Home: how you are feeling today, front and centre, then shortcuts and
/// the next special day. Recent activity lives behind the bell.
/// Updates live when your partner does something; pull down to refresh.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Couple? _couple;
  List<Profile> _members = [];
  List<MoodEntry> _moods = [];
  List<QuestionAnswer> _answers = [];
  List<ImportantDate> _dates = [];
  List<Activity> _activities = [];
  List<Map<String, dynamic>> _unseen = [];
  bool _partnerAnswered = false;
  int _unread = 0;
  bool _loading = true;
  bool _busy = false;
  bool _celebrated = false;
  String? _error;
  RealtimeChannel? _live;

  /// A mood tapped in the grid but not saved yet. Shown on the hero.
  Mood? _preview;
  bool _savingMood = false;

  /// On the hero's Share / Add a note row, to scroll it into view.
  final _heroActionsKey = GlobalKey();

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
      final members = await ProfileService.withPhotos(
        await CoupleService.members(_coupleId),
      );
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
        unread = partnerId == null
            ? 0
            : await ChatService.unreadCount(_coupleId);
      } catch (_) {
        // the badge is a bonus; Home still loads without it
      }

      if (!mounted) return;
      final newAffection = unseen.length > _unseen.length;
      setState(() {
        _couple = couple;
        _members = members;
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
      if (newAffection) {
        showGesturePulse(context, _affectionEmoji(unseen.first['kind']));
      }
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
      showConfetti(context);
      showFloatingHearts(context);
    }
  }

  static String _affectionEmoji(Object? kind) => switch (kind) {
    'hug' => '🫂',
    'kiss' => '💋',
    'cuddle' => '🤗',
    'listen' => '👂',
    _ => '💗',
  };

  void _showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  // ---------------------------------------------------------------- mood

  /// Tapping a mood only previews it. Tapping today's saved mood again
  /// clears the preview.
  void _previewMood(Mood mood) {
    if (_savingMood) return;
    HapticFeedback.selectionClick();
    final preview = mood == _savedMood ? null : mood;
    setState(() => _preview = preview);

    // Make it clear nothing is shared yet: say so to screen readers, and
    // bring the Share button into view if the grid has scrolled it away.
    SemanticsService.sendAnnouncement(
      View.of(context),
      preview == null
          ? '${mood.label}, already shared today'
          : '${mood.label}, not shared yet. Share mood button is above.',
      Directionality.of(context),
    );
    if (preview != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _heroActionsKey.currentContext;
        if (target == null || !target.mounted) return;
        Scrollable.ensureVisible(
          target,
          duration: motionOff(target) ? Duration.zero : AppMotion.medium,
          curve: AppMotion.enter,
          // Scroll only if it is not already on screen.
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      });
    }
  }

  /// Saves the previewed mood (shared with your partner).
  Future<void> _shareMood() async {
    final mood = _preview;
    if (mood == null || _savingMood) return;
    setState(() => _savingMood = true);
    try {
      await MoodService.checkIn(coupleId: _coupleId, mood: mood);
      if (!mounted) return;
      // Saved: show it as today's mood straight away, even if the reload
      // below fails, so a successful share never looks unsaved.
      setState(() {
        _moods = [
          MoodEntry(
            id: 'just-shared',
            userId: _myId,
            mood: mood,
            createdAt: DateTime.now(),
          ),
          ..._moods,
        ];
        _preview = null;
      });
      _showMessage(
        _partner == null ? 'Mood saved' : 'Mood shared with $_partnerName',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    } finally {
      if (mounted) setState(() => _savingMood = false);
    }
  }

  /// The existing check-in sheet: a note, and a private option.
  Future<void> _checkMood() async {
    final current = _preview ?? _savedMood;
    final saved = await _sheet(
      MoodSheet(
        coupleId: _coupleId,
        partnerName: _partnerName,
        // A history-only mood is never preselected: it cannot be picked again.
        current: current != null && current.selectable ? current : null,
      ),
    );
    if (saved != true) return;
    await _load();
    if (!mounted) return;
    setState(() => _preview = null);
    _showMessage('Mood saved');
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
    _showMessage('Memory saved');
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
    showFloatingHearts(context, emoji: '💌');
    _showMessage('Answer saved');
  }

  Future<void> _writeNote({bool sealed = false}) async {
    if (_partner == null) return;
    final sent = await _sheet(
      WriteNoteSheet(
        coupleId: _coupleId,
        partnerName: _partnerName,
        anniversary: _couple?.anniversaryDate,
        startSealed: sealed,
      ),
    );
    if (sent != true) return;
    await _load();
    if (!mounted) return;
    showEnvelopeFly(context, emoji: sealed ? '🔒' : '💌');
    _showMessage(
      sealed ? 'Time capsule sealed 🔒' : 'Love note sent to $_partnerName 💌',
    );
  }

  Future<void> _openChat() async {
    final partner = _partner;
    if (partner == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChatScreen(coupleId: _coupleId, me: _me, partner: partner),
      ),
    );
    await _load(); // clears the unread badge
  }

  /// Recent activity, behind the bell. (The full Notifications screen
  /// replaces this page in the next phase.)
  Future<void> _openActivity() async {
    final names = {for (final m in _members) m.userId: m.displayName};
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Recent activity')),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            children: [
              ActivityFeed(
                activities: _activities,
                myUserId: _myId,
                names: names,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openWorkItOut() async {
    if (_partner == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkItOutScreen(
          coupleId: _coupleId,
          myUserId: _myId,
          partnerName: _partnerName,
          me: _me,
          partner: _partner,
          anniversary: _couple?.anniversaryDate,
        ),
      ),
    );
    await _load();
  }

  /// True when the hug was sent.
  Future<bool> _sendHug() async {
    if (_partner == null || _busy) return false;
    setState(() => _busy = true);
    try {
      await AffectionService.send(coupleId: _coupleId, kind: 'hug');
      if (!mounted) return true;
      showGesturePulse(context, '🫂');
      _showMessage('Hug sent to $_partnerName 🫂');
      return true;
    } catch (e) {
      if (!mounted) return false;
      _showMessage(friendlyError(e));
      return false;
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

  /// Only marks their gesture seen once the hug back has actually gone.
  Future<void> _sendBack() async {
    if (await _sendHug()) await _dismissAffection();
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
      _showMessage('Anniversary saved');
    } catch (e) {
      if (!mounted) return;
      _showMessage(friendlyError(e));
    }
  }

  // ---------------------------------------------------------------- build

  static const _needsPartner = 'Available once your partner joins';

  static String _first(String name) => name.split(' ').first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    if (_loading) {
      return const Scaffold(body: SafeArea(child: SkeletonList(count: 5)));
    }

    final couple = _couple;
    final partner = _partner;
    final partnerFirst = partner == null ? null : _first(partner.displayName);
    final today = _today;
    final saved = _savedMood;
    final shown = _preview ?? saved;
    final partnerMood = partner == null
        ? null
        : latestMoodOn(_moods, partner.userId, today)?.mood;
    final myAnswered = _answers.any((a) => a.userId == _myId);
    final upcoming = _dates
        .where((d) => d.daysUntil() != null)
        .take(3)
        .toList();
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
        section(
          'error',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: 'Try again',
                  variant: AppButtonVariant.outlined,
                  onPressed: _load,
                ),
              ),
            ],
          ),
        ),
      if (couple == null && _error == null)
        section(
          'no-couple',
          Text(
            "We couldn't load your space just now. Pull down to try again.",
            style: muted,
          ),
        ),
      if (couple != null) ...[
        // Mood hero: what you are feeling (or previewing).
        section(
          'hero',
          MoodHero(
            name: _first(_me.displayName),
            mood: shown,
            pending: _preview != null && _preview != saved,
            saving: _savingMood,
            hasPartner: partner != null,
            onShare: _shareMood,
            onAddNote: _checkMood,
            actionsKey: _heroActionsKey,
          ),
          after: AppSpacing.md,
        ),
        if (partner != null)
          section(
            'partner-mood',
            PartnerMoodChip(
              partnerName: partnerFirst!,
              mood: partnerMood,
              onTap: _openMoodHistory,
            ),
            after: AppSpacing.md,
          ),
        if (_unseen.isNotEmpty && partner != null)
          section(
            'affection',
            AffectionBanner(
              partnerName: partnerFirst!,
              unseen: _unseen,
              busy: _busy,
              onSendBack: _sendBack,
              onDismiss: _dismissAffection,
            ),
            after: AppSpacing.md,
          ),
        if (partner == null)
          section(
            'invite',
            _InviteBanner(code: couple.pairingCode),
            after: AppSpacing.md,
          ),
        const SizedBox(key: ValueKey('hero-gap'), height: gap - AppSpacing.md),

        // Mood today: two rows of four.
        section(
          'moods',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTitle(
                'Mood today',
                actionLabel: 'History',
                onAction: _openMoodHistory,
              ),
              MoodGrid(selected: shown, saved: saved, onSelect: _previewMood),
            ],
          ),
        ),

        section(
          'quick-actions',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionTitle('Quick actions'),
              QuickActions(
                actions: [
                  QuickAction(
                    'Add memory',
                    Icons.add_photo_alternate_outlined,
                    _addMemory,
                  ),
                  QuickAction(
                    'Love note',
                    Icons.mail_outline_rounded,
                    partner == null ? null : _writeNote,
                    disabledReason: _needsPartner,
                  ),
                  QuickAction(
                    'Send a hug',
                    Icons.volunteer_activism_outlined,
                    partner == null ? null : _sendHug,
                    disabledReason: _needsPartner,
                  ),
                  QuickAction(
                    'Daily question',
                    Icons.forum_outlined,
                    _answerQuestion,
                    // A dot when your partner has answered and you haven't.
                    badge: _partnerAnswered && !myAnswered
                        ? '$partnerFirst answered'
                        : null,
                  ),
                  QuickAction(
                    'Our questions',
                    Icons.history_edu_outlined,
                    () => _push(
                      QuestionArchiveScreen(
                        coupleId: _coupleId,
                        myUserId: _myId,
                        partnerName: _partnerName,
                      ),
                    ),
                  ),
                  QuickAction(
                    'Work it out',
                    Icons.handshake_outlined,
                    partner == null ? null : _openWorkItOut,
                    disabledReason: _needsPartner,
                  ),
                  QuickAction(
                    'Bucket list',
                    Icons.checklist_rounded,
                    () => _push(
                      BucketListScreen(profile: widget.profile),
                      reload: true,
                    ),
                  ),
                  QuickAction(
                    'Time capsule',
                    Icons.lock_clock_outlined,
                    partner == null ? null : () => _writeNote(sealed: true),
                    disabledReason: _needsPartner,
                  ),
                ],
              ),
            ],
          ),
        ),

        // The anniversary, then the next special days.
        section(
          'countdown',
          CountdownCard(
            anniversary: couple.anniversaryDate,
            onTap: _setAnniversary,
          ),
          after: AppSpacing.md,
        ),
        section(
          'coming-up',
          HomeCard(
            title: 'Coming up',
            actionLabel: 'Manage',
            onAction: () => _push(ImportantDatesScreen(coupleId: _coupleId)),
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
                          : "${_first(m.displayName)}'s birthday",
                      days: AnniversaryInfo.from(m.birthday!).daysUntilNext,
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
          after: 0,
        ),
      ],
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
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
                      // Header: wordmark, then chat and the bell.
                      Row(
                        children: [
                          // Shrinks rather than overflowing with very
                          // large text on a narrow phone.
                          const Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: USpaceWordmark(size: 26, isHeader: true),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Spacer(),
                          HeaderIconButton(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: partner == null
                                ? 'Chat. $_needsPartner'
                                : 'Chat',
                            count: _unread,
                            onPressed: partner == null ? null : _openChat,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          HeaderIconButton(
                            icon: Icons.notifications_none_rounded,
                            label: 'Notifications',
                            onPressed: _openActivity,
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
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text, style: theme.textTheme.titleMedium),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.touchTarget),
              ),
              child: Text(actionLabel!),
            ),
        ],
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
              Text(
                when,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
              ),
              Text(
                shortDate(date),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Code copied')));
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
