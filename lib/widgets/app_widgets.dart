import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../setup_screen.dart';
import '../presentation/onboarding/onboarding_flow.dart';
import '../presentation/notifiers/user_notifier.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import 'splash_screen.dart';
import '../presentation/widgets/animated_theme_wrapper.dart';
import '../presentation/hooks/game_theme_sync.dart';
import '../services/supabase_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../core/app_router.dart';
import '../core/notification_routes.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  debugPrint('authStateProvider: Setting up auth state listener');
  return Supabase.instance.client.auth.onAuthStateChange.map((data) {
    final user = data.session?.user;
    debugPrint(
        'authStateProvider: Auth state changed - event: ${data.event}, user: ${user?.id ?? "null"}, session exists: ${data.session != null}');
    return user;
  });
});

/// ConsumerWidget for the main MaterialApp with theme support and go_router
class SquadSyncMaterialApp extends ConsumerWidget {
  const SquadSyncMaterialApp({super.key});

  // Static flag to ensure splash is only removed once
  static bool _splashRemoved = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sync theme with current game selection
    GameThemeSync.watch(ref);

    final router = ref.watch(goRouterProvider);
    NotificationRoutes.bindRouter(router, rootNavigatorKey);

    // Remove native splash after first frame is rendered (only once)
    if (!_splashRemoved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_splashRemoved) {
          _splashRemoved = true;
          FlutterNativeSplash.remove();
          debugPrint('🎨 Native splash removed after first frame');
        }
      });
    }

    return AnimatedThemeWrapper(
      child: MaterialApp.router(
        title: 'Cod Squad',
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// ConsumerWidget for handling authentication and onboarding logic
class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  static final Logger _logger = Logger();
  bool _minDurationElapsed = false;
  Timer? _minDurationTimer;
  bool _userSyncedToSupabase = false;

  @override
  void initState() {
    super.initState();
    // Ensure splash screen shows for minimum duration
    _minDurationTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _minDurationElapsed = true;
        });
      }
    });
  }

  /// Sync Supabase user to users table
  Future<void> _syncUserToSupabase(User supabaseUser) async {
    if (_userSyncedToSupabase) return;

    try {
      _logger.d('🔄 Syncing user ${supabaseUser.id} to Supabase...');

      // Check if user already exists in Supabase
      final existingUser = await supabase
          .from('users')
          .select('uid')
          .eq('uid', supabaseUser.id)
          .maybeSingle();

      if (existingUser != null) {
        _logger.d('👤 User already exists in Supabase');
        _userSyncedToSupabase = true;
        return;
      }

      // Create user in Supabase
      final userData = {
        'uid': supabaseUser.id,
        'email': supabaseUser.email ?? 'unknown@user.com',
        'display_name': supabaseUser.userMetadata?['display_name'] ?? 'User',
        'photo_url': supabaseUser.userMetadata?['photo_url'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('users').insert(userData);
      _logger.i('✅ Created user ${supabaseUser.id} in Supabase');
      _userSyncedToSupabase = true;
    } catch (e) {
      _logger.e('❌ Failed to sync user to Supabase: $e');
      // Don't block app startup on sync failure
    }
  }

  @override
  void dispose() {
    _minDurationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state using Riverpod provider
    final authState = ref.watch(authStateProvider);

    // Show splash screen until minimum duration elapsed
    if (!_minDurationElapsed) {
      return const SplashScreen();
    }

    return authState.when(
      data: (user) {
        if (user != null) {
          _logger.i('User authenticated: ${user.id}');

          // Sync user to Supabase in the background
          _syncUserToSupabase(user);

          // User is authenticated, wait for data to load before showing UI
          return const OnboardingWrapper();
        } else {
          _logger.i('User not authenticated, showing setup screen');
          // User not authenticated, show login/setup screen
          return const SetupScreen();
        }
      },
      loading: () => const SplashScreen(),
      error: (error, stack) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Auth error: $error',
              style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

/// Wrapper to check if user needs onboarding
class OnboardingWrapper extends ConsumerStatefulWidget {
  const OnboardingWrapper({super.key});

  @override
  ConsumerState<OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends ConsumerState<OnboardingWrapper> {
  bool _dataReady = false;
  bool _transitionComplete = false;
  bool _nativeSplashRemoved = false;

  @override
  Widget build(BuildContext context) {
    debugPrint('🟡 OnboardingWrapper: build() called');

    // Watch both user state and squad state to ensure all critical data is loaded
    final userStateAsync = ref.watch(userNotifierProvider);
    debugPrint(
        '🟡 OnboardingWrapper: userStateAsync = ${userStateAsync.runtimeType}, isLoading: ${userStateAsync.isLoading}, hasValue: ${userStateAsync.hasValue}, hasError: ${userStateAsync.hasError}');

    final squadStateAsync = ref.watch(ln.lobbyNotifierProvider);
    debugPrint('🟡 OnboardingWrapper: squadStateAsync loaded');

    // Wait for both user data and squad data to load
    if (userStateAsync.isLoading || squadStateAsync.isLoading) {
      debugPrint('🟡 OnboardingWrapper: Still loading - showing splash');
      return const SplashScreen();
    }

    // Both are loaded, mark as ready and add delay for smooth transition
    if (!_dataReady && userStateAsync.hasValue && squadStateAsync.hasValue) {
      _dataReady = true;
      // Longer delay to ensure smooth transition from AuthWrapper's minimum duration
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _transitionComplete = true;
          });

          // Remove native splash after Flutter content is ready
          if (!_nativeSplashRemoved) {
            _nativeSplashRemoved = true;
            FlutterNativeSplash.remove();
            debugPrint('🎨 Native splash removed - app ready');
          }
        }
      });
      return const SplashScreen();
    }

    // Keep showing splash until transition is complete
    if (_dataReady && !_transitionComplete) {
      debugPrint('🟡 OnboardingWrapper: Waiting for smooth transition');
      return const SplashScreen();
    }

    // If either has an error, proceed to main screen (graceful degradation)
    if (userStateAsync.hasError || squadStateAsync.hasError) {
      // Remove native splash on error too
      if (!_nativeSplashRemoved) {
        _nativeSplashRemoved = true;
        FlutterNativeSplash.remove();
      }
      // Redirect handled by router
      return const SizedBox.shrink();
    }

    // All data is loaded and ready, check onboarding status
    final userState = userStateAsync.value;

    // Ensure native splash is removed before showing final screen
    if (!_nativeSplashRemoved) {
      _nativeSplashRemoved = true;
      FlutterNativeSplash.remove();
    }

    if (userState == null) {
      // Redirect handled by router
      return const SizedBox.shrink();
    } else if (userState.pinnedGames.isEmpty) {
      return const OnboardingFlow();
    } else {
      // Redirect handled by router
      return const SizedBox.shrink();
    }
  }
}
