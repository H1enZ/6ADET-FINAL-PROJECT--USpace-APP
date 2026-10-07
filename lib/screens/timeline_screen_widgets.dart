part of 'timeline_screen.dart';

// The Timeline screen's smaller pieces: the connect banner, header,
// board viewport, dates toggle, month labels and the empty state.

class _ConnectBanner extends StatelessWidget {
  const _ConnectBanner({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: 14, right: 4),
    decoration: BoxDecoration(
      color: UsPalette.card.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: NotePalette.rose.withValues(alpha: 0.6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const UsIcon(UsIcons.link, size: 16, color: NotePalette.rose),
        const SizedBox(width: 8),
        Text(
          'Tap another memory to connect',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: NotePalette.cream),
        ),
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(foregroundColor: NotePalette.pink),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.searching,
    required this.editing,
    required this.canEdit,
    required this.onSearch,
    required this.onEdit,
    required this.onAdd,
    this.onUndo,
    this.onArrange,
  });

  final bool searching;
  final bool editing;
  final bool canEdit;
  final VoidCallback onSearch;
  final VoidCallback onEdit;
  final VoidCallback? onAdd;

  /// While editing: Undo (null when there is nothing to undo) and Arrange.
  final VoidCallback? onUndo;
  final VoidCallback? onArrange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Our Timeline',
                          style: NotePalette.display(
                            MediaQuery.sizeOf(context).width < 360 || editing
                                ? 24
                                : 30,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // The heart makes room for the title on narrow phones.
                    if (!editing &&
                        MediaQuery.sizeOf(context).width >= 360) ...[
                      const SizedBox(width: 6),
                      const UsIcon(
                        UsIcons.heart,
                        size: 20,
                        color: NotePalette.rose,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  editing
                      ? 'Tap to select, hold to move.'
                      : 'The little moments that became us.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NotePalette.muted,
                  ),
                ),
              ],
            ),
          ),
          if (editing) ...[
            IconButton(
              tooltip: 'Undo',
              onPressed: onUndo,
              icon: UsIcon(
                UsIcons.undo,
                color: onUndo == null
                    ? NotePalette.muted.withValues(alpha: 0.35)
                    : NotePalette.cream,
              ),
            ),
            // Narrow phones: just the icon, so the title keeps its room.
            if (MediaQuery.sizeOf(context).width < 360)
              IconButton(
                tooltip: 'Arrange',
                onPressed: onArrange,
                icon: const UsIcon(UsIcons.arrange, color: NotePalette.cream),
              )
            else
              OutlinedButton.icon(
                onPressed: onArrange,
                style: OutlinedButton.styleFrom(
                  foregroundColor: NotePalette.cream,
                  side: BorderSide(
                    color: NotePalette.pink.withValues(alpha: 0.45),
                  ),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const UsIcon(UsIcons.arrange, size: 18),
                label: const Text('Arrange'),
              ),
          ] else ...[
            if (canEdit)
              IconButton(
                tooltip: 'Edit scrapbook',
                onPressed: onEdit,
                icon: const UsIcon(UsIcons.edit, color: NotePalette.cream),
              ),
            IconButton(
              tooltip: searching ? 'Close search' : 'Find a memory',
              onPressed: onSearch,
              icon: UsIcon(
                searching ? UsIcons.close : UsIcons.search,
                color: NotePalette.cream,
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Add a memory',
              child: Semantics(
                button: true,
                label: 'Add a memory',
                excludeSemantics: true,
                child: Material(
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    decoration: const BoxDecoration(
                      gradient: NotePalette.buttonGradient,
                    ),
                    child: InkWell(
                      onTap: onAdd,
                      child: const SizedBox.square(
                        dimension: 48,
                        child: Center(
                          child: UsIcon(
                            UsIcons.plus,
                            color: UsPalette.onRose,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The zoomable scrapbook plus what sits on top of it at normal size: month
/// labels when far out, and the Hide / Show dates button.
class _ScrapbookViewport extends StatelessWidget {
  const _ScrapbookViewport({
    required this.layout,
    required this.view,
    required this.viewport,
    required this.minScale,
    required this.maxScale,
    required this.defaultScale,
    required this.editing,
    required this.canvas,
    required this.onInteractionStart,
    required this.onInteractionEnd,
    required this.onMonth,
    required this.hideDates,
    required this.onToggleDates,
    this.overlay,
  });

  final bool hideDates;
  final VoidCallback onToggleDates;

  final ScrapbookLayout layout;
  final TransformationController view;
  final Size viewport;
  final double minScale;
  final double maxScale;
  final double defaultScale;
  final bool editing;
  final Widget canvas;
  final VoidCallback onInteractionStart;
  final VoidCallback onInteractionEnd;
  final void Function(ScrapMonth) onMonth;

  /// The editing toolbar and banners, on top of everything.
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The wall the framed board hangs on: soft plum, seen only above or
        // below a board shorter than the screen.
        const Positioned.fill(child: ColoredBox(color: UsPalette.surface)),
        InteractiveViewer(
          transformationController: view,
          constrained: false,
          minScale: minScale,
          maxScale: maxScale,
          // Room to pull past the edges a little, never to lose the page.
          boundaryMargin: EdgeInsets.symmetric(
            horizontal: viewport.width * 0.5,
            vertical: viewport.height * 0.3,
          ),
          clipBehavior: Clip.none,
          onInteractionStart: (_) => onInteractionStart(),
          onInteractionEnd: (_) => onInteractionEnd(),
          child: RepaintBoundary(child: canvas),
        ),
        // Everything below listens to the view and redraws on its own;
        // the scrapbook itself is never rebuilt while you zoom.
        if (!hideDates)
          Positioned.fill(
            child: _MonthLabels(
              layout: layout,
              view: view,
              viewport: viewport,
              defaultScale: defaultScale,
              onMonth: onMonth,
            ),
          ),
        // Zoomed out: hide or show the dates (above the editing toolbar
        // while editing).
        Positioned(
          right: 12,
          bottom: editing ? 96 : 16,
          child: _DatesToggle(
            view: view,
            defaultScale: defaultScale,
            hidden: hideDates,
            onTap: onToggleDates,
          ),
        ),
        ?overlay,
      ],
    );
  }
}

/// "Hide dates" / "Show dates", only while zoomed out (where the month
/// labels float over the board).
class _DatesToggle extends StatelessWidget {
  const _DatesToggle({
    required this.view,
    required this.defaultScale,
    required this.hidden,
    required this.onTap,
  });

  final TransformationController view;
  final double defaultScale;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: view,
      builder: (context, _) {
        final far = view.value.getMaxScaleOnAxis() < defaultScale * 0.6;
        return IgnorePointer(
          ignoring: !far,
          child: AnimatedOpacity(
            opacity: far ? 1 : 0,
            duration: motionOff(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            child: Material(
              color: UsPalette.card.withValues(alpha: 0.9),
              shape: StadiumBorder(
                side: BorderSide(
                  color: NotePalette.pink.withValues(alpha: 0.35),
                ),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const UsIcon(
                        UsIcons.calendar,
                        size: 18,
                        color: NotePalette.pink,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hidden ? 'Show dates' : 'Hide dates',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: NotePalette.cream,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Far out, each month's paper tag at readable size over its chapter
/// (taking over from the board's own tags, which fade out first). Tap one
/// to zoom into that month. Tags never overlap: crowded ones move down,
/// and any that would fall off screen wait until you zoom in.
class _MonthLabels extends StatelessWidget {
  const _MonthLabels({
    required this.layout,
    required this.view,
    required this.viewport,
    required this.defaultScale,
    required this.onMonth,
  });

  final ScrapbookLayout layout;
  final TransformationController view;
  final Size viewport;
  final double defaultScale;
  final void Function(ScrapMonth) onMonth;

  /// Lettering size of a floating tag (screen pixels).
  static const _size = 16.0;

  /// Room above and below a tag so it is easy to tap.
  static const _pad = 10.0;

  /// A tag's on-screen size, from its text.
  static Size _measure(String label) {
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: AppTypography.monthTag(size: _size),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final size = Size(
      text.width + _size * 1.8 + 4,
      text.height + _size * 0.2 + _pad * 2,
    );
    text.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final still = motionOff(context);
    final sizes = {
      for (final m in layout.months)
        (m.year, m.month): _measure(monthTitle(m.year, m.month)),
    };
    return AnimatedBuilder(
      animation: view,
      builder: (context, _) {
        final m = view.value;
        final s = m.getMaxScaleOnAxis();
        final opacity = floatingTagOpacity(
          farOutProgress(s, defaultScale),
          still: still,
        );
        if (opacity == 0) return const SizedBox.shrink();
        final tr = m.getTranslation();
        final shown = <ScrapMonth>[];
        final boxes = <Rect>[];
        for (final month in layout.months) {
          final size = sizes[(month.year, month.month)]!;
          final top = month.headingRect.top * s + tr.y - _pad;
          if (top < -size.height || top > viewport.height) continue;
          final left = (month.headingRect.left * s + tr.x)
              .clamp(8.0, math.max(8.0, viewport.width - size.width - 8))
              .toDouble();
          shown.add(month);
          boxes.add(Offset(left, top) & size);
        }
        final spots = spreadTags(boxes, maxBottom: viewport.height);
        return Opacity(
          opacity: opacity,
          child: Stack(
            children: [
              for (var i = 0; i < shown.length; i++)
                if (spots[i] case final spot?)
                  Positioned.fromRect(
                    rect: spot,
                    child: _FloatingTag(
                      month: shown[i],
                      onTap: () => onMonth(shown[i]),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _FloatingTag extends StatelessWidget {
  const _FloatingTag({required this.month, required this.onTap});

  final ScrapMonth month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${monthTitle(month.year, month.month)}, ${month.count} memories. Zoom in',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: _MonthLabels._pad),
          child: MonthTag(
            label: monthTitle(month.year, month.month),
            size: _MonthLabels._size,
          ),
        ),
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const QuickActionArtView(QuickActionArt.memory, size: 110),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Our story starts here.',
              textAlign: TextAlign.center,
              style: NotePalette.display(24),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add your first memory together.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: NotePalette.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            NotePrimaryButton(
              label: 'Add a memory',
              icon: UsIcons.plus,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}
