import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'squad_state.dart';
import 'chat/chat_groups_screen.dart';
import 'notification_service.dart';
import 'chat/chat_state.dart';
import 'join_squad_screen.dart';
import 'chat/dialogs/group_actions_dialog.dart';
import 'managers/notification_manager.dart';
import 'managers/firestore_manager.dart';
import 'managers/availability_manager.dart';
import 'managers/game_manager.dart';
import 'managers/user_manager.dart';
import 'managers/review_manager.dart';
import 'managers/squad_manager.dart';
import 'widgets/app_widgets.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  runApp(const SquadSyncApp());
}

Future<void> _initializeFirebase() async {
  try {
    debugPrint('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');

    // Initialize Firebase Analytics
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    debugPrint('Firebase Analytics initialized');

    // Firebase Database persistence is not supported on web
    if (!kIsWeb) {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      debugPrint('Firebase Database persistence enabled');
    }

    try {
      await NotificationService.initialize();
      await NotificationManager.initialize();
      debugPrint('Notification services initialized');
    } catch (e) {
      debugPrint('Notification initialization failed: $e');
      // Notification initialization failed - silently handled
    }

    // IGDB credentials setup (uncomment for first run, then comment out)
    // try {
    //   print('About to call storeCredentials...');
    //   final igdbService = IgdbAuthService();
    //   await igdbService.storeCredentials();
    //   print('IGDB credentials stored - comment out this code after first run');
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

class SquadSyncApp extends StatefulWidget {
  const SquadSyncApp({super.key});

  @override
  State<SquadSyncApp> createState() => _SquadSyncAppState();
}

class _SquadSyncAppState extends State<SquadSyncApp> {
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
    final user = FirebaseAuth.instance.currentUser;
    final squadState = p.Provider.of<SquadState>(context, listen: false);

    if (link == 'codsquadapp://chat' &&
        mounted &&
        user != null &&
        squadState.selectedSquadId != null) {
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
    } else if (link == 'codsquadapp://chat' &&
        mounted &&
        squadState.selectedSquadId == null) {
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
          final user = FirebaseAuth.instance.currentUser;
          final squadState = p.Provider.of<SquadState>(context, listen: false);

          if (user != null && squadState.selectedSquadId != null) {
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
      child: p.MultiProvider(
        providers: [
          p.ChangeNotifierProvider(create: (_) => SquadState()),
          p.ChangeNotifierProvider(create: (_) => ChatState()),
          p.ChangeNotifierProvider(create: (_) => FirestoreManager()),
          p.ChangeNotifierProvider(create: (_) => NotificationManager()),
          p.ChangeNotifierProvider(create: (_) => AvailabilityManager()),
          p.ChangeNotifierProvider(create: (_) => GameManager()),
          p.ChangeNotifierProvider(create: (_) => UserManager()),
          p.ChangeNotifierProvider(create: (_) => ReviewManager()),
          p.ChangeNotifierProvider(create: (_) => SquadManager()),
        ],
        child: const SquadSyncMaterialApp(),
      ),
    );
  }
}
