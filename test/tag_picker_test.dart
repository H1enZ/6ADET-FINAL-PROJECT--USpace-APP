import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/widgets/molecules/tag_picker.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('tapping a pill picks it, tapping again removes it', (t) async {
    var tags = <String>[];
    await t.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, set) => TagPicker(
            selected: tags,
            onChanged: (v) => set(() => tags = v),
          ),
        ),
      ),
    );
    await t.tap(find.text('Travel'));
    await t.pumpAndSettle();
    expect(tags, ['travel']);
    await t.tap(find.text('Travel'));
    await t.pumpAndSettle();
    expect(tags, isEmpty);
  });

  testWidgets('your own tag field opens only when asked', (t) async {
    var tags = <String>[];
    await t.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, set) => TagPicker(
            selected: tags,
            onChanged: (v) => set(() => tags = v),
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    await t.tap(find.text('Your own'));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Monthsary');
    await t.tap(find.text('Add'));
    await t.pumpAndSettle();
    expect(tags, ['Monthsary']);
    // Added: the field closes and the new tag shows as a picked pill.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Monthsary'), findsOneWidget);
  });
}
