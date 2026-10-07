import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/mood_visual.dart';

import '../../theme/app_spacing.dart';
import '../../utils/anniversary.dart';
import '../../utils/special_events.dart';
import '../atoms/avatar_circle.dart';
import '../effects/motion.dart';
import '../home/mood_particles.dart';
import '../atoms/us_icon.dart';

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

  static const _plumTop = Color(0xFF6E2D61);
  static const _plumMid = Color(0xFF4B1D47);
  static const _plumBottom = Color(0xFF2B1029);
  static const _cream = Color(0xFFFFF3EC);
  static const _pink = Color(0xFFF6A9C1);
  static const _rose = Color(0xFFEF6F98);

  UsIconData get _icon => switch (event.kind) {
    SpecialEventKind.anniversary => UsIcons.heartFilled,
    SpecialEventKind.monthsary => UsIcons.heart,
    SpecialEventKind.partnerBirthday ||
    SpecialEventKind.myBirthday => UsIcons.tagCelebration,
    SpecialEventKind.valentines => UsIcons.flower,
    SpecialEventKind.custom => UsIcons.calendar,
  };

  String get _partner => partnerName ?? 'your partner';

  /// "days until"
  String get _lead => '${event.daysUntil == 1 ? 'day' : 'days'} until';

  /// "your 3rd monthsary", highlighted after [_lead].
  String get _what => switch (event.kind) {
    SpecialEventKind.anniversary => 'your ${ordinal(event.count)} anniversary',
    SpecialEventKind.monthsary => 'your ${ordinal(event.count)} monthsary',
    SpecialEventKind.partnerBirthday => '$_partner\'s birthday',
    SpecialEventKind.myBirthday => 'your birthday',
    SpecialEventKind.valentines => 'Valentine\'s Day',
    SpecialEventKind.custom => event.title,
  };

  /// "Happy 1st Anniversary"
  String get _celebration => switch (event.kind) {
    SpecialEventKind.anniversary => 'Happy ${ordinal(event.count)} Anniversary',
    SpecialEventKind.monthsary => 'Happy ${ordinal(event.count)} Monthsary',
    SpecialEventKind.partnerBirthday =>
      partnerName == null
          ? 'It\'s your partner\'s birthday!'
          : 'Happy Birthday, $partnerName!',
    SpecialEventKind.myBirthday => 'Happy Birthday, $myName!',
    SpecialEventKind.valentines => 'Happy Valentine\'s Day',
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
          event.isToday ? 'A day to remember' : 'Counting down together',
          event.repeatsYearly
              ? 'Every ${monthDay(event.date)}'
              : 'Just the two of you',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final ringSize = narrow ? 84.0 : 96.0;
    final (supportTitle, supportLine) = _support;
    final progress = event.progress;
    final percent = progress == null
        ? null
        : event.isToday
        ? 100
        : (progress * 100).round().clamp(0, 99);

    // Cream fading into pink, for the big number and the celebration.
    Widget glowText(Widget child) => ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_cream, Color(0xFFFFC4D6)],
      ).createShader(r),
      child: child,
    );

    final headline = event.isToday
        ? glowText(
            Text(
              _celebration,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: glowText(
                  CountUpText(
                    '${event.daysUntil}',
                    maxLines: 1,
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1,
                      fontSize: narrow ? 56 : 66,
                      letterSpacing: -1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$_lead '),
                    TextSpan(
                      text: _what,
                      style: const TextStyle(
                        color: _pink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _cream.withValues(alpha: 0.9),
                  height: 1.25,
                ),
              ),
            ],
          );

    final dateLine = Row(
      children: [
        const UsIcon(UsIcons.calendar, size: 15, color: _pink),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            fullDate(event.date),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: _cream.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    final ring = SizedBox.square(
      dimension: ringSize,
      child: CustomPaint(
        painter: _GlowRing(
          value: progress ?? 0,
          track: _cream.withValues(alpha: 0.12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: narrow ? 32 : 36,
                height: narrow ? 32 : 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _pink.withValues(alpha: 0.16),
                ),
                alignment: Alignment.center,
                child: UsIcon(
                  event.isToday ? UsIcons.tagCelebration : _icon,
                  color: _pink,
                  size: narrow ? 18 : 20,
                ),
              ),
              if (percent != null || event.isToday) ...[
                const SizedBox(height: 3),
                Text(
                  event.isToday ? 'Today' : '$percent%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _cream,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final eyebrow = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _pink.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _pink.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UsIcon(
            event.isToday ? UsIcons.sparkle : UsIcons.heartFilled,
            size: 11,
            color: _pink,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              event.isToday ? 'TODAY' : 'NEXT SPECIAL DAY',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: _pink,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    final support = Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      decoration: BoxDecoration(
        color: _cream.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cream.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFC4D6), _rose],
              ),
            ),
            alignment: Alignment.center,
            child: UsIcon(_icon, size: 18, color: _plumBottom),
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
                const SizedBox(height: 1),
                Text(
                  hint ?? supportLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: hint != null ? _pink : _cream.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            UsIcon(UsIcons.chevronRight, color: _cream.withValues(alpha: 0.6)),
        ],
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Partners(
              myName: myName,
              myPhoto: myPhoto,
              partnerName: partnerName,
              partnerPhoto: partnerPhoto,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: eyebrow),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  headline,
                  const SizedBox(height: AppSpacing.sm),
                  // The short accent bar the mood hero uses.
                  Container(
                    width: 28,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _rose,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
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
        support,
      ],
    );

    final radius = BorderRadius.circular(AppRadius.hero);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: _plumBottom.withValues(alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: _rose.withValues(alpha: 0.12),
            blurRadius: 36,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Material(
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        color: _plumBottom,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_plumTop, _plumMid, _plumBottom],
              stops: [0, 0.5, 1],
            ),
            border: Border.all(color: _pink.withValues(alpha: 0.14)),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                // A soft pink glow behind the ring.
                Positioned(
                  right: -50,
                  top: 10,
                  child: IgnorePointer(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _rose.withValues(alpha: 0.30),
                            _rose.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // The same drifting hearts as the mood hero.
                const Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: MoodParticlesLayer(
                        style: MoodParticles.hearts,
                        color: _pink,
                      ),
                    ),
                  ),
                ),
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

/// The progress ring: a pink gradient arc with a soft glow.
class _GlowRing extends CustomPainter {
  _GlowRing({required this.value, required this.track});

  final double value;
  final Color track;

  static const _stroke = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(_stroke / 2 + 2);
    canvas.drawArc(
      arcRect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke,
    );
    final sweep = 2 * math.pi * value.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    final shader = const SweepGradient(
      transform: GradientRotation(-math.pi / 2),
      colors: [
        Color(0xFFFFC4D6),
        SpecialEventCard._pink,
        SpecialEventCard._rose,
        Color(0xFFFFC4D6),
      ],
    ).createShader(rect);
    // Glow underneath, then the crisp arc.
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = SpecialEventCard._rose.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke + 2
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GlowRing old) => old.value != value || old.track != track;
}

/// You and your partner: two overlapping photos joined by a little heart.
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
  static const _ring = 2.0;
  static const _overlap = 10.0;

  @override
  Widget build(BuildContext context) {
    const outer = _size + 2 * _ring;
    Widget ringed(String name, String? url) => Container(
      padding: const EdgeInsets.all(_ring),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFFC4D6), SpecialEventCard._rose],
        ),
      ),
      child: AvatarCircle(
        name: name,
        imageUrl: url,
        size: _size,
        background: const Color(0xFFF3D8DF),
      ),
    );

    final partner = partnerName;
    final width = partner == null ? outer : 2 * outer - _overlap;
    return Semantics(
      label: partner == null ? 'You' : 'You and $partner',
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: outer + 4,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (partner != null)
                Positioned(
                  left: outer - _overlap,
                  child: ringed(partner, partnerPhoto),
                ),
              ringed(myName, myPhoto),
              if (partner != null)
                Positioned(
                  left: width / 2 - 8,
                  bottom: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: SpecialEventCard._plumMid,
                    ),
                    alignment: Alignment.center,
                    child: const UsIcon(
                      UsIcons.heartFilled,
                      size: 10,
                      color: SpecialEventCard._rose,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
