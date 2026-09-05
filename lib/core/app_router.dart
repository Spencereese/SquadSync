import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/discovery_swipe_screen.dart';
import '../screens/lobby_tab_screen.dart';
import '../chat/chat_groups_screen.dart';
import '../chat/chat_screen.dart';
import '../profile_tab.dart';
import '../screens/clips_screen.dart';
import '../screens/performance_stats_screen.dart';
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
import 'deep_link_routes.dart';
import 'lobby_chat_bind.dart';
import 'package:squad_sync/presentation/notifiers/notification_notifier.dart';

/// A/B Testing Service Provider
final abTestingServiceProvider = FutureProvider<ABTestingService>((ref) async {
  return await ABTestingService.initialize();
});

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// `/squad` and `/squad/:gameName` extras plus `lobby_id` query.
/// `spot_index` highlights the offered peacock seat (ticket 35).
@visibleForTesting
class SquadRouteArgs {
  const SquadRouteArgs({
    this.gameName,
    this.lobbyId,
    this.game,
    this.chatGroupId,
    this.spotIndex,
  });

  final String? gameName;
  final String? lobbyId;
  final Map<String, dynamic>? game;
  final String? chatGroupId;
  final int? spotIndex;

  factory SquadRouteArgs.fromState(GoRouterState state) {
    final extra = state.extra as Map<String, dynamic>?;
    final pathGame = state.pathParameters['gameName'];
    final query = state.uri.queryParameters;
    return SquadRouteArgs(
      gameName: _nonEmpty(pathGame) ?? extra?['gameName'] as String?,
      lobbyId: _nonEmpty(extra?['lobbyId']) ?? _nonEmpty(query['lobby_id']),
      game: extra?['game'] as Map<String, dynamic>?,
      chatGroupId: extra?['chatGroupId'] as String?,
      spotIndex: NotificationRoutes.spotIndexFrom({
        ...query,
        if (extra != null) ...extra,
      }),
    );
  }

  static String? _nonEmpty(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}

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
            var openId = lastGroupId;
            try {
              final snapshot = await loadLobbyChatBindSnapshot(lastGroupId);
              final resolved = resolveActiveChatGroupId(
                widgetChatGroupId: lastGroupId,
                isSquad: false,
                lobbyChatGroupId: snapshot.lobbyChatGroupId,
                historyCounts: snapshot.historyCounts,
                extraChatIds: snapshot.candidates,
              );
              if (resolved != null && resolved.isNotEmpty) {
                openId = resolved;
                if (openId != lastGroupId) {
                  await prefs.setString('last_chat_group', openId);
                }
              }
            } catch (e) {
              debugPrint('GoRouter: last-chat bind skipped: $e');
            }
            debugPrint(
              'GoRouter: groups-list path before last-chat redirect '
              'last=$lastGroupId open=$openId',
            );
            debugPrint('GoRouter: Redirecting to last chat: $openId');
            return '/chat/$openId';
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
          final args = SquadRouteArgs.fromState(state);
          return LobbyTabScreen(
            gameName: args.gameName,
            lobbyId: args.lobbyId,
            game: args.game,
            chatGroupId: args.chatGroupId,
            highlightSpotIndex: args.spotIndex,
          );
        },
      ),
      GoRoute(
        path: '/squad/:gameName',
        name: 'squadWithGame',
        builder: (context, state) {
          final args = SquadRouteArgs.fromState(state);
          return LobbyTabScreen(
            gameName: args.gameName,
            lobbyId: args.lobbyId,
            game: args.game,
            chatGroupId: args.chatGroupId,
            highlightSpotIndex: args.spotIndex,
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

              final response = snapshot.data;
              return ChatScreen(
                chatGroupId: chatGroupId,
                chatGroupName: response?['name'] as String? ?? 'Chat',
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
        path: '/stats',
        name: 'stats',
        builder: (context, state) => const PerformanceStatsScreen(),
      ),
      GoRoute(
        path: '/clips',
        name: 'clips',
        builder: (context, state) => const ClipsScreen(),
      ),
      GoRoute(
        path: '/discover-swipe',
        name: 'discoverSwipe',
        builder: (context, state) => const DiscoverySwipeScreen(),
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
    final authService = AuthServiceSupabase();
    final user = authService.currentUser;

    // Get user and squad state
    final squadAsync = ref.read(ln.lobbyNotifierProvider);

    final squadId = squadAsync.maybeWhen(
      data: (squadState) => squadState.selectedLobbyId,
      orElse: () => null,
    );

    // Web invite dialog stays on the HTTPS join URL. Lobby / peacock /
    // LFG / notification taps share [locationForDeepLink] below.
    if (link.startsWith('https://lobbiesync.app/join/')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => const GroupActionsDialog(),
        );
      });
      return;
    }

    // Live AppLinks path: leftover sim UL dropped; unknown lobby ids
    // still map to /squad?lobby_id= (existence is not required).
    final location = locationForLiveAppLink(link);
    if (location == null) return;
    debugPrint('DeepLinkRouter: $link -> $location');

    // /squad?lobby_id= must still land even when the lobby does not exist
    // and even if SquadSyncApp's context is above MaterialApp.router.
    if (location.startsWith('/squad')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _go(location);
      });
      return;
    }

    if (location.startsWith('/chat') && user == null) {
      _showSnackBar(context, 'Please sign in first');
      return;
    }

    if (location == '/chat') {
      if (user != null && squadId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _go('/chat');
        });
      } else if (user == null) {
        _showSnackBar(context, 'Please sign in first');
      } else {
        _showSnackBar(context, 'Please join a squad first');
      }
      return;
    }

    final parsedChatId = _chatIdFromLocation(location);
    if (parsedChatId != null) {
      // Do not drop /chat/:id (1f580ae AppLinks overlay mentioned the
      // 46-row thread once and never opened it).
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        var openId = parsedChatId;
        try {
          final snapshot = await loadLobbyChatBindSnapshot(parsedChatId);
          final resolved = resolveActiveChatGroupId(
            widgetChatGroupId: parsedChatId,
            isSquad: false,
            lobbyChatGroupId: snapshot.lobbyChatGroupId,
            historyCounts: snapshot.historyCounts,
            extraChatIds: snapshot.candidates,
          );
          if (resolved != null && resolved.isNotEmpty) openId = resolved;
        } catch (e) {
          debugPrint('DeepLinkRouter: chat bind skipped: $e');
        }
        debugPrint('DeepLinkRouter: Opening chat $openId');
        _go('/chat/$openId');
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _go(location);
    });
  }

  /// Prefer the bound GoRouter. [GoRouter.of] on SquadSyncApp's context
  /// is above MaterialApp.router and would throw, leaving splash/black.
  static void _go(String location) {
    debugPrint('DeepLinkRouter: go $location');
    final go = NotificationRoutes.go;
    if (go != null) {
      go(location);
      return;
    }
    final stored = NotificationRoutes.router;
    if (stored != null) {
      stored.go(location);
      return;
    }
    final navContext = NotificationRoutes.navigatorKey?.currentContext;
    if (navContext != null && navContext.mounted) {
      GoRouter.of(navContext).go(location);
      return;
    }
    NotificationRoutes.navigate(location);
  }

  static String? _chatIdFromLocation(String location) {
    final uri = Uri.parse(location);
    if (uri.pathSegments.length < 2 || uri.pathSegments.first != 'chat') {
      return null;
    }
    final id = uri.pathSegments[1].trim();
    return id.isEmpty ? null : id;
  }

  /// Pure URI → go_router location. See [locationForDeepLink].
  static String? locationFor(String link) => locationForDeepLink(link);

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
