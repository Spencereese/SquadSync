import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:squad_sync/core/app_env.dart';
import 'package:squad_sync/core/app_router.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/presentation/notifiers/discovery_notifier.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/screens/discovery_screen.dart';
import 'package:squad_sync/screens/discovery_swipe_screen.dart';
import 'package:squad_sync/screens/lobby_tab_screen.dart';

/// Slice L reds: friendsMode + no selected lobby + no deep-link lobby_id
/// lands Tonight empty home — not Discovery, not the 0.75 game carousel.
///
/// No product in this commit. Loop greens in ≤3 lib files:
/// 1. [LobbyTabScreen] empty branch (friendsMode, no selected lobby,
///    no `lobby_id`) → Tonight home instead of [DiscoveryScreen]
/// 2. Tonight strip / ± one new TonightHome file (presence → card →
///    LFG/peacock → last locked)
/// 3. Start a lobby = Slice A [createLobby] bind. Do not open
///    [DiscoverySwipeScreen]. Keep [LobbyTabScreen.shouldShowFullSquad]
///    for deep links.
///
/// Friend taps / sees (empty Tonight):
/// 1. Presence row (On / Looking / In lobby)
/// 2. Tonight card: "Nothing tonight" + primary Start a lobby +
///    secondary I'm on
/// 3. LFG / peacock queue compact row
/// 4. Last locked session (ratings) only if one exists
const kTonightEmptyHomeKey = Key('tonight-empty-home');
const kTonightPresenceRowKey = Key('tonight-presence-row');
const kTonightCardNothingKey = Key('tonight-card-nothing');
const kTonightStartLobbyKey = Key('tonight-start-lobby');
const kTonightImOnKey = Key('tonight-im-on');
const kTonightLfgRowKey = Key('tonight-lfg-row');
const kTonightLastLockedKey = Key('tonight-last-locked');
const kLobbyDiscoveryKey = Key('lobby-discovery');
const kLobbyFullSquadKey = Key('lobby-full-squad');
const kLobbyGameCarouselKey = Key('lobby-game-carousel');

const _kTonightHomeLibPaths = [
  'lib/screens/lobby_tab_screen.dart',
  'lib/lobbies_tab/lobbies_tab.dart',
  'lib/lobbies_tab/widgets/lobby_controls.dart',
  'lib/screens/tonight_home.dart',
  'lib/lobbies_tab/widgets/tonight_home.dart',
  'lib/widgets/tonight_home.dart',
];

class _EmptyHomeLobbyNotifier extends LobbyNotifier {
  int createLobbyCalls = 0;
  String? lastChatGroupId;
  bool lastIsPublic = false;

  @override
  Future<LobbyState> build() async => LobbyState.initial();

  @override
  Future<String> createLobby({
    required String chatGroupId,
    required String gameName,
    required int maxSpots,
    bool isPublic = false,
    String? chatGroupName,
  }) async {
    createLobbyCalls++;
    lastChatGroupId = chatGroupId;
    lastIsPublic = isPublic;
    return 'lobby-created';
  }
}

String _readExisting(List<String> paths) {
  final chunks = <String>[];
  for (final path in paths) {
    final file = File(path);
    if (file.existsSync()) chunks.add(file.readAsStringSync());
  }
  return chunks.join('\n');
}

String _tonightHomeLibSource() => _readExisting(_kTonightHomeLibPaths);

bool _productWiresTonightEmptyHome() {
  final src = _tonightHomeLibSource();
  return src.contains('tonight-empty-home') &&
      src.contains('tonight-presence-row') &&
      src.contains('tonight-card-nothing') &&
      src.contains('tonight-start-lobby') &&
      src.contains('tonight-im-on') &&
      src.contains('tonight-lfg-row');
}

bool _friendsEmptyHomeStillDiscovery(String src) {
  return src.contains("key: Key('lobby-discovery')") &&
      src.contains('DiscoveryScreen()') &&
      !src.contains('tonight-empty-home');
}

bool _emptyHomeUsesGameCarousel(String src) {
  return src.contains('viewportFraction: 0.75') &&
      (src.contains('_buildPinnedGamesCarousel') ||
          src.contains('lobby-game-carousel')) &&
      !src.contains('tonight-empty-home');
}

String _startLobbyHandlerSource() {
  final src = _tonightHomeLibSource();
  final keyAt = src.indexOf('tonight-start-lobby');
  if (keyAt < 0) return '';
  final start = keyAt < 400 ? 0 : keyAt - 400;
  final end = (keyAt + 800).clamp(0, src.length);
  return src.substring(start, end);
}

Future<void> _pumpLobbyTabEmpty(
  WidgetTester tester, {
  required _EmptyHomeLobbyNotifier notifier,
  String? lobbyId,
  String? gameName,
}) async {
  AppEnv.debugReplaceForTest({'FRIENDS_MODE': 'true'});
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lobbyNotifierProvider.overrideWith(() => notifier),
        publicLobbiesProvider.overrideWith(
          (ref) => Stream.value(const <Lobby>[]),
        ),
      ],
      child: MaterialApp(
        home: LobbyTabScreen(
          lobbyId: lobbyId,
          gameName: gameName,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Pump product LobbyTab when Loop has keys; otherwise the current
/// Discovery / 0.75 carousel fallthrough so widget expects stay red.
Future<void> _pumpFriendsEmptyTonight(
  WidgetTester tester, {
  required _EmptyHomeLobbyNotifier notifier,
}) async {
  if (_productWiresTonightEmptyHome()) {
    await _pumpLobbyTabEmpty(tester, notifier: notifier);
    return;
  }

  await tester.pumpWidget(
    const MaterialApp(
      home: KeyedSubtree(
        key: kLobbyDiscoveryKey,
        child: SizedBox.expand(
          child: ColoredBox(
            key: kLobbyGameCarouselKey,
            color: Color(0xFF0B0E14),
            child: Text('Discovery / 0.75 carousel fallthrough'),
          ),
        ),
      ),
    ),
  );
}

void _expectEmptyHomeStack() {
  expect(find.byKey(kTonightEmptyHomeKey), findsOneWidget);
  expect(find.byKey(kTonightPresenceRowKey), findsOneWidget);
  expect(find.byKey(kTonightCardNothingKey), findsOneWidget);
  expect(find.text('Nothing tonight'), findsOneWidget);
  expect(find.byKey(kTonightStartLobbyKey), findsOneWidget);
  expect(find.text('Start a lobby'), findsOneWidget);
  expect(find.byKey(kTonightImOnKey), findsOneWidget);
  expect(find.text("I'm on"), findsOneWidget);
  expect(find.byKey(kTonightLfgRowKey), findsOneWidget);
}

void _expectNotDiscoveryOrCarousel() {
  expect(find.byKey(kLobbyDiscoveryKey), findsNothing);
  expect(find.byType(DiscoveryScreen), findsNothing);
  expect(find.byType(DiscoverySwipeScreen), findsNothing);
  expect(find.byKey(kLobbyGameCarouselKey), findsNothing);
  expect(find.text('Add Game'), findsNothing);
  expect(find.text('No pinned games'), findsNothing);
}

void main() {
  setUp(() {
    AppEnv.debugReplaceForTest({});
  });
  tearDown(() {
    AppEnv.debugReplaceForTest({});
  });

  group('Slice L — friends empty Tonight is not Discovery', () {
    test(
      'lobby tab empty branch no longer falls through to DiscoveryScreen',
      () {
        final src = File('lib/screens/lobby_tab_screen.dart').readAsStringSync();
        expect(
          src.contains('tonight-empty-home') ||
              src.contains('kTonightEmptyHome'),
          isTrue,
          reason: 'friendsMode empty /squad must key Tonight empty home',
        );
        expect(
          src.contains('AppEnv.friendsMode') || src.contains('friendsMode'),
          isTrue,
          reason: 'empty home is the friendsMode /squad landing, not Discovery',
        );
        expect(
          _friendsEmptyHomeStillDiscovery(src),
          isFalse,
          reason: 'selectedLobbyId == null must not return lobby-discovery / '
              'DiscoveryScreen when friendsMode and no deep-link lobby_id',
        );
      },
    );

    test('empty Tonight home does not keep the 0.75 pinned-game carousel', () {
      final src = File('lib/screens/lobby_tab_screen.dart').readAsStringSync();
      expect(
        _emptyHomeUsesGameCarousel(src),
        isFalse,
        reason: 'friends empty home is Tonight stack, not PageView 0.75',
      );
      expect(
        src.contains('_buildPinnedGamesCarousel') &&
            !src.contains('tonight-empty-home'),
        isFalse,
      );
    });

    testWidgets(
      'friendsMode + no selected lobby + no lobby_id shows Tonight empty home',
      (tester) async {
        expect(AppEnv.friendsMode, isTrue);
        expect(
          LobbyTabScreen.shouldShowFullSquad(gameName: null, lobbyId: null),
          isFalse,
        );
        expect(LobbyState.initial().selectedLobbyId, isNull);

        final notifier = _EmptyHomeLobbyNotifier();
        await _pumpFriendsEmptyTonight(tester, notifier: notifier);

        _expectEmptyHomeStack();
        expect(find.byKey(kTonightLastLockedKey), findsNothing);
        _expectNotDiscoveryOrCarousel();
      },
    );

    testWidgets(
      'empty Tonight stack order is presence → card → LFG → last locked',
      (tester) async {
        final notifier = _EmptyHomeLobbyNotifier();
        await _pumpFriendsEmptyTonight(tester, notifier: notifier);

        _expectEmptyHomeStack();

        final presence = tester.getTopLeft(find.byKey(kTonightPresenceRowKey)).dy;
        final card = tester.getTopLeft(find.byKey(kTonightCardNothingKey)).dy;
        final lfg = tester.getTopLeft(find.byKey(kTonightLfgRowKey)).dy;
        expect(presence < card, isTrue, reason: 'presence row first');
        expect(card < lfg, isTrue, reason: 'Tonight card above LFG row');
        expect(find.byKey(kTonightLastLockedKey), findsNothing);
      },
    );
  });

  group('Slice L — product LobbyTabScreen empty landing', () {
    testWidgets(
      'LobbyTabScreen() under friendsMode is empty home, not Discovery',
      (tester) async {
        final notifier = _EmptyHomeLobbyNotifier();
        await _pumpLobbyTabEmpty(tester, notifier: notifier);

        expect(find.byKey(kTonightEmptyHomeKey), findsOneWidget);
        expect(find.byKey(kTonightPresenceRowKey), findsOneWidget);
        expect(find.byKey(kTonightCardNothingKey), findsOneWidget);
        expect(find.byKey(kTonightStartLobbyKey), findsOneWidget);
        expect(find.byKey(kTonightImOnKey), findsOneWidget);
        expect(find.byKey(kTonightLfgRowKey), findsOneWidget);
        expect(find.byKey(kTonightLastLockedKey), findsNothing);

        expect(find.byKey(kLobbyDiscoveryKey), findsNothing);
        expect(find.byType(DiscoveryScreen), findsNothing);
        expect(find.byType(DiscoverySwipeScreen), findsNothing);
        expect(find.text('Add Game'), findsNothing);
        expect(find.byType(PageView), findsNothing);
      },
    );

    testWidgets(
      'Start a lobby is createLobby bind, not DiscoverySwipeScreen',
      (tester) async {
        final handler = _startLobbyHandlerSource();
        expect(
          handler.contains('createLobby'),
          isTrue,
          reason: 'tonight-start-lobby must call Slice A createLobby bind',
        );
        expect(
          handler.contains('DiscoverySwipeScreen'),
          isFalse,
          reason: 'Start a lobby must not push DiscoverySwipeScreen',
        );
        expect(
          handler.contains('DiscoveryScreen'),
          isFalse,
          reason: 'Start a lobby must not open Discovery',
        );

        final notifier = _EmptyHomeLobbyNotifier();
        await _pumpFriendsEmptyTonight(tester, notifier: notifier);

        expect(find.byKey(kTonightStartLobbyKey), findsOneWidget);
        await tester.tap(find.byKey(kTonightStartLobbyKey));
        await tester.pump();

        expect(notifier.createLobbyCalls, greaterThan(0));
        expect(
          notifier.lastIsPublic,
          isFalse,
          reason: 'Start a lobby is Slice A bind, not public Discovery create',
        );
        expect(find.byType(DiscoverySwipeScreen), findsNothing);
        expect(find.byType(DiscoveryScreen), findsNothing);
      },
    );
  });

  group('Slice L — last locked only when a session exists', () {
    testWidgets('no locked session keeps tonight-last-locked off empty home',
        (tester) async {
      final notifier = _EmptyHomeLobbyNotifier();
      await _pumpFriendsEmptyTonight(tester, notifier: notifier);

      expect(find.byKey(kTonightEmptyHomeKey), findsOneWidget);
      expect(find.byKey(kTonightLastLockedKey), findsNothing);
    });
  });

  group('Slice L — shouldShowFullSquad deep-link guard', () {
    test('deep-link lobby_id still opens full squad, not empty home', () {
      expect(
        LobbyTabScreen.shouldShowFullSquad(
          gameName: null,
          lobbyId: 'lobby-9',
        ),
        isTrue,
      );
      expect(
        LobbyTabScreen.shouldShowFullSquad(gameName: 'Warzone', lobbyId: null),
        isTrue,
      );
      expect(
        LobbyTabScreen.shouldShowFullSquad(gameName: null, lobbyId: null),
        isFalse,
      );

      final src = File('lib/screens/lobby_tab_screen.dart').readAsStringSync();
      expect(src.contains('shouldShowFullSquad'), isTrue);
      expect(src.contains('lobby-full-squad'), isTrue);
    });

    testWidgets(
      'GoRouter /squad?lobby_id= still shouldShowFullSquad under friendsMode',
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
        expect(
          LobbyTabScreen.shouldShowFullSquad(
            gameName: null,
            lobbyId: seenLobbyId,
          ),
          isTrue,
          reason: 'deep-link lobby_id keeps full squad, not empty Tonight',
        );
        expect(find.byKey(kTonightEmptyHomeKey), findsNothing);
      },
    );
  });
}
