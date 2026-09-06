import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/app_router.dart';
import 'package:squad_sync/core/deep_link_routes.dart';

/// Ticket 12 router: [locationForDeepLink] / [DeepLinkRouter.locationFor].
/// This slice only asserts `https://codsquad.app/l/{id}` (and variants)
/// map to the existing lobby route. Do not add a second parser here.
void main() {
  const lobbyId = 'lobby-9';
  const expected = '/squad?lobby_id=lobby-9';

  String lobbyHttps(String id, {String host = kLobbyUniversalLinkHost}) =>
      'https://$host/l/$id';

  void expectLobbyRoute(String url, String location, {String? reason}) {
    expect(locationForDeepLink(url), location, reason: reason ?? url);
    expect(DeepLinkRouter.locationFor(url), location, reason: reason ?? url);
  }

  group('https://codsquad.app/l/{id} → lobby route', () {
    test('apex short path matches custom-scheme lobby', () {
      const httpsShort = 'https://codsquad.app/l/$lobbyId';
      const custom = 'codsquadapp://lobby/$lobbyId';
      expectLobbyRoute(httpsShort, expected);
      expectLobbyRoute(custom, expected);
      expect(locationForDeepLink(httpsShort), locationForDeepLink(custom));
    });

    test('www, trailing slash, and host constant', () {
      expectLobbyRoute(lobbyHttps(lobbyId), expected);
      expectLobbyRoute('https://www.codsquad.app/l/$lobbyId', expected);
      expectLobbyRoute('https://codsquad.app/l/$lobbyId/', expected);
      expect(
        lobbyHttps(lobbyId),
        'https://$kLobbyUniversalLinkHost/l/$lobbyId',
      );
    });

    test('query game_name still selects the lobby', () {
      expectLobbyRoute(
        'https://codsquad.app/l/$lobbyId?game_name=Warzone',
        '/squad/Warzone?lobby_id=lobby-9',
      );
    });

    test('extra query and fragment do not steal the lobby id', () {
      expectLobbyRoute(
        'https://codsquad.app/l/$lobbyId?utm_source=share',
        expected,
      );
      expectLobbyRoute(
        'https://codsquad.app/l/$lobbyId#section',
        expected,
      );
    });

    test('mixed-case path /L/<id> and uppercase host', () {
      expectLobbyRoute('https://codsquad.app/L/$lobbyId', expected);
      expectLobbyRoute('https://CODSQUAD.APP/l/$lobbyId', expected);
    });

    test('uuid and hyphenated ids stay on lobby_id query', () {
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      expectLobbyRoute(
        'https://codsquad.app/l/$uuid',
        '/squad?lobby_id=$uuid',
      );
      expectLobbyRoute(
        'https://codsquad.app/l/abc-123',
        '/squad?lobby_id=abc-123',
      );
    });

    test('percent-decoded path id', () {
      expectLobbyRoute(
        'https://codsquad.app/l/abc%20123',
        '/squad?lobby_id=abc%20123',
      );
    });

    test('short path id is not treated as a game name', () {
      expect(
        locationForDeepLink('https://codsquad.app/l/$lobbyId'),
        isNot('/squad/$lobbyId'),
      );
      expectLobbyRoute('https://codsquad.app/l/$lobbyId', expected);
    });

    test('/l without id does not invent lobby_id', () {
      expectLobbyRoute('https://codsquad.app/l', '/squad');
      expectLobbyRoute('https://codsquad.app/l/', '/squad');
    });

    test('custom-scheme /l/<id> alias matches https', () {
      expectLobbyRoute('codsquadapp://l/$lobbyId', expected);
    });

    test('http scheme still parses (AASA itself is https-only)', () {
      expectLobbyRoute('http://codsquad.app/l/$lobbyId', expected);
    });
  });

  group('AASA + associated-domains artifacts', () {
    const aasaPaths = [
      'ios/associated-domains/apple-app-site-association',
      'web/.well-known/apple-app-site-association',
      'web/apple-app-site-association',
    ];

    test('host copies are identical valid JSON claiming /l/*', () {
      String? canonical;
      for (final path in aasaPaths) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path missing');
        final text = file.readAsStringSync();
        canonical ??= text;
        expect(text, canonical, reason: '$path drifted from canonical AASA');
        final decoded = jsonDecode(text) as Map<String, dynamic>;
        expect(decoded.containsKey('applinks'), isTrue);
        final details = (decoded['applinks'] as Map)['details'] as List;
        final first = details.first as Map;
        expect(first['appID'], 'TEAMID.com.example.codSquadApp');
        expect((first['appIDs'] as List).first, 'TEAMID.com.example.codSquadApp');
        expect((first['paths'] as List).contains('/l/*'), isTrue);
        final components = first['components'] as List;
        expect(
          (components.first as Map)['/'],
          '/l/*',
        );
      }
    });

    test('entitlements template claims applinks:codsquad.app', () {
      final template =
          File('ios/associated-domains/associated-domains.entitlements')
              .readAsStringSync();
      expect(template.contains('<string>applinks:codsquad.app</string>'), isTrue);
      expect(
        template.contains('<string>applinks:www.codsquad.app</string>'),
        isTrue,
      );
      expect(template.contains('com.example.codSquadApp'), isTrue);
      final device = File('ios/Runner/Runner.entitlements').readAsStringSync();
      expect(device.contains('<string>applinks:codsquad.app</string>'), isTrue);
      expect(
        device.contains('<string>applinks:www.codsquad.app</string>'),
        isTrue,
      );
      final sim =
          File('ios/Runner/Runner.simulator.entitlements').readAsStringSync();
      expect(
        sim.contains('<key>com.apple.developer.associated-domains</key>'),
        isFalse,
      );
    });
  });
}
