// USpace: a private app for two people in one relationship.
//
// Start-up order:
//   1. Read the Supabase settings passed in at build time (lib/config.dart).
//   2. Connect to Supabase, which also restores a saved session.
//   3. Show Splash, which decides: Sign in, Pair, or Home.

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/config_missing_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.isConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseKey,
    );
  }

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
    return MaterialApp(
      title: 'USpace',
      debugShowCheckedModeBanner: false,

      // These two lines make the DevicePreview toolbar change the app.
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system, // the Profile switch replaces this later

      home: AppConfig.isConfigured
          ? const SplashScreen()
          : const ConfigMissingScreen(),
    );
  }
}
