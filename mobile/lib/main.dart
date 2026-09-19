import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// App imports
import 'app_shell.dart';
import 'firebase_options.dart';
import 'pages/welcome_page.dart';
import 'onboarding/onboarding_page.dart';
import 'services/profile_service.dart';
import 'models/user_profile.dart';
import 'pages/profile_setup_page.dart';
import 'pages/discoverability_setup_page.dart';
import 'services/messaging_service.dart';
import 'services/location_service.dart';
import 'services/local_prefs.dart';

// Design system imports
import 'core/theme/app_theme.dart';

/// Main entry point for the Common Grounds app.
///
/// Initializes Firebase and wraps the app with Riverpod's ProviderScope
/// for state management throughout the application.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Wrap the app with ProviderScope for Riverpod state management
  runApp(const ProviderScope(child: MyApp()));
}

/// Root widget of the Common Grounds application.
///
/// Configures the MaterialApp with our custom theme system that includes:
/// - Light and dark mode support
/// - Consistent color palette (jade green primary)
/// - Typography system with proper text styles
/// - Spacing and layout constants
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Common Grounds',
      debugShowCheckedModeBanner: false,

      // Apply custom theme with light/dark mode support
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Follows system preference
      // Named routes for navigation
      routes: {
        '/app': (_) => const AppShell(),
        '/welcome': (_) => const WelcomePage(),
      },

      // Bootstrap gate handles initial routing logic
      home: const BootstrapGate(),
    );
  }
}

/// Bootstrap Gate - Authentication and Profile Flow Manager
///
/// This widget handles the initial routing logic for the app:
/// 1. Check if user is authenticated with Firebase
/// 2. Check if user has completed their profile
/// 3. Initialize user services (FCM, location tracking)
/// 4. Route to appropriate screen based on state
///
/// Flow: Welcome (Auth) → Profile Setup → App Shell
class BootstrapGate extends StatefulWidget {
  const BootstrapGate({super.key});

  @override
  State<BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<BootstrapGate>
    with WidgetsBindingObserver {
  String? _activeUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final userId = _activeUserId;
      if (userId != null) {
        LocationService.instance.pauseDiscoverability(userId);
      }
    }
  }

  /// Initialize FCM and location services for the authenticated user.
  ///
  /// This is called once the user is authenticated to set up:
  /// - Firebase Cloud Messaging (FCM) for push notifications
  /// - Location tracking for proximity-based features
  ///
  /// Note: Location permission denial doesn't block the app -
  /// users can enable it later in settings.
  Future<void> _initUserServices(String uid) async {
    _activeUserId = uid;
    debugPrint('🔍 _initUserServices: Starting for uid=$uid');

    try {
      debugPrint('🔍 _initUserServices: Initializing FCM...');
      // Initialize FCM for push notifications
      await MessagingService.instance.initForUser(uid);
      debugPrint('🔍 _initUserServices: FCM initialized successfully');
    } catch (e) {
      debugPrint('FCM initialization failed (non-critical): $e');
    }

    debugPrint('🔍 _initUserServices: Completed');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        debugPrint(
          '🔍 BootstrapGate: Auth connection state = ${authSnap.connectionState}',
        );

        if (authSnap.connectionState == ConnectionState.waiting) {
          debugPrint('🔍 BootstrapGate: Waiting for auth...');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (authSnap.hasError) {
          debugPrint('🔍 BootstrapGate: Auth error = ${authSnap.error}');
          return Scaffold(
            body: Center(child: Text('Auth error: ${authSnap.error}')),
          );
        }

        final user = authSnap.data;
        debugPrint('🔍 BootstrapGate: User = ${user?.uid ?? "null"}');
        if (user == null) {
          _activeUserId = null;
          return FutureBuilder<bool>(
            future: LocalPrefs.hasOnboarded(),
            builder: (context, onboardingSnap) {
              if (onboardingSnap.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return onboardingSnap.data == true
                  ? const WelcomePage()
                  : const OnboardingPage();
            },
          );
        }

        // Ensure there's a profile doc, then watch it.
        debugPrint(
          '🔍 BootstrapGate: Initializing user services for ${user.uid}...',
        );
        return FutureBuilder<void>(
          future: _initUserServices(user.uid),
          builder: (context, initSnap) {
            debugPrint(
              '🔍 BootstrapGate: Service init state = ${initSnap.connectionState}',
            );

            if (initSnap.connectionState != ConnectionState.done) {
              debugPrint(
                '🔍 BootstrapGate: Waiting for services to initialize...',
              );
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            // If init fails, don't block the app—just continue
            // (you can show a snackbar/toast elsewhere if desired)
            if (initSnap.hasError) {
              debugPrint(
                '🔍 BootstrapGate: Service init error = ${initSnap.error}',
              );
              return Scaffold(
                body: Center(
                  child: Text('Service init error: ${initSnap.error}'),
                ),
              );
            }

            debugPrint(
              '🔍 BootstrapGate: Services initialized, watching profile...',
            );
            return StreamBuilder<UserProfile?>(
              stream: ProfileService.instance.watchProfile(user.uid),
              builder: (context, profSnap) {
                debugPrint(
                  '🔍 BootstrapGate: Profile connection state = ${profSnap.connectionState}',
                );

                if (profSnap.connectionState == ConnectionState.waiting) {
                  debugPrint('🔍 BootstrapGate: Waiting for profile...');
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (profSnap.hasError) {
                  debugPrint(
                    '🔍 BootstrapGate: Profile error = ${profSnap.error}',
                  );
                  return Scaffold(
                    body: Center(
                      child: Text('Profile load error: ${profSnap.error}'),
                    ),
                  );
                }
                final profile = profSnap.data;
                debugPrint(
                  '🔍 BootstrapGate: Profile = ${profile?.uid}, isComplete = ${profile?.isComplete}',
                );

                if (profile == null || !profile.isComplete) {
                  debugPrint(
                    '🔍 BootstrapGate: Profile incomplete, showing ProfileSetupPage',
                  );
                  return ProfileSetupPage(
                    profile:
                        profile ??
                        UserProfile(
                          uid: user.uid,
                          displayName: user.displayName,
                          photoUrl: user.photoURL,
                          bio: null,
                          classYear: null,
                          major: null,
                          interests: const [],
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                  );
                }
                if (!profile.hasCompletedDiscoverySetup) {
                  return DiscoverabilitySetupPage(profile: profile);
                }
                debugPrint(
                  '🔍 BootstrapGate: Profile complete, showing AppShell',
                );
                return const AppShell();
              },
            );
          },
        );
      },
    );
  }
}
