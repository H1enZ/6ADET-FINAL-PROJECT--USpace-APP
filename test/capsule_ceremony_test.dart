import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/widgets/capsule/candle_ceremony.dart';
import 'package:final_project/widgets/capsule/monogram_seal.dart';

void main() {
  test('the seal shows the first letter of the sender name', () {
    expect(sealInitial('therabot-d'), 'T');
    expect(sealInitial('  ana '), 'A');
    expect(sealInitial(''), '♥');
  });

  testWidgets('sealing runs to the end and Done closes it', (t) async {
    var done = false;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CapsuleSealingCeremony(
              width: 300,
              initial: 'A',
              letter: 'Dear you,',
              title: 'Our first trip',
              caption: 'Opens 13 Oct',
              onDone: () => done = true,
            ),
          ),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 8));
    await t.tap(find.text('Done'));
    expect(done, isTrue);
  });

  testWidgets('with reduced motion the opening is already finished', (t) async {
    var revealed = false;
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SingleChildScrollView(
              child: CapsuleOpeningCeremony(
                width: 300,
                initial: 'A',
                letter: 'Dear you,',
                onReveal: () => revealed = true,
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.tap(find.text('Tap the letter to read it'));
    expect(revealed, isTrue);
  });
}
