import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'squad_state.dart';
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
      print('NotificationService initialization failed: $e');
    }
  } catch (e) {
    print('Firebase initialization failed: $e');
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

class SquadSyncApp extends StatelessWidget {
  const SquadSyncApp({super.key});

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
