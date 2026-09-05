import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/app_router.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/core/notification_routes.dart';

void main() {
  group('locationForDeepLink chat / join', () {
    test('codsquadapp chat id maps to /chat/:id', () {
      expect(
        locationForDeepLink('codsquadapp://chat/1766270568521'),
        '/chat/1766270568521',
      );
      expect(
        DeepLinkRouter.locationFor('https://lobbiesync.app/chat/abc'),
        '/chat/abc',
      );
    });

    test('chat list without id maps to /chat', () {
      expect(locationForDeepLink('codsquadapp://chat'), '/chat');
      expect(locationForDeepLink('codsquadapp://chat/'), '/chat');
    });

    test('join code maps to /join/:code', () {
      expect(locationForDeepLink('codsquadapp://join/ABC123'), '/join/ABC123');
      expect(
        locationForDeepLink('https://lobbiesync.app/join/XYZ'),
        '/join/XYZ',
      );
      expect(
        locationForDeepLink('codsquadapp://join?code=INVITE'),
        '/join/INVITE',
      );
    });
  });

  group('locationForDeepLink squad / peacock / lobby_id', () {
    test('squad host with lobby_id', () {
      expect(
        locationForDeepLink('codsquadapp://squad?lobby_id=lobby-9'),
        '/squad?lobby_id=lobby-9',
      );
    });

    test('squad host with game path and lobby_id', () {
      expect(
        locationForDeepLink('codsquadapp://squad/Warzone?lobby_id=lobby-9'),
        '/squad/Warzone?lobby_id=lobby-9',
      );
    });

    test('https squad path reuses lobby_id', () {
      expect(
        locationForDeepLink(
          'https://lobbiesync.app/squad/Warzone?lobby_id=lobby-9',
        ),
        '/squad/Warzone?lobby_id=lobby-9',
      );
    });

    test('peacock host routes like peacock_assigned', () {
      expect(
        locationForDeepLink(
          'codsquadapp://peacock?lobby_id=lobby-9&game_name=Warzone',
        ),
        '/squad/Warzone?lobby_id=lobby-9',
      );
      expect(
        locationForDeepLink('codsquadapp://peacock?lobby_id=lobby-9'),
        '/squad?lobby_id=lobby-9',
      );
    });

    test('screen=squad|lobby reuses lobby_id on /squad', () {
      expect(
        locationForDeepLink(
          'codsquadapp://open?screen=squad&lobby_id=lobby-9&game_name=Warzone',
        ),
        '/squad/Warzone?lobby_id=lobby-9',
      );
      expect(
        locationForDeepLink(
          'codsquadapp://open?screen=lobby&lobby_id=lobby-9',
        ),
        '/squad?lobby_id=lobby-9',
      );
    });

    test('type=peacock_assigned query is a squad route', () {
      expect(
        locationForDeepLink(
          'codsquadapp://notify?type=peacock_assigned&lobby_id=lobby-9',
        ),
        '/squad?lobby_id=lobby-9',
      );
    });

    test('lobby query alias maps to lobby_id', () {
      expect(
        locationForDeepLink(
          'codsquadapp://notify?type=availability_ping&lobby=lobby-9',
        ),
        '/squad?lobby_id=lobby-9',
      );
      expect(
        locationForDeepLink(
          'codsquadapp://notify?type=lobby_locked&lobby=lobby-9',
        ),
        '/squad?lobby_id=lobby-9',
      );
    });

    test('empty lobby_id does not append a query', () {
      expect(locationForDeepLink('codsquadapp://squad?lobby_id='), '/squad');
    });

    test('auth-callback is not an in-app product route', () {
      expect(
        locationForDeepLink('com.example.codsquadapp://auth-callback'),
        isNull,
      );
    });

    test('unknown URI does not invent a route', () {
      expect(locationForDeepLink('codsquadapp://unknown/path'), isNull);
      expect(locationForDeepLink(''), isNull);
    });
  });

  group('shared parser: peacock card / notification / lfg / lobby', () {
    const lobbyId = 'lobby-9';
    const game = 'Warzone';
    const expected = '/squad/Warzone?lobby_id=lobby-9';
    const expectedLobbyOnly = '/squad?lobby_id=lobby-9';

    test('peacock card URL parses through locationForDeepLink', () {
      expect(
        locationForDeepLink(
          peacockCardDeepLink(lobbyId: lobbyId, gameName: game),
        ),
        expected,
      );
      expect(
        DeepLinkRouter.locationFor(
          peacockCardDeepLink(lobbyId: lobbyId, gameName: game),
        ),
        expected,
      );
    });

    test('peacock card tap uses NotificationRoutes.go with shared parse', () {
      String? opened;
      openPeacockCard(
        lobbyId: lobbyId,
        gameName: game,
        go: (location) => opened = location,
      );
      expect(opened, expected);
    });

    test('notification / lfg_matched / peacock / lobby URLs match peacock card',
        () {
      final fromCard = locationForDeepLink(
        peacockCardDeepLink(lobbyId: lobbyId, gameName: game),
      );
      expect(fromCard, expected);

      const urls = [
        'codsquadapp://notify?type=peacock_assigned&lobby_id=$lobbyId&game_name=$game',
        'codsquadapp://notify?type=lfg_matched&lobby_id=$lobbyId&game_name=$game',
        'codsquadapp://lfg_matched?lobby_id=$lobbyId&game_name=$game',
        'codsquadapp://peacock?lobby_id=$lobbyId&game_name=$game',
        'codsquadapp://lobby?lobby_id=$lobbyId&game_name=$game',
        'codsquadapp://open?screen=lobby&lobby_id=$lobbyId&game_name=$game',
        'https://lobbiesync.app/lobby?lobby_id=$lobbyId&game_name=$game',
        'https://lobbiesync.app/peacock?lobby_id=$lobbyId&game_name=$game',
      ];
      for (final url in urls) {
        expect(
          locationForDeepLink(url),
          fromCard,
          reason: url,
        );
        expect(DeepLinkRouter.locationFor(url), fromCard, reason: url);
      }

      expect(
        NotificationRoutes.locationFor({
          'type': 'peacock_assigned',
          'lobby_id': lobbyId,
          'game_name': game,
        }),
        fromCard,
      );
      expect(
        NotificationRoutes.locationFor({
          'type': 'lfg_matched',
          'lobby_id': lobbyId,
          'game_name': game,
        }),
        fromCard,
      );
      expect(
        NotificationRoutes.locationFor({
          'screen': 'lobby',
          'lobby_id': lobbyId,
          'game_name': game,
        }),
        fromCard,
      );
    });

    test('availability_ping URLs share the squad parse', () {
      const pingExpected = '/squad/Warzone?lobby_id=lobby-9';
      const urls = [
        'codsquadapp://notify?type=availability_ping&lobby_id=$lobbyId&game_name=$game',
        'codsquadapp://availability_ping?lobby_id=$lobbyId&game_name=$game',
      ];
      for (final url in urls) {
        expect(locationForDeepLink(url), pingExpected, reason: url);
        expect(DeepLinkRouter.locationFor(url), pingExpected, reason: url);
      }
      expect(
        NotificationRoutes.locationFor({
          'type': 'availability_ping',
          'lobby_id': lobbyId,
          'game_name': game,
        }),
        pingExpected,
      );
    });

    test('lobby_locked URLs share the squad parse', () {
      const lockExpected = '/squad/Warzone?lobby_id=lobby-9';
      const urls = [
        'codsquadapp://notify?type=lobby_locked&lobby_id=$lobbyId&game_name=$game',
        'codsquadapp://lobby_locked?lobby_id=$lobbyId&game_name=$game',
      ];
      for (final url in urls) {
        expect(locationForDeepLink(url), lockExpected, reason: url);
        expect(DeepLinkRouter.locationFor(url), lockExpected, reason: url);
      }
      expect(
        NotificationRoutes.locationFor({
          'type': 'lobby_locked',
          'lobby_id': lobbyId,
          'game_name': game,
        }),
        lockExpected,
      );
    });

    test('lfg_alert URLs share the chat parse', () {
      const expectedChat = '/chat/squad-1';
      const urls = [
        'codsquadapp://lfg_alert?squad_id=squad-1',
        'codsquadapp://notify?type=lfg_alert&squad_id=squad-1',
        'codsquadapp://open?type=lfg_alert&squad_id=squad-1',
        'https://lobbiesync.app/lfg_alert?squad_id=squad-1',
      ];
      for (final url in urls) {
        expect(locationForDeepLink(url), expectedChat, reason: url);
        expect(DeepLinkRouter.locationFor(url), expectedChat, reason: url);
      }
      expect(
        NotificationRoutes.locationFor({
          'type': 'lfg_alert',
          'squad_id': 'squad-1',
        }),
        expectedChat,
      );
    });

    test('lobby_id without game still highlights the same lobby', () {
      const urls = [
        'codsquadapp://peacock?lobby_id=$lobbyId',
        'codsquadapp://lobby?lobby_id=$lobbyId',
        'codsquadapp://lfg_matched?lobby_id=$lobbyId',
        'codsquadapp://notify?type=peacock_assigned&lobby_id=$lobbyId',
        'codsquadapp://notify?type=lfg_matched&lobby_id=$lobbyId',
      ];
      for (final url in urls) {
        expect(locationForDeepLink(url), expectedLobbyOnly, reason: url);
      }
      expect(
        locationForDeepLink(peacockCardDeepLink(lobbyId: lobbyId)),
        expectedLobbyOnly,
      );
    });
  });

  group('lobby share / copy URI', () {
    test('lobbyShareDeepLink is codsquadapp://lobby/<id>', () {
      expect(
        lobbyShareDeepLink(lobbyId: 'lobby-9'),
        'codsquadapp://lobby/lobby-9',
      );
      expect(
        lobbyShareDeepLink(lobbyId: '  lobby-9  '),
        'codsquadapp://lobby/lobby-9',
      );
    });

    test('unknown lobby id still maps to /squad?lobby_id=', () {
      const link = 'codsquadapp://lobby/smoke-no-such-lobby-20260903';
      expect(
        locationForDeepLink(link),
        '/squad?lobby_id=smoke-no-such-lobby-20260903',
      );
      expect(
        DeepLinkRouter.locationFor(link),
        '/squad?lobby_id=smoke-no-such-lobby-20260903',
      );
      expect(
        locationForLiveAppLink(link, isIosSimulator: true),
        '/squad?lobby_id=smoke-no-such-lobby-20260903',
      );
    });

    test('share URI parses through locationForDeepLink', () {
      const lobbyId = 'lobby-9';
      final link = lobbyShareDeepLink(lobbyId: lobbyId);
      expect(link, 'codsquadapp://lobby/lobby-9');
      expect(locationForDeepLink(link), '/squad?lobby_id=lobby-9');
      expect(
        locationForDeepLink('codsquadapp://lobby/$lobbyId'),
        '/squad?lobby_id=lobby-9',
      );
      expect(
        DeepLinkRouter.locationFor(link),
        '/squad?lobby_id=lobby-9',
      );
      expect(
        locationForDeepLink('https://lobbiesync.app/lobby/$lobbyId'),
        '/squad?lobby_id=lobby-9',
      );
    });

    test('https://codsquad.app/l/<id> maps to the same lobby route', () {
      const lobbyId = 'lobby-9';
      const custom = 'codsquadapp://lobby/$lobbyId';
      const httpsShort = 'https://$kLobbyUniversalLinkHost/l/$lobbyId';
      const expected = '/squad?lobby_id=lobby-9';
      expect(locationForDeepLink(custom), expected);
      expect(locationForDeepLink(httpsShort), expected);
      expect(
        locationForDeepLink('https://www.codsquad.app/l/$lobbyId'),
        expected,
      );
      expect(DeepLinkRouter.locationFor(httpsShort), expected);
      expect(
        locationForDeepLink('https://codsquad.app/l/$lobbyId/'),
        expected,
      );
      expect(
        locationForDeepLink(
          'https://codsquad.app/l/$lobbyId?game_name=Warzone',
        ),
        '/squad/Warzone?lobby_id=lobby-9',
      );
      expect(
        locationForDeepLink('codsquadapp://l/$lobbyId'),
        expected,
      );
    });

    test('https short lobby id is not treated as a game name', () {
      expect(
        locationForDeepLink('https://codsquad.app/l/lobby-9'),
        isNot('/squad/lobby-9'),
      );
      expect(
        locationForDeepLink('https://codsquad.app/l/lobby-9'),
        '/squad?lobby_id=lobby-9',
      );
    });

    test('path lobby id is not treated as a game name', () {
      expect(
        locationForDeepLink('codsquadapp://lobby/lobby-9'),
        isNot('/squad/lobby-9'),
      );
      expect(
        locationForDeepLink('codsquadapp://lobby/lobby-9?game_name=Warzone'),
        '/squad/Warzone?lobby_id=lobby-9',
      );
    });

    test('shareLobbyLink copies and shares the built URI', () async {
      final copied = <String>[];
      final shared = <String>[];
      final link = await shareLobbyLink(
        lobbyId: 'lobby-9',
        copy: (text) async => copied.add(text),
        share: (text) async => shared.add(text),
      );
      expect(link, 'codsquadapp://lobby/lobby-9');
      expect(copied, [link]);
      expect(shared, [link]);
      expect(locationForDeepLink(link), '/squad?lobby_id=lobby-9');
    });
  });

  group('live AppLinks path', () {
    test('simulator leftover https is dropped; product lobby is not', () {
      expect(
        locationForLiveAppLink(
          'https://lobbiesync.app/chat/leftover',
          isIosSimulator: true,
        ),
        isNull,
      );
      expect(
        locationForLiveAppLink(
          'https://lobbiesync.app/chat/leftover',
          isIosSimulator: false,
        ),
        '/chat/leftover',
      );
      expect(
        locationForLiveAppLink(
          'https://codsquad.app/l/lobby-9',
          isIosSimulator: true,
        ),
        isNull,
      );
      expect(
        locationForLiveAppLink(
          'https://codsquad.app/l/lobby-9',
          isIosSimulator: false,
        ),
        '/squad?lobby_id=lobby-9',
      );
      expect(
        locationForLiveAppLink(
          'codsquadapp://lobby/smoke-no-such-lobby-20260903',
          isIosSimulator: true,
        ),
        '/squad?lobby_id=smoke-no-such-lobby-20260903',
      );
    });

    test('device live path routes https://codsquad.app/l/<id> to lobby', () {
      var splashDismissed = false;
      final logs = <String>[];
      final location = prepareLiveAppLink(
        'https://codsquad.app/l/lobby-9',
        isIosSimulator: false,
        dismissSplash: () => splashDismissed = true,
        log: logs.add,
      );
      expect(location, '/squad?lobby_id=lobby-9');
      expect(splashDismissed, isTrue);
      expect(logs.single, contains('lobby_id=lobby-9'));

      String? opened;
      NotificationRoutes.go = (loc) => opened = loc;
      NotificationRoutes.go?.call(location!);
      expect(opened, location);
      NotificationRoutes.go = null;
    });

    test('prepareLiveAppLink dismisses splash and logs lobby location', () {
      var splashDismissed = false;
      final logs = <String>[];
      final location = prepareLiveAppLink(
        'codsquadapp://lobby/smoke-no-such-lobby-20260903',
        isIosSimulator: true,
        dismissSplash: () => splashDismissed = true,
        log: logs.add,
      );
      expect(location, '/squad?lobby_id=smoke-no-such-lobby-20260903');
      expect(splashDismissed, isTrue);
      expect(logs, isNotEmpty);
      expect(logs.single, contains('lobby_id=smoke-no-such-lobby-20260903'));
    });

    test('prepareLiveAppLink does not dismiss splash for swallowed leftover',
        () {
      var splashDismissed = false;
      final location = prepareLiveAppLink(
        'https://lobbiesync.app/chat/leftover',
        isIosSimulator: true,
        dismissSplash: () => splashDismissed = true,
      );
      expect(location, isNull);
      expect(splashDismissed, isFalse);
    });

    test('live lobby URL is what NotificationRoutes.go would open', () {
      String? opened;
      NotificationRoutes.go = (location) => opened = location;
      final location = prepareLiveAppLink(
        'codsquadapp://lobby/smoke-no-such-lobby-20260903',
        isIosSimulator: true,
        dismissSplash: () {},
      );
      expect(location, '/squad?lobby_id=smoke-no-such-lobby-20260903');
      NotificationRoutes.go?.call(location!);
      expect(opened, location);
      NotificationRoutes.go = null;
    });
  });

  group('simulator Info.plist scheme (no SpringBoard)', () {
    test('Info.simulator.plist registers expected schemes', () {
      final plist = File('ios/Runner/Info.simulator.plist');
      expect(plist.existsSync(), isTrue, reason: 'simulator plist missing');
      final text = plist.readAsStringSync();
      for (final scheme in kSimulatorRegisteredUrlSchemes) {
        expect(
          text.contains('<string>$scheme</string>'),
          isTrue,
          reason: 'Info.simulator.plist must register $scheme',
        );
      }
      expect(text.contains(kSimulatorDeepLinkScheme), isTrue);
    });

    test('device Info.plist also registers codsquadapp', () {
      final plist = File('ios/Runner/Info.plist');
      expect(plist.existsSync(), isTrue);
      final text = plist.readAsStringSync();
      expect(text.contains('<string>codsquadapp</string>'), isTrue);
      expect(
        text.contains('<string>com.example.codSquadApp</string>'),
        isTrue,
      );
    });
  });

  group('Universal Links AASA / associated-domains prep', () {
    test('device entitlements claim applinks:codsquad.app; sim does not', () {
      final device = File('ios/Runner/Runner.entitlements').readAsStringSync();
      expect(device.contains('<string>applinks:codsquad.app</string>'), isTrue);
      expect(
        device.contains('<string>applinks:www.codsquad.app</string>'),
        isTrue,
      );
      expect(device.contains('com.example.codSquadApp'), isTrue);
      final sim =
          File('ios/Runner/Runner.simulator.entitlements').readAsStringSync();
      expect(
        sim.contains('<key>com.apple.developer.associated-domains</key>'),
        isFalse,
      );
    });

    test('AASA prep files claim /l/* for parked bundle ID', () {
      final paths = [
        'ios/associated-domains/apple-app-site-association',
        'web/.well-known/apple-app-site-association',
      ];
      for (final path in paths) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path missing');
        final text = file.readAsStringSync();
        expect(text.contains('TEAMID.com.example.codSquadApp'), isTrue);
        expect(text.contains('/l/*'), isTrue);
        expect(text.contains('"applinks"'), isTrue);
      }
    });

    test('AppDelegate sim swallow list includes codesquad.app', () {
      final text = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(text.contains('codsquad.app'), isTrue);
      expect(text.contains('isProductCustomScheme'), isTrue);
    });
  });
}
