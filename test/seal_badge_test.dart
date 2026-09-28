import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/widgets/atoms/seal_badge.dart';

void main() {
  testWidgets('SealBadge draws at the requested size with its letter',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: SealBadge(size: 96))),
    ));

    expect(find.text('S'), findsOneWidget);
    expect(tester.getSize(find.byType(SealBadge)), const Size(96, 96));
  });

  testWidgets('broken state still shows the letter', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(child: SealBadge(state: SealState.broken)),
      ),
    ));
    expect(find.text('S'), findsOneWidget);
  });
}
