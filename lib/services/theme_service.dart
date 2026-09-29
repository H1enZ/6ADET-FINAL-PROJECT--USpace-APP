import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light, Dark or System (follow the device). The choice is saved on this
/// device only (in the browser's storage on the web), not in Supabase,
/// because it is a personal preference and not the couple's data.
class ThemeService {
  ThemeService._();

  static const _key = 'theme_mode';

  /// The app rebuilds whenever this changes (see main.dart).
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  /// Call once at start-up, before the first frame.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      mode.value = _fromName(prefs.getString(_key));
    } catch (_) {
      mode.value = ThemeMode.system; // storage unavailable: follow the device
    }
  }

  static Future<void> set(ThemeMode value) async {
    mode.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value.name);
    } catch (_) {
      // Still changes for this visit, just not remembered.
    }
  }

  static ThemeMode _fromName(String? name) => ThemeMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => ThemeMode.system,
      );
}
