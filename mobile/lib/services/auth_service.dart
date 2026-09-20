// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  static const _googleIosClientId =
      '800333772675-skk1odgbh1hlskfq23u9ilj12m2g7r8a.apps.googleusercontent.com';
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
}
