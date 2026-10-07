import 'package:supabase_flutter/supabase_flutter.dart';

import 'couple_service.dart';
import 'couple_sync.dart';
import 'storage_links.dart';

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
    _expectSignOut = false;
    forgetAccountData();
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
    _expectSignOut = false;
    forgetAccountData();
    await _auth.signInWithPassword(email: email.trim(), password: password);
  }

  // Set by [signOut] and used up by the sign-out event it causes, however
  // late that event arrives, so the app's listener can tell a sign-out you
  // asked for from one that just happened (an expired session).
  static bool _expectSignOut = false;

  /// True once for the sign-out event caused by [signOut].
  static bool takeExpectedSignOut() {
    final expected = _expectSignOut;
    _expectSignOut = false;
    return expected;
  }

  static Future<void> signOut() async {
    _expectSignOut = true;
    try {
      await _auth.signOut();
    } catch (_) {
      _expectSignOut = false;
      rethrow;
    } finally {
      forgetAccountData();
    }
  }

  /// Signed-in or signed-out changes (see USpaceApp, which sends you back
  /// to the start when your session ends on its own).
  static Stream<AuthState> get changes => _auth.onAuthStateChange;

  /// Clears everything kept in memory for the signed-in account, so none
  /// of it can show for the next person who signs in on this device.
  static void forgetAccountData() {
    CoupleSync.reset();
    CoupleService.forget();
    StorageLinks.clear();
  }
}

/// An error whose message is already written for the user.
class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

const _connectionError =
    'Something went wrong. Check your connection and try again.';

/// Turns any error into a sentence the user can act on. Only messages that
/// were written for people are shown as they are: ours, Supabase Auth's,
/// and the database's own `raise exception` lines (code P0001). Anything
/// else (policy, constraint or token errors) never reaches the screen raw.
String friendlyError(Object error) {
  if (error is AppException) return error.message;
  if (error is AuthRetryableFetchException) return _connectionError;
  if (error is AuthException) return error.message;
  if (error is StorageException) {
    if (error.statusCode == '413') {
      return 'That photo is too large. Try a smaller one.';
    }
    return "Couldn't load or save the photo just now. Try again.";
  }
  if (error is PostgrestException) {
    final code = error.code ?? '';
    if (code == 'P0001' && error.message.length <= 200) return error.message;
    if (code == 'PGRST301' || code == 'PGRST303') {
      return 'Your session has ended. Sign in again to continue.';
    }
    if (code == '42501') return "You don't have access to that.";
    if (code == '23505') return 'That has already been saved.';
    if (code.startsWith('22') || code.startsWith('23')) {
      return "That didn't fit. Check what you entered and try again.";
    }
    return "Couldn't reach USpace just now. Try again in a moment.";
  }
  return _connectionError;
}
