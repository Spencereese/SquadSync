import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/app_links_policy.dart';
import 'package:squad_sync/core/app_router.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/core/lobby_chat_bind.dart';
import 'package:squad_sync/core/notification_routes.dart';
import 'package:squad_sync/notification_service.dart';

/// Ticket 46: cold-start + background-resume pending-link stubs.
/// Resolves through existing [locationForDeepLink] / [NotificationRoutes]
/// product routes only.
void main() {
  late PendingLinkQueue queue;

  setUp(() {
    queue = PendingLinkQueue();
    pendingLinkQueue.clear();
    NotificationRoutes.go = null;
    NotificationRoutes.router = null;
    NotificationRoutes.navigatorKey = null;
  });

  tearDown(() {
    queue.clear();
    pendingLinkQueue.clear();
    NotificationRoutes.go = null;
    NotificationRoutes.router = null;
    NotificationRoutes.navigatorKey = null;
  });

  group('cold start: killed → open URL', () {
    test('getInitialLink lobby URL holds /squad?lobby_id= until flush', () {
      const url = 'codsquadapp://lobby/lobby-9';
      final location = queue.offerColdStartUri(
        Uri.parse(url),
        isIosSimulator: true,
      );
      expect(location, '/squad?lobby_id=lobby-9');
      expect(DeepLinkRouter.locationFor(url), location);
      expect(queue.location, location);
      expect(queue.source, PendingLinkSource.coldStart);
      expect(queue.isPending, isTrue);

      final opened = <String>[];
      expect(queue.flush(go: opened.add), location);
      expect(opened, [location]);
      expect(queue.isPending, isFalse);
    });

    test('https://codsquad.app/l/:id holds lobby on device, drops on sim', () {
      const url = 'https://codsquad.app/l/lobby-9';
      expect(
        queue.offerColdStartUrl(url, isIosSimulator: false),
        '/squad?lobby_id=lobby-9',
      );
      queue.clear();
      expect(
        queue.offerColdStartUrl(url, isIosSimulator: true),
        isNull,
      );
      expect(queue.isPending, isFalse);
    });

    test('peacock / chat / stats / join URLs reuse ticket 42 routes', () {
      expect(
        queue.offerColdStartUrl(
          'codsquadapp://peacock/lobby-9?game_name=Warzone&spot_index=2',
          isIosSimulator: true,
        ),
        '/squad/Warzone?lobby_id=lobby-9&spot_index=2',
      );
      queue.clear();
      expect(
        queue.offerColdStartUrl(
          'codsquadapp://chat/1766270568521',
          isIosSimulator: true,
        ),
        '/chat/1766270568521',
      );
      queue.clear();
      expect(
        queue.offerColdStartUrl('codsquadapp://stats', isIosSimulator: true),
        '/stats',
      );
      queue.clear();
      expect(
        queue.offerColdStartUrl(
          'codsquadapp://join/ABC123',
          isIosSimulator: true,
        ),
        '/join/ABC123',
      );
    });

    test('getInitialMessage payload holds the same lobby route', () {
      final location = queue.offerColdStartPayload({
        'type': 'availability_ping',
        'lobby_id': 'lobby-9',
      });
      expect(location, '/squad?lobby_id=lobby-9');
      expect(queue.source, PendingLinkSource.coldStart);
      expect(
        NotificationRoutes.locationFor({
          'type': 'peacock_assigned',
          'lobby_id': 'lobby-9',
        }),
        location,
      );
    });

    test('consumeAppLinkStubs is getInitialLink then uriLinkStream', () {
      var splash = 0;
      final result = queue.consumeAppLinkStubs(
        initialUri: Uri.parse('codsquadapp://lobby/lobby-9'),
        isIosSimulator: true,
        dismissSplash: () => splash++,
      );
      expect(result.launch, '/squad?lobby_id=lobby-9');
      expect(result.resume, isNull);
      expect(splash, 1);
      expect(queue.source, PendingLinkSource.coldStart);
    });

    test('plan still reads getInitialLink on simulator', () {
      final plan = planAppLinkListen(isIosSimulator: true);
      expect(plan.consumeInitialLink, isTrue);
      expect(plan.subscribeUriLinkStream, isTrue);
    });
  });

  group('background-resume with pending link', () {
    test('uriLinkStream lobby URL holds and flushes once', () {
      const url = 'codsquadapp://lobby/lobby-9';
      final location = queue.offerResumeUri(
        Uri.parse(url),
        isIosSimulator: true,
      );
      expect(location, '/squad?lobby_id=lobby-9');
      expect(queue.source, PendingLinkSource.resume);

      final opened = <String>[];
      queue.flush(go: opened.add);
      queue.flush(go: opened.add);
      expect(opened, [location]);
    });

    test('onMessageOpenedApp payload holds lobby / chat / stats', () {
      expect(
        queue.offerResumePayload({
          'type': 'lobby_locked',
          'lobby_id': 'lobby-9',
          'game_name': 'Warzone',
        }),
        '/squad/Warzone?lobby_id=lobby-9',
      );
      queue.clear();
      expect(
        queue.offerResumePayload({
          'type': 'lfg_alert',
          'squad_id': 'squad-1',
        }),
        '/chat/squad-1',
      );
      queue.clear();
      expect(queue.offerResumePayload({'type': 'stats'}), '/stats');
    });

    test('killed URL then matching resume is stored once', () {
      const url = 'codsquadapp://lobby/lobby-9';
      final result = queue.consumeAppLinkStubs(
        initialLink: url,
        resumeLink: url,
        isIosSimulator: true,
      );
      expect(result.launch, '/squad?lobby_id=lobby-9');
      expect(result.resume, '/squad?lobby_id=lobby-9');
      expect(queue.location, '/squad?lobby_id=lobby-9');
      expect(queue.source, PendingLinkSource.coldStart);

      final opened = <String>[];
      queue.flush(go: opened.add);
      expect(opened, ['/squad?lobby_id=lobby-9']);
    });

    test('sim leftover launch does not clobber a later product resume', () {
      final result = queue.consumeAppLinkStubs(
        initialLink: 'https://lobbiesync.app/chat/leftover',
        resumeLink: 'codsquadapp://lobby/lobby-9',
        isIosSimulator: true,
      );
      expect(result.launch, isNull);
      expect(result.resume, '/squad?lobby_id=lobby-9');
      expect(queue.source, PendingLinkSource.resume);
    });

    test('resume URL replaces a different pending cold-start', () {
      queue.offerColdStartUrl(
        'codsquadapp://chat/1766270568521',
        isIosSimulator: true,
      );
      expect(queue.location, '/chat/1766270568521');
      queue.offerResumeUrl(
        'codsquadapp://lobby/lobby-9',
        isIosSimulator: true,
      );
      expect(queue.location, '/squad?lobby_id=lobby-9');
      expect(queue.source, PendingLinkSource.resume);
    });

    test('consumeNotificationStubs is getInitialMessage then opened-app', () {
      final result = queue.consumeNotificationStubs(
        initialMessage: {
          'type': 'peacock_assigned',
          'lobby_id': 'lobby-9',
        },
      );
      expect(result.launch, '/squad?lobby_id=lobby-9');
      expect(result.resume, isNull);

      final resumed = queue.consumeNotificationStubs(
        openedAppRaw: 'codsquadapp://chat/1766270568521',
      );
      expect(resumed.resume, '/chat/1766270568521');
      expect(queue.location, '/chat/1766270568521');
    });
  });

  group('unknown / missing id empty+error', () {
    test('unknown URL does not invent a route or pending location', () {
      expect(
        queue.offerColdStartUrl(
          'codsquadapp://unknown/path',
          isIosSimulator: true,
        ),
        isNull,
      );
      expect(queue.offerResumeUrl('', isIosSimulator: true), isNull);
      expect(queue.offerColdStartUrl(null), isNull);
      expect(queue.offerColdStartPayload({'type': 'unknown'}), isNull);
      expect(queue.offerColdStartPayload({}), isNull);
      expect(queue.offerColdStartRaw('hello'), isNull);
      expect(queue.isPending, isFalse);
    });

    test('missing lobby_id peacock is empty /squad, not an error route', () {
      expect(
        queue.offerColdStartPayload({'type': 'peacock_assigned'}),
        '/squad',
      );
      expect(
        queue.offerResumePayload({'type': 'lobby', 'lobby_id': ''}),
        '/squad',
      );
      expect(
        queue.offerColdStartUrl('codsquadapp://peacock', isIosSimulator: true),
        '/squad',
      );
    });

    test('missing chat id is empty /chat, not a card', () {
      expect(queue.offerColdStartPayload({'type': 'chat'}), '/chat');
      expect(queue.offerResumePayload({'type': 'lfg_alert'}), '/chat');
      expect(
        queue.offerColdStartUrl('codsquadapp://chat', isIosSimulator: true),
        '/chat',
      );
    });

    test('unknown lobby id still maps to /squad?lobby_id=', () {
      const missing = 'smoke-no-such-lobby-20260903';
      expect(
        queue.offerColdStartUrl(
          'codsquadapp://lobby/$missing',
          isIosSimulator: true,
        ),
        '/squad?lobby_id=$missing',
      );
      expect(
        DeepLinkRouter.locationFor('codsquadapp://lobby/$missing'),
        '/squad?lobby_id=$missing',
      );
    });

    test('auth-callback is not a product pending link', () {
      expect(
        queue.offerColdStartUrl(
          'com.example.codsquadapp://auth-callback',
          isIosSimulator: true,
        ),
        isNull,
      );
    });

    test('flush without go leaves the pending location', () {
      queue.offerColdStartUrl(
        'codsquadapp://lobby/lobby-9',
        isIosSimulator: true,
      );
      expect(queue.flush(), '/squad?lobby_id=lobby-9');
      expect(queue.isPending, isTrue);
    });
  });

  group('NotificationRoutes open holds until bindRouter', () {
    test('handleOpenedData before bind is pending, flush delivers', () {
      NotificationService.handleOpenedData({
        'type': 'availability_ping',
        'lobby_id': 'lobby-9',
      });
      expect(pendingLinkQueue.location, '/squad?lobby_id=lobby-9');
      expect(pendingLinkQueue.source, PendingLinkSource.coldStart);

      final opened = <String>[];
      NotificationRoutes.go = opened.add;
      pendingLinkQueue.flush();
      expect(opened, ['/squad?lobby_id=lobby-9']);
      expect(pendingLinkQueue.isPending, isFalse);
    });

    test('openRaw product URL before bind is pending', () {
      NotificationRoutes.openRaw('codsquadapp://lobby/lobby-9');
      expect(pendingLinkQueue.location, '/squad?lobby_id=lobby-9');
      NotificationRoutes.openRaw('codsquadapp://unknown/path');
      expect(pendingLinkQueue.location, '/squad?lobby_id=lobby-9');
    });

    test('open with go bound still delivers immediately', () {
      final opened = <String>[];
      NotificationRoutes.go = opened.add;
      NotificationRoutes.open({
        'type': 'chat',
        'chatGroupId': '1766270568521',
      });
      expect(opened, ['/chat/1766270568521']);
      expect(pendingLinkQueue.isPending, isFalse);
    });
  });

  group('Slice I — cold start vs resume apply THAT lobby', () {
    const lobbyId = 'lobby-9';
    const expected = '/squad?lobby_id=lobby-9';

    test(
      'peacock_assigned / lobby_lock / lobby_created hold THAT lobby '
      'and applyLobbyDeepLink selects + binds',
      () {
        for (final type in [
          'peacock_assigned',
          'lobby_lock',
          'lobby_created',
        ]) {
          expect(
            queue.offerColdStartPayload({
              'type': type,
              'lobby_id': lobbyId,
            }),
            expected,
            reason: type,
          );
          expect(queue.source, PendingLinkSource.coldStart, reason: type);
          queue.clear();
        }
        expect(
          File('lib/core/deep_link_routes.dart').readAsStringSync(),
          contains('applyLobbyDeepLink'),
          reason: 'same helper after pending hold — selectedLobbyId + Slice G',
        );
      },
    );

    test(
      'cold start vs resume PendingLinkSource then apply once',
      () {
        expect(
          queue.offerColdStartUrl(
            'codsquadapp://lobby/$lobbyId',
            isIosSimulator: true,
          ),
          expected,
        );
        expect(queue.source, PendingLinkSource.coldStart);
        queue.clear();
        expect(
          queue.offerResumeUrl(
            'codsquadapp://lobby/$lobbyId',
            isIosSimulator: true,
          ),
          expected,
        );
        expect(queue.source, PendingLinkSource.resume);
        expect(
          File('lib/core/deep_link_routes.dart').readAsStringSync(),
          contains('LobbyDeepLinkApply applyLobbyDeepLink'),
        );
      },
    );

    test(
      'AppLinks + pending queue + GoRouter do not double-go',
      () {
        final opened = <String>[];
        NotificationRoutes.go = opened.add;
        const url = 'codsquadapp://lobby/$lobbyId';
        pendingLinkQueue.offerColdStartUrl(url, isIosSimulator: true);
        pendingLinkQueue.flush();
        NotificationRoutes.openRaw(url);
        pendingLinkQueue.flush();
        expect(
          opened,
          [expected],
          reason: 'one apply — not AppLinks then queue then go',
        );
      },
    );

    test(
      'flush apply: selectedLobbyId, subscribe, Slice G bind, splash down',
      () {
        var splash = 0;
        queue.offerColdStartUrl(
          'codsquadapp://lobby/$lobbyId',
          isIosSimulator: true,
          dismissSplash: () => splash++,
        );
        expect(splash, 1);
        final src = File('lib/core/deep_link_routes.dart').readAsStringSync();
        expect(src, contains('applyLobbyDeepLink'));
        expect(src, contains('selectedLobbyId'));
        expect(src, contains('switchActiveLobbyChatBind'));
        expect(
          ActiveLobbyChatBind.empty.chatGroupId,
          isNull,
          reason: 'prior leftover thread is not the apply target',
        );
      },
    );

    test(
      'malformed / missing id drops, stays put, no hang',
      () {
        expect(
          queue.offerColdStartPayload({'type': 'peacock_assigned'}),
          isNot(expected),
        );
        expect(
          File('lib/core/deep_link_routes.dart').readAsStringSync(),
          contains('stayedPut'),
          reason: 'apply must stay put when lobby_id is missing — no splash hang',
        );
      },
    );
  });
}
