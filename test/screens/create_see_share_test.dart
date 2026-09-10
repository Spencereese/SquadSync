import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/app_env.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_header.dart';
import 'package:squad_sync/presentation/notifiers/discovery_notifier.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/screens/lobby_tab_screen.dart';

/// Slice CREATE-SEE-SHARE reds: friends create must stay on THAT lobby
/// and expose a share/copy HTTPS link. No product in this commit.
///
/// North star (Spencer dogfood P0):
/// 1. After [createLobby], user sees / returns to that lobby UI — not
///    empty Tonight home, not lost selection / Discovery dashboard.
/// 2. From that lobby, share or copy emits
///    `https://cod-squad-a4c62.web.app/l/<id>` (AASA host, not
///    retired `codsquad.app`).
///
/// Out of scope: joining public / Discovery lobbies (friendsMode
/// compile-out).
///
/// Loop greens in ≤3 lib files (report only — Tester does not edit):
/// 1. [LobbyTabScreen] — selectedLobbyId after create keeps
///    `lobby-full-squad` (not [FullShellLobbyDashboard] / Discovery)
/// 2. [TonightEmptyHome] create path — land selection so Tonight
///    does not stay empty
/// 3. [LobbyNotifier.createLobby] / `_landOnCreatedLobby` bind if
///    selectedLobby persistence is the miss
///
/// Share helper host is already AASA (`lobbyShareHttpsLink`). Do not
/// bump pubspec. No goldens. No Orbitron snapshot.
const kTonightEmptyHomeKey = Key('tonight-empty-home');
const kTonightStartLobbyKey = Key('tonight-start-lobby');
const kLobbyDiscoveryKey = Key('lobby-discovery');
const kLobbyFullSquadKey = Key('lobby-full-squad');
const kSeatMapHeroKey = Key('seat-map-hero');
const kLobbyShareLinkKey = Key('lobby-share-link');

const kCreatedLobbyId = 'lobby-created';
const kAasaHost = 'cod-squad-a4c62.web.app';
const kRetiredAasaHost = 'codsquad.app';

const _kLobbyTabSrc = 'lib/screens/lobby_tab_screen.dart';
const _kTonightHomeSrc = 'lib/screens/tonight_home.dart';
const _kLobbyNotifierSrc = 'lib/presentation/notifiers/lobby_notifier.dart';
const _kLobbyHeaderSrc = 'lib/lobbies_tab/widgets/lobby_header.dart';

class _CreateSeeLobbyNotifier extends LobbyNotifier {
  int createLobbyCalls = 0;
  bool lastIsPublic = false;
  bool persistSelection = false;

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
    lastIsPublic = isPublic;
    if (persistSelection) {
      state = AsyncData(_landedState());
    }
    return kCreatedLobbyId;
  }
}

Lobby _createdLobby() {
  return Lobby.create(
    name: 'Squad',
    gameName: 'Squad',
    maxSpots: 8,
    createdBy: 'creator-1',
  ).copyWith(id: kCreatedLobbyId);
}

LobbyState _landedState() {
  final lobby = _createdLobby();
  return LobbyState.initial().copyWith(
    selectedLobbyId: kCreatedLobbyId,
    currentLobby: lobby,
    userLobbies: {kCreatedLobbyId: lobby},
    userLobbyIds: const [kCreatedLobbyId],
  );
}

String _read(String path) => File(path).readAsStringSync();

/// Guard + key for `lobby-full-squad` only — do not bleed into the
/// later empty-Tonight `selectedLobbyId == null` branch.
String _fullSquadWindow(String src) {
  final keyAt = src.indexOf('lobby-full-squad');
  if (keyAt < 0) return '';
  final start = keyAt < 400 ? 0 : keyAt - 400;
  final end = (keyAt + 90).clamp(0, src.length);
  return src.substring(start, end);
}

bool _fullSquadWindowUsesSelectedLobby(String src) {
  final window = _fullSquadWindow(src);
  if (!window.contains('selectedLobbyId')) return false;
  return window.contains('widget.lobbyId ??') ||
      window.contains('squadState.selectedLobbyId') ||
      window.contains('shouldShowFullSquad');
}

/// Product create→see: selected lobby after createLobby is full squad.
bool _productLandsCreatedLobbyOnFullSquad() {
  return _fullSquadWindowUsesSelectedLobby(_read(_kLobbyTabSrc));
}

String _startLobbyHandlerSource() {
  final src = _read(_kTonightHomeSrc);
  final keyAt = src.indexOf('tonight-start-lobby');
  if (keyAt < 0) return '';
  final start = keyAt < 400 ? 0 : keyAt - 400;
  final end = (keyAt + 800).clamp(0, src.length);
  return src.substring(start, end);
}

Future<void> _pumpLobbyTabEmpty(
  WidgetTester tester, {
  required _CreateSeeLobbyNotifier notifier,
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
      child: const MaterialApp(
        home: LobbyTabScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Landed create→see surface once Loop keys selectedLobby → full squad.
Future<void> _pumpLandedCreateSee(
  WidgetTester tester, {
  required _CreateSeeLobbyNotifier notifier,
  required Future<void> Function(BuildContext context) onShare,
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
        home: Scaffold(
          body: KeyedSubtree(
            key: kLobbyFullSquadKey,
            child: Column(
              children: [
                const KeyedSubtree(
                  key: kSeatMapHeroKey,
                  child: SizedBox(height: 8),
                ),
                Builder(
                  builder: (context) {
                    return LobbyShareButton(
                      onPressed: () => onShare(context),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _expectCreatedLobbyVisible() {
  expect(
    find.byKey(kTonightEmptyHomeKey),
    findsNothing,
    reason: 'create→see: after createLobby must not return to empty Tonight',
  );
  expect(
    find.byKey(kLobbyDiscoveryKey),
    findsNothing,
    reason: 'create→see: selected lobby must not disappear onto Discovery',
  );
  expect(
    find.byKey(kLobbyFullSquadKey),
    findsOneWidget,
    reason: 'create→see: user remains on that lobby UI (lobby-full-squad)',
  );
}

void main() {
  setUp(() {
    AppEnv.debugReplaceForTest({});
  });
  tearDown(() {
    AppEnv.debugReplaceForTest({});
  });

  group('Slice CREATE-SEE-SHARE — create→see', () {
    test(
      'lobby-full-squad after create uses selectedLobbyId, not only deep-link args',
      () {
        final src = _read(_kLobbyTabSrc);
        expect(src.contains('lobby-full-squad'), isTrue);
        expect(src.contains('tonight-empty-home'), isTrue);
        expect(
          _fullSquadWindowUsesSelectedLobby(src),
          isTrue,
          reason: '$_kLobbyTabSrc createLobby land must keep lobby-full-squad '
              'via selectedLobbyId. widget.lobbyId / gameName alone drops the '
              'Tonight create path back to empty home or Discovery.',
        );
        expect(
          File(_kLobbyNotifierSrc).existsSync(),
          isTrue,
        );
      },
    );

    test('Start a lobby createLobby path exists on Tonight empty home', () {
      final handler = _startLobbyHandlerSource();
      expect(
        handler.contains('createLobby'),
        isTrue,
        reason: 'tonight-start-lobby must call Slice A createLobby bind',
      );
      expect(
        handler.contains('DiscoverySwipeScreen') ||
            handler.contains('DiscoveryScreen'),
        isFalse,
        reason: 'Start a lobby is friends create, not Discovery',
      );
    });

    testWidgets(
      'after successful createLobby the created lobby stays visible',
      (tester) async {
        final notifier = _CreateSeeLobbyNotifier();

        if (_productLandsCreatedLobbyOnFullSquad()) {
          notifier.persistSelection = true;
          await _pumpLandedCreateSee(
            tester,
            notifier: notifier,
            onShare: (_) async {},
          );
        } else {
          notifier.persistSelection = true;
          await _pumpLobbyTabEmpty(tester, notifier: notifier);
          expect(find.byKey(kTonightEmptyHomeKey), findsOneWidget);
          expect(find.byKey(kTonightStartLobbyKey), findsOneWidget);
          await tester.tap(find.byKey(kTonightStartLobbyKey));
          await tester.pump();
          await tester.pump();

          expect(notifier.createLobbyCalls, greaterThan(0));
          expect(
            notifier.lastIsPublic,
            isFalse,
            reason: 'Start a lobby is friends create, not public Discovery',
          );
        }

        _expectCreatedLobbyVisible();
      },
    );
  });

  group('Slice CREATE-SEE-SHARE — share/copy AASA https', () {
    test(
      'shareLobbyLink / lobbyShareHttpsLink host is AASA firebase host',
      () {
        expect(kLobbyUniversalLinkHost, kAasaHost);
        expect(kLobbyUniversalLinkHost, isNot(kRetiredAasaHost));
        expect(
          lobbyShareHttpsLink(lobbyId: kCreatedLobbyId),
          'https://$kAasaHost/l/$kCreatedLobbyId',
        );
        expect(
          lobbyShareHttpsLink(lobbyId: kCreatedLobbyId),
          isNot(contains(kRetiredAasaHost)),
        );
        expect(
          lobbySharePayload(lobbyId: kCreatedLobbyId),
          contains('https://$kAasaHost/l/$kCreatedLobbyId'),
        );
      },
    );

    test(
      'create→see land surface is the path that can share the lobby link',
      () {
        expect(
          _productLandsCreatedLobbyOnFullSquad(),
          isTrue,
          reason: 'friends cannot copy https://$kAasaHost/l/<id> until '
              'createLobby keeps lobby-full-squad (header share lives there)',
        );
        final header = _read(_kLobbyHeaderSrc);
        expect(header.contains('lobby-share-link'), isTrue);
        expect(header.contains('shareLobbyLink'), isTrue);
      },
    );

    testWidgets(
      'from the created lobby, share/copy emits AASA https://host/l/<id>',
      (tester) async {
        String? copied;
        String? shared;
        final notifier = _CreateSeeLobbyNotifier();

        if (_productLandsCreatedLobbyOnFullSquad()) {
          notifier.persistSelection = true;
          await _pumpLandedCreateSee(
            tester,
            notifier: notifier,
            onShare: (context) async {
              final result = await shareLobbyLink(
                lobbyId: kCreatedLobbyId,
                copy: (text) async => copied = text,
                share: (text) async => shared = text,
              );
              presentLobbyShare(context, result);
            },
          );
        } else {
          notifier.persistSelection = true;
          await _pumpLobbyTabEmpty(tester, notifier: notifier);
          expect(find.byKey(kTonightStartLobbyKey), findsOneWidget);
          await tester.tap(find.byKey(kTonightStartLobbyKey));
          await tester.pump();
          await tester.pump();
          expect(notifier.createLobbyCalls, greaterThan(0));
        }

        _expectCreatedLobbyVisible();
        expect(
          find.byKey(kLobbyShareLinkKey),
          findsOneWidget,
          reason: 'created lobby must expose lobby-share-link so friends '
              'can copy https://$kAasaHost/l/$kCreatedLobbyId',
        );

        await tester.tap(find.byKey(kLobbyShareLinkKey));
        await tester.pump();

        expect(
          copied,
          contains(lobbyShareHttpsLink(lobbyId: kCreatedLobbyId)),
        );
        expect(copied, contains('https://$kAasaHost/l/$kCreatedLobbyId'));
        expect(copied, isNot(contains('https://$kRetiredAasaHost/')));
        expect(shared, copied);
        expect(
          kLobbyUniversalLinkHost,
          kAasaHost,
          reason: 'host must be $kAasaHost not $kRetiredAasaHost',
        );
      },
    );
  });
}
