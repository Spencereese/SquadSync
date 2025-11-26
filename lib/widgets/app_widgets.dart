import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../screens/squad_tab_screen.dart';
import '../chat/chat_groups_screen.dart';
import '../setup_screen.dart';
import '../screens/onboarding/onboarding_flow.dart';
import '../providers.dart'; // Keep for themeProvider
import '../providers/service_providers.dart'; // Keep for authStateProvider
import '../presentation/notifiers/user_notifier.dart';

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
  static final Logger _logger = Logger();
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth state using Riverpod provider
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          _logger.i('User authenticated: ${user.uid}');
          // User is authenticated, initialize SquadStateNotifier and show main app
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // ref.read(sn.squadNotifierProvider.notifier).initialize(context); // Initialization is automatic in build
            // Note: UserNotifier loads data automatically in build method
          });
          // Show onboarding wrapper that will check if onboarding is needed
          return const OnboardingWrapper();
        } else {
          _logger.i('User not authenticated, showing setup screen');
          // User not authenticated, show login/setup screen
          return const SetupScreen();
        }
      },
      loading: () => Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      ),
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
class OnboardingWrapper extends ConsumerWidget {
  const OnboardingWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch user state to determine if onboarding is needed
    final userStateAsync = ref.watch(userNotifierProvider);

    return userStateAsync.when(
      loading: () => const ChatGroupsScreen(),
      error: (error, stack) =>
          const ChatGroupsScreen(), // Default to main screen on error
      data: (userState) {
        // If no pinned games, show onboarding
        if (userState == null) {
          return const ChatGroupsScreen();
        } else if (userState.pinnedGames.isEmpty) {
          return const OnboardingFlow();
        } else {
          return const ChatGroupsScreen();
        }
      },
    );
  }
}
