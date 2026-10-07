import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/therabot.dart';
import '../../theme/app_spacing.dart';
import '../../theme/us_palette.dart';
import '../atoms/app_button.dart';
import '../effects/motion.dart';
import '../effects/smooth_scroll.dart';
import '../atoms/us_icon.dart';

/// The exact Therabot subtitle, shown wherever Therabot introduces itself.
const therabotSubtitle = 'A private relationship reflection assistant';

/// Therabot's background: the plain dark page, nothing moving. Therabot is
/// the quietest place in USpace.
class TherabotBackground extends StatelessWidget {
  const TherabotBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Theme.of(context).colorScheme.surface, child: child);
}

/// A plain Therabot card: flat, one hairline edge, no glow. [selected]
/// marks your own pick with a rose edge. ([radius] is kept for callers.)
BoxDecoration therabotCardDecoration({
  bool selected = false,
  double radius = AppRadius.card,
}) => BoxDecoration(
  color: UsPalette.card,
  borderRadius: BorderRadius.circular(AppRadius.card),
  border: Border.all(
    color: selected ? UsPalette.rose : UsPalette.line,
    width: selected ? 1.4 : 1,
  ),
);

/// A Therabot page: a readable column centred on wide screens, like the
/// "Let's work it out" pages.
class TherabotPage extends StatelessWidget {
  const TherabotPage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.onRefresh,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget list(ScrollController scroll) => ListView(
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SmoothScroll(
        builder: (scroll) => onRefresh == null
            ? list(scroll)
            : RefreshIndicator(onRefresh: onRefresh!, child: list(scroll)),
      ),
    );
  }
}

/// A soft, rounded card. [tinted] uses the blush container colour for the
/// warm moments; otherwise it is the white outlined card used across USpace.
class TherabotCard extends StatelessWidget {
  const TherabotCard({
    super.key,
    required this.child,
    this.label,
    this.tinted = false,
    this.tentative = false,
  });

  final Widget child;
  final String? label;
  final bool tinted;

  /// A quieter, flatter card (no fill, faint edge, no shadow) for things
  /// that are only possibilities, never facts.
  final bool tentative;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: tinted
            ? scheme.primaryContainer
            : tentative
            ? scheme.surface
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: tinted
            ? null
            : Border.all(
                color: tentative
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                    : scheme.outline,
                width: tentative ? 1.2 : 1,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) ...[
            Text(
              label!.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: tinted
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          child,
        ],
      ),
    );
  }
}

/// "Therabot" with its subtitle, the way it introduces itself.
class TherabotHeader extends StatelessWidget {
  const TherabotHeader({super.key, this.caption});

  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: UsIcon(UsIcons.therabot,
                color: scheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Therabot', style: theme.textTheme.titleLarge),
                  Text(
                    therabotSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (caption != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            caption!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// A small lock line: what stays private. Calm, not a warning.
class PrivacyNote extends StatelessWidget {
  const PrivacyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UsIcon(UsIcons.lock, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// How long the session stays open, said gently. Updates every minute.
class ExpiryNote extends StatefulWidget {
  const ExpiryNote({super.key, required this.expiresAt});

  final DateTime expiresAt;

  @override
  State<ExpiryNote> createState() => _ExpiryNoteState();
}

class _ExpiryNoteState extends State<ExpiryNote> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        UsIcon(UsIcons.history, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            expiryText(widget.expiresAt, DateTime.now()),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Open for about 18 more hours. Private answers clear after that."
String expiryText(DateTime expiresAt, DateTime now) {
  final left = expiresAt.difference(now);
  if (left.isNegative) return 'This session has finished its 24 hours.';
  final String span;
  if (left.inHours >= 2) {
    span = 'about ${left.inHours} more hours';
  } else if (left.inMinutes >= 60) {
    span = 'about an hour more';
  } else if (left.inMinutes >= 2) {
    span = '${left.inMinutes} more minutes';
  } else {
    span = 'a moment more';
  }
  return 'Open for $span. Private answers are cleared after that.';
}

/// Shown while Therabot is writing: a still leaf and a few calm lines.
class TherabotThinking extends StatefulWidget {
  const TherabotThinking({super.key, required this.lines});

  final List<String> lines;

  @override
  State<TherabotThinking> createState() => _TherabotThinkingState();
}

class _TherabotThinkingState extends State<TherabotThinking> {
  int _line = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted) setState(() => _line = (_line + 1) % widget.lines.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      label: 'Therabot is writing',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
        child: Column(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: UsIcon(
                  UsIcons.therabot,
                  color: scheme.onSurfaceVariant,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AnimatedSwitcher(
              duration: Duration(milliseconds: motionOff(context) ? 0 : 450),
              child: Text(
                widget.lines[_line],
                key: ValueKey(_line),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A friendly error with a way forward.
class TherabotErrorView extends StatelessWidget {
  const TherabotErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TherabotCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(message, style: theme.textTheme.bodyLarge),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Try again',
              variant: AppButtonVariant.outlined,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

/// A list of short lines with a quiet marker.
/// AI-written reflection text with "Partner 1" / "Partner 2" shown as the
/// partners' usernames (see [TherabotNames]). The text itself is unchanged;
/// only the labels it already contains are rendered as names.
class PartnerText extends StatelessWidget {
  const PartnerText(this.text, {super.key, this.names, this.style});

  final String text;
  final TherabotNames? names;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final n = names;
    if (n == null) return Text(text, style: style);
    final nameStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: style?.color,
    );
    return Text.rich(
      TextSpan(
        children: [
          for (final s in n.segments(text))
            TextSpan(text: s.text, style: s.partner == null ? null : nameStyle),
        ],
      ),
      style: style,
    );
  }
}

class SoftList extends StatelessWidget {
  const SoftList({
    super.key,
    required this.items,
    this.italic = false,
    this.marker = '•',
    this.names,
  });

  final List<String> items;
  final bool italic;
  final String marker;

  /// Set for AI-written items, so partner labels show as usernames.
  final TherabotNames? names;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge?.copyWith(
      fontStyle: italic ? FontStyle.italic : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    marker,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: PartnerText(item, names: names, style: style),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The four next steps, always all four, always the same size and colour.
/// Nothing is highlighted, recommended or ranked; only YOUR own pick gets
/// a check mark once you have made it.
class NextStepGrid extends StatelessWidget {
  const NextStepGrid({
    super.key,
    required this.selected,
    required this.onTap,
    this.busy = false,
  });

  final TherabotChoice? selected;
  final ValueChanged<TherabotChoice> onTap;
  final bool busy;

  /// Every tile is exactly this tall (grown with the text size), so no step
  /// looks bigger than another.
  static const tileHeight = 132.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0);
    return LayoutBuilder(
      builder: (context, box) {
        const gap = AppSpacing.sm;
        // Large text: one tile per row, still all the same size.
        final columns = scale > 1.3 ? 1 : 2;
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        final height = tileHeight * scale;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in TherabotChoice.values)
              SizedBox(
                width: width,
                height: height,
                child: Semantics(
                  button: true,
                  selected: c == selected,
                  label: '${c.label}. ${c.blurb}',
                  excludeSemantics: true,
                  child: Material(
                    color: scheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      side: BorderSide(
                        color: c == selected ? scheme.primary : scheme.outline,
                        width: c == selected ? 1.6 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: busy ? null : () => onTap(c),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                UsIcon(c.icon, size: 26, color: scheme.primary),
                                const Spacer(),
                                if (c == selected)
                                  UsIcon(UsIcons.check,
                                    size: 18,
                                    color: scheme.primary,
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(c.label, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Expanded(
                              child: Text(
                                c.blurb,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Short phrases (like needs) as soft pills that wrap onto several lines,
/// so nothing a person wrote is cut off.
class SoftPills extends StatelessWidget {
  const SoftPills({
    super.key,
    required this.items,
    this.onTinted = false,
    this.names,
  });

  final List<String> items;

  /// Set for AI-written items, so partner labels show as usernames.
  final TherabotNames? names;

  /// Sitting on a tinted card: use the white pill so it stands out.
  final bool onTinted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: onTinted
                  ? scheme.surfaceContainerHighest
                  : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.bubble),
            ),
            child: PartnerText(
              item,
              names: names,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onTinted ? scheme.onSurface : scheme.onPrimaryContainer,
              ),
            ),
          ),
      ],
    );
  }
}

/// Safety mode, for the person whose words were flagged, and only them.
/// The normal flow stops: no summary, no shared reflection, no common
/// ground, no "make up" prompts. [message] is the server's fixed text.
class TherabotSafetyView extends StatelessWidget {
  const TherabotSafetyView({
    super.key,
    required this.message,
    required this.onDone,
  });

  final String message;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TherabotCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UsIcon(UsIcons.breathe, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      "Let's pause here",
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SelectableText(message, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const PrivacyNote(
          'This stays with you. Your partner only sees that the session ended.',
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(label: 'Back to USpace', onPressed: onDone, fullWidth: true),
      ],
    );
  }
}

void therabotToast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
