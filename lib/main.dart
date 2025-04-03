import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'setup_screen.dart';
import 'notification_service.dart';
import 'chat/chat_screen.dart';
import 'chat/chat_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CodSquadApp());
}

class CodSquadApp extends StatelessWidget {
  const CodSquadApp({super.key});

  Future<void> _initializeFirebase() async {
    try {
      // Initialize Firebase with default options (should pick up GoogleService-Info.plist automatically)
      await Firebase.initializeApp();
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      await Future.delayed(const Duration(seconds: 1));
      await NotificationService.initialize();
    } catch (e) {
      // Re-throw the error so FutureBuilder can catch it
      throw Exception('Firebase initialization failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeFirebase(),
      builder: (context, snapshot) {
        // While waiting for initialization
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // If an error occurred during initialization
        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text(
                  'Error initializing Firebase:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        // If initialization succeeded, build the main app
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ChatState()),
          ],
          child: MaterialApp(
            title: 'SquadSync',
            theme: ThemeData(
              brightness: Brightness.dark,
              primarySwatch: Colors.indigo,
              scaffoldBackgroundColor: Colors.transparent,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.black,
                foregroundColor: Colors.cyanAccent,
                elevation: 0,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              cardTheme: CardTheme(
                color: Colors.grey[900]!,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.cyanAccent.withAlpha(76), width: 1),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              ),
              textTheme: const TextTheme(
                bodyMedium: TextStyle(color: Colors.white, fontSize: 16),
                titleLarge: TextStyle(
                    color: Colors.cyanAccent, fontSize: 20, fontWeight: FontWeight.bold),
                labelLarge: TextStyle(color: Colors.white, fontSize: 16),
                headlineMedium: TextStyle(
                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: Colors.black,
                selectedItemColor: Colors.cyanAccent,
                unselectedItemColor: Colors.grey[600],
              ),
              iconTheme: const IconThemeData(
                color: Colors.cyanAccent,
                size: 24,
              ),
              sliderTheme: const SliderThemeData(
                activeTrackColor: Colors.cyanAccent,
                inactiveTrackColor: Colors.grey,
                thumbColor: Colors.cyanAccent,
                overlayColor: Colors.cyanAccent,
                valueIndicatorColor: Colors.cyanAccent,
                valueIndicatorTextStyle: TextStyle(color: Colors.black),
              ),
            ),
            home: const SetupScreen(),
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}