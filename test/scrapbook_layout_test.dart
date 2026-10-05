import 'package:final_project/models/memory.dart';
import 'package:final_project/models/scrapbook.dart';
import 'package:final_project/widgets/timeline/scrapbook_layout.dart';
import 'package:flutter_test/flutter_test.dart';

Memory mem(
  String id,
  DateTime date, {
  bool photo = false,
  List<String> tags = const [],
}) => Memory(
  id: id,
  coupleId: 'c',
  authorId: 'a',
  caption: 'Memory $id',
  memoryDate: date,
  tags: tags,
  photos: photo
      ? [const PhotoRef(path: 'c/x.jpg', url: 'https://x/x.jpg')]
      : const [],
);

void main() {
  final memories = [
    mem('a1', DateTime(2026, 10, 17), photo: true),
    mem('a2', DateTime(2026, 10, 5)),
    mem('a3', DateTime(2026, 10, 2), photo: true),
    mem('b1', DateTime(2026, 9, 20), photo: true),
    mem('b2', DateTime(2026, 9, 3), tags: ['anniversary']),
    mem('c1', DateTime(2025, 12, 24), photo: true),
  ];

  test('organize is deterministic', () {
    final one = ScrapbookLayout.organize(memories);
    final two = ScrapbookLayout.organize([...memories.reversed]);
    expect(one.items, two.items);
    expect(one.height, two.height);
  });

  test('organize keeps newest first, grouped by year and month', () {
    final org = ScrapbookLayout.organize(memories);
    expect(
      [for (final m in org.months) '${m.year}-${m.month}'],
      ['2026-10', '2026-9', '2025-12'],
    );
    // A year stamp where each new year starts.
    expect(
      [for (final m in org.months) m.yearRect != null],
      [true, false, true],
    );
    // Within October, newer memories sit higher.
    expect(org.items['a1']!.y, lessThan(org.items['a3']!.y));
    // Older months sit lower on the board.
    expect(org.items['a3']!.y, lessThan(org.items['b1']!.y));
  });

  test('organize keeps chosen frames and sizes memories for them', () {
    final plain = ScrapbookLayout.organize(memories);
    final framed = ScrapbookLayout.organize(
      memories,
      frames: {'a2': FrameStyle.loveNote},
    );
    expect(framed.items['a2']!.frame, FrameStyle.loveNote);
    expect(plain.items['a2']!.frame, isNull);
    // Tilts stay gentle.
    for (final i in framed.items.values) {
      expect(i.rotation.abs(), lessThanOrEqualTo(3));
    }
  });

  test('an automatic scrapbook is exactly the organized one', () {
    final org = ScrapbookLayout.organize(memories);
    final layout = ScrapbookLayout.compose(
      memories: memories,
      saved: const {},
      customized: false,
    );
    for (final p in layout.pieces) {
      expect(p.item, org.items[p.memory.id]);
      expect(p.isNew, isFalse);
    }
  });

  test('new memories wait in the New strip; nothing else moves', () {
    final org = ScrapbookLayout.organize(memories);
    final fresh = mem('z9', DateTime(2026, 10, 30), photo: true);
    final layout = ScrapbookLayout.compose(
      memories: [...memories, fresh],
      saved: org.items,
      customized: true,
    );
    final newPiece = layout.pieceOf('z9')!;
    expect(newPiece.isNew, isTrue);
    expect(layout.newStripRect, isNotNull);
    // Every placed memory keeps its saved place.
    for (final m in memories) {
      expect(layout.pieceOf(m.id)!.item, org.items[m.id]);
    }
    // The strip is above everything placed.
    final placedTop = [
      for (final p in layout.pieces)
        if (!p.isNew) p.rect.top,
    ].reduce((a, b) => a < b ? a : b);
    expect(newPiece.rect.bottom, lessThan(placedTop));
  });

  test('the board is wide: months spread sideways, time runs down', () {
    final busy = [
      for (var i = 0; i < 10; i++)
        mem('m$i', DateTime(2026, 8, 28 - i), photo: i.isEven),
      ...memories,
    ];
    final org = ScrapbookLayout.organize(busy);
    // Every memory inside the range the database allows.
    for (final i in org.items.values) {
      expect(i.x, inInclusiveRange(ScrapbookLayout.minX, ScrapbookLayout.maxX));
      expect(
        i.x + i.width,
        lessThanOrEqualTo(ScrapbookLayout.maxX + ScrapbookLayout.maxWidth),
      );
    }
    // A busy month uses far more than the old 400-unit page.
    final august = org.months.firstWhere((m) => m.month == 8);
    expect(august.area.width, greaterThan(700));
    // Months still run down the board, newest first.
    for (var i = 1; i < org.months.length; i++) {
      expect(org.months[i].top, greaterThan(org.months[i - 1].top));
    }
  });

  test('the drawn content box covers every memory', () {
    final layout = ScrapbookLayout.compose(
      memories: memories,
      saved: const {},
      customized: false,
    );
    for (final p in layout.pieces) {
      expect(layout.contentRect.inflate(1).contains(p.rect.topLeft), isTrue);
      expect(
        layout.contentRect.inflate(1).contains(p.rect.bottomRight),
        isTrue,
      );
    }
    // The canvas spans the whole board sideways.
    expect(layout.width, greaterThanOrEqualTo(ScrapbookLayout.boardWidth));
  });

  test('frames suit the memory', () {
    expect(FrameStyle.forKind(ContentKind.photo), contains(FrameStyle.film));
    expect(
      FrameStyle.forKind(ContentKind.text),
      isNot(contains(FrameStyle.polaroid)),
    );
    expect(FrameStyle.forKind(ContentKind.event), contains(FrameStyle.ticket));
    // A chosen frame that no longer suits (photo removed) falls back.
    final text = mem('t', DateTime(2026));
    expect(effectiveFrame(text, FrameStyle.polaroid, 1), FrameStyle.sticky);
  });

  test('photo frames keep a sensible shape at any allowed width', () {
    final photo = memories.first;
    for (final f in FrameStyle.forKind(ContentKind.photo)) {
      for (final w in [110.0, 178.0, 300.0, 360.0]) {
        final h = ScrapbookLayout.frameHeight(f, w, photo);
        expect(h / w, inInclusiveRange(0.4, 1.6), reason: '$f at $w');
      }
    }
  });

  test('saved values stay inside the database limits', () {
    const wild = LayoutItem(
      memoryId: 'm',
      x: -900,
      y: -5000,
      width: 1000,
      rotation: 40,
      z: 1 << 30,
    );
    final row = wild.toRow('c');
    expect(row['x'], -400);
    expect(row['y'], -2000);
    expect(row['width'], 380);
    expect(row['rotation'], 6);
    expect(row['z_index'], 100000);
  });
}
