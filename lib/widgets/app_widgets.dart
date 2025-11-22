import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/squad_tab_screen.dart';
import '../chat/chat_groups_screen.dart';
import '../setup_screen.dart';
import '../screens/onboarding/onboarding_flow.dart';
import '../squad_state.dart';
import '../providers.dart';
import '../providers/service_providers.dart';

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
    // Watch auth state using Riverpod provider
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          debugPrint('User authenticated: ${user.uid}');
          // User is authenticated, initialize SquadStateNotifier and show main app
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(squadStateNotifierProvider.notifier).initialize(context);
            ref.read(userManagerProvider).fetchPinnedGames();
          });
          // Show onboarding wrapper that will check if onboarding is needed
          return const OnboardingWrapper();
        } else {
          debugPrint('User not authenticated, showing setup screen');
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
    // Watch pinned games and fetch status to determine if onboarding is needed
    final userManager = ref.watch(userManagerProvider);
    final pinnedGames = userManager.pinnedGames;
    final pinnedGamesFetched = userManager.pinnedGamesFetched;

    // If pinned games haven't been fetched yet, show loading or main screen
    if (!pinnedGamesFetched) {
      return const ChatGroupsScreen(); // Default to main screen while loading
    }

    // If no pinned games after fetching, show onboarding
    if (pinnedGames.isEmpty) {
      return const OnboardingFlow();
    } else {
      return const ChatGroupsScreen();
    }
  }
}
