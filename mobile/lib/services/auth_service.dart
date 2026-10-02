// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;
  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    required this.emailVerified,
  });
  factory AppUser.fromFirebaseUser(User u) => AppUser(
    uid: u.uid,
    email: u.email,
    displayName: u.displayName,
    photoUrl: u.photoURL,
    emailVerified: u.emailVerified,
  );
}

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  /// The App Review/test account is exempt from inbox verification so reviewers
  /// can exercise nearby discovery normally. Firestore enforces this same
  /// narrow exception server-side.
  static const reviewerTestEmail = 'test@gmail.com';

  static const _googleIosClientId =
      '800333772675-c31gm5goii7mkhm53h0kncaibudoctar.apps.googleusercontent.com';
  static const _googleWebClientId =
      '800333772675-fpnvhp5evfrqifff778b5ssvinldunu7.apps.googleusercontent.com';

  final _auth = FirebaseAuth.instance;
  final ValueNotifier<bool> isSigningOut = ValueNotifier(false);

  /// OPTIONAL: call once on app start (e.g., in main after Firebase.initializeApp).
  /// If you see a runtime error asking for serverClientId on Android,
  /// pass the Web client ID here: initialize(serverClientId: 'xxx.apps.googleusercontent.com');
  bool _initialized = false;
  Future<void> initialize({String? clientId, String? serverClientId}) async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: clientId ?? _googleIosClientId,
      serverClientId: serverClientId ?? _googleWebClientId,
    );
    _initialized = true;
  }

  Stream<AppUser?> get user$ => _auth.authStateChanges().map(
    (u) => u == null ? null : AppUser.fromFirebaseUser(u),
  );

  AppUser? get currentUser {
    final u = _auth.currentUser;
    return u == null ? null : AppUser.fromFirebaseUser(u);
  }

  /// Creates an email/password account and immediately sends its verification
  /// email. Firebase rejects duplicate emails, including emails already used by
  /// a Google or Apple account, so this cannot create a second Common Grounds
  /// profile for the same address.
  Future<AppUser> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFlowException('Account creation failed.');
      }
      await user.sendEmailVerification();
      await FirebaseFirestore.instance.enableNetwork();
      return AppUser.fromFirebaseUser(user);
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException.fromFirebase(error);
    }
  }

  /// Signs in with an existing email/password credential.
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) throw const AuthFlowException('Sign-in failed.');
      await FirebaseFirestore.instance.enableNetwork();
      return AppUser.fromFirebaseUser(user);
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException.fromFirebase(error);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException.fromFirebase(error);
    }
  }

  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFlowException('Please sign in again.');
    await user.sendEmailVerification();
  }

  /// Refreshes Firebase's verification state after the member returns from
  /// their inbox. `userChanges` in BootstrapGate then advances the app.
  Future<bool> reloadEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshedUser = _auth.currentUser;
    if (refreshedUser?.emailVerified == true) {
      // Firestore rules use the ID-token email_verified claim. Refresh it now
      // so the member can immediately continue to discovery.
      await refreshedUser!.getIdToken(true);
      return true;
    }
    return false;
  }

  static bool isReviewerTestEmail(String? email) =>
      email?.trim().toLowerCase() == reviewerTestEmail;

  bool requiresEmailVerification(User user) =>
      !isReviewerTestEmail(user.email) &&
      !user.emailVerified &&
      user.providerData.any((provider) => provider.providerId == 'password');

  bool get canAddEmailPassword =>
      _auth.currentUser != null &&
      !_auth.currentUser!.providerData.any(
        (provider) => provider.providerId == 'password',
      );

  /// Lets a member who began with Google or Apple add email sign-in to that
  /// *same* Firebase user. This is the supported account-linking path rather
  /// than creating another profile for the same person.
  Future<void> addEmailPassword({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFlowException('Please sign in again.');
    if (user.email?.toLowerCase() != email.trim().toLowerCase()) {
      throw const AuthFlowException(
        'Use the email already associated with this Common Grounds account.',
      );
    }
    try {
      await user.linkWithCredential(
        EmailAuthProvider.credential(email: email.trim(), password: password),
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException.fromFirebase(error);
    }
  }

  /// Google sign-in using the v7 flow.
  Future<AppUser> signInWithGoogle() async {
    // Ensure plugin is ready (safe to call multiple times)
    await initialize();

    // Try lightweight auth; if it doesn't sign in, fall back to full authenticate().
    await GoogleSignIn.instance.attemptLightweightAuthentication();

    GoogleSignInAccount? gUser;
    // If the platform supports the built-in UI, use it.
    if (GoogleSignIn.instance.supportsAuthenticate()) {
      gUser = await GoogleSignIn.instance.authenticate();
    } else {
      // (Primarily for web) you’d render the official button from google_sign_in_web.
      // For your Android/iOS app this branch won’t be hit.
      throw Exception(
        'Platform requires platform-specific Google button flow.',
      );
    }

    // Get tokens, exchange for Firebase credential (idToken is sufficient).
    final gAuth = gUser.authentication;
    final credential = GoogleAuthProvider.credential(idToken: gAuth.idToken);
    final cred = await _auth.signInWithCredential(credential);

    final user = cred.user;
    if (user == null) throw Exception('Firebase sign-in failed.');
    await FirebaseFirestore.instance.enableNetwork();
    return AppUser.fromFirebaseUser(user);
  }

  /// Apple Sign-In using Sign in with Apple.
  /// Generates a cryptographic nonce for security and exchanges Apple credentials
  /// for Firebase credentials.
  Future<AppUser> signInWithApple() async {
    // Generate a cryptographic nonce
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    try {
      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Create OAuth credential for Firebase
      final oauthCredential = OAuthProvider(
        'apple.com',
      ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce);

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user;

      if (user == null) throw Exception('Firebase sign-in failed.');

      await FirebaseFirestore.instance.enableNetwork();

      // Update display name if this is a new user and Apple provided name info
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        final fullName =
            appleCredential.givenName != null ||
                appleCredential.familyName != null
            ? '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                  .trim()
            : null;

        if (fullName != null && fullName.isNotEmpty) {
          await user.updateDisplayName(fullName);
          await user.reload();
        }
      }

      return AppUser.fromFirebaseUser(user);
    } catch (e) {
      throw Exception('Apple sign-in failed: $e');
    }
  }

  /// Generates a cryptographically secure random nonce for Apple Sign-In
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Returns the sha256 hash of the input string
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> signOut() async {
    if (isSigningOut.value) return;

    // BootstrapGate removes the authenticated shell as soon as this flips.
    // Waiting one frame lets its Firestore listeners cancel while credentials
    // are still valid, avoiding permission-denied errors during sign-out.
    isSigningOut.value = true;
    try {
      await WidgetsBinding.instance.endOfFrame;
      // Halt requests before the Firebase credential disappears. Otherwise an
      // in-flight listener can be evaluated as signed out before its widget is
      // disposed and report a spurious permission-denied exception.
      await FirebaseFirestore.instance.disableNetwork();
      await _auth.signOut();
      await GoogleSignIn.instance.signOut();
      // Note: Sign in with Apple doesn't require explicit sign out.
    } finally {
      isSigningOut.value = false;
    }
  }

  /// Permanently removes the signed-in member and their Common data.
  /// The callable owns cleanup so a partially completed client operation cannot
  /// leave private data behind.
  Future<void> deleteAccount() async {
    await FirebaseFunctions.instance
        .httpsCallable('deleteUserAccount')
        .call<void>({'confirm': true});
    await signOut();
  }
}

/// User-facing auth errors. Keep Firebase's implementation details out of UI
/// and point people with an existing social account back to its sign-in button.
class AuthFlowException implements Exception {
  const AuthFlowException(this.message);
  final String message;

  factory AuthFlowException.fromFirebase(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return const AuthFlowException(
          'An account already uses this email. Sign in with the method you used before, then add a password from your account settings.',
        );
      case 'account-exists-with-different-credential':
        return const AuthFlowException(
          'This email is already connected to another sign-in method. Use that method to sign in.',
        );
      case 'invalid-email':
        return const AuthFlowException('Enter a valid email address.');
      case 'weak-password':
        return const AuthFlowException(
          'Use a stronger password with at least 8 characters.',
        );
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return const AuthFlowException('That email or password is incorrect.');
      case 'too-many-requests':
        return const AuthFlowException(
          'Too many attempts. Please wait a moment and try again.',
        );
      case 'requires-recent-login':
        return const AuthFlowException(
          'For security, sign in again before adding a password.',
        );
      default:
        return AuthFlowException(
          error.message ?? 'Something went wrong. Please try again.',
        );
    }
  }

  @override
  String toString() => message;
}
