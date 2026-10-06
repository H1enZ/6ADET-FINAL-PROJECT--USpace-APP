import 'package:final_project/models/mood.dart';
import 'package:final_project/theme/app_theme.dart';
import 'package:final_project/widgets/home/mood_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts a MoodCard whose mood follows onPick, like Home does, with an
/// optional failure to test the rollback.
class _Host extends StatefulWidget {
  const _Host({
    this.start,
    this.partnerMood,
    this.fail = false,
    this.myNote,
    this.partnerNote,
  });

  final Mood? start;
  final Mood? partnerMood;
  final bool fail;
  final String? myNote;
  final String? partnerNote;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Mood? mood = widget.start;
  late Mood? partner = widget.partnerMood;
  bool busy = false;
  final picks = <Mood>[];

  /// A realtime update of the partner's mood.
  void partnerChanged(Mood m) => setState(() => partner = m);

  Future<void> pick(Mood m) async {
    picks.add(m);
    final previous = mood;
    setState(() {
      mood = m;
      busy = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      if (widget.fail) mood = previous;
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) => MoodCard(
    me: MoodPerson(name: 'Mikko', mood: mood, note: widget.myNote),
    partner: MoodPerson(name: 'Ana', mood: partner, note: widget.partnerNote),
    busy: busy,
    onPick: pick,
    onAddNote: () {},
    onShowNotes: () {},
  );
}

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.dark,
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      disableAnimations: reduceMotion,
    ),
    child: Scaffold(
      body: Padding(padding: const EdgeInsets.all(20), child: child),
    ),
  ),
);

bool _pickerActive(WidgetTester tester) {
  final ignore = tester.widget<IgnorePointer>(
    find
        .ancestor(
          of: find.text('How are you feeling?'),
          matching: find.byType(IgnorePointer),
        )
        .first,
  );
  return !ignore.ignoring;
}

void main() {
  testWidgets('tapping a mood shares it once and merges into the couple '
      'state inside the same card', (tester) async {
    await tester.pumpWidget(_app(const _Host(partnerMood: Mood.calm)));
    await tester.pump();
    expect(_pickerActive(tester), isTrue);
    final cardSize = tester.getSize(find.byType(MoodCard));

    // Rapid double tap: only one write.
    await tester.tap(find.bySemanticsLabel('Happy').first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.bySemanticsLabel('Happy').first, warnIfMissed: false);
    // Mid-merge the tapped artwork is travelling inside the card.
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('mood-flight')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    final host = tester.state<_HostState>(find.byType(_Host));
    expect(host.picks, [Mood.happy]);
    // ...and has landed: the travelling copy is gone.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('mood-flight')), findsNothing);

    // Same card, now showing both of you; no permanent "shared" text.
    expect(_pickerActive(tester), isFalse);
    expect(find.text('Happy'), findsWidgets);
    expect(find.text('Calm'), findsWidgets);
    expect(find.textContaining('shared with'), findsNothing);
    expect(find.text('Share mood'), findsNothing);
    // The card kept its size: no collapse between the two states.
    expect(tester.getSize(find.byType(MoodCard)), cardSize);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('partner without a mood shows "Not shared yet", then animates '
      'in when theirs arrives', (tester) async {
    await tester.pumpWidget(_app(const _Host(start: Mood.loved)));
    await tester.pump();
    expect(_pickerActive(tester), isFalse);
    expect(find.text('Not shared yet'), findsOneWidget);

    final host = tester.state<_HostState>(find.byType(_Host));
    host.partnerChanged(Mood.excited); // realtime update
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Excited'), findsWidgets);
    expect(find.text('Not shared yet'), findsNothing);
    // Your side did not reset.
    expect(find.text('Loved'), findsWidgets);
    expect(_pickerActive(tester), isFalse);
  });

  testWidgets('a failed save restores the previous mood', (tester) async {
    await tester.pumpWidget(
      _app(const _Host(start: null, partnerMood: Mood.calm, fail: true)),
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Happy').first);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    final host = tester.state<_HostState>(find.byType(_Host));
    expect(host.mood, isNull);
    expect(_pickerActive(tester), isTrue);
  });

  testWidgets('changing an existing mood opens the picker in place', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const _Host(start: Mood.calm, partnerMood: Mood.happy)),
    );
    await tester.pump();
    expect(_pickerActive(tester), isFalse);
    await tester.tap(find.bySemanticsLabel('You are feeling Calm'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));
    expect(_pickerActive(tester), isTrue);
    expect(find.text('Keep calm'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Flirty').first);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.state<_HostState>(find.byType(_Host)).mood, Mood.flirty);
    expect(_pickerActive(tester), isFalse);
  });

  testWidgets('reduced motion: no travelling art, just a quick crossfade', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const _Host(partnerMood: Mood.calm), reduceMotion: true),
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Happy').first);
    await tester.pump();
    expect(_pickerActive(tester), isFalse);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('one permanent rounded clip wraps everything that animates', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const _Host(partnerMood: Mood.calm)));
    await tester.pump();
    final clip = find.descendant(
      of: find.byType(MoodCard),
      matching: find.byType(ClipRRect),
    );
    final outer = tester.widget<ClipRRect>(clip.first);
    expect(outer.borderRadius, isNot(BorderRadius.zero));
    final outerBox = tester.renderObject(clip.first);
    // The same clip is still the outermost one mid-merge.
    await tester.tap(find.bySemanticsLabel('Happy').first);
    for (var ms = 0; ms <= 560; ms += 40) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.renderObject(clip.first), same(outerBox));
    }
    await tester.pump(const Duration(milliseconds: 400));
  });

  double sharedOpacity(WidgetTester tester, String text) {
    final f = find.text(text);
    if (f.evaluate().isEmpty) return 0;
    return tester
        .widgetList<Opacity>(
          find.ancestor(of: f, matching: find.byType(Opacity)),
        )
        .fold(1.0, (v, o) => v * o.opacity);
  }

  List<Color> bgColors(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('mood-base')),
    );
    final gradient =
        (container.decoration! as BoxDecoration).gradient! as LinearGradient;
    return [gradient.colors[0], gradient.colors[3]];
  }

  for (final m in [Mood.happy, Mood.excited, Mood.emotional]) {
    testWidgets('same mood merges: ${m.label} + ${m.label}', (tester) async {
      await tester.pumpWidget(_app(_Host(start: m, partnerMood: m)));
      await tester.pump();
      expect(sharedOpacity(tester, '${m.label} together'), closeTo(1, 0.01));
      // The whole card takes that mood's colours.
      final c = bgColors(tester);
      expect(c.first, c.last);
    });
  }

  for (final pair in [
    (Mood.happy, Mood.excited),
    (Mood.happy, Mood.calm),
    (Mood.emotional, Mood.needAHug),
  ]) {
    testWidgets('different moods stay apart: '
        '${pair.$1.label} + ${pair.$2.label}', (tester) async {
      await tester.pumpWidget(
        _app(_Host(start: pair.$1, partnerMood: pair.$2)),
      );
      await tester.pump();
      expect(find.text('${pair.$1.label} together'), findsNothing);
      expect(find.text(pair.$1.label), findsWidgets);
      expect(find.text(pair.$2.label), findsWidgets);
      // Each side keeps its own mood background.
      final c = bgColors(tester);
      expect(c.first, isNot(c.last));
    });
  }

  testWidgets('partner matches live: the sides merge; then they separate', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const _Host(start: Mood.happy, partnerMood: Mood.calm)),
    );
    await tester.pump();
    final host = tester.state<_HostState>(find.byType(_Host));
    host.partnerChanged(Mood.happy);
    await tester.pump(const Duration(milliseconds: 200));
    // Mid-merge: on its way in, not a hard cut.
    final mid = sharedOpacity(tester, 'Happy together');
    expect(mid, lessThan(1));
    await tester.pump(const Duration(milliseconds: 600));
    expect(sharedOpacity(tester, 'Happy together'), closeTo(1, 0.01));

    host.partnerChanged(Mood.excited);
    await tester.pump(const Duration(milliseconds: 200));
    expect(sharedOpacity(tester, 'Happy together'), greaterThan(0));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('Happy together'), findsNothing);
    expect(find.text('Excited'), findsWidgets);
  });

  testWidgets("tapping your partner's mood merges after the art lands", (
    tester,
  ) async {
    await tester.pumpWidget(_app(const _Host(partnerMood: Mood.calm)));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Calm').first);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(seconds: 1));
    expect(sharedOpacity(tester, 'Calm together'), closeTo(1, 0.01));
  });

  testWidgets('same mood, two different notes: both kept, card stays clean', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const _Host(
          start: Mood.happy,
          partnerMood: Mood.happy,
          myNote: 'Finished my exams.',
          partnerNote: 'Had a good day at work.',
        ),
      ),
    );
    await tester.pump();
    expect(sharedOpacity(tester, 'Happy together'), closeTo(1, 0.01));
    expect(find.text('2 notes'), findsOneWidget);
    // The merged card does not print the notes themselves.
    final merged = find.ancestor(
      of: find.text('Happy together'),
      matching: find.byType(Column),
    );
    expect(
      find.descendant(of: merged.last, matching: find.textContaining('exams')),
      findsNothing,
    );
  });

  testWidgets('same mood, only one note: "1 note"', (tester) async {
    await tester.pumpWidget(
      _app(
        const _Host(
          start: Mood.calm,
          partnerMood: Mood.calm,
          partnerNote: 'Long day.',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('1 note'), findsOneWidget);
  });

  testWidgets('different moods: each note as a one-line preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const _Host(
          start: Mood.excited,
          partnerMood: Mood.happy,
          myNote: 'Finished my exams and I am going to celebrate all weekend.',
          partnerNote: 'Had a good day at work.',
        ),
      ),
    );
    await tester.pump();
    final mine = tester.widget<Text>(find.textContaining('Finished my exams'));
    expect(mine.maxLines, 1);
    expect(find.text('Had a good day at work.'), findsOneWidget);
    expect(find.text('Excited together'), findsNothing);
  });

  testWidgets('your side without a note offers "Add a note"', (tester) async {
    await tester.pumpWidget(
      _app(const _Host(start: Mood.excited, partnerMood: Mood.happy)),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Add a note'), findsWidgets);
  });
}
