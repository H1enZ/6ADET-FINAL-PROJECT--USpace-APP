import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../atoms/fit_label.dart';
import '../atoms/soft_tile.dart';

class QuickAction {
  const QuickAction(
    this.label,
    this.icon,
    this.onTap, {
    this.badge,
    this.disabledReason,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  /// A small dot on the icon, and this text read by screen readers
  /// (e.g. "your partner answered"). Null for no dot.
  final String? badge;

  /// Read by screen readers when [onTap] is null, so a dimmed tile says why.
  final String? disabledReason;
}

/// Shortcut tiles in rows of equal height: 4 per row on phones, 8 on wide
/// screens, so the eight Home shortcuts sit in two tidy rows (or one).
class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.actions});

  final List<QuickAction> actions;

  static const _gap = AppSpacing.sm;
  static const double _iconCircle = 40;
  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final perRow = box.maxWidth >= AppSpacing.compactMax ? 8 : 4;
        final tileWidth = (box.maxWidth - _gap * (perRow - 1)) / perRow;
        // Inside the tile: horizontal padding plus the 2 px border each side.
        final labelWidth =
            tileWidth - (AppSpacing.xs + SoftTile.borderWidth) * 2;
        final rows = <List<QuickAction>>[
          for (var i = 0; i < actions.length; i += perRow)
            actions.sublist(i, (i + perRow).clamp(0, actions.length)),
        ];
        return Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: _gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < perRow; i++) ...[
                      if (i > 0) const SizedBox(width: _gap),
                      Expanded(
                        // An empty slot keeps a short last row aligned.
                        child: i < rows[r].length
                            ? _tile(theme, scheme, rows[r][i], labelWidth)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _tile(
    ThemeData theme,
    ColorScheme scheme,
    QuickAction a,
    double labelWidth,
  ) {
    final enabled = a.onTap != null;
    return SoftTile(
      semanticLabel: a.label,
      semanticValue: a.badge,
      semanticHint: enabled ? null : a.disabledReason,
      onTap: a.onTap,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.xs,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: _iconCircle,
            height: _iconCircle,
            decoration: BoxDecoration(
              color: enabled
                  ? scheme.primaryContainer
                  : scheme.outline.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Badge(
              isLabelVisible: a.badge != null,
              backgroundColor: scheme.primary,
              smallSize: 9,
              child: Icon(
                a.icon,
                size: _iconSize,
                color: enabled ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FitLabel(
            a.label,
            maxWidth: labelWidth,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
