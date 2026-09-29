// USpace: a private app for two people in one relationship.
//
// Start-up order:
//   1. Read the Supabase settings passed in at build time (lib/config.dart).
//   2. Connect to Supabase, which also restores a saved session.
//   3. Load the saved Light / Dark / System choice.
//   4. Show Splash, which decides: Sign in, Pair, or Home.

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/config_missing_screen.dart';
import 'screens/splash_screen.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.isConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseKey,
    );
  }

  await ThemeService.load();

  runApp(
    // Phone frame, kept on in the deployed build on purpose (see START-HERE.md).
    DevicePreview(
      enabled: true,
      builder: (context) => const USpaceApp(),
    ),
  );
}

class USpaceApp extends StatelessWidget {
  const USpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds with the new theme whenever it is changed on Profile.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.mode,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'USpace',
        debugShowCheckedModeBanner: false,

        // These two lines make the DevicePreview toolbar change the app.
        locale: DevicePreview.locale(context),
        builder: DevicePreview.appBuilder,

        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,

        home: AppConfig.isConfigured
            ? const SplashScreen()
            : const ConfigMissingScreen(),
      ),
    );
  }
}
