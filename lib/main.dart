import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'presentation/controllers/game_theme_controller.dart';
import 'package:app_links/app_links.dart';
import 'services/auth_service_supabase.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'presentation/notifiers/user_notifier.dart';
import 'presentation/notifiers/squad_notifier.dart';
import 'chat/chat_groups_screen.dart';
import 'notification_service.dart';
import 'join_squad_screen.dart';
import 'chat/dialogs/group_actions_dialog.dart';
import 'widgets/app_widgets.dart';
import 'services/igdb_auth_service.dart';
import 'core/injection.dart' as di;
import 'services/supabase_service.dart';
import 'services/session_debug_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load();
  } catch (e) {
    debugPrint('dotenv load failed: $e');
  }

  // Initialize SharedPreferences for theme persistence
  final prefs = await SharedPreferences.getInstance();

  // Ensure Firebase is initialized FIRST
  await _initializeFirebase();

  // Initialize Supabase (dual client architecture)
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

  runApp(SquadSyncApp(prefs: prefs));
}

Future<void> _initializeFirebase() async {
  try {
    debugPrint('Initializing Firebase...');

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

    // Initialize Firebase Analytics
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    debugPrint('Firebase Analytics initialized');

    try {
      await NotificationService.initialize();

      debugPrint('Notification services initialized');
    } catch (e) {
      debugPrint('Notification initialization failed: $e');
      // Notification initialization failed - silently handled
    }

    // Dependency injection is already done before this function is called
    // Remove duplicate call to avoid issues
    // await di.setupInjection();
    // debugPrint('Dependency injection initialized');

    // IGDB credentials setup (uncomment for first run, then comment out)
    try {
      print('About to call storeCredentials...');
      final igdbService = IgdbAuthService();
      await igdbService.storeCredentials();
      print('IGDB credentials stored - comment out this code after first run');
    } catch (e) {
      debugPrint('IGDB credentials setup failed: $e');
    }

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
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    // Handle initial link
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      _handleDeepLink(initialLink.toString());
    }

    // Listen for incoming links - initial link handling may be different in v6
    _sub = _appLinks.uriLinkStream.listen((Uri? link) {
      if (link != null) {
        _handleDeepLink(link.toString());
      }
    }, onError: (err) {
      // Error in link stream - silently handled
    });
  }

  void _handleDeepLink(String link) {
    // Check if user is authenticated and has a squad before navigating
    final userAsync = ref.watch(userNotifierProvider);
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);

    final authService = AuthServiceSupabase();
    final user = userAsync.maybeWhen(
      data: (userState) => userState != null && userState.displayName != null
          ? authService.currentUser
          : null,
      orElse: () => null,
    );
    final squadId = squadAsync.maybeWhen(
      data: (squadState) => squadState.selectedLobbyId,
      orElse: () => null,
    );

    if (link == 'codsquadapp://chat' &&
        mounted &&
        user != null &&
        squadId != null) {
      // Defer navigation to avoid _debugLocked assertion
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatGroupsScreen()),
          );
        }
      });
    } else if (link.startsWith('codsquadapp://join/') && mounted) {
      final code = link.split('/').last;
      // Defer navigation to avoid _debugLocked assertion
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JoinSquadScreen(initialCode: code),
            ),
          );
        }
      });
    } else if (link.startsWith('https://squadsync.app/join/') && mounted) {
      // Handle web deep links for group invites
      final uri = Uri.parse(link);
      final code = uri.queryParameters['code'];
      // Defer navigation to avoid _debugLocked assertion
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => GroupActionsDialog(
              initialTabIndex: 0, // Join tab
              initialCode: code,
            ),
          );
        }
      });
    } else if (link == 'codsquadapp://chat' && mounted && user == null) {
      // User not authenticated, show login screen
      _showSnackBar('Please sign in first');
    } else if (link == 'codsquadapp://chat' && mounted && squadId == null) {
      // User authenticated but no squad, show squad selection
      _showSnackBar('Please join a squad first');
    }
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
          final squadAsync = ref.watch(ln.lobbyNotifierProvider);

          final squadId = squadAsync.maybeWhen(
            data: (squadState) => squadState.selectedLobbyId,
            orElse: () => null,
          );

          if (user != null && squadId != null) {
            // Defer navigation to avoid _debugLocked assertion
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatGroupsScreen(),
                  ),
                );
              }
            });
            return true;
          } else if (user == null) {
            _showSnackBar('Please sign in first');
            return false;
          } else {
            _showSnackBar('Please join a squad first');
            return false;
          }
        }
        return false;
      });
    } catch (e) {
      // Error setting up Siri channel - silently handled
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(widget.prefs),
      ],
      child: const SquadSyncMaterialApp(),
    );
  }
}
