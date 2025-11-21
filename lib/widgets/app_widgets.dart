import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart' as p;
import '../screens/squad_tab_screen.dart';
import '../chat/chat_groups_screen.dart';
import '../setup_screen.dart';
import '../screens/onboarding/onboarding_flow.dart';
import '../squad_state.dart';
import '../managers/user_manager.dart';
import '../providers.dart';

/// ConsumerWidget for the main MaterialApp with theme support
class SquadSyncMaterialApp extends ConsumerWidget {
  const SquadSyncMaterialApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = ref.watch(themeProvider);

    return MaterialApp(
      title: 'SquadSync',
      theme: themeData,
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
        '/main': (context) => const ChatGroupsScreen(),
      },
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// ConsumerWidget for handling authentication and onboarding logic
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only watch the pinnedGames property for granular updates
    final pinnedGames = ref.watch(
        userManagerProvider.select((userManager) => userManager.pinnedGames));

    // Use StreamBuilder to listen to auth state changes
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        debugPrint(
            'Auth state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, user: ${snapshot.data}, error: ${snapshot.error}');

        // Check if Firebase is properly initialized
        try {
          FirebaseAuth.instance.app
              .name; // This will throw if Firebase isn't initialized
        } catch (e) {
          debugPrint('Firebase not properly initialized: $e');
          return const SetupScreen();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          // Still checking auth status
          return Scaffold(
            backgroundColor: Colors.black,
            body: const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            ),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          debugPrint('User authenticated: ${user.uid}');
          // User is authenticated, initialize SquadState and show main app
          WidgetsBinding.instance.addPostFrameCallback((_) {
            p.Provider.of<SquadState>(context, listen: false).initialize();
            p.Provider.of<UserManager>(context, listen: false)
                .fetchPinnedGames();
          });
          // Check if user has completed onboarding (has pinned games)
          if (pinnedGames.isEmpty) {
            return const OnboardingFlow();
          } else {
            return const ChatGroupsScreen();
          }
        } else {
          debugPrint('User not authenticated, showing setup screen');
          // User not authenticated, show login/setup screen
          return const SetupScreen();
        }
      },
    );
  }
}
