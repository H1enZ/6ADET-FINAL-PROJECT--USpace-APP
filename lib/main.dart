// USpace: a private app for two people in one relationship.
//
// Start-up order:
//   1. Read the Supabase settings passed in at build time (lib/config.dart).
//   2. Connect to Supabase, which also restores a saved session.
//   3. Show Splash, which decides: Sign in, Pair, or Home.
//   4. While the app runs, a session that ends on its own (expired or
//      revoked) sends you back to Splash, with this account's data cleared.

import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/config_missing_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'widgets/organisms/phone_frame.dart';

/// The DevicePreview phone frame is for responsive-layout work only. It is
/// off unless the build asks for it:
///   flutter run -d edge --dart-define=ENABLE_DEVICE_PREVIEW=true
/// Normal runs and the deployed build never include the wrapper (it moves
/// the whole app between parents after it loads, which breaks open overlays).
const bool enableDevicePreview = bool.fromEnvironment('ENABLE_DEVICE_PREVIEW');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.isConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseKey,
    );
  }

  runApp(
    enableDevicePreview
        ? DevicePreview(builder: (context) => const USpaceApp())
        : const USpaceApp(),
  );
}

class USpaceApp extends StatefulWidget {
  const USpaceApp({super.key});

  @override
  State<USpaceApp> createState() => _USpaceAppState();
}

class _USpaceAppState extends State<USpaceApp> {
  final _navigator = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _auth;

  @override
  void initState() {
    super.initState();
    if (AppConfig.isConfigured) _auth = AuthService.changes.listen(_onAuth);
  }

  /// Signing out from a button already restarts the flow itself; this only
  /// handles a session that ended without you asking.
  void _onAuth(AuthState state) {
    if (state.event != AuthChangeEvent.signedOut) return;
    if (AuthService.takeExpectedSignOut()) return;
    AuthService.forgetAccountData();
    final context = _navigator.currentContext;
    if (context != null) restartFlow(context);
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigator,
      title: 'USpace',
      debugShowCheckedModeBanner: false,

      // On a wide window the app is shown inside a phone (see PhoneFrame:
      // it wraps the Navigator, so dialogs and sheets open inside it).
      // With DevicePreview on, its toolbar drives the app instead.
      locale: enableDevicePreview ? DevicePreview.locale(context) : null,
      builder: enableDevicePreview
          ? DevicePreview.appBuilder
          : (context, child) => PhoneFrame(child: child!),

      // Lets a mouse or trackpad drag sideways lists (filter pills, photo
      // strips) on the web, the same way a finger swipes them on a phone.
      scrollBehavior: const _DragEverywhereScrollBehavior(),

      // Dark mode only.
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,

      home: AppConfig.isConfigured
          ? const SplashScreen()
          : const ConfigMissingScreen(),
    );
  }
}

/// Flutter's default only lets touch drag a scrollable list. On the web
/// that leaves mouse users unable to reach pills hidden off to the side,
/// so this also accepts mouse, trackpad and stylus drags.
class _DragEverywhereScrollBehavior extends MaterialScrollBehavior {
  const _DragEverywhereScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
