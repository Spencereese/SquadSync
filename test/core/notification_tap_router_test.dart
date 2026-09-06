import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:squad_sync/core/app_env.dart';
import 'package:squad_sync/core/app_router.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/core/lobby_chat_bind.dart';
import 'package:squad_sync/core/notification_routes.dart';
import 'package:squad_sync/notification_service.dart';
import 'package:squad_sync/screens/lobby_tab_screen.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// Ticket 42: notification tap → bound [GoRouter] → lobby / peacock / chat /
/// deep-link screens already in the tree. No second presenter.
void main() {
  late GoRouter router;
  late GlobalKey<NavigatorState> navigatorKey;

  setUp(() {
    pendingLinkQueue.clear();
    navigatorKey = GlobalKey<NavigatorState>();
    router = _productRouter(navigatorKey);
    NotificationRoutes.bindRouter(router, navigatorKey);
  });

  tearDown(() {
    pendingLinkQueue.clear();
    NotificationRoutes.go = null;
    NotificationRoutes.router = null;
    NotificationRoutes.navigatorKey = null;
    router.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('screen:home'), findsOneWidget);
  }

  Future<void> tap(WidgetTester tester, void Function() fire) async {
    fire();
    await tester.pumpAndSettle();
  }

  group('happy path: tap → router → screen', () {
    testWidgets('lobby availability_ping tap opens lobby', (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationService.handleOpenedData({
          'type': 'availability_ping',
          'lobby_id': 'lobby-9',
        }),
      );
      expect(find.text('screen:home'), findsNothing);
      expect(
        find.text('screen:lobby lobby:lobby-9 game:none spot:none'),
        findsOneWidget,
      );
      expect(find.text('screen:lobby-empty'), findsNothing);
    });

    testWidgets('peacock_assigned JSON tap opens lobby with game',
        (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.openRaw(
          '{"type":"peacock_assigned","game_name":"Warzone","lobby_id":"lobby-9"}',
        ),
      );
      expect(
        find.text('screen:lobby lobby:lobby-9 game:Warzone spot:none'),
        findsOneWidget,
      );
    });

    testWidgets('peacock assigned with spot_index highlights the seat',
        (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.open({
          'type': 'peacock_assigned',
          'lobby_id': 'lobby-9',
          'game_name': 'Warzone',
          'spot_index': 2,
        }),
      );
      expect(
        find.text('screen:lobby lobby:lobby-9 game:Warzone spot:2'),
        findsOneWidget,
      );
    });

    testWidgets('lobby_locked tap opens the same lobby screen', (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.open({
          'type': 'lobby_locked',
          'lobby_id': 'lobby-9',
        }),
      );
      expect(
        find.text('screen:lobby lobby:lobby-9 game:none spot:none'),
        findsOneWidget,
      );
    });

    testWidgets('chat payload tap opens the chat card', (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.open({
          'type': 'chat',
          'chatGroupId': '1766270568521',
        }),
      );
      expect(find.text('screen:chat id:1766270568521'), findsOneWidget);
    });

    testWidgets('lfg_alert tap opens the chat card', (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.open({
          'type': 'lfg_alert',
          'squad_id': 'squad-1',
        }),
      );
      expect(find.text('screen:chat id:squad-1'), findsOneWidget);
    });

    testWidgets('chat peacock card tap opens lobby with offered seat',
        (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => openPeacockCard(
          lobbyId: 'lobby-9',
          gameName: 'Warzone',
          spotIndex: 2,
        ),
      );
      expect(
        find.text('screen:lobby lobby:lobby-9 game:Warzone spot:2'),
        findsOneWidget,
      );
    });

    testWidgets(
        'peacock card tap and peacock_assigned notification open the same lobby',
        (tester) async {
      await pumpApp(tester);
      const payload = {
        'type': 'peacock_assigned',
        'lobby_id': 'lobby-9',
        'game_name': 'Warzone',
        'spot_index': 2,
      };
      expect(
        locationForDeepLink(
          peacockCardDeepLink(
            lobbyId: 'lobby-9',
            gameName: 'Warzone',
            spotIndex: 2,
          ),
        ),
        NotificationRoutes.locationFor(payload),
      );
      await tap(
        tester,
        () => openPeacockCard(
          lobbyId: 'lobby-9',
          gameName: 'Warzone',
          spotIndex: 2,
        ),
      );
      expect(
        find.text('screen:lobby lobby:lobby-9 game:Warzone spot:2'),
        findsOneWidget,
      );
    });

    testWidgets('offline peacock card tap does not leave home', (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => openPeacockCard(
          lobbyId: 'lobby-9',
          gameName: 'Warzone',
          spotIndex: 2,
          isOffline: true,
        ),
      );
      expect(find.text('screen:home'), findsOneWidget);
      expect(find.textContaining('screen:lobby'), findsNothing);
      expect(find.textContaining('screen:error'), findsNothing);
    });

    testWidgets('stats payload tap opens stats', (tester) async {
      await pumpApp(tester);
      await tap(tester, () => NotificationRoutes.open({'type': 'stats'}));
      expect(find.text('screen:stats'), findsOneWidget);
    });
  });

  group('happy path: deep-link targets already in the tree', () {
    testWidgets('codsquadapp://lobby/:id opens lobby', (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.openRaw('codsquadapp://lobby/lobby-9'),
      );
      expect(
        find.text('screen:lobby lobby:lobby-9 game:none spot:none'),
        findsOneWidget,
      );
    });

    testWidgets('https://codsquad.app/l/:id opens lobby', (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.openRaw('https://codsquad.app/l/lobby-9'),
      );
      expect(
        find.text('screen:lobby lobby:lobby-9 game:none spot:none'),
        findsOneWidget,
      );
    });

    testWidgets('codsquadapp://peacock/:id opens lobby', (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.openRaw('codsquadapp://peacock/lobby-9'),
      );
      expect(
        find.text('screen:lobby lobby:lobby-9 game:none spot:none'),
        findsOneWidget,
      );
    });

    testWidgets('codsquadapp://chat/:id opens chat card', (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.openRaw('codsquadapp://chat/1766270568521'),
      );
      expect(find.text('screen:chat id:1766270568521'), findsOneWidget);
    });

    testWidgets('codsquadapp://stats opens stats', (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.openRaw('codsquadapp://stats'),
      );
      expect(find.text('screen:stats'), findsOneWidget);
    });

    testWidgets('codsquadapp://join/:code opens join', (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.openRaw('codsquadapp://join/ABC123'),
      );
      expect(find.text('screen:join code:ABC123'), findsOneWidget);
    });

    testWidgets('product URLs never hit the error builder', (tester) async {
      await pumpApp(tester);
      const urls = [
        'codsquadapp://lobby/lobby-9',
        'codsquadapp://peacock/lobby-9',
        'codsquadapp://chat/1766270568521',
        'codsquadapp://stats',
        'https://codsquad.app/l/lobby-9',
        'codsquadapp://join/ABC123',
        'codsquadapp://notify?type=peacock_assigned&lobby_id=lobby-9',
      ];
      for (final url in urls) {
        NotificationRoutes.openRaw(url);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('screen:error'),
          findsNothing,
          reason: url,
        );
        expect(find.text('screen:home'), findsNothing, reason: url);
      }
    });

    testWidgets('DeepLinkRouter.locationFor matches the bound go path',
        (tester) async {
      await pumpApp(tester);
      const url = 'codsquadapp://lobby/lobby-9';
      final location = DeepLinkRouter.locationFor(url);
      expect(location, '/squad?lobby_id=lobby-9');
      await tap(tester, () => NotificationRoutes.go?.call(location!));
      expect(
        find.text('screen:lobby lobby:lobby-9 game:none spot:none'),
        findsOneWidget,
      );
    });
  });

  group('unknown payload / missing id empty+error paths', () {
    testWidgets('unknown payload does not leave home', (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.open({'type': 'unknown'}),
      );
      expect(find.text('screen:home'), findsOneWidget);
      expect(find.textContaining('screen:lobby'), findsNothing);
      expect(find.textContaining('screen:error'), findsNothing);
    });

    testWidgets('empty and garbage openRaw stay on home', (tester) async {
      await pumpApp(tester);
      for (final raw in [
        null,
        '',
        '   ',
        'hello',
        '{not-json',
        'not=a-route'
      ]) {
        NotificationRoutes.openRaw(raw);
        await tester.pumpAndSettle();
        expect(find.text('screen:home'), findsOneWidget, reason: '$raw');
        expect(find.textContaining('screen:error'), findsNothing,
            reason: '$raw');
      }
    });

    testWidgets('handleOpenedData empty map does not navigate', (tester) async {
      await pumpApp(tester);
      await tap(tester, () => NotificationService.handleOpenedData({}));
      expect(find.text('screen:home'), findsOneWidget);
    });

    testWidgets('unknown deep-link URI does not invent a screen',
        (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.openRaw('codsquadapp://unknown/path'),
      );
      expect(find.text('screen:home'), findsOneWidget);
      expect(find.textContaining('screen:error'), findsNothing);
    });

    testWidgets('missing lobby_id peacock tap is empty squad not error',
        (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.open({'type': 'peacock_assigned'}),
      );
      expect(
        find.text('screen:lobby lobby:none game:none spot:none'),
        findsOneWidget,
      );
      expect(find.text('screen:lobby-empty'), findsOneWidget);
      expect(find.textContaining('screen:error'), findsNothing);
      expect(
        LobbyTabScreen.shouldShowFullSquad(gameName: null, lobbyId: null),
        isFalse,
      );
    });

    testWidgets('empty lobby_id string is missing id, not a lobby',
        (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.open({
          'type': 'lobby',
          'lobby_id': '',
        }),
      );
      expect(
        find.text('screen:lobby lobby:none game:none spot:none'),
        findsOneWidget,
      );
      expect(find.text('screen:lobby-empty'), findsOneWidget);
    });

    testWidgets('missing chat id opens empty chat list not a card',
        (tester) async {
      await pumpApp(tester);
      await tap(tester, () => NotificationRoutes.open({'type': 'chat'}));
      expect(find.text('screen:chat-list'), findsOneWidget);
      expect(find.textContaining('screen:chat id:'), findsNothing);
      expect(find.textContaining('screen:error'), findsNothing);
    });

    testWidgets('empty chatGroupId is missing id → chat list', (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.open({
          'type': 'chat',
          'chatGroupId': '  ',
        }),
      );
      expect(find.text('screen:chat-list'), findsOneWidget);
    });

    testWidgets('peacock card with missing lobby_id is empty squad',
        (tester) async {
      await pumpApp(tester);
      await tap(tester, () => openPeacockCard());
      expect(
        find.text('screen:lobby lobby:none game:none spot:none'),
        findsOneWidget,
      );
      expect(find.text('screen:lobby-empty'), findsOneWidget);
    });

    testWidgets('lfg_alert without squad_id opens empty chat list',
        (tester) async {
      await pumpApp(tester);
      await tap(tester, () => NotificationRoutes.open({'type': 'lfg_alert'}));
      expect(find.text('screen:chat-list'), findsOneWidget);
    });

    testWidgets('unknown type with lobby_id still opens that lobby',
        (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationRoutes.open({
          'type': 'unknown_event',
          'lobby_id': 'lobby-9',
        }),
      );
      expect(
        find.text('screen:lobby lobby:lobby-9 game:none spot:none'),
        findsOneWidget,
      );
    });
  });

  group('cold start: killed → open URL', () {
    setUp(() {
      NotificationRoutes.go = null;
      NotificationRoutes.router = null;
      NotificationRoutes.navigatorKey = null;
      pendingLinkQueue.clear();
    });

    Future<void> pumpUnbound(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('screen:home'), findsOneWidget);
    }

    testWidgets('getInitialLink lobby URL opens after bindRouter flush',
        (tester) async {
      await pumpUnbound(tester);
      pendingLinkQueue.offerColdStartUri(
        Uri.parse('codsquadapp://lobby/lobby-9'),
        isIosSimulator: true,
      );
      expect(find.text('screen:home'), findsOneWidget);
      expect(pendingLinkQueue.source, PendingLinkSource.coldStart);

      NotificationRoutes.bindRouter(router, navigatorKey);
      await tester.pumpAndSettle();
      expect(
        find.text('screen:lobby lobby:lobby-9 game:none spot:none'),
        findsOneWidget,
      );
      expect(find.textContaining('screen:error'), findsNothing);
      expect(pendingLinkQueue.isPending, isFalse);
    });

    testWidgets('getInitialMessage peacock payload opens after bind',
        (tester) async {
      await pumpUnbound(tester);
      NotificationService.handleOpenedData({
        'type': 'peacock_assigned',
        'lobby_id': 'lobby-9',
        'game_name': 'Warzone',
        'spot_index': 2,
      });
      expect(find.text('screen:home'), findsOneWidget);
      expect(
        pendingLinkQueue.location,
        '/squad/Warzone?lobby_id=lobby-9&spot_index=2',
      );

      NotificationRoutes.bindRouter(router, navigatorKey);
      await tester.pumpAndSettle();
      expect(
        find.text('screen:lobby lobby:lobby-9 game:Warzone spot:2'),
        findsOneWidget,
      );
    });

    testWidgets('device https /l/:id cold start opens lobby', (tester) async {
      await pumpUnbound(tester);
      pendingLinkQueue.offerColdStartUrl(
        'https://codsquad.app/l/lobby-9',
        isIosSimulator: false,
      );
      NotificationRoutes.bindRouter(router, navigatorKey);
      await tester.pumpAndSettle();
      expect(
        find.text('screen:lobby lobby:lobby-9 game:none spot:none'),
        findsOneWidget,
      );
    });

    testWidgets('unknown killed URL stays home, no error screen',
        (tester) async {
      await pumpUnbound(tester);
      pendingLinkQueue.offerColdStartUrl(
        'codsquadapp://unknown/path',
        isIosSimulator: true,
      );
      NotificationRoutes.bindRouter(router, navigatorKey);
      await tester.pumpAndSettle();
      expect(find.text('screen:home'), findsOneWidget);
      expect(find.textContaining('screen:error'), findsNothing);
    });

    testWidgets('missing lobby_id peacock cold start is empty squad',
        (tester) async {
      await pumpUnbound(tester);
      pendingLinkQueue.offerColdStartPayload({'type': 'peacock_assigned'});
      NotificationRoutes.bindRouter(router, navigatorKey);
      await tester.pumpAndSettle();
      expect(
        find.text('screen:lobby lobby:none game:none spot:none'),
        findsOneWidget,
      );
      expect(find.text('screen:lobby-empty'), findsOneWidget);
      expect(find.textContaining('screen:error'), findsNothing);
    });

    testWidgets('missing chat id cold start is empty chat list',
        (tester) async {
      await pumpUnbound(tester);
      pendingLinkQueue.offerColdStartPayload({'type': 'chat'});
      NotificationRoutes.bindRouter(router, navigatorKey);
      await tester.pumpAndSettle();
      expect(find.text('screen:chat-list'), findsOneWidget);
      expect(find.textContaining('screen:chat id:'), findsNothing);
      expect(find.textContaining('screen:error'), findsNothing);
    });

    testWidgets('unknown lobby id cold start still lands on that lobby',
        (tester) async {
      await pumpUnbound(tester);
      pendingLinkQueue.offerColdStartUrl(
        'codsquadapp://lobby/smoke-no-such-lobby-20260903',
        isIosSimulator: true,
      );
      NotificationRoutes.bindRouter(router, navigatorKey);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'screen:lobby lobby:smoke-no-such-lobby-20260903 game:none spot:none',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('screen:error'), findsNothing);
    });
  });

  group('background-resume with pending link', () {
    testWidgets('uriLinkStream lobby URL opens the lobby screen',
        (tester) async {
      await pumpApp(tester);
      final location = pendingLinkQueue.offerResumeUri(
        Uri.parse('codsquadapp://lobby/lobby-9'),
        isIosSimulator: true,
      );
      expect(location, '/squad?lobby_id=lobby-9');
      pendingLinkQueue.flush();
      await tester.pumpAndSettle();
      expect(
        find.text('screen:lobby lobby:lobby-9 game:none spot:none'),
        findsOneWidget,
      );
    });

    testWidgets('onMessageOpenedApp payload opens lobby', (tester) async {
      await pumpApp(tester);
      await tap(
        tester,
        () => NotificationService.handleOpenedData({
          'type': 'lobby_locked',
          'lobby_id': 'lobby-9',
        }),
      );
      expect(
        find.text('screen:lobby lobby:lobby-9 game:none spot:none'),
        findsOneWidget,
      );
    });

    testWidgets('resume pending chat / stats / join stay on product routes',
        (tester) async {
      await pumpApp(tester);
      pendingLinkQueue.offerResumeUrl(
        'codsquadapp://chat/1766270568521',
        isIosSimulator: true,
      );
      pendingLinkQueue.flush();
      await tester.pumpAndSettle();
      expect(find.text('screen:chat id:1766270568521'), findsOneWidget);

      pendingLinkQueue.offerResumeUrl(
        'codsquadapp://stats',
        isIosSimulator: true,
      );
      pendingLinkQueue.flush();
      await tester.pumpAndSettle();
      expect(find.text('screen:stats'), findsOneWidget);

      pendingLinkQueue.offerResumeUrl(
        'codsquadapp://join/ABC123',
        isIosSimulator: true,
      );
      pendingLinkQueue.flush();
      await tester.pumpAndSettle();
      expect(find.text('screen:join code:ABC123'), findsOneWidget);
      expect(find.textContaining('screen:error'), findsNothing);
    });

    testWidgets('launch + matching resume flushes once to lobby',
        (tester) async {
      await pumpApp(tester);
      const url = 'codsquadapp://lobby/lobby-9';
      pendingLinkQueue.consumeAppLinkStubs(
        initialLink: url,
        resumeLink: url,
        isIosSimulator: true,
      );
      pendingLinkQueue.flush();
      await tester.pumpAndSettle();
      expect(
        find.text('screen:lobby lobby:lobby-9 game:none spot:none'),
        findsOneWidget,
      );
      expect(find.textContaining('screen:error'), findsNothing);
    });

    testWidgets('unknown resume URL stays home, no error', (tester) async {
      await pumpApp(tester);
      pendingLinkQueue.offerResumeUrl(
        'codsquadapp://unknown/path',
        isIosSimulator: true,
      );
      pendingLinkQueue.flush();
      await tester.pumpAndSettle();
      expect(find.text('screen:home'), findsOneWidget);
      expect(find.textContaining('screen:error'), findsNothing);
    });

    testWidgets('missing id resume peacock is empty squad', (tester) async {
      await pumpApp(tester);
      pendingLinkQueue.offerResumePayload({'type': 'peacock_assigned'});
      pendingLinkQueue.flush();
      await tester.pumpAndSettle();
      expect(
        find.text('screen:lobby lobby:none game:none spot:none'),
        findsOneWidget,
      );
      expect(find.text('screen:lobby-empty'), findsOneWidget);
      expect(find.textContaining('screen:error'), findsNothing);
    });
  });

  group('Slice I — notification tap apply THAT lobby', () {
    testWidgets(
      'peacock_assigned | lobby_lock | lobby_created with lobby_id '
      'open THAT lobby not empty /squad',
      (tester) async {
        await pumpApp(tester);
        for (final type in [
          'peacock_assigned',
          'lobby_lock',
          'lobby_created',
        ]) {
          NotificationRoutes.open({
            'type': type,
            'lobby_id': 'lobby-9',
          });
          await tester.pumpAndSettle();
          expect(
            find.text('screen:lobby lobby:lobby-9 game:none spot:none'),
            findsOneWidget,
            reason: type,
          );
          expect(find.text('screen:lobby-empty'), findsNothing, reason: type);
          expect(find.text('screen:home'), findsNothing, reason: type);
        }
        expect(
          File('lib/core/notification_routes.dart').readAsStringSync(),
          contains('applyLobbyDeepLink'),
          reason: 'tap must apply selectedLobbyId + Slice G bind, not go-only',
        );
      },
    );

    testWidgets(
      'custom scheme and https /l/:id tap the same apply helper',
      (tester) async {
        await pumpApp(tester);
        for (final url in [
          'codsquadapp://lobby/lobby-9',
          'https://codsquad.app/l/lobby-9',
        ]) {
          NotificationRoutes.openRaw(url);
          await tester.pumpAndSettle();
          expect(
            find.text('screen:lobby lobby:lobby-9 game:none spot:none'),
            findsOneWidget,
            reason: url,
          );
        }
        expect(
          File('lib/core/deep_link_routes.dart').readAsStringSync(),
          contains('LobbyDeepLinkApply applyLobbyDeepLink'),
        );
      },
    );

    testWidgets(
      'friendsMode tap still /squad?lobby_id= not Discovery',
      (tester) async {
        AppEnv.debugReplaceForTest({'FRIENDS_MODE': 'true'});
        addTearDown(() => AppEnv.debugReplaceForTest({}));
        await pumpApp(tester);
        await tap(
          tester,
          () => NotificationRoutes.open({
            'type': 'lobby_created',
            'lobby_id': 'lobby-9',
          }),
        );
        expect(
          NotificationRoutes.locationFor({
            'type': 'lobby_created',
            'lobby_id': 'lobby-9',
          }),
          '/squad?lobby_id=lobby-9',
        );
        expect(
          friendsRootAllowsLocation(
            '/squad?lobby_id=lobby-9',
            friendsMode: true,
          ),
          isTrue,
        );
        expect(find.text('screen:lobby lobby:lobby-9 game:none spot:none'),
            findsOneWidget);
        expect(
          File('lib/core/notification_routes.dart').readAsStringSync(),
          contains('applyLobbyDeepLink'),
        );
      },
    );

    test(
      'after tap: selectedLobbyId, subscribe, Slice G bind, splash down',
      () {
        final routes =
            File('lib/core/notification_routes.dart').readAsStringSync();
        final apply =
            File('lib/core/deep_link_routes.dart').readAsStringSync();
        expect(routes, contains('applyLobbyDeepLink'));
        expect(apply, contains('selectedLobbyId'));
        expect(apply, contains('switchActiveLobbyChatBind'));
        expect(apply, contains('dismissSplash'));
        expect(
          ActiveLobbyChatBind.empty.isBound,
          isFalse,
          reason: 'must not keep the last random thread',
        );
      },
    );

    test(
      'malformed / missing id tap drops, stays put, no hang',
      () {
        expect(
          File('lib/core/deep_link_routes.dart').readAsStringSync(),
          contains('stayedPut'),
        );
      },
    );

    test('do not double-go AppLinks + pending + GoRouter on tap', () {
      final opened = <String>[];
      NotificationRoutes.go = opened.add;
      const url = 'codsquadapp://lobby/lobby-9';
      pendingLinkQueue.offerColdStartUrl(url, isIosSimulator: true);
      pendingLinkQueue.flush();
      NotificationRoutes.openRaw(url);
      expect(opened, ['/squad?lobby_id=lobby-9']);
    });

    test('XOR still planPeacockSelfNotify after tap apply', () {
      expect(
        planPeacockSelfNotify(
          notificationId: 'tap-1',
          currentUid: 'me',
          isForeground: false,
          locallyPresentedIds: {'tap-1'},
        ).sendFcmToSelf,
        isFalse,
      );
    });
  });
}

GoRouter _productRouter(GlobalKey<NavigatorState> key) {
  return GoRouter(
    navigatorKey: key,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Text('screen:home'),
      ),
      GoRoute(
        path: '/squad',
        builder: (context, state) =>
            _LobbyScreen(args: SquadRouteArgs.fromState(state)),
      ),
      GoRoute(
        path: '/squad/:gameName',
        builder: (context, state) =>
            _LobbyScreen(args: SquadRouteArgs.fromState(state)),
      ),
      GoRoute(
        path: '/chat',
        builder: (_, __) => const Text('screen:chat-list'),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          return Text('screen:chat id:${state.pathParameters['id']}');
        },
      ),
      GoRoute(
        path: '/stats',
        builder: (_, __) => const Text('screen:stats'),
      ),
      GoRoute(
        path: '/join/:code',
        builder: (context, state) {
          return Text('screen:join code:${state.pathParameters['code']}');
        },
      ),
    ],
    errorBuilder: (context, state) => Text('screen:error ${state.uri}'),
  );
}

class _LobbyScreen extends StatelessWidget {
  const _LobbyScreen({required this.args});

  final SquadRouteArgs args;

  @override
  Widget build(BuildContext context) {
    final empty = !LobbyTabScreen.shouldShowFullSquad(
      gameName: args.gameName,
      lobbyId: args.lobbyId,
    );
    return Column(
      children: [
        Text(
          'screen:lobby lobby:${args.lobbyId ?? 'none'} '
          'game:${args.gameName ?? 'none'} '
          'spot:${args.spotIndex ?? 'none'}',
        ),
        if (empty) const Text('screen:lobby-empty'),
      ],
    );
  }
}
