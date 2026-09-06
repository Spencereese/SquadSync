import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/app_links_policy.dart';
import 'package:squad_sync/core/app_router.dart';
import 'package:squad_sync/core/deep_link_routes.dart';

/// Ticket 61: remaining Universal Links / Associated Domains edge units.
/// Pairs with tickets 12/15. AASA hosting / Apple portal stay a human gate.
void main() {
  late PendingLinkQueue queue;

  setUp(() {
    queue = PendingLinkQueue();
    pendingLinkQueue.clear();
    debugSetIosSimulatorChannelValue(null);
  });

  tearDown(() {
    queue.clear();
    pendingLinkQueue.clear();
    debugSetIosSimulatorChannelValue(null);
  });

  const lobbyHttps = 'https://codsquad.app/l/lobby-9';
  const lobbyCustom = 'codsquadapp://lobby/lobby-9';
  const expectedLobby = '/squad?lobby_id=lobby-9';

  group('cold-start vs resume Universal Links', () {
    test('device cold-start https://codsquad.app/l/:id holds until flush', () {
      final gate = AppLinkAcceptGate.deviceReady();
      var splash = 0;
      final location = queue.offerColdStartUrl(
        lobbyHttps,
        isIosSimulator: false,
        acceptGate: gate,
        dismissSplash: () => splash++,
      );
      expect(location, expectedLobby);
      expect(locationForDeepLink(lobbyHttps), location);
      expect(DeepLinkRouter.locationFor(lobbyHttps), location);
      expect(queue.source, PendingLinkSource.coldStart);
      expect(queue.isPending, isTrue);
      expect(splash, 1);

      final opened = <String>[];
      expect(queue.flush(go: opened.add), expectedLobby);
      expect(opened, [expectedLobby]);
      expect(queue.isPending, isFalse);
    });

    test('device resume https://codsquad.app/l/:id holds and flushes once', () {
      final gate = AppLinkAcceptGate.deviceReady();
      final location = queue.offerResumeUrl(
        lobbyHttps,
        isIosSimulator: false,
        acceptGate: gate,
      );
      expect(location, expectedLobby);
      expect(queue.source, PendingLinkSource.resume);

      final opened = <String>[];
      queue.flush(go: opened.add);
      queue.flush(go: opened.add);
      expect(opened, [expectedLobby]);
    });

    test('killed UL then matching resume is stored once as cold-start', () {
      final gate = AppLinkAcceptGate.deviceReady();
      final result = queue.consumeUniversalLinkStubs(
        initialLink: lobbyHttps,
        resumeLink: lobbyHttps,
        isIosSimulator: false,
        acceptGate: gate,
      );
      expect(result.launch, expectedLobby);
      expect(result.resume, expectedLobby);
      expect(queue.location, expectedLobby);
      expect(queue.source, PendingLinkSource.coldStart);

      final opened = <String>[];
      queue.flush(go: opened.add);
      expect(opened, [expectedLobby]);
    });

    test('resume UL replaces a different pending cold-start UL', () {
      final gate = AppLinkAcceptGate.deviceReady();
      queue.offerColdStartUrl(
        'https://codsquad.app/l/lobby-9',
        isIosSimulator: false,
        acceptGate: gate,
      );
      expect(queue.location, expectedLobby);
      queue.offerResumeUrl(
        'https://www.codsquad.app/l/lobby-other',
        isIosSimulator: false,
        acceptGate: gate,
      );
      expect(queue.location, '/squad?lobby_id=lobby-other');
      expect(queue.source, PendingLinkSource.resume);
    });

    test('sim leftover launch does not clobber a later device-ready resume',
        () {
      final gate = AppLinkAcceptGate.deviceReady();
      final result = queue.consumeUniversalLinkStubs(
        initialLink: 'https://codsquad.app/l/leftover',
        resumeLink: lobbyHttps,
        isIosSimulator: true,
        acceptGate: gate,
      );
      expect(result.launch, isNull);
      expect(result.resume, isNull);
      expect(queue.isPending, isFalse);
    });

    test('sim swallows https UL even when Associated Domains is mocked Accept',
        () {
      final gate = AppLinkAcceptGate.deviceReady();
      expect(
        queue.offerColdStartUrl(
          lobbyHttps,
          isIosSimulator: true,
          acceptGate: gate,
        ),
        isNull,
      );
      expect(
        locationForUniversalLink(
          lobbyHttps,
          isIosSimulator: true,
          acceptGate: gate,
        ),
        isNull,
      );
      expect(queue.isPending, isFalse);
    });

    test('device custom-scheme and https UL share the lobby route', () {
      final gate = AppLinkAcceptGate.deviceReady();
      expect(
        queue.offerColdStartUrl(
          lobbyCustom,
          isIosSimulator: false,
          acceptGate: gate,
        ),
        expectedLobby,
      );
      queue.clear();
      expect(
        queue.offerResumeUrl(
          lobbyHttps,
          isIosSimulator: false,
          acceptGate: gate,
        ),
        expectedLobby,
      );
      expect(locationForDeepLink(lobbyCustom), locationForDeepLink(lobbyHttps));
    });

    test('consumeUniversalLinkStubs ignores custom-scheme so resume UL can land',
        () {
      final gate = AppLinkAcceptGate.deviceReady();
      final result = queue.consumeUniversalLinkStubs(
        initialLink: lobbyCustom,
        resumeLink: lobbyHttps,
        isIosSimulator: false,
        acceptGate: gate,
      );
      expect(result.launch, isNull);
      expect(result.resume, expectedLobby);
      expect(queue.source, PendingLinkSource.resume);
    });

    test('malformed cold-start does not clobber a later resume UL', () {
      final gate = AppLinkAcceptGate.deviceReady();
      expect(
        queue.offerColdStartUrl(
          'https://codsquad.app/l/lobby 9',
          isIosSimulator: false,
          acceptGate: gate,
        ),
        isNull,
      );
      expect(queue.isPending, isFalse);
      expect(
        queue.offerResumeUrl(
          lobbyHttps,
          isIosSimulator: false,
          acceptGate: gate,
        ),
        expectedLobby,
      );
      expect(queue.source, PendingLinkSource.resume);
    });

    test('malformed resume does not clobber a pending cold-start UL', () {
      final gate = AppLinkAcceptGate.deviceReady();
      queue.offerColdStartUrl(
        lobbyHttps,
        isIosSimulator: false,
        acceptGate: gate,
      );
      expect(
        queue.offerResumeUrl(
          'not a url',
          isIosSimulator: false,
          acceptGate: gate,
        ),
        isNull,
      );
      expect(queue.location, expectedLobby);
      expect(queue.source, PendingLinkSource.coldStart);
    });
  });

  group('malformed URL', () {
    test('empty whitespace and null do not invent a route', () {
      expect(isMalformedAppLink(null), isTrue);
      expect(isMalformedAppLink(''), isTrue);
      expect(isMalformedAppLink('   '), isTrue);
      expect(locationForDeepLink(''), isNull);
      expect(locationForLiveAppLink('   '), isNull);
      expect(locationForUniversalLink(''), isNull);
      expect(tryParseAppLinkUri(null), isNull);
    });

    test('internal whitespace and control chars are malformed', () {
      expect(isMalformedAppLink('https://codsquad.app/l/lobby 9'), isTrue);
      expect(isMalformedAppLink('https://codsquad.app/l/lobby-9 extra'), isTrue);
      expect(isMalformedAppLink('https://codsquad.app/l/lobby-\n9'), isTrue);
      expect(
        isMalformedAppLink('https://codsquad.app/l/lobby-9\u0000'),
        isTrue,
      );
      expect(locationForLiveAppLink('https://codsquad.app/l/lobby 9'), isNull);
      expect(
        locationForUniversalLink('https://codsquad.app/l/lobby 9'),
        isNull,
      );
    });

    test('unsupported schemes do not invent a lobby route', () {
      const urls = [
        'javascript:alert(1)',
        'data:text/html,hi',
        'file:///tmp/l/lobby-9',
        'ftp://codsquad.app/l/lobby-9',
        'intent://codsquad.app/l/lobby-9',
      ];
      for (final url in urls) {
        expect(isMalformedAppLink(url), isTrue, reason: url);
        expect(locationForLiveAppLink(url), isNull, reason: url);
        expect(locationForUniversalLink(url), isNull, reason: url);
        expect(locationForDeepLink(url), isNull, reason: url);
      }
    });

    test('https without host and scheme-less text are malformed', () {
      expect(isMalformedAppLink('https://'), isTrue);
      expect(isMalformedAppLink('https:///l/lobby-9'), isTrue);
      expect(isMalformedAppLink('codsquad.app/l/lobby-9'), isTrue);
      expect(isMalformedAppLink('::'), isTrue);
      expect(locationForUniversalLink('https://'), isNull);
      expect(locationForUniversalLink('codsquad.app/l/lobby-9'), isNull);
    });

    test('wrong host is not an AASA Universal Link', () {
      const spoofs = [
        'https://codsquad.app.evil.com/l/lobby-9',
        'https://evil.com/l/lobby-9',
        'https://lobbiesync.app/l/lobby-9',
        'https://not-codsquad.app/l/lobby-9',
      ];
      for (final url in spoofs) {
        expect(isLobbyUniversalLink(url), isFalse, reason: url);
        expect(locationForUniversalLink(url), isNull, reason: url);
      }
    });

    test('https /lobby/:id parses in Dart but is not AASA /l/* delivery', () {
      const longPath = 'https://codsquad.app/lobby/lobby-9';
      expect(locationForDeepLink(longPath), expectedLobby);
      expect(isLobbyUniversalLink(longPath), isFalse);
      expect(locationForUniversalLink(longPath), isNull);
    });

    test('well-formed unknown custom-scheme is empty, not malformed', () {
      expect(isMalformedAppLink('codsquadapp://unknown/path'), isFalse);
      expect(locationForDeepLink('codsquadapp://unknown/path'), isNull);
      expect(
        locationForLiveAppLink(
          'codsquadapp://unknown/path',
          isIosSimulator: true,
        ),
        isNull,
      );
    });

    test('trimmed well-formed UL still maps through ticket 12 parser', () {
      expect(isMalformedAppLink('  $lobbyHttps  '), isFalse);
      expect(isLobbyUniversalLink('  $lobbyHttps  '), isTrue);
      expect(locationForDeepLink('  $lobbyHttps  '), expectedLobby);
      expect(
        locationForUniversalLink(
          '  $lobbyHttps  ',
          isIosSimulator: false,
        ),
        expectedLobby,
      );
    });
  });

  group('Accept-gate regression mocks', () {
    test('Open-in copy matches the SpringBoard sheet; plist is Cod Squad', () {
      expect(kOpenInCodSquadPrompt, 'Open in Cod Squad?');
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist.contains('<string>Cod Squad</string>'), isTrue);
    });

    test('first custom-scheme open presents the gate and does not deliver', () {
      final gate = AppLinkAcceptGate();
      final outcome = resolveAppLinkAccept(
        link: lobbyCustom,
        gate: gate,
        isIosSimulator: true,
      );
      expect(outcome.kind, AppLinkAcceptKind.customScheme);
      expect(outcome.presentedPrompt, isTrue);
      expect(outcome.prompt, kOpenInCodSquadPrompt);
      expect(outcome.decision, AppLinkAcceptDecision.pending);
      expect(outcome.location, isNull);
      expect(gate.delivers(lobbyCustom, isIosSimulator: true), isFalse);
      expect(
        queue.offerColdStartUrl(
          lobbyCustom,
          isIosSimulator: true,
          acceptGate: gate,
        ),
        isNull,
      );
    });

    test('mocked Accept delivers through locationForDeepLink', () {
      final gate = AppLinkAcceptGate();
      gate.answerCustomSchemePrompt(AppLinkAcceptDecision.accept);
      final outcome = resolveAppLinkAccept(
        link: lobbyCustom,
        gate: gate,
        isIosSimulator: true,
      );
      expect(outcome.presentedPrompt, isFalse);
      expect(outcome.delivers, isTrue);
      expect(outcome.location, expectedLobby);
      expect(outcome.location, locationForDeepLink(lobbyCustom));
      expect(gate.customSchemeAcceptedThisInstall, isTrue);

      expect(
        queue.offerColdStartUrl(
          lobbyCustom,
          isIosSimulator: true,
          acceptGate: gate,
        ),
        expectedLobby,
      );
    });

    test('mocked Cancel does not invent a route; next open still gated', () {
      final gate = AppLinkAcceptGate();
      gate.answerCustomSchemePrompt(AppLinkAcceptDecision.cancel);
      final outcome = resolveAppLinkAccept(
        link: lobbyCustom,
        gate: gate,
        isIosSimulator: true,
      );
      expect(outcome.kind, AppLinkAcceptKind.customScheme);
      expect(outcome.decision, AppLinkAcceptDecision.cancel);
      expect(outcome.location, isNull);
      expect(gate.customSchemeAcceptedThisInstall, isFalse);
      expect(
        queue.offerResumeUrl(
          lobbyCustom,
          isIosSimulator: true,
          acceptGate: gate,
        ),
        isNull,
      );
    });

    test('second custom-scheme open after Accept skips the sheet', () {
      final gate = AppLinkAcceptGate();
      gate.answerCustomSchemePrompt(AppLinkAcceptDecision.accept);
      expect(
        resolveAppLinkAccept(
          link: lobbyCustom,
          gate: gate,
          isIosSimulator: true,
        ).presentedPrompt,
        isFalse,
      );
      expect(
        resolveAppLinkAccept(
          link: 'codsquadapp://chat/1766270568521',
          gate: gate,
          isIosSimulator: true,
        ).location,
        '/chat/1766270568521',
      );
    });

    test('sim leftover https UL is swallowed and must not present Open-in', () {
      final gate = AppLinkAcceptGate();
      for (final url in [
        lobbyHttps,
        'https://www.codsquad.app/l/lobby-9',
        'https://lobbiesync.app/chat/leftover',
      ]) {
        final outcome = resolveAppLinkAccept(
          link: url,
          gate: gate,
          isIosSimulator: true,
        );
        expect(outcome.kind, AppLinkAcceptKind.swallowed, reason: url);
        expect(outcome.presentedPrompt, isFalse, reason: url);
        expect(outcome.prompt, isNull, reason: url);
        expect(outcome.location, isNull, reason: url);
      }
    });

    test('portalBlocked does not invent Associated Domains Accept', () {
      final gate = AppLinkAcceptGate.portalBlocked();
      expect(
        gate.associatedDomainsDecision,
        AppLinkAcceptDecision.cancel,
      );
      expect(gate.delivers(lobbyHttps, isIosSimulator: false), isFalse);
      expect(
        locationForUniversalLink(
          lobbyHttps,
          isIosSimulator: false,
          acceptGate: gate,
        ),
        isNull,
      );
      final outcome = resolveAppLinkAccept(
        link: lobbyHttps,
        gate: gate,
        isIosSimulator: false,
      );
      expect(outcome.kind, AppLinkAcceptKind.universalLink);
      expect(outcome.decision, AppLinkAcceptDecision.cancel);
      expect(outcome.presentedPrompt, isFalse);
      expect(outcome.location, isNull);
      expect(
        queue.offerColdStartUrl(
          lobbyHttps,
          isIosSimulator: false,
          acceptGate: gate,
        ),
        isNull,
      );
    });

    test('mocked Associated Domains Accept delivers device UL only', () {
      final gate = AppLinkAcceptGate.portalBlocked();
      gate.mockAssociatedDomainsPortal(AppLinkAcceptDecision.accept);
      expect(
        locationForUniversalLink(
          lobbyHttps,
          isIosSimulator: false,
          acceptGate: gate,
        ),
        expectedLobby,
      );
      expect(
        locationForUniversalLink(
          lobbyHttps,
          isIosSimulator: true,
          acceptGate: gate,
        ),
        isNull,
      );
      final device = resolveAppLinkAccept(
        link: lobbyHttps,
        gate: gate,
        isIosSimulator: false,
      );
      expect(device.delivers, isTrue);
      expect(device.location, expectedLobby);
      expect(device.presentedPrompt, isFalse);
    });

    test('Accept-gate mock does not rewrite AASA TEAMID placeholder', () {
      final gate = AppLinkAcceptGate.deviceReady();
      expect(
        gate.associatedDomainsDecision,
        AppLinkAcceptDecision.accept,
      );
      const paths = [
        'ios/associated-domains/apple-app-site-association',
        'web/.well-known/apple-app-site-association',
        'web/apple-app-site-association',
      ];
      for (final path in paths) {
        final text = File(path).readAsStringSync();
        expect(text.contains('TEAMID.com.example.codSquadApp'), isTrue);
        expect(text.contains('/l/*'), isTrue);
      }
    });

    test('malformed URL is cancel without presenting Open-in', () {
      final gate = AppLinkAcceptGate();
      final outcome = resolveAppLinkAccept(
        link: 'javascript:alert(1)',
        gate: gate,
        isIosSimulator: true,
      );
      expect(outcome.kind, AppLinkAcceptKind.malformed);
      expect(outcome.presentedPrompt, isFalse);
      expect(outcome.location, isNull);
    });
  });
}
