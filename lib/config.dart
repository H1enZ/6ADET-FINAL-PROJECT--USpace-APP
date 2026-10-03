import 'package:flutter/foundation.dart';

/// Settings passed in when the app is built or run, with --dart-define or
/// --dart-define-from-file=.env. Nothing secret is written in the code.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Development only: a locally running Therabot function, for example
  /// http://localhost:8000. Empty means the deployed Edge Function.
  static const String therabotFunctionsUrl = String.fromEnvironment(
    'THERABOT_FUNCTIONS_URL',
  );

  static const _localHosts = {'localhost', '127.0.0.1', '10.0.2.2'};

  /// True when [therabotFunctionsUrl] was given in a debug build. Release
  /// and profile builds always ignore it.
  static bool get wantsLocalTherabot =>
      kDebugMode && therabotFunctionsUrl.isNotEmpty;

  /// The local Therabot base URL, or null. Only in debug builds and only
  /// plain http(s) to a local development host, so the signed-in user's
  /// token can never be sent to any other machine.
  static String? get localTherabotUrl {
    if (!wantsLocalTherabot) return null;
    final uri = Uri.tryParse(therabotFunctionsUrl);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        !_localHosts.contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final base = uri.toString();
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }
}
