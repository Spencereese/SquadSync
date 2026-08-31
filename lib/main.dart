import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/app_env.dart';
import 'firebase_options.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'presentation/controllers/game_theme_controller.dart';
import 'package:app_links/app_links.dart';
import 'services/auth_service_supabase.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'core/injection.dart' as di;
import 'core/app_router.dart';
import 'notification_service.dart';
import 'widgets/app_widgets.dart';
import 'services/supabase_service.dart';
import 'services/session_debug_helper.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'services/background_sync_service.dart';
import 'services/peacock_notification_service.dart';
import 'services/auto_merge_service.dart';

void main() async {
  // Preserve native splash screen until we're ready
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  try {
    await AppEnv.load();
  } catch (e) {
    debugPrint('dotenv load failed: $e');
  }

  // Initialize SharedPreferences for theme persistence
  final prefs = await SharedPreferences.getInstance();

  // Initialize background sync service for offline-first operations
  try {
    debugPrint('Initializing background sync service...');
    final syncService = BackgroundSyncService();
    await syncService.initialize();
    debugPrint('Background sync service initialized successfully');
  } catch (e) {
    debugPrint('Background sync initialization failed: $e');
    // Continue - app will work but without background sync
  }

  // Initialize Firebase (ANALYTICS & MESSAGING ONLY - all DB ops on Supabase)
  // Note: Firebase Core/Firestore removed Dec 2025 - retained only for:
  //   - firebase_analytics: User analytics and event tracking
  //   - firebase_messaging: Push notifications (FCM)
  await _initializeFirebase();

  // Initialize Supabase (PRIMARY DATABASE - all auth, real-time, storage)
  try {
    await SupabaseService.initialize();

    // Debug: Check session persistence (only in debug mode)
    if (kDebugMode) {
      await SessionDebugHelper.checkSessionPersistence();
      SessionDebugHelper.setupAuthListener();
    }
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
    // Continue with Firebase-only mode
  }

  // Setup dependency injection AFTER Firebase is ready
  try {
    debugPrint('Starting dependency injection setup...');
    await di.setupInjection();
    debugPrint('Dependency injection completed successfully');
  } catch (e, stackTrace) {
    debugPrint('Dependency injection failed: $e');
    debugPrint('Stack trace: $stackTrace');
    // Re-throw to prevent app from running with broken dependencies
    rethrow;
  }

  try {
    if (!di.getIt.isRegistered<AutoMergeService>()) {
      di.getIt.registerSingleton<AutoMergeService>(AutoMergeService());
    }
    if (AppEnv.isSupabaseConfigured && SupabaseService.isInitialized) {
      di.getIt<AutoMergeService>().startMergeDetection();
      debugPrint('Auto-merge service initialized');
    } else {
      debugPrint('AutoMerge skipped: Supabase not configured');
    }
  } catch (e) {
    debugPrint('Auto-merge service initialization failed: $e');
  }

  // Note: Native splash will be removed by app_widgets.dart after Flutter content is ready
  // DO NOT call FlutterNativeSplash.remove() here - it removes splash too early

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // ProviderScope must wrap the app — SquadSyncApp is a ConsumerStatefulWidget.
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: SquadSyncApp(prefs: prefs),
    ),
  );
}

/// Initialize Firebase for Analytics & Messaging ONLY
/// Note: All database operations use Supabase (PostgreSQL + Realtime)
/// Firebase retained only for:
///   - firebase_analytics: User behavior tracking
///   - firebase_messaging: Push notifications (FCM)
Future<void> _initializeFirebase() async {
  try {
    debugPrint('Initializing Firebase (Analytics & Messaging only)...');

    // Check if Firebase is already initialized to avoid duplicate app error
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized successfully');
    } else {
      debugPrint('Firebase already initialized, skipping...');
    }

    // Debug assertions for null safety
    if (kDebugMode) {
      assert(Firebase.apps.isNotEmpty, 'Firebase not initialized');
    }

    // Initialize Firebase Analytics (for user behavior tracking)
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    debugPrint('Firebase Analytics initialized');

    // Initialize push notifications (Firebase Cloud Messaging)
    try {
      await NotificationService.initialize();
      debugPrint('Notification services (FCM) initialized');
    } catch (e) {
      debugPrint('Notification initialization failed: $e');
      // Notification initialization failed - silently handled
    }

    // Initialize peacock queue notifications (after user authentication)
    // This is called after login in AuthServiceSupabase
    // PeacockNotificationService.initialize() is called when user signs in

    // Auto-merge starts after GetIt setup in main() — not here.
    // Remove duplicate call to avoid issues
    // await di.setupInjection();
    // debugPrint('Dependency injection initialized');

    // IGDB credentials setup - COMMENTED OUT (blocks app initialization)
    // Uncomment only for first-time setup, then comment out again
    // try {
    //   debugPrint('About to call storeCredentials...');
    //   final igdbService = IgdbAuthService();
    //   await igdbService.storeCredentials();
    //   debugPrint(
    //       'IGDB credentials stored - comment out this code after first run');
    // } catch (e) {
    //   debugPrint('IGDB credentials setup failed: $e');
    // }

    // Grok API key setup (uncomment for first run, then comment out)
    // try {
    //   print('Setting up Grok API key...');
    //   final grokService = GrokService();
    //   await grokService.storeApiKey();
    //   print('Grok API key stored - comment out this code after first run');
    // } catch (e) {
    //   debugPrint('Grok API key setup failed: $e');
    // }
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    // Firebase initialization failed - silently handled
  }
}

class SquadSyncApp extends ConsumerStatefulWidget {
  final SharedPreferences prefs;

  const SquadSyncApp({super.key, required this.prefs});

  @override
  ConsumerState<SquadSyncApp> createState() => _SquadSyncAppState();
}

class _SquadSyncAppState extends ConsumerState<SquadSyncApp> {
  static const platform = MethodChannel('com.example.codSquadApp/siri');
  late AppLinks _appLinks;
  StreamSubscription<Uri?>? _sub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    // Initialize deep links after Firebase is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDeepLinks();
      _initSiriShortcuts();
      _initPeacockNotifications();
    });
  }

  @override
  void dispose() {
    PeacockNotificationService.dispose();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    // Handle initial link
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null && mounted) {
      _handleDeepLink(initialLink.toString());
    }

    // Listen for incoming links - initial link handling may be different in v6
    _sub = _appLinks.uriLinkStream.listen((Uri? link) {
      if (link != null && mounted) {
        _handleDeepLink(link.toString());
      }
    }, onError: (err) {
      // Error in link stream - silently handled
    });
  }

  void _handleDeepLink(String link) {
    if (!mounted) return;

    // Use DeepLinkRouter for go_router integration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        DeepLinkRouter.handleDeepLink(context, ref, link);
      }
    });
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _initSiriShortcuts() async {
    try {
      platform.setMethodCallHandler((call) async {
        if (call.method == 'sendMessage' && mounted) {
          final authService = AuthServiceSupabase();
          final user = authService.currentUser;

          if (user != null && mounted) {
            // Defer navigation to avoid _debugLocked assertion
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.go('/chat');
              }
            });
            return true;
          } else if (user == null) {
            _showSnackBar('Please sign in first');
            return false;
          }
        }
        return false;
      });
    } catch (e) {
      // Error setting up Siri channel - silently handled
    }
  }

  Future<void> _initPeacockNotifications() async {
    try {
      final authService = AuthServiceSupabase();
      final user = authService.currentUser;

      if (user != null) {
        final session = await SupabaseService.ensureFreshSession();
        if (session == null) {
          debugPrint('Peacock skipped: session expired');
        } else {
          await PeacockNotificationService.initialize();
          await PeacockNotificationService.checkPendingNotifications();
          debugPrint('✅ Peacock notification service initialized');
        }
      }

      // Listen for auth state changes to handle login/logout
      final authClient = SupabaseService.maybeClient;
      if (authClient == null) return;
      authClient.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        if (session != null) {
          // User logged in - initialize peacock notifications
          PeacockNotificationService.initialize();
          PeacockNotificationService.checkPendingNotifications();
          debugPrint(
              '✅ Peacock notifications active for user: ${session.user.id}');
        } else {
          // User logged out - dispose listener
          PeacockNotificationService.dispose();
          debugPrint('🦚 Peacock notifications disposed');
        }
      });
    } catch (e) {
      debugPrint('⚠️ Peacock notification initialization failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SquadSyncMaterialApp();
  }
}
