/// Settings passed in when the app is built or run, with --dart-define or
/// --dart-define-from-file=.env. Nothing secret is written in the code.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
