import 'package:flutter_test/flutter_test.dart';
import 'package:final_project/models/therabot.dart';

void main() {
  group('TherabotNames', () {
    test('Partner 1 is whoever started the session', () {
      const iStarted = TherabotNames(
        myPartnerNumber: 1,
        myName: 'Mikko',
        partnerName: 'Therabot-E',
      );
      expect(iStarted.of(1), 'Mikko');
      expect(iStarted.of(2), 'Therabot-E');

      // The same couple, seen by the partner who did not start it.
      const theyStarted = TherabotNames(
        myPartnerNumber: 2,
        myName: 'Therabot-E',
        partnerName: 'Mikko',
      );
      expect(theyStarted.of(1), 'Mikko');
      expect(theyStarted.of(2), 'Therabot-E');
    });

    test('falls back to Partner 1 / Partner 2 when a name is missing', () {
      const names = TherabotNames(myPartnerNumber: 2, myName: '  ');
      expect(names.of(1), 'Partner 1');
      expect(names.of(2), 'Partner 2');
    });

    test('maps only the exact labels, leaving the rest of the text', () {
      const names = TherabotNames(
        myPartnerNumber: 1,
        myName: 'Mikko',
        partnerName: 'Therabot-E',
      );
      const text =
          "Partner 1 stopped replying, while Partner 2's worry grew. "
          'Partner 12 and partner 1 are not labels.';
      expect(
        names.display(text),
        "Mikko stopped replying, while Therabot-E's worry grew. "
        'Partner 12 and partner 1 are not labels.',
      );
      final labels = names.segments(text).where((s) => s.partner != null);
      expect(labels.map((s) => s.partner), [1, 2]);
    });
  });
}
