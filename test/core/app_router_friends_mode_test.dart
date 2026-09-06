import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:squad_sync/core/app_env.dart';
import 'package:squad_sync/core/app_router.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/screens/lobby_tab_screen.dart';

/// Slice F reds: friendsMode shell. Files stay; gate router + bottom nav.
/// No product behavior in this commit — Loop greens in ≤3 lib files:
/// 1. [AppEnv.friendsMode] / FRIENDS_MODE dart-define (app_env.dart)
/// 2. friends root tabs + route gate + post-login landing (app_router.dart)
/// 3. bottom nav / main shell widget only if the tab list needs a widget
///
/// Friend taps / sees (friendsMode on): Tonight/Squad, Chat (bound lobby
/// thread), You. Discovery / constitution / Grok / poll creation / public
/// lobby browser stay on disk but are not root-reachable.
void main() {
  setUp(() {
    AppEnv.debugReplaceForTest({});
  });
  tearDown(() {
    AppEnv.debugReplaceForTest({});
  });

  group('AppEnv.friendsMode', () {
    test('defaults true when FRIENDS_MODE is unset', () {
      AppEnv.debugReplaceForTest({});
      expect(AppEnv.friendsMode, isTrue);
    });

    test('reads FRIENDS_MODE from dart-define overlay', () {
      AppEnv.debugReplaceForTest(mergeEnvLayers(
        dartDefines: const {'FRIENDS_MODE': 'true'},
      ));
      expect(AppEnv.friendsMode, isTrue);

      AppEnv.debugReplaceForTest(mergeEnvLayers(
        dartDefines: const {'FRIENDS_MODE': 'false'},
      ));
      expect(AppEnv.friendsMode, isFalse);
    });
  });

  group('friendsMode true — root tabs', () {
    test('only Tonight/Squad + Chat + You are root tabs', () {
      final tabs = friendsRootTabs(friendsMode: true);
      expect(tabs, hasLength(3));
      expect(
        tabs.map((tab) => tab.label).toList(),
        ['Tonight/Squad', 'Chat', 'You'],
      );
      expect(
        tabs.map((tab) => tab.route).toList(),
        ['/squad', '/chat', '/profile'],
      );
    });

    test('only Tonight/Squad + Chat + You routes are reachable from root', () {
      const allowed = [
        '/squad',
        '/squad?lobby_id=lobby-9',
        '/squad/Warzone?lobby_id=lobby-9',
        '/chat',
        '/chat/lobby-thread-9',
        '/profile',
      ];
      for (final location in allowed) {
        expect(
          friendsRootAllowsLocation(location, friendsMode: true),
          isTrue,
          reason: location,
        );
      }

      const blockedFromRoot = [
        '/',
        '/discover-swipe',
        '/join',
        '/join/ABC',
        '/stats',
        '/clips',
      ];
      for (final location in blockedFromRoot) {
        expect(
          friendsRootAllowsLocation(location, friendsMode: true),
          isFalse,
          reason: location,
        );
      }
    });
  });

  group('friendsMode true — gated surfaces stay on disk', () {
    test('Discovery / constitution / Grok / polls / public browser files stay',
        () {
      const kept = [
        'lib/screens/discovery_swipe_screen.dart',
        'lib/screens/discovery_screen.dart',
        'lib/services/constitution_manager.dart',
        'lib/chat/dialogs/constitution_voting_sheet.dart',
        'lib/widgets/grok_concierge.dart',
        'lib/services/grok_concierge.dart',
        'lib/chat/poll_creation_dialog.dart',
        'lib/join_lobby_screen.dart',
        'lib/chat/lobbies_screen.dart',
      ];
      for (final path in kept) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('those surfaces are gated off the friends root, not deleted', () {
      const gated = [
        FriendsGatedSurface.discovery,
        FriendsGatedSurface.constitution,
        FriendsGatedSurface.grok,
        FriendsGatedSurface.pollCreation,
        FriendsGatedSurface.publicLobbyBrowser,
      ];
      for (final surface in gated) {
        expect(
          friendsGatesSurface(surface, friendsMode: true),
          isTrue,
          reason: surface.name,
        );
      }
      expect(
        friendsRootAllowsLocation('/discover-swipe', friendsMode: true),
        isFalse,
      );
      expect(
        friendsRootAllowsLocation('/join', friendsMode: true),
        isFalse,
      );
    });
  });

  group('friendsMode true — /squad?lobby_id= still resolves', () {
    test('friends root still allows the lobby deep-link location', () {
      expect(
        friendsRootAllowsLocation(
          '/squad?lobby_id=lobby-9',
          friendsMode: true,
        ),
        isTrue,
      );
      expect(
        locationForDeepLink('codsquadapp://squad?lobby_id=lobby-9'),
        '/squad?lobby_id=lobby-9',
      );
    });

    testWidgets('GoRouter still lands /squad?lobby_id= under friendsMode',
        (tester) async {
      AppEnv.debugReplaceForTest({'FRIENDS_MODE': 'true'});
      expect(AppEnv.friendsMode, isTrue);

      String? seenLobbyId;
      final router = GoRouter(
        initialLocation: '/squad?lobby_id=lobby-9',
        redirect: (context, state) {
          if (!friendsRootAllowsLocation(
            state.uri.toString(),
            friendsMode: AppEnv.friendsMode,
          )) {
            return '/squad';
          }
          return null;
        },
        routes: [
          GoRoute(
            path: '/squad',
            builder: (context, state) {
              final args = SquadRouteArgs.fromState(state);
              seenLobbyId = args.lobbyId;
              return Text('lobby:${args.lobbyId ?? 'none'}');
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(seenLobbyId, 'lobby-9');
      expect(find.text('lobby:lobby-9'), findsOneWidget);
      expect(
        LobbyTabScreen.shouldShowFullSquad(
          gameName: null,
          lobbyId: seenLobbyId,
        ),
        isTrue,
      );
    });
  });

  group('friendsMode true — login lands on /squad', () {
    test('login success goes to /squad, not last random chat', () {
      expect(
        resolveFriendsPostLoginLocation(
          friendsMode: true,
          lastChatGroupId: 'random-chat-22',
          boundLobbyThreadId: 'lobby-thread-9',
        ),
        '/squad',
      );
      expect(
        resolveFriendsPostLoginLocation(
          friendsMode: true,
          lastChatGroupId: 'random-chat-22',
          boundLobbyThreadId: null,
        ),
        '/squad',
      );
      expect(
        resolveFriendsPostLoginLocation(
          friendsMode: true,
          lastChatGroupId: null,
          boundLobbyThreadId: null,
        ),
        '/squad',
      );
    });

    test('login may open last chat only when it is the bound lobby thread', () {
      expect(
        resolveFriendsPostLoginLocation(
          friendsMode: true,
          lastChatGroupId: 'lobby-thread-9',
          boundLobbyThreadId: 'lobby-thread-9',
        ),
        '/chat/lobby-thread-9',
      );
    });
  });

  group('friendsMode false — prior full shell', () {
    test('full root tabs and gated surfaces return', () {
      final tabs = friendsRootTabs(friendsMode: false);
      expect(tabs.length, greaterThan(3));
      expect(
        tabs.map((tab) => tab.route),
        containsAll(['/', '/discover-swipe', '/squad', '/chat', '/profile']),
      );

      for (final surface in FriendsGatedSurface.values) {
        expect(
          friendsGatesSurface(surface, friendsMode: false),
          isFalse,
          reason: surface.name,
        );
      }

      for (final location in const [
        '/',
        '/discover-swipe',
        '/join',
        '/join/ABC',
        '/stats',
        '/clips',
        '/squad',
        '/chat',
        '/profile',
      ]) {
        expect(
          friendsRootAllowsLocation(location, friendsMode: false),
          isTrue,
          reason: location,
        );
      }
    });

    test('login still follows last chat (prior redirect)', () {
      expect(
        resolveFriendsPostLoginLocation(
          friendsMode: false,
          lastChatGroupId: 'random-chat-22',
          boundLobbyThreadId: 'lobby-thread-9',
        ),
        '/chat/random-chat-22',
      );
      expect(
        resolveFriendsPostLoginLocation(
          friendsMode: false,
          lastChatGroupId: null,
          boundLobbyThreadId: 'lobby-thread-9',
        ),
        '/',
      );
    });
  });
}
