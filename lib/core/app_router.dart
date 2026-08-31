import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/lobby_tab_screen.dart';
import '../chat/chat_groups_screen.dart';
import '../chat/chat_screen.dart';
import '../profile_tab.dart';
import '../screens/clips_screen.dart';
import '../join_lobby_screen.dart';
import '../setup_screen.dart';
import '../chat/dialogs/group_actions_dialog.dart';
import '../services/auth_service_supabase.dart';
import '../services/ab_testing_service.dart';
import '../services/supabase_service.dart';
import 'app_env.dart';
import '../domain/entities/message.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'notification_routes.dart';

/// A/B Testing Service Provider
final abTestingServiceProvider = FutureProvider<ABTestingService>((ref) async {
  return await ABTestingService.initialize();
});

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter configuration provider with A/B testing integration
final goRouterProvider = Provider<GoRouter>((ref) {
  final analytics = FirebaseAnalytics.instance;
  final abTestService = ref.watch(abTestingServiceProvider).asData?.value;

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    debugLogDiagnostics: kDebugMode,
    initialLocation: '/',
    redirect: (context, state) async {
      final isLoginRoute = state.matchedLocation == '/setup';

      if (!AppEnv.isSupabaseConfigured || !SupabaseService.isInitialized) {
        return isLoginRoute ? null : '/setup';
      }

      final session = await SupabaseService.ensureFreshSession();
      final user = session?.user;

      // Track navigation for A/B testing
      if (abTestService != null) {
        await abTestService.trackNavigation(
          state.matchedLocation,
          method: 'redirect',
          additionalParams: {
            'authenticated': user != null,
            'target_route': state.matchedLocation,
          },
        );
      }

      // Redirect to setup if not authenticated
      if (user == null && !isLoginRoute) {
        return '/setup';
      }

      // If authenticated and on setup, redirect to main
      if (user != null && isLoginRoute) {
        return '/';
      }

      // OPTIMIZATION: Redirect to last chat on app startup to avoid flash of groups screen
      // Only do this on the initial '/' route to avoid interfering with manual navigation
      if (state.matchedLocation == '/' && user != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final lastGroupId = prefs.getString('last_chat_group');

          if (lastGroupId != null && lastGroupId.isNotEmpty) {
            debugPrint('GoRouter: Redirecting to last chat: $lastGroupId');
            return '/chat/$lastGroupId';
          }
        } catch (e) {
          debugPrint('GoRouter: Error checking last chat: $e');
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const ChatGroupsScreen(),
      ),
      GoRoute(
        path: '/setup',
        name: 'setup',
        builder: (context, state) => const SetupScreen(),
      ),
      GoRoute(
        path: '/squad',
        name: 'squad',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return LobbyTabScreen(
            gameName: extra?['gameName'] as String?,
            lobbyId: extra?['lobbyId'] as String?,
            game: extra?['game'] as Map<String, dynamic>?,
            chatGroupId: extra?['chatGroupId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/squad/:gameName',
        name: 'squadWithGame',
        builder: (context, state) {
          final gameName = state.pathParameters['gameName']!;
          final extra = state.extra as Map<String, dynamic>?;
          return LobbyTabScreen(
            gameName: gameName,
            lobbyId: extra?['lobbyId'] as String?,
            game: extra?['game'] as Map<String, dynamic>?,
            chatGroupId: extra?['chatGroupId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/chat',
        name: 'chat',
        builder: (context, state) => const ChatGroupsScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        name: 'chatDetail',
        builder: (context, state) {
          final chatGroupId = state.pathParameters['id']!;

          // Use a FutureBuilder to handle async loading
          return FutureBuilder<Map<String, dynamic>?>(
            future: SupabaseService.client
                .from('chat_groups')
                .select()
                .eq('id', chatGroupId)
                .maybeSingle(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError || snapshot.data == null) {
                return const ChatGroupsScreen();
              }

              final response = snapshot.data!;
              return ChatScreen(
                chatGroupId: chatGroupId,
                chatGroupName: response['name'] ?? 'Unknown Group',
                chatType: ChatType.userGroup,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileTab(),
      ),
      GoRoute(
        path: '/clips',
        name: 'clips',
        builder: (context, state) => const ClipsScreen(),
      ),
      GoRoute(
        path: '/join',
        name: 'join',
        builder: (context, state) {
          final code = state.uri.queryParameters['code'];
          return JoinLobbyScreen(initialCode: code);
        },
      ),
      GoRoute(
        path: '/join/:code',
        name: 'joinWithCode',
        builder: (context, state) {
          final code = state.pathParameters['code']!;
          return JoinLobbyScreen(initialCode: code);
        },
      ),
    ],
    // Error builder for 404 pages
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              '404 - Page Not Found',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
    observers: [
      FirebaseAnalyticsObserver(analytics: analytics),
    ],
  );
  NotificationRoutes.bindRouter(router, rootNavigatorKey);
  return router;
});

/// Deep link router - handles universal links and app links
class DeepLinkRouter {
  static Future<void> handleDeepLink(
    BuildContext context,
    WidgetRef ref,
    String link,
  ) async {
    final router = GoRouter.of(context);
    final authService = AuthServiceSupabase();
    final user = authService.currentUser;

    // Get user and squad state
    final squadAsync = ref.read(ln.lobbyNotifierProvider);

    final squadId = squadAsync.maybeWhen(
      data: (squadState) => squadState.selectedLobbyId,
      orElse: () => null,
    );

    // Handle different deep link patterns
    if (link == 'codsquadapp://chat' || link.contains('/chat')) {
      if (user != null && squadId != null) {
        // Deferred navigation with addPostFrameCallback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          router.go('/chat');
        });
      } else if (user == null) {
        _showSnackBar(context, 'Please sign in first');
      } else {
        _showSnackBar(context, 'Please join a squad first');
      }
    } else if (link.startsWith('codsquadapp://join/') ||
        link.contains('/join/')) {
      // Extract code from URL
      final uri = Uri.parse(link);
      final code = link.startsWith('codsquadapp://')
          ? link.split('/').last
          : uri.queryParameters['code'] ?? uri.pathSegments.last;

      // Deferred navigation with addPostFrameCallback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        router.go('/join/$code');
      });
    } else if (link.startsWith('https://lobbiesync.app/join/')) {
      // Handle web deep links for group invites
      // Deferred navigation with addPostFrameCallback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => const GroupActionsDialog(),
        );
      });
    }
  }

  static void _showSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

/// A/B Testing Configuration
class ABTestConfig {
  static const String experimentId = 'routing_experiment_v1';
  static const String variantA = 'legacy_navigation';
  static const String variantB = 'go_router_navigation';

  /// Get user's A/B test variant (50/50 split based on user ID hash)
  static String getVariant(String? userId) {
    if (userId == null) return variantA;

    // Use hash of user ID for deterministic variant assignment
    final hash = userId.hashCode.abs();
    return hash % 2 == 0 ? variantA : variantB;
  }

  /// Track A/B test event to Firebase Analytics
  static Future<void> trackEvent(
    String variant,
    String eventName, {
    Map<String, dynamic>? parameters,
  }) async {
    final analytics = FirebaseAnalytics.instance;

    await analytics.logEvent(
      name: eventName,
      parameters: {
        'experiment_id': experimentId,
        'variant': variant,
        ...?parameters,
      },
    );
  }

  /// Track navigation events for A/B testing
  static Future<void> trackNavigation(
    String variant,
    String route, {
    String? method,
  }) async {
    await trackEvent(
      variant,
      'navigation',
      parameters: {
        'route': route,
        'method': method ?? 'unknown',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
}
