import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/app_router.dart';
import 'package:squad_sync/core/deep_link_routes.dart';

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
}
