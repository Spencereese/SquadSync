import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart'; // Add this import
import 'setup_screen.dart';
import 'notification_service.dart';
import 'chat/chat_state.dart'; // Import ChatState

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => ChatState(), // Provide ChatState here
      child: const CodSquadApp(),
    ),
  );
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

class CodSquadApp extends StatelessWidget {
  const CodSquadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
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
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 24,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            cardTheme: CardTheme(
              color: Colors.grey[900]!,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.cyanAccent.withAlpha(76),
                  width: 1,
                ),
              ),
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.white, fontSize: 16),
              titleLarge: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              labelLarge: TextStyle(color: Colors.white, fontSize: 16),
              headlineMedium: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: Colors.black,
              selectedItemColor: Colors.cyanAccent,
              unselectedItemColor: Colors.grey[600],
              selectedLabelStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              showUnselectedLabels: true,
              selectedIconTheme:
                  const IconThemeData(color: Colors.cyanAccent, size: 24),
              unselectedIconTheme:
                  IconThemeData(color: Colors.grey[600], size: 24),
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
        );
      },
    );
  }
}
