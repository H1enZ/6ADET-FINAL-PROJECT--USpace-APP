import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/theme/us_icons.dart';

void main() {
  test('every chat icon has its SVG in assets/icons', () {
    const chatIcons = [
      UsIcons.send,
      UsIcons.image,
      UsIcons.smile,
      UsIcons.keyboard,
      UsIcons.copy,
      UsIcons.check,
      UsIcons.minusCircle,
      UsIcons.chevronUp,
      UsIcons.lock,
      UsIcons.close,
      UsIcons.heart,
      UsIcons.edit,
      UsIcons.trash,
      UsIcons.plus,
    ];
    for (final icon in chatIcons) {
      expect(File(icon.asset).existsSync(), isTrue, reason: icon.asset);
    }
  });

  test('the icons in us_icons.dart all point at real files', () {
    final source = File('lib/theme/us_icons.dart').readAsStringSync();
    final names = RegExp(
      r"UsIconData\('([a-z0-9-]+)'\)",
    ).allMatches(source).map((m) => m.group(1)!).toList();
    expect(names, isNotEmpty);
    for (final name in names) {
      expect(File('assets/icons/$name.svg').existsSync(), isTrue, reason: name);
    }
  });
}
