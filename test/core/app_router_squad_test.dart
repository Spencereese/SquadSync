import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:squad_sync/core/app_router.dart';
import 'package:squad_sync/core/notification_routes.dart';
import 'package:squad_sync/screens/lobby_tab_screen.dart';

void main() {
  testWidgets('squad route honors lobby_id without gameName', (tester) async {
    String? seenLobbyId;
    String? seenGameName;

    final router = GoRouter(
      initialLocation: '/squad?lobby_id=lobby-9',
      routes: [
        GoRoute(
          path: '/squad',
          builder: (context, state) {
            final args = SquadRouteArgs.fromState(state);
            seenLobbyId = args.lobbyId;
            seenGameName = args.gameName;
            return Text(
              'lobby:${args.lobbyId ?? 'none'} game:${args.gameName ?? 'none'}',
            );
          },
        ),
        GoRoute(
          path: '/squad/:gameName',
          builder: (context, state) {
            final args = SquadRouteArgs.fromState(state);
            seenLobbyId = args.lobbyId;
            seenGameName = args.gameName;
            return Text(
              'lobby:${args.lobbyId ?? 'none'} game:${args.gameName ?? 'none'}',
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(seenLobbyId, 'lobby-9');
    expect(seenGameName, isNull);
    expect(find.text('lobby:lobby-9 game:none'), findsOneWidget);
    expect(
      LobbyTabScreen.shouldShowFullSquad(
        gameName: seenGameName,
        lobbyId: seenLobbyId,
      ),
      isTrue,
    );
    expect(
      LobbyTabScreen.shouldShowFullSquad(gameName: null, lobbyId: null),
      isFalse,
    );

    router.go('/squad/Warzone?lobby_id=lobby-9');
    await tester.pumpAndSettle();
    expect(seenLobbyId, 'lobby-9');
    expect(seenGameName, 'Warzone');
    expect(find.text('lobby:lobby-9 game:Warzone'), findsOneWidget);
  });

  testWidgets('squad route honors spot_index highlight from peacock card',
      (tester) async {
    int? seenSpot;

    final router = GoRouter(
      initialLocation: '/squad/Warzone?lobby_id=lobby-9&spot_index=2',
      routes: [
        GoRoute(
          path: '/squad',
          builder: (context, state) {
            final args = SquadRouteArgs.fromState(state);
            seenSpot = args.spotIndex;
            return Text('spot:${args.spotIndex ?? 'none'}');
          },
        ),
        GoRoute(
          path: '/squad/:gameName',
          builder: (context, state) {
            final args = SquadRouteArgs.fromState(state);
            seenSpot = args.spotIndex;
            return Text('spot:${args.spotIndex ?? 'none'}');
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(seenSpot, 2);
    expect(find.text('spot:2'), findsOneWidget);
  });

  testWidgets('unknown lobby id still lands on /squad with lobby_id',
      (tester) async {
    const missing = 'smoke-no-such-lobby-20260903';
    String? seenLobbyId;

    final router = GoRouter(
      initialLocation: '/squad?lobby_id=$missing',
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

    expect(seenLobbyId, missing);
    expect(find.text('lobby:$missing'), findsOneWidget);
    expect(
      LobbyTabScreen.shouldShowFullSquad(gameName: null, lobbyId: missing),
      isTrue,
    );
  });

  testWidgets('missing lobby_id is empty squad, not a 404', (tester) async {
    String? seenLobbyId;
    String? seenGameName;

    final router = GoRouter(
      initialLocation: '/squad',
      routes: [
        GoRoute(
          path: '/squad',
          builder: (context, state) {
            final args = SquadRouteArgs.fromState(state);
            seenLobbyId = args.lobbyId;
            seenGameName = args.gameName;
            return Text(
              'lobby:${args.lobbyId ?? 'none'} game:${args.gameName ?? 'none'}',
            );
          },
        ),
      ],
      errorBuilder: (context, state) => Text('error:${state.uri}'),
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(seenLobbyId, isNull);
    expect(seenGameName, isNull);
    expect(find.text('lobby:none game:none'), findsOneWidget);
    expect(find.textContaining('error:'), findsNothing);
    expect(
      LobbyTabScreen.shouldShowFullSquad(
        gameName: seenGameName,
        lobbyId: seenLobbyId,
      ),
      isFalse,
    );
  });

  testWidgets('notification tap uses bound router to open lobby',
      (tester) async {
    final key = GlobalKey<NavigatorState>();
    final router = GoRouter(
      navigatorKey: key,
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Text('home'),
        ),
        GoRoute(
          path: '/squad',
          builder: (context, state) {
            final args = SquadRouteArgs.fromState(state);
            return Text('lobby:${args.lobbyId ?? 'none'}');
          },
        ),
      ],
    );
    NotificationRoutes.bindRouter(router, key);
    addTearDown(() {
      NotificationRoutes.go = null;
      NotificationRoutes.router = null;
      NotificationRoutes.navigatorKey = null;
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);

    NotificationRoutes.open({
      'type': 'availability_ping',
      'lobby_id': 'lobby-9',
    });
    await tester.pumpAndSettle();
    expect(find.text('lobby:lobby-9'), findsOneWidget);
  });
}
