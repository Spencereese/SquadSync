
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'squad_state.dart';
import 'chat/chat_screen.dart';
import 'setup_screen.dart';
import 'notification_service.dart';
import 'chat/chat_state.dart';
import 'app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SquadSyncApp());
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    try {
      await NotificationService.initialize();
    } catch (e) {
      debugPrint('NotificationService initialization failed: $e');
    }
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
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
  StreamSubscription<String?>? _sub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
    _initSiriShortcuts();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialLink = await _appLinks.getInitialAppLinkString();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    _sub = _appLinks.stringLinkStream.listen((String? link) {
      if (link != null) {
        _handleDeepLink(link);
      }
    }, onError: (err) {
      debugPrint('Error in link stream: $err');
    });
  }

  void _handleDeepLink(String link) {
    if (link == 'codsquadapp://chat' && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChatScreen()),
      );
    }
  }

  Future<void> _initSiriShortcuts() async {
    try {
      platform.setMethodCallHandler((call) async {
        if (call.method == 'sendMessage' && mounted) {
          final message = call.arguments['message'] as String;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(initialMessage: message),
            ),
          );
          return true;
        }
        return false;
      });
    } catch (e) {
      debugPrint('Error setting up Siri channel: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SquadState()),
        ChangeNotifierProvider(create: (_) => ChatState()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => FutureBuilder(
          future: _initializeFirebase(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return MaterialApp(
                home: Scaffold(
                  backgroundColor: Colors.black,
                  body: const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return MaterialApp(
                home: Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              );
            }
            return MaterialApp(
              title: 'SquadSync',
              theme: themeProvider.theme,
              home: Builder(
                builder: (context) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Provider.of<SquadState>(context, listen: false)
                        .initialize(context);
                  });
                  return const SetupScreen();
                },
              ),
              debugShowCheckedModeBanner: false,
            );
          },
        ),
      ),
    );
  }
}
