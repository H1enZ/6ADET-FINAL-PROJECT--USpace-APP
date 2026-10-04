import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../utils/anniversary.dart';
import '../../utils/special_events.dart';
import '../atoms/avatar_circle.dart';
import '../atoms/unlock_ring.dart';
import '../effects/motion.dart';

/// The plum card on Home that counts down to the nearest special day:
/// a monthsary, an anniversary, either birthday, Valentine's Day or one of
/// the couple's own dates (see [nearestEvent]). On the day itself it turns
/// into a quiet celebration.
///
/// It stays deep plum in both themes, like a printed keepsake.
class SpecialEventCard extends StatelessWidget {
  const SpecialEventCard({
    super.key,
    required this.event,
    required this.myName,
    this.myPhoto,
    this.partnerName,
    this.partnerPhoto,
    this.together,
    this.hint,
    this.onTap,
  });

  final SpecialEvent event;

  /// First names, as shown in the wording ("Ana's birthday").
  final String myName;
  final String? partnerName;
  final String? myPhoto;
  final String? partnerPhoto;

  /// The day they got together, if set. Shown under anniversaries and
  /// monthsaries only.
  final DateTime? together;

  /// Replaces the supporting line, e.g. "Tap to add your anniversary".
  final String? hint;
  final VoidCallback? onTap;

  static const _plumTop = Color(0xFF5B2A56);
  static const _plumBottom = Color(0xFF34162F);
  static const _cream = Color(0xFFFFF3EC);
  static const _pink = Color(0xFFF6A9C1);

  IconData get _icon => switch (event.kind) {
    SpecialEventKind.anniversary => Icons.favorite_rounded,
    SpecialEventKind.monthsary => Icons.favorite_border_rounded,
    SpecialEventKind.partnerBirthday ||
    SpecialEventKind.myBirthday => Icons.cake_rounded,
    SpecialEventKind.valentines => Icons.local_florist_rounded,
    SpecialEventKind.custom => Icons.event_rounded,
  };

  String get _partner => partnerName ?? 'your partner';

  /// "days until your 3rd monthsary"
  String get _countdownLine {
    final unit = event.daysUntil == 1 ? 'day' : 'days';
    final what = switch (event.kind) {
      SpecialEventKind.anniversary =>
        'your ${ordinal(event.count)} anniversary',
      SpecialEventKind.monthsary => 'your ${ordinal(event.count)} monthsary',
      SpecialEventKind.partnerBirthday => '$_partner\'s birthday',
      SpecialEventKind.myBirthday => 'your birthday',
      SpecialEventKind.valentines => 'Valentine\'s Day',
      SpecialEventKind.custom => event.title,
    };
    return '$unit until $what';
  }

  /// "Happy 1st Anniversary ♥"
  String get _celebration => switch (event.kind) {
    SpecialEventKind.anniversary =>
      'Happy ${ordinal(event.count)} Anniversary ♥',
    SpecialEventKind.monthsary => 'Happy ${ordinal(event.count)} Monthsary ♥',
    SpecialEventKind.partnerBirthday =>
      partnerName == null
          ? 'It\'s your partner\'s birthday!'
          : 'Happy Birthday, $partnerName!',
    SpecialEventKind.myBirthday => 'Happy Birthday, $myName!',
    SpecialEventKind.valentines => 'Happy Valentine\'s Day ♥',
    SpecialEventKind.custom => '${event.title} is today!',
  };

  /// The two lines at the bottom: what the day is about.
  (String, String) get _support {
    final age = event.count > 0 && event.count < 130 ? event.count : null;
    switch (event.kind) {
      case SpecialEventKind.anniversary:
      case SpecialEventKind.monthsary:
        final since = together;
        if (since == null) return ('Your love story', 'Every day counts');
        final today = event.date.subtract(Duration(days: event.daysUntil));
        final days = today
            .difference(DateTime.utc(since.year, since.month, since.day))
            .inDays;
        return (
          'Together for $days ${days == 1 ? 'day' : 'days'}',
          'Since ${fullDate(since)}',
        );
      case SpecialEventKind.partnerBirthday:
        return (
          partnerName == null
              ? 'Your partner\'s special day'
              : 'Celebrating $partnerName',
          age == null ? 'Your partner\'s special day' : 'Turning $age',
        );
      case SpecialEventKind.myBirthday:
        return (
          'Your special day',
          age == null ? 'Make a wish' : 'Turning $age',
        );
      case SpecialEventKind.valentines:
        return ('Our day of love', 'Every February 14');
      case SpecialEventKind.custom:
        return (
          event.isToday
              ? 'A day to remember'
              : 'Counting down together',
          event.repeatsYearly
              ? 'Every ${monthDay(event.date)}'
              : 'Just the two of you',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final ringSize = narrow ? 80.0 : 92.0;
    final (supportTitle, supportLine) = _support;
    final progress = event.progress;
    final percent = progress == null
        ? null
        : event.isToday
        ? 100
        : (progress * 100).round().clamp(0, 99);

    final headline = event.isToday
        ? Text(
            _celebration,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: _cream,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: CountUpText(
                  '${event.daysUntil}',
                  maxLines: 1,
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: _cream,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    fontSize: narrow ? 52 : 60,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _countdownLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _cream.withValues(alpha: 0.92),
                  height: 1.25,
                ),
              ),
            ],
          );

    final dateLine = Row(
      children: [
        Icon(Icons.calendar_today_rounded, size: 14, color: _pink),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            fullDate(event.date),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: _cream.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );

    final ring = UnlockRing(
      elapsedFraction: progress ?? 0,
      size: ringSize,
      strokeWidth: 6,
      color: _pink,
      trackColor: _cream.withValues(alpha: 0.14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            event.isToday ? Icons.celebration_rounded : _icon,
            color: _pink,
            size: narrow ? 22 : 26,
          ),
          if (percent != null || event.isToday) ...[
            const SizedBox(height: 2),
            Text(
              event.isToday ? 'Today' : '$percent%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: _cream,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );

    final partners = _Partners(
      myName: myName,
      myPhoto: myPhoto,
      partnerName: partnerName,
      partnerPhoto: partnerPhoto,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            partners,
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                event.isToday ? 'TODAY' : 'NEXT SPECIAL DAY',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _pink,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  headline,
                  const SizedBox(height: AppSpacing.sm),
                  dateLine,
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            ring,
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(height: 1, color: _cream.withValues(alpha: 0.12)),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pink.withValues(alpha: 0.16),
              ),
              child: Icon(_icon, size: 16, color: _pink),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supportTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: _cream,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    hint ?? supportLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: hint != null
                          ? _pink
                          : _cream.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: _cream.withValues(alpha: 0.6),
              ),
          ],
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: _plumBottom.withValues(alpha: dark ? 0.5 : 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        color: _plumBottom,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_plumTop, _plumBottom],
            ),
            border: dark
                ? Border.all(color: _cream.withValues(alpha: 0.08))
                : null,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                // Decorative hearts, behind everything.
                const Positioned.fill(child: _Hearts()),
                Padding(
                  padding: EdgeInsets.all(
                    narrow ? AppSpacing.lg : AppSpacing.xl,
                  ),
                  child: content,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// You and your partner, two small overlapping photos.
class _Partners extends StatelessWidget {
  const _Partners({
    required this.myName,
    this.myPhoto,
    this.partnerName,
    this.partnerPhoto,
  });

  final String myName;
  final String? myPhoto;
  final String? partnerName;
  final String? partnerPhoto;

  static const _size = 32.0;
  static const _overlap = 10.0;

  @override
  Widget build(BuildContext context) {
    Widget ringed(String name, String? url) => Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: SpecialEventCard._plumTop,
      ),
      child: AvatarCircle(
        name: name,
        imageUrl: url,
        size: _size,
        background: const Color(0xFFF3D8DF),
      ),
    );

    final partner = partnerName;
    return Semantics(
      label: partner == null ? 'You' : 'You and $partner',
      child: ExcludeSemantics(
        child: SizedBox(
          width: partner == null ? _size + 4 : 2 * (_size + 4) - _overlap,
          height: _size + 4,
          child: Stack(
            children: [
              if (partner != null)
                Positioned(
                  left: _size + 4 - _overlap,
                  child: ringed(partner, partnerPhoto),
                ),
              ringed(myName, myPhoto),
            ],
          ),
        ),
      ),
    );
  }
}

/// A few faint hearts scattered across the card.
class _Hearts extends StatelessWidget {
  const _Hearts();

  @override
  Widget build(BuildContext context) {
    Widget heart(double size, double alpha) => Icon(
      Icons.favorite_rounded,
      size: size,
      color: SpecialEventCard._pink.withValues(alpha: alpha),
    );
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          children: [
            Positioned(right: 18, top: 10, child: heart(18, 0.14)),
            Positioned(right: 54, top: 30, child: heart(10, 0.12)),
            Positioned(left: 92, top: 14, child: heart(9, 0.12)),
            Positioned(right: -10, bottom: 56, child: heart(46, 0.06)),
            Positioned(left: -12, bottom: -10, child: heart(40, 0.05)),
          ],
        ),
      ),
    );
  }
}
