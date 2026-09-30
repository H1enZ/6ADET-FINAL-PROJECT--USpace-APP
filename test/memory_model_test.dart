import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/models/memory.dart';

Map<String, dynamic> row({String? cover, List<String> tags = const []}) => {
      'id': 'm1',
      'couple_id': 'c1',
      'author_id': 'u1',
      'caption': 'Beach day',
      'memory_date': '2025-07-01',
      'description': 'Sunset swim',
      'location': 'Zambales',
      'tags': tags,
      'photo_path': cover,
      'is_favorite': true,
    };

void main() {
  test('an older memory with one cover photo still has one photo', () {
    final m = Memory.fromMap(row(cover: 'c1/old.jpg'));
    expect(m.photos.map((p) => p.path), ['c1/old.jpg']);
    expect(m.title, 'Beach day');
    expect(m.location, 'Zambales');
    expect(m.isFavorite, isTrue);
  });

  test('memory_photos take over, in order, cover first', () {
    final m = Memory.fromMap(row(cover: 'c1/a.jpg'),
        photoPaths: ['c1/a.jpg', 'c1/b.jpg', 'c1/c.jpg']);
    expect(m.photos.map((p) => p.path), ['c1/a.jpg', 'c1/b.jpg', 'c1/c.jpg']);
  });

  test('no photos at all', () {
    final m = Memory.fromMap(row());
    expect(m.photos, isEmpty);
    expect(m.photoUrl, isNull);
  });

  test('tags are read from the database names; unknown ones are ignored', () {
    final m = Memory.fromMap(row(tags: ['travel', 'first_date', 'party']));
    expect(m.tags, [MemoryTag.travel, MemoryTag.firstDate]);
  });

  test('every tag name matches the database list', () {
    expect(MemoryTag.values.map((t) => t.dbName).toList(),
        ['first_date', 'anniversary', 'travel', 'celebration', 'everyday', 'special']);
  });

  test('photo links are attached without losing the order', () {
    final m = Memory.fromMap(row(), photoPaths: ['c1/a.jpg', 'c1/b.jpg']);
    final signed = m.copyWith(photos: [
      for (final p in m.photos) p.withUrl('https://signed/${p.path}'),
    ]);
    expect(signed.photoUrl, 'https://signed/c1/a.jpg');
    expect(signed.photos.last.url, 'https://signed/c1/b.jpg');
  });
}
