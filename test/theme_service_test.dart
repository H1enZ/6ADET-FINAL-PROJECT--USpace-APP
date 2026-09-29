import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:final_project/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('follows the device when nothing is saved yet', () async {
    SharedPreferences.setMockInitialValues({});
    ThemeService.mode.value = ThemeMode.light;
    await ThemeService.load();
    expect(ThemeService.mode.value, ThemeMode.system);
  });

  test('remembers the choice for the next visit', () async {
    SharedPreferences.setMockInitialValues({});
    await ThemeService.set(ThemeMode.dark);

    ThemeService.mode.value = ThemeMode.system; // as if the app restarted
    await ThemeService.load();
    expect(ThemeService.mode.value, ThemeMode.dark);
  });

  test('ignores an unknown saved value', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'purple'});
    await ThemeService.load();
    expect(ThemeService.mode.value, ThemeMode.system);
  });
}
