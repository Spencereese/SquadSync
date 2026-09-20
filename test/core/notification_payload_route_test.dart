import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/core/notification_routes.dart';
import 'package:squad_sync/managers/notification_manager.dart';
import 'package:squad_sync/notification_service.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// Real-device FCM / local tap payloads → `/squad?lobby_id=` via the
/// existing [NotificationRoutes] pipeline (no second presenter).
void main() {
  tearDown(() {
    pendingLinkQueue.clear();
    NotificationRoutes.go = null;
    NotificationRoutes.router = null;
    NotificationRoutes.navigatorKey = null;
  });

  const lobby = 'lobby-9';
  const expected = '/squad?lobby_id=lobby-9';
  const expectedGame = '/squad/Warzone?lobby_id=lobby-9';

  group('availability_ping / peacock_assigned / lobby_locked → lobby', () {
    test('canonical payloads open /squad?lobby_id=', () {
      for (final type in [
        'availability_ping',
        'peacock_assigned',
        'lobby_locked',
      ]) {
        expect(
          NotificationRoutes.locationFor({
            'type': type,
            'lobby_id': lobby,
          }),
          expected,
          reason: type,
        );
      }
    });

    test('game_name keeps lobby_id on the squad route', () {
      for (final type in [
        'availability_ping',
        'peacock_assigned',
        'lobby_locked',
      ]) {
        expect(
          NotificationRoutes.locationFor({
            'type': type,
            'lobby_id': lobby,
            'game_name': 'Warzone',
          }),
          expectedGame,
          reason: type,
        );
      }
    });

    test('camelCase lobbyId and lobby aliases resolve', () {
      expect(
        NotificationRoutes.locationFor({
          'type': 'availability_ping',
          'lobbyId': lobby,
        }),
        expected,
      );
      expect(
        NotificationRoutes.locationFor({
          'type': 'peacock_assigned',
          'lobbyID': lobby,
        }),
        expected,
      );
      expect(
        NotificationRoutes.locationFor({
          'type': 'lobby_locked',
          'lobby': lobby,
        }),
        expected,
      );
      expect(
        NotificationRoutes.locationFor({
          'type': 'peacock_assigned',
          'lobby': {'id': lobby},
        }),
        expected,
      );
    });

    test('type aliases and case fold onto the existing types', () {
      const aliases = {
        'PEACOCK_ASSIGNED': 'peacock_assigned',
        'peacock': 'peacock_assigned',
        'peacock-assigned': 'peacock_assigned',
        'peacock_assign': 'peacock_assigned',
        'I_AM_ON': 'availability_ping',
        'im_on': 'availability_ping',
        'i-am-on': 'availability_ping',
        'on_now': 'availability_ping',
        'availability': 'availability_ping',
        'LOBBY_LOCKED': 'lobby_locked',
        'lobby-locked': 'lobby_locked',
        'lobby_lock': 'lobby_locked',
        'ready_lock': 'lobby_locked',
      };
      aliases.forEach((raw, canonical) {
        expect(NotificationRoutes.canonicalType(raw), canonical, reason: raw);
        expect(
          NotificationRoutes.locationFor({
            'type': raw,
            'lobby_id': lobby,
          }),
          expected,
          reason: raw,
        );
      });
    });

    test('lobby_id present without type still opens the lobby', () {
      expect(
        NotificationRoutes.locationFor({'lobby_id': lobby}),
        expected,
      );
      expect(
        NotificationRoutes.locationFor({
          'type': 'unknown_event',
          'lobby_id': lobby,
        }),
        expected,
      );
      expect(
        NotificationRoutes.locationFor({
          'type': 'local',
          'lobby_id': lobby,
        }),
        expected,
      );
    });

    test('unknown type without lobby_id still does not invent a route', () {
      expect(NotificationRoutes.locationFor({'type': 'unknown'}), isNull);
      expect(NotificationRoutes.locationFor({'type': 'local'}), isNull);
    });

    test('handleOpenedData unknown / empty payload does not navigate', () {
      String? opened;
      NotificationRoutes.go = (location) => opened = location;
      NotificationService.handleOpenedData({'type': 'unknown'});
      expect(opened, isNull);
      NotificationService.handleOpenedData({});
      expect(opened, isNull);
      NotificationService.handleOpenedData({'type': 'local'});
      expect(opened, isNull);
    });

    test('handleOpenedData missing lobby_id peacock is empty squad', () {
      String? opened;
      NotificationRoutes.go = (location) => opened = location;
      NotificationService.handleOpenedData({'type': 'peacock_assigned'});
      expect(opened, '/squad');
      opened = null;
      NotificationService.handleOpenedData({
        'type': 'unknown_event',
        'lobby_id': '',
      });
      expect(opened, isNull);
    });

    test('chat and lfg_alert keep chat routes even when lobby_id is present',
        () {
      expect(
        NotificationRoutes.locationFor({
          'type': 'chat',
          'chatGroupId': 'g1',
          'lobby_id': lobby,
        }),
        '/chat/g1',
      );
      expect(
        NotificationRoutes.locationFor({
          'type': 'lfg_alert',
          'squad_id': 'squad-1',
          'lobby_id': lobby,
        }),
        '/chat/squad-1',
      );
    });
  });

  group('nested / string FCM shapes', () {
    test('JSON-string data wrapper flattens to lobby_id', () {
      expect(
        NotificationRoutes.locationFor({
          'data':
              '{"type":"peacock_assigned","lobby_id":"lobby-9","game_name":"Warzone"}',
        }),
        expectedGame,
      );
      expect(
        NotificationRoutes.locationFor({
          'payload': '{"type":"availability_ping","lobby_id":"lobby-9"}',
        }),
        expected,
      );
    });

    test('nested payload map flattens to lobby_id', () {
      expect(
        NotificationRoutes.locationFor({
          'payload': {
            'type': 'lobby_locked',
            'lobby_id': lobby,
          },
        }),
        expected,
      );
      expect(
        NotificationRoutes.locationFor({
          'data': {
            'type': 'availability_ping',
            'lobbyId': lobby,
          },
        }),
        expected,
      );
    });

    test('top-level type wins over nested data', () {
      expect(
        NotificationRoutes.locationFor({
          'type': 'lobby_locked',
          'lobby_id': lobby,
          'data': '{"type":"chat","chatGroupId":"g1"}',
        }),
        expected,
      );
    });

    test('FCM string map (all values strings) routes', () {
      const data = <String, dynamic>{
        'gcm.n.e': '1',
        'google.c.a.e': '1',
        'type': 'availability_ping',
        'lobby_id': 'lobby-9',
      };
      expect(NotificationRoutes.locationFor(data), expected);
    });

    test('deep_link / url fields reuse locationForDeepLink', () {
      expect(
        NotificationRoutes.locationFor({
          'deep_link':
              'codsquadapp://notify?type=peacock_assigned&lobby_id=lobby-9',
        }),
        expected,
      );
      expect(
        NotificationRoutes.locationFor({
          'url': 'https://codsquad.app/l/lobby-9',
        }),
        expected,
      );
      expect(
        NotificationRoutes.locationFor({
          'click_action':
              'codsquadapp://notify?type=lobby_locked&lobby_id=lobby-9',
        }),
        expected,
      );
      expect(
        NotificationRoutes.locationFor({
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        }),
        isNull,
      );
    });
  });

  group('openRaw real-device tap payloads', () {
    test('JSON, query string, and product URLs all go to the lobby', () {
      String? opened;
      NotificationRoutes.go = (location) => opened = location;

      NotificationRoutes.openRaw(
        '{"type":"availability_ping","lobby_id":"lobby-9"}',
      );
      expect(opened, expected);

      opened = null;
      NotificationRoutes.openRaw(
        'type=peacock_assigned&lobby_id=lobby-9',
      );
      expect(opened, expected);

      opened = null;
      NotificationRoutes.openRaw(
        'codsquadapp://notify?type=lobby_locked&lobby_id=lobby-9',
      );
      expect(opened, expected);

      opened = null;
      NotificationRoutes.openRaw('https://codsquad.app/l/lobby-9');
      expect(opened, expected);

      opened = null;
      NotificationRoutes.openRaw(
        Uri.encodeFull(
          '{"type":"peacock_assigned","lobby_id":"lobby-9"}',
        ),
      );
      expect(opened, expected);
    });

    test('mapFromRaw ignores unrelated text', () {
      expect(NotificationRoutes.mapFromRaw('hello'), isNull);
      expect(NotificationRoutes.mapFromRaw(''), isNull);
      expect(NotificationRoutes.mapFromRaw(null), isNull);
    });
  });

  group('outbound payload / FCM string data', () {
    test('payloadFor copies lobby alias onto lobby_id', () {
      expect(
        NotificationManager.payloadFor(
          type: 'availability_ping',
          payload: const {'lobby': 'lobby-9'},
        )['lobby_id'],
        lobby,
      );
    });

    test('stringDataForFcm flattens nested JSON and stringifies values', () {
      final sent = NotificationService.stringDataForFcm({
        'data': {
          'type': 'lobby_locked',
          'lobby_id': lobby,
          'spot_index': 2,
        },
      });
      expect(sent['type'], 'lobby_locked');
      expect(sent['lobby_id'], lobby);
      expect(sent['spot_index'], '2');
      expect(sent.containsKey('data'), isFalse);
      expect(
        NotificationRoutes.locationFor(sent),
        '$expected&spot_index=2',
      );
    });

    test('handleOpenedData opens through NotificationRoutes only', () {
      String? opened;
      NotificationRoutes.go = (location) => opened = location;
      NotificationService.handleOpenedData({
        'payload': '{"type":"availability_ping","lobby_id":"lobby-9"}',
      });
      expect(opened, expected);
    });

    test('peacock XOR stays planPeacockSelfNotify — no second presenter', () {
      expect(
        planPeacockSelfNotify(
          notificationId: 'n1',
          currentUid: 'me',
          isForeground: true,
          locallyPresentedIds: {},
        ).wouldDoubleNotifySelf,
        isFalse,
      );
      expect(
        planPeacockSelfNotify(
          notificationId: 'n1',
          currentUid: 'me',
          isForeground: false,
          locallyPresentedIds: {},
        ).wouldDoubleNotifySelf,
        isFalse,
      );
      expect(
        planPeacockSelfNotify(
          notificationId: 'evt-1',
          currentUid: 'me',
          isForeground: false,
          locallyPresentedIds: {'evt-1'},
        ).sendFcmToSelf,
        isFalse,
      );
    });
  });

  group('deep-link URLs share the same lobby parse', () {
    test('notify / host / Universal Link all yield /squad?lobby_id=', () {
      const urls = [
        'codsquadapp://notify?type=availability_ping&lobby_id=lobby-9',
        'codsquadapp://notify?type=peacock_assigned&lobby_id=lobby-9',
        'codsquadapp://notify?type=lobby_locked&lobby_id=lobby-9',
        'codsquadapp://availability_ping?lobby_id=lobby-9',
        'codsquadapp://peacock?lobby_id=lobby-9',
        'codsquadapp://peacock/lobby-9',
        'codsquadapp://lobby/lobby-9',
        'codsquadapp://lobby_locked?lobby_id=lobby-9',
        'codsquadapp://notify?type=availability_ping&lobby=lobby-9',
        'https://codsquad.app/l/lobby-9',
        'https://codsquad.app/lobby/lobby-9',
        'https://codsquad.app/peacock/lobby-9',
      ];
      for (final url in urls) {
        expect(locationForDeepLink(url), expected, reason: url);
        expect(
          NotificationRoutes.locationFor({'deep_link': url}),
          expected,
          reason: 'payload $url',
        );
      }
    });

    test('chat and stats product URLs keep their own routes', () {
      expect(
        locationForDeepLink('codsquadapp://chat/1766270568521'),
        '/chat/1766270568521',
      );
      expect(
        locationForDeepLink('https://codsquad.app/chat/1766270568521'),
        '/chat/1766270568521',
      );
      expect(locationForDeepLink('codsquadapp://stats'), '/stats');
      expect(locationForDeepLink('https://codsquad.app/stats'), '/stats');
      expect(
        NotificationRoutes.locationFor({
          'url': 'https://codsquad.app/stats',
        }),
        '/stats',
      );
      expect(
        NotificationRoutes.locationFor({
          'deep_link': 'codsquadapp://chat/1766270568521',
        }),
        '/chat/1766270568521',
      );
    });
  });

  testWidgets('openRaw JSON tap uses the bound go handler', (tester) async {
    String? opened;
    NotificationRoutes.go = (location) => opened = location;
    NotificationRoutes.openRaw(
      '{"type":"lobby_locked","lobby_id":"lobby-9"}',
    );
    expect(opened, expected);
    await tester.pump();
  });
}
