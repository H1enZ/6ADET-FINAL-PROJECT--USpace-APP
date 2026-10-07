// CoupleSync: the shared live-update connection, opened by screens and
// closed on sign-out. Runs against an unreachable local address: the
// channels are created but never connect, which is all these tests need.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:final_project/services/couple_sync.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      publishableKey: 'test-key',
    );
  });

  tearDown(CoupleSync.reset);

  test('sign-out closes every open connection without throwing', () {
    // Two couples' hubs open at once (normally only one, but reset must
    // cope with any number): closing one used to change the map that
    // reset was looping over, which threw and stopped sign-out half way.
    CoupleSync.listen('couple-a', const {'messages'}, () {});
    CoupleSync.listen('couple-b', const {'bucket_items'}, () {});

    expect(CoupleSync.reset, returnsNormally);
  });

  test('after a reset, listening again opens a fresh connection', () {
    var calls = 0;
    CoupleSync.listen('couple-a', const {'messages'}, () => calls++);
    CoupleSync.reset();

    final handle = CoupleSync.listen('couple-a', const {
      'messages',
    }, () => calls++);
    expect(handle.cancel, returnsNormally);
    expect(calls, 0);
  });

  test('cancelling a handle twice, or after a reset, is harmless', () {
    final handle = CoupleSync.listen('couple-a', const {'notes'}, () {});
    CoupleSync.reset();
    expect(handle.cancel, returnsNormally);
    expect(handle.cancel, returnsNormally);
  });
}
