import 'package:flutter/material.dart';

import '../models/mood.dart';
import '../models/mood_visual.dart';
import '../services/auth_service.dart';
import '../services/mood_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/home/mood_art.dart';
import '../widgets/atoms/us_icon.dart';
import '../widgets/effects/motion.dart';
import '../widgets/molecules/us_states.dart';

/// The days either of you checked in, newest first and grouped by month.
/// Each day shows your mood and your partner's shared mood (the latest
/// check-in that day). Days with no mood from either of you are left out.
class MoodHistoryScreen extends StatefulWidget {
  const MoodHistoryScreen({
    super.key,
    required this.coupleId,
    required this.myUserId,
    required this.partnerId,
    required this.partnerName,
  });

  final String coupleId;
  final String myUserId;
  final String? partnerId;
  final String partnerName;

  @override
  State<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

/// One day with at least one mood on it.
class _Day {
  _Day(this.date, this.mine, this.partner);

  final DateTime date;
  final MoodEntry? mine;
  final MoodEntry? partner;
}

class _MoodHistoryScreenState extends State<MoodHistoryScreen> {
  List<MoodEntry> _entries = [];
  bool _loading = true;
  String? _error;

  /// How far back the history reaches.
  static const _days = 365;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await MoodService.recent(widget.coupleId, days: _days);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  /// Only the dates that have a mood from either of you, newest first.
  List<_Day> get _moodDays {
    final dates = <DateTime>{
      for (final e in _entries)
        if (e.userId == widget.myUserId || e.userId == widget.partnerId)
          DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day),
    }.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final d in dates)
        _Day(
          d,
          latestMoodOn(_entries, widget.myUserId, d),
          widget.partnerId == null
              ? null
              : latestMoodOn(_entries, widget.partnerId!, d),
        ),
    ];
  }

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = _moodDays;

    final children = <Widget>[
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: UsErrorNotice(message: _error!, onRetry: _load),
        ),
    ];

    if (days.isEmpty && _error == null) {
      children.add(const _EmptyHistory());
    } else {
      int? month;
      int? year;
      for (final day in days) {
        if (day.date.month != month || day.date.year != year) {
          month = day.date.month;
          year = day.date.year;
          final count = days
              .where((d) => d.date.month == month && d.date.year == year)
              .length;
          children.add(
            _MonthHeader(
              title: '${_months[month - 1]} $year',
              count: count,
              first: children.isEmpty,
            ),
          );
        }
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _DayCard(day: day, partnerName: widget.partnerName),
          ),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Text(
            'Private check-ins only appear on your side. '
            'Your partner sees only the moods you shared.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mood history')),
      body: _loading
          ? const SkeletonList(count: 5, height: 72)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.sm,
                  AppSpacing.screenMargin,
                  AppSpacing.xxl,
                ),
                children: children,
              ),
            ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.title,
    required this.count,
    required this.first,
  });

  final String title;
  final int count;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        top: first ? AppSpacing.sm : AppSpacing.xl,
        bottom: AppSpacing.md,
      ),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$count ${count == 1 ? 'day' : 'days'}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Container(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One day: the date on the left, then your mood and your partner's.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.partnerName});

  final _Day day;
  final String partnerName;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = day.date;
    final dark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: dark
            ? Color.alphaBlend(
                scheme.primaryContainer.withValues(alpha: 0.35),
                scheme.surfaceContainer,
              )
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: dark ? 0.35 : 0.6),
        ),
      ),
      child: Row(
        children: [
          // The date.
          SizedBox(
            width: 46,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${d.day}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_shortMonths[d.month - 1]} ${d.year}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _weekdays[d.weekday - 1],
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 52,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(
            child: _MoodSide(who: 'You', entry: day.mine),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MoodSide(who: partnerName, entry: day.partner),
          ),
        ],
      ),
    );
  }
}

/// One person's mood that day, or a quiet "No mood shared".
class _MoodSide extends StatelessWidget {
  const _MoodSide({required this.who, required this.entry});

  final String who;
  final MoodEntry? entry;

  static const _art = 34.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final e = entry;
    final visual = e == null ? null : MoodVisual.of(e.mood);

    final Widget badge = visual != null
        ? Container(
            width: _art + 6,
            height: _art + 6,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: visual.gradientFor(theme.brightness),
              ),
            ),
            child: MoodArt(visual: visual, size: _art, semantic: false),
          )
        : Container(
            width: _art + 6,
            height: _art + 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 10,
              height: 1.5,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          );

    final Widget words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          who,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Text(
          e == null ? 'No mood shared' : e.mood.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: e == null
              ? theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                  fontStyle: FontStyle.italic,
                )
              : theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: visual!.accentFor(theme.brightness),
                  height: 1.15,
                ),
        ),
        if (e != null && !e.isShared)
          Text(
            'Private',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );

    // On a narrow phone the art sits above the words, so long mood names
    // never break mid-word.
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return Semantics(
      label: e == null
          ? '$who: no mood shared'
          : '$who: ${e.mood.label}${e.isShared ? '' : ', private'}',
      child: ExcludeSemantics(
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [badge, const SizedBox(height: 6), words],
              )
            : Row(
                children: [
                  badge,
                  const SizedBox(width: 8),
                  Expanded(child: words),
                ],
              ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const UsEmptyState(
      icon: UsIcons.mood,
      title: 'No moods shared yet',
      message: 'Your shared mood journey will appear here.',
    );
  }
}
