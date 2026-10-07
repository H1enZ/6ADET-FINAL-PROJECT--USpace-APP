import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/mood.dart';
import '../models/mood_visual.dart';
import '../services/notification_service.dart';
import '../theme/app_effects.dart';
import '../theme/app_spacing.dart';
import '../utils/daily_content.dart';
import '../widgets/effects/motion.dart';
import '../widgets/atoms/us_icon.dart';
import '../widgets/molecules/us_states.dart';

/// What has happened between you two, and what is coming up. Opened from
/// the bell on Home. Tapping an item closes this screen and returns the item,
/// so Home (which knows the tabs) opens the right place.
///
/// Opening (and pulling to refresh) remembers what you have seen. Items that
/// were new stay highlighted for this visit, and when you come straight back
/// after following one ([keepNew]).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.myId,
    required this.load,
    this.keepNew = const {},
    this.onNewKeys,
  });

  final String myId;

  /// Loads the notifications (with unread already set).
  final Future<List<AppNotification>> Function() load;

  /// Keys still to highlight as new from a moment ago (see above).
  final Set<String> keepNew;

  /// Told which keys were new, so Home can pass them back as [keepNew].
  final ValueChanged<Set<String>>? onNewKeys;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _items;
  String? _error;
  late final Set<String> _newThisVisit = {...widget.keepNew};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    // Stamped before fetching: anything that happens after this stays new.
    final loadedAt = DateTime.now();
    try {
      final items = await widget.load();
      if (!mounted) return;
      _newThisVisit.addAll([
        for (final n in items)
          if (n.unread) n.key,
      ]);
      setState(() {
        _items = [
          for (final n in items) n.withUnread(_newThisVisit.contains(n.key)),
        ];
        _error = null;
      });
      widget.onNewKeys?.call(_newThisVisit);
      await NotificationService.markAllSeen(
        items,
        widget.myId,
        loadedAt: loadedAt,
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            "Couldn't load notifications. Check your connection and try again.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final all = items ?? const <AppNotification>[];
    final reminders = [
      for (final n in all)
        if (n.isReminder) n,
    ];
    final events = [
      for (final n in all)
        if (!n.isReminder) n,
    ];
    final todays = [
      for (final n in events)
        if (n.time != null && !n.time!.isBefore(today)) n,
    ];
    final earlier = [
      for (final n in events)
        if (n.time == null || n.time!.isBefore(today)) n,
    ];
    final newCount = NotificationService.unreadCount(all);

    final children = <Widget>[
      if (_error != null)
        Padding(
          key: const ValueKey('error'),
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: UsErrorNotice(message: _error!, onRetry: _refresh),
        ),
      if (items != null && items.isEmpty)
        const _AllCaughtUp(key: ValueKey('empty')),
      for (final (title, group) in [
        ('Coming up', reminders),
        ('Today', todays),
        ('Earlier', earlier),
      ])
        if (group.isNotEmpty) ...[
          _GroupTitle(title, key: ValueKey('group:$title')),
          for (final n in group)
            Padding(
              key: ValueKey(n.key),
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _NotificationCard(
                item: n,
                onTap: () => Navigator.of(context).pop(n),
              ),
            ),
          SizedBox(key: ValueKey('gap:$title'), height: AppSpacing.md),
        ],
    ];

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: Text(
            newCount > 0 ? 'Notifications ($newCount new)' : 'Notifications',
          ),
        ),
      ),
      body: items == null && _error == null
          ? const SkeletonList(count: 4, height: 76)
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.sm,
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
                        children: staggered(children),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleMedium),
      ),
    );
  }
}

/// One notification: a soft card with a category icon, title, a short line,
/// when it happened, and a "New" label.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  static const double _iconCircle = 44;
  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = _accent(item.kind).accentFor(theme.brightness);
    final shape = BorderRadius.circular(AppRadius.card);
    final when = _when(item);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final card = item.unread
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.06),
            scheme.surfaceContainerHighest,
          )
        : scheme.surfaceContainerHighest;

    return Semantics(
      button: true,
      label: _sentences([item.title, item.body, ?when, if (item.unread) 'New']),
      hint: _hint(item.target),
      onTap: onTap,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: card,
          borderRadius: shape,
          border: Border.all(
            color: item.unread
                ? scheme.primary.withValues(alpha: 0.35)
                : scheme.outline.withValues(alpha: 0.6),
          ),
          boxShadow: AppShadows.soft(scheme),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: shape,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: _iconCircle,
                    height: _iconCircle,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: UsIcon(
                      _icon(item.kind),
                      color: accent,
                      size: _iconSize,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            // Clearly bolder when new, not just a shade.
                            fontWeight: item.unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        if (item.body.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.body,
                            // A little more room when the text is large.
                            maxLines: largeText ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (when != null || item.unread) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (item.unread) const _NewLabel(),
                              if (when != null)
                                Text(
                                  when,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Joins parts into sentences without doubling punctuation
  /// ("Happy anniversary!" + "5m ago", not "Happy anniversary!. 5m ago").
  static String _sentences(List<String> parts) {
    final out = StringBuffer();
    for (final p in parts.where((p) => p.trim().isNotEmpty)) {
      if (out.isNotEmpty) out.write(' ');
      final t = p.trim();
      out.write(RegExp(r'[.!?]$').hasMatch(t) ? t : '$t.');
    }
    return out.toString();
  }

  /// "5m ago" for events, "Opened 2h ago" for a previous (Love Notes)
  /// capsule that just opened, "Ready 2h ago" for a Time Capsule waiting to
  /// be opened; other reminders say their day in the body instead.
  static String? _when(AppNotification n) {
    final t = n.time;
    if (t == null) return null;
    if (n.isReminder) {
      if (n.kind != NotificationKind.capsule) return null;
      return n.target == NotificationTarget.timeCapsules
          ? 'Ready ${timeAgo(t)}'
          : 'Opened ${timeAgo(t)}';
    }
    return timeAgo(t);
  }

  /// Category colours come from the mood palette, so the screen matches Home.
  static MoodVisual _accent(NotificationKind k) => MoodVisual.of(switch (k) {
    NotificationKind.memory => Mood.romantic,
    NotificationKind.mood => Mood.calm,
    NotificationKind.loveNote => Mood.loved,
    NotificationKind.capsule => Mood.emotional,
    NotificationKind.hug => Mood.needAHug,
    NotificationKind.date || NotificationKind.anniversary => Mood.excited,
    NotificationKind.bucket => Mood.happy,
    NotificationKind.question => Mood.flirty,
    NotificationKind.therabot => Mood.emotional,
  });

  static UsIconData _icon(NotificationKind k) => switch (k) {
    NotificationKind.memory => UsIcons.image,
    NotificationKind.mood => UsIcons.mood,
    NotificationKind.loveNote => UsIcons.loveNotes,
    NotificationKind.capsule => UsIcons.timeCapsule,
    NotificationKind.hug => UsIcons.hug,
    NotificationKind.date => UsIcons.calendar,
    NotificationKind.anniversary => UsIcons.heart,
    NotificationKind.bucket => UsIcons.star,
    NotificationKind.question => UsIcons.question,
    NotificationKind.therabot => UsIcons.therabot,
  };

  static String _hint(NotificationTarget t) => switch (t) {
    NotificationTarget.memory => 'Opens the memory',
    NotificationTarget.timeline => 'Opens your timeline',
    NotificationTarget.moodHistory => 'Opens mood history',
    NotificationTarget.loveNotes => 'Opens Love Notes',
    NotificationTarget.timeCapsules => 'Opens Time Capsules',
    NotificationTarget.importantDates => 'Opens special dates',
    NotificationTarget.bucketList => 'Opens the bucket list',
    NotificationTarget.questions => 'Opens your questions',
    NotificationTarget.answerQuestion => "Opens today's question",
    NotificationTarget.therabot => 'Opens Therabot',
    NotificationTarget.chat => 'Opens your chat',
    NotificationTarget.sendHugBack => 'Offers to send a hug back',
    NotificationTarget.countdown => 'Shows your anniversary countdown',
    NotificationTarget.home => 'Back to Home',
  };
}

/// The "New" marker: a word, not only a coloured dot.
class _NewLabel extends StatelessWidget {
  const _NewLabel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.bubble),
      ),
      child: Text(
        'New',
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _AllCaughtUp extends StatelessWidget {
  const _AllCaughtUp({super.key});

  @override
  Widget build(BuildContext context) {
    return const UsEmptyState(
      icon: UsIcons.bell,
      title: "You're all caught up",
      message: 'New memories, notes, moods and special days will show up here.',
    );
  }
}
