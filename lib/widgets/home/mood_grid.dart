import 'package:flutter/material.dart';

import '../../models/mood.dart';
import '../../models/mood_visual.dart';
import '../../theme/app_spacing.dart';
import '../atoms/fit_label.dart';
import '../atoms/soft_tile.dart';
import 'mood_art.dart';

/// Mood Today: the eight Home moods, two rows of four, at every width.
/// Tapping one only previews it (see MoodHero); nothing is saved here.
class MoodGrid extends StatelessWidget {
  const MoodGrid({
    super.key,
    required this.selected,
    required this.saved,
    required this.onSelect,
  });

  /// The highlighted mood, or null.
  final Mood? selected;

  /// Today's saved mood, so screen readers can tell it from a preview.
  final Mood? saved;
  final ValueChanged<Mood> onSelect;

  static const _gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moods = Mood.selectableMoods; // exactly eight, in grid order
    // No label here: the "Mood today" heading above already names it.
    return Semantics(
      container: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final tileWidth = (box.maxWidth - _gap * 3) / 4;
          final artSize = (tileWidth * 0.62).clamp(32.0, 64.0);
          // Inside the tile: horizontal padding plus the 2 px border each side.
          final labelWidth =
              tileWidth - (AppSpacing.xs + SoftTile.borderWidth) * 2;
          Widget row(List<Mood> four) => IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < four.length; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  Expanded(
                    child: _tile(context, theme, four[i], artSize, labelWidth),
                  ),
                ],
              ],
            ),
          );
          return Column(
            children: [
              row(moods.sublist(0, 4)),
              const SizedBox(height: _gap),
              row(moods.sublist(4, 8)),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    ThemeData theme,
    Mood mood,
    double artSize,
    double labelWidth,
  ) {
    final visual = MoodVisual.of(mood);
    final isSelected = mood == selected;
    return SoftTile(
      semanticLabel: mood.label,
      selected: isSelected,
      exclusiveGroup: true,
      semanticHint: 'Preview',
      semanticValue: mood == saved ? 'shared today' : null,
      selectedColor: visual.accentFor(theme.brightness),
      onTap: () => onSelect(mood),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xs,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MoodArt(visual: visual, size: artSize, semantic: false),
          const SizedBox(height: AppSpacing.xs),
          FitLabel(
            mood.label,
            maxWidth: labelWidth,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
