import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart'
    show GoogleSignInExceptionCode;

/// A recoverable auth problem carrying a message that is safe to show the user
/// as-is. [toString] is the message itself so it renders cleanly in a SnackBar.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  static final GoogleSignIn _google = GoogleSignIn.instance;

  /// google_sign_in v7 requires exactly one [GoogleSignIn.initialize] before any
  /// sign-in call. The future is cached so a second tap joins the first attempt
  /// instead of racing another initialize; a failed attempt is discarded so the
  /// next tap can retry.
  static Future<void>? _googleReady;

  static Future<void> _prepareGoogle() async {
    final pending = _googleReady;
    if (pending != null) return pending;

    // No serverClientId is passed: on Android the plugin reads the web client id
    // that the google-services plugin generates from google-services.json, which
    // keeps it out of the Dart source and out of version control.
    final started = _google.initialize();
    _googleReady = started;
    try {
      await started;
    } catch (_) {
      _googleReady = null;
      rethrow;
    }
  }

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;
  static String? get currentUserId => _auth.currentUser?.uid;
  static bool get isAuthenticated => _auth.currentUser != null;

  /// Emits the current user immediately on subscribe, then on every sign-in and
  /// sign-out. [AppProvider] listens to this to bind and unbind its data streams.
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Best name available for the signed-in user: the profile name set by Google,
  /// otherwise the local part of their email.
  static String get displayName {
    final user = currentUser;
    if (user == null) return 'User';

    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final email = user.email ?? '';
    return email.isEmpty ? 'User' : email.split('@').first;
  }

  // ── Email and password ──

  static Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_describe(e));
    }
  }

  /// Creates the account and sends a verification mail. Firebase signs the new
  /// user in straight away, so callers can move on to the app.
  static Future<void> signUp(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_describe(e));
    }
  }

  static Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_describe(e));
    }
  }

  // ── Google ──

  /// Signs in through Credential Manager on Android, which is the supported
  /// path now that the legacy Google Sign-In SDK is deprecated.
  ///
  /// Returns false when the user backs out of the account sheet — that is a
  /// decision, not a failure, so it must not surface as an error.
  static Future<bool> signInWithGoogle() async {
    try {
      await _prepareGoogle();

      final account = await _google.authenticate();

      // Credential Manager returns an ID token and nothing else; an access token
      // now comes from a separate authorization request, and Firebase does not
      // need one to establish the session.
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthFailure(
          'Google did not return a sign-in token. Check that the SHA-1 '
          'fingerprint for this build is registered in Firebase.',
        );
      }

      await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      throw AuthFailure(_describeGoogle(e));
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_describe(e));
    } on PlatformException catch (e) {
      throw AuthFailure(_describePlatform(e));
    }
  }

  // ── Session ──

  static Future<void> signOut() async {
    // Clearing the Google session is best-effort: if it fails, signing out of
    // Firebase is what actually ends the app session, and that must still run.
    try {
      await _prepareGoogle();
      await _google.signOut();
    } catch (e) {
      debugPrint('Google sign-out skipped: $e');
    }
    await _auth.signOut();
  }

  static String _describe(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Invalid email or password. Please try again.';
      case 'invalid-email':
        return 'That email address doesn\'t look right.';
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'weak-password':
        return 'Choose a password with at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'account-exists-with-different-credential':
        return 'This email is already registered with a different sign-in method.';
      case 'operation-not-allowed':
        return 'This sign-in method is turned off for the project.';
      default:
        return error.message ?? 'Sign-in failed. Please try again.';
    }
  }

  static String _describeGoogle(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
      case GoogleSignInExceptionCode.interrupted:
        return 'Sign-in was cancelled.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Google Sign-In is not set up for this build. Check that this '
            'build\'s SHA-1 fingerprint is registered in Firebase.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google Play services is unavailable or out of date on this '
            'device.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google Sign-In could not open. Please try again.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'That is a different Google account. Please try again.';
      case GoogleSignInExceptionCode.unknownError:
        return 'Google Sign-In failed. Please try again.';
    }
  }

  static String _describePlatform(PlatformException error) {
    switch (error.code) {
      case 'network_error':
        return 'No internet connection. Please check your network.';
      case 'sign_in_canceled':
        return 'Sign-in was cancelled.';
      default:
        return 'Google Sign-In failed. Please try again.';
    }
  }
}
