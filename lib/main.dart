import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'squad_state.dart';
import 'chat/chat_groups_screen.dart';
import 'setup_screen.dart';
import 'notification_service.dart';
import 'chat/chat_state.dart';
import 'app_theme.dart';
import 'join_squad_screen.dart';
import 'managers/notification_manager.dart';
import 'managers/firestore_manager.dart';
import 'managers/availability_manager.dart';
import 'managers/game_manager.dart';
import 'managers/user_manager.dart';
import 'managers/review_manager.dart';
import 'managers/squad_manager.dart';
import 'screens/squad_tab_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  runApp(const SquadSyncApp());
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Firebase Database persistence is not supported on web
    if (!kIsWeb) {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
    }
    try {
      await NotificationService.initialize();
      await NotificationManager.initialize();
    } catch (e) {
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
    // Firebase initialization failed - silently handled
  }
}

class ThemeProvider with ChangeNotifier {
  bool _isDarkTheme = true;
  ThemeData get theme =>
      _isDarkTheme ? AppTheme.darkTheme : AppTheme.lightTheme;

  void toggleTheme(bool isDark) {
    _isDarkTheme = isDark;
    notifyListeners();
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
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    // Deep links will be initialized after Firebase is ready
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
    final squadState = Provider.of<SquadState>(context, listen: false);

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
          final squadState = Provider.of<SquadState>(context, listen: false);

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SquadState()),
        ChangeNotifierProvider(create: (_) => ChatState()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FirestoreManager()),
        ChangeNotifierProvider(create: (_) => NotificationManager()),
        ChangeNotifierProvider(create: (_) => AvailabilityManager()),
        ChangeNotifierProvider(create: (_) => GameManager()),
        ChangeNotifierProvider(create: (_) => UserManager()),
        ChangeNotifierProvider(create: (_) => ReviewManager()),
        ChangeNotifierProvider(create: (_) => SquadManager()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'SquadSync',
          theme: themeProvider.theme,
          routes: {
            '/squad': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is Map<String, dynamic>) {
                // New format: Map with gameName, chatGroupId, etc.
                return SquadTabScreen(
                  gameName: args['gameName'],
                  lobbyId: args['lobbyId'],
                  game: args['game'],
                  chatGroupId: args['chatGroupId'],
                );
              } else if (args is String) {
                // Legacy format: just gameName as string
                return SquadTabScreen(gameName: args);
              }
              return const SquadTabScreen();
            },
          },
          home: Builder(
            builder: (context) {
              // Initialize deep links and Siri shortcuts after Firebase is ready (only once)
              if (!_isInitialized) {
                _isInitialized = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _initDeepLinks();
                  _initSiriShortcuts();
                });
              }

              // Use StreamBuilder to listen to auth state changes
              return StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // Still checking auth status
                    return Scaffold(
                      backgroundColor: Colors.black,
                      body: const Center(
                        child:
                            CircularProgressIndicator(color: Colors.cyanAccent),
                      ),
                    );
                  }

                  final user = snapshot.data;
                  if (user != null) {
                    // User is authenticated, initialize SquadState and show main app
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Provider.of<SquadState>(context, listen: false)
                          .initialize(context);
                      // Load pinned games for Quick Start
                      Provider.of<UserManager>(context, listen: false)
                          .fetchPinnedGames();
                    });
                    return const ChatGroupsScreen();
                  } else {
                    // User not authenticated, show login/setup screen
                    return const SetupScreen();
                  }
                },
              );
            },
          ),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
