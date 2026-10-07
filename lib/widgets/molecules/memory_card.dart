import 'package:flutter/material.dart';

import '../../models/memory.dart';
import '../../theme/app_spacing.dart';
import '../../utils/anniversary.dart';
import '../atoms/us_icon.dart';

enum MemoryCardLayout { list, grid }

/// Photo, caption, date and favourite heart. A 16:9 photo in a single-column
/// list, 4:3 in the wider grid.
class MemoryCard extends StatelessWidget {
  const MemoryCard({
    super.key,
    required this.memory,
    required this.authorName,
    this.onTap,
    this.onFavourite,
    this.layout = MemoryCardLayout.list,
  });

  final Memory memory;

  /// "you" for your own memories, otherwise your partner's name.
  final String authorName;
  final VoidCallback? onTap;
  final VoidCallback? onFavourite;
  final MemoryCardLayout layout;

  /// Height of the text row under the photo. Grids use it to size each cell.
  static const double footerHeight = 76;

  double get photoAspectRatio =>
      layout == MemoryCardLayout.list ? 16 / 9 : 4 / 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fav = memory.isFavorite;

    return Material(
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: photoAspectRatio,
              child: MemoryPhoto(url: memory.photoUrl),
            ),
            SizedBox(
              height: footerHeight,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.cardPadding,
                  right: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memory.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${longDate(memory.memoryDate)} \u00B7 added by $authorName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: fav
                          ? 'Remove from favourites'
                          : 'Add to favourites',
                      onPressed: onFavourite,
                      icon: UsIcon(
                        fav ? UsIcons.heartFilled : UsIcons.heart,
                        color: fav ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The photo, or a soft placeholder when there is none or it can't load.
class MemoryPhoto extends StatelessWidget {
  const MemoryPhoto({super.key, required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.primaryContainer,
      child: Center(
        child: UsIcon(UsIcons.image, size: 40, color: scheme.primary),
      ),
    );

    if (url == null) return placeholder;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
      errorBuilder: (context, error, stack) => placeholder,
    );
  }
}
