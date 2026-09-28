import 'package:supabase_flutter/supabase_flutter.dart';

/// Signing up, in and out. Supabase stores the session for us, so a
/// returning user stays signed in after closing the app.
class AuthService {
  AuthService._();

  static GoTrueClient get _auth => Supabase.instance.client.auth;

  static Session? get session => _auth.currentSession;
  static User? get user => _auth.currentUser;

  /// Returns true when the new account is signed in straight away, or false
  /// when Supabase wants the email confirmed first.
  static Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );
    return response.session != null;
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithPassword(email: email.trim(), password: password);
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }
}

/// An error whose message is already written for the user.
class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Turns any error into a sentence the user can act on.
String friendlyError(Object error) {
  if (error is AppException) return error.message;
  if (error is AuthException) return error.message;
  if (error is StorageException) return error.message;
  if (error is PostgrestException) return error.message;
  return 'Something went wrong. Check your connection and try again.';
}
