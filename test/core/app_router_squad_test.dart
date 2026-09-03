import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:squad_sync/core/app_router.dart';
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
}
