import 'package:flutter/material.dart';

import '../../models/mood.dart';
import '../../models/mood_visual.dart';
import '../../theme/app_spacing.dart';
import '../atoms/fit_label.dart';
import '../atoms/soft_tile.dart';
import 'mood_art.dart';

/// The mood picker on Home: the eight moods in one row that scrolls
/// sideways, the next tile peeking in at the edge. Tapping one only
/// previews it (see MoodHero); nothing is saved here.
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
  static const _tileWidth = 72.0;
  static const _artSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moods = Mood.selectableMoods;
    final labelWidth = _tileWidth - (AppSpacing.xs + SoftTile.borderWidth) * 2;
    // No label here: the "Today's mood" heading above already names it.
    return Semantics(
      container: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // Lets the selected outline and shadow show at the ends.
        clipBehavior: Clip.none,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < moods.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                SizedBox(
                  width: _tileWidth,
                  child: _tile(context, theme, moods[i], _artSize, labelWidth),
                ),
              ],
            ],
          ),
        ),
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
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0,
              color: isSelected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
