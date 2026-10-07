import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_spacing.dart';
import '../atoms/app_button.dart';
import '../atoms/us_icon.dart';

/// The one USpace empty state: art (or a quiet icon), a short title, a
/// gentle line and an optional action. Screens with their own expressive
/// art (Timeline, Love Notes, Time Capsules) pass it in as [art] and can
/// tint the text with [titleStyle] and [mutedColor] to suit their paper.
class UsEmptyState extends StatelessWidget {
  const UsEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.art,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.titleStyle,
    this.mutedColor,
  });

  final String title;
  final String? message;

  /// A USpace icon on a soft rose disc, used when there is no [art].
  final UsIconData? icon;
  final Widget? art;
  final String? actionLabel;
  final UsIconData? actionIcon;
  final VoidCallback? onAction;
  final TextStyle? titleStyle;
  final Color? mutedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final picture =
        art ??
        (icon == null
            ? null
            : Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.14),
                ),
                child: UsIcon(icon!, size: 32, color: scheme.primary),
              ));

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: AppSpacing.huge,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.formMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (picture != null) ...[
                ExcludeSemantics(child: picture),
                const SizedBox(height: AppSpacing.lg),
              ],
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: titleStyle ?? theme.textTheme.titleMedium,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: mutedColor ?? scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: actionLabel!,
                  usIcon: actionIcon,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The one USpace error notice: an alert icon, a plain sentence and
/// "Try again". It is announced as soon as it appears, so the retry is
/// reachable without pull to refresh. [centered] is for a screen that has
/// nothing else to show; otherwise it sits at the top of the content.
class UsErrorNotice extends StatelessWidget {
  const UsErrorNotice({
    super.key,
    required this.message,
    this.onRetry,
    this.centered = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final retry = onRetry == null
        ? null
        : AppButton(
            label: 'Try again',
            variant: AppButtonVariant.outlined,
            onPressed: onRetry,
          );

    if (centered) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.formMaxWidth,
            ),
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AlertIcon(size: 32, color: scheme.error),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (retry != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    retry,
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: scheme.error.withValues(alpha: 0.32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: _AlertIcon(size: 20, color: scheme.error),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(message, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
            if (retry != null) ...[
              const SizedBox(height: AppSpacing.md),
              Padding(padding: const EdgeInsets.only(left: 32), child: retry),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small centred spinner for loading inside a card or section, where a
/// page skeleton would be too big.
class UsInlineLoader extends StatelessWidget {
  const UsInlineLoader({super.key, this.padding = AppSpacing.xl});

  final double padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            semanticsLabel: 'Loading',
          ),
        ),
      ),
    );
  }
}

/// The one USpace snackbar: a short message, with an alert icon when
/// something went wrong. Replaces any message already showing.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showUsMessage(
  BuildContext context,
  String text, {
  bool error = false,
  SnackBarAction? action,
  Duration? duration,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  final scheme = Theme.of(context).colorScheme;
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      action: action,
      duration: duration ?? const Duration(milliseconds: 4000),
      content: error
          ? Row(
              children: [
                _AlertIcon(size: 20, color: scheme.error),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(text)),
              ],
            )
          : Text(text),
    ),
  );
}

// The alert icon is drawn from this copy of assets/icons/alert-circle.svg,
// not the asset, so it still shows when the network is down (which is
// exactly when most errors appear and the asset may never have loaded).
const _alertSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
    'stroke="#000" stroke-width="1.75" stroke-linecap="round" '
    'stroke-linejoin="round"><circle cx="12" cy="12" r="8.5"/>'
    '<path d="M12 7.5v5.5"/><path d="M12 16.4v.1"/></svg>';

class _AlertIcon extends StatelessWidget {
  const _AlertIcon({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.string(
      _alertSvg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    ),
  );
}
