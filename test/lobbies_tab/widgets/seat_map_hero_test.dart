import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_controls.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_grid.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_seat_affordance.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_spot_map_seat.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/services/lobby_ready_lock.dart';
import 'package:squad_sync/services/lobby_seat_status.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';

/// Slice M reds: seat map is the hero. Files stay; no product in this commit.
/// Loop greens later in lease files only (spot_widgets, peacock_widgets,
/// lobby header, lobbies_tab / grid / controls / seat affordance).
/// Do not bump pubspec. Do not touch machines (read ready-lock snapshot only).
///
/// Friend sees (full squad):
/// 1. Seat grid first (full squad view)
/// 2. One footer CTA: I'm Ready → Waiting on N → Lock → Locked
/// 3. More (voice / share / clips live here or in the header icon row)
///
/// Seat states at arm's length:
/// - empty: dashed + Claim
/// - offered: pulse ONCE then static highlight (spot_index deep link)
/// - seated: avatar + name, no Orbitron
/// - you: stronger ring
/// - locked: lock glyph + mm:ss from ready-lock snapshot only
///
/// No extra Ready toggle on seats. No second stack of neon
/// voice/share/clips cards.
const kSeatMapHeroKey = Key('seat-map-hero');
const kSeatGridKey = Key('seat-grid');
const kSeatEmptyKey = Key('seat-empty');
const kSeatClaimKey = Key('seat-claim');
const kSeatOfferedKey = Key('seat-offered');
const kSeatSeatedKey = Key('seat-seated');
const kSeatYouKey = Key('seat-you');
const kSeatLockedKey = Key('seat-locked');
const kLobbyFooterCtaKey = Key('lobby-footer-cta');

const kFooterImReady = "I'm Ready";
const kFooterLock = 'Lock';
const kFooterLocked = 'Locked';

const _kSliceMLeasePaths = [
  'lib/lobbies_tab/spot_widgets.dart',
  'lib/lobbies_tab/peacock_widgets.dart',
  'lib/lobbies_tab/widgets/lobby_header.dart',
  'lib/lobbies_tab/lobbies_tab.dart',
  'lib/lobbies_tab/widgets/lobby_grid.dart',
  'lib/lobbies_tab/widgets/lobby_controls.dart',
  'lib/lobbies_tab/widgets/lobby_seat_affordance.dart',
  'lib/lobbies_tab/widgets/lobby_spot_map_seat.dart',
];

String _readExisting(List<String> paths) {
  final chunks = <String>[];
  for (final path in paths) {
    final file = File(path);
    if (file.existsSync()) chunks.add(file.readAsStringSync());
  }
  return chunks.join('\n');
}

String _leaseSource() => _readExisting(_kSliceMLeasePaths);

bool _productWiresSeatMapHero() {
  final src = _leaseSource();
  return src.contains('seat-map-hero') &&
      src.contains('seat-grid') &&
      src.contains('seat-empty') &&
      src.contains('seat-claim') &&
      src.contains('seat-offered') &&
      src.contains('seat-seated') &&
      src.contains('seat-you') &&
      src.contains('seat-locked') &&
      src.contains('lobby-footer-cta');
}

/// Footer label from ready-lock snapshot only. Loop must match this.
String lobbyFooterCtaLabelFromSnapshot({
  required LobbyReadyLockSnapshot snapshot,
  required String uid,
}) {
  if (snapshot.isLocked) return kFooterLocked;
  if (!snapshot.seatedUids.contains(uid)) return kFooterImReady;
  if (!snapshot.isReady(uid)) return kFooterImReady;
  final waitingOn =
      snapshot.seatedUids.where((id) => !snapshot.isReady(id)).length;
  if (waitingOn > 0) return 'Waiting on $waitingOn';
  return kFooterLock;
}

LobbyState _openLobbyState({
  List<String?> spots = const ['u1', null, null, null],
  Map<String, String> statuses = const {'u1': 'Occupied'},
  Map<String, String> names = const {'u1': 'Alice', 'u2': 'Bob'},
}) {
  final lobby = Lobby.create(
    name: 'Tonight',
    gameName: 'Warzone',
    maxSpots: spots.length,
    createdBy: 'u1',
  ).copyWith(
    id: 'lobby-9',
    memberUids: const ['u1', 'u2'],
    spots: spots,
    statuses: statuses,
    chatGroupId: 'chat-9',
  );
  return LobbyState.initial().copyWith(
    selectedLobbyId: 'lobby-9',
    currentLobby: lobby,
    currentGame: {'name': 'Warzone', 'maxSpots': spots.length},
    gameLobbySpots: {'Warzone': spots},
    gameStatuses: {'Warzone': statuses},
    globalStatuses: statuses,
    memberDisplayNames: names,
  );
}

class _HeroLobbyNotifier extends LobbyNotifier {
  _HeroLobbyNotifier(this._seed);

  final LobbyState _seed;

  @override
  Future<LobbyState> build() async => _seed;

  @override
  LobbyReadyLockSnapshot? get lastReadyLockSnapshot =>
      resolveLobbyReadyLockFromState(_seed, gameName: 'Warzone');
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

Future<void> _pumpHeroSurface(
  WidgetTester tester, {
  required LobbyState state,
}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lobbyNotifierProvider.overrideWith(() => _HeroLobbyNotifier(state)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              LobbyGrid(highlightSpotIndex: 2),
              LobbyControls(),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

bool _isOrbitron(TextStyle? style) {
  final family = style?.fontFamily ?? '';
  final fallback = style?.fontFamilyFallback ?? const <String>[];
  return family.contains('Orbitron') ||
      fallback.any((name) => name.contains('Orbitron'));
}

void main() {
  setUp(() {
    MatchmakingQueueTracker.resetInstance();
  });

  tearDown(() {
    MatchmakingQueueTracker.resetInstance();
  });

  group('Slice M — product keys on the seat-map hero', () {
    test('lease files wire seat-map-hero, seat-grid, seat states, footer CTA',
        () {
      expect(
        _productWiresSeatMapHero(),
        isTrue,
        reason: 'Loop must key the hero map + footer CTA. Missing one of '
            'seat-map-hero / seat-grid / seat-empty / seat-claim / '
            'seat-offered / seat-seated / seat-you / seat-locked / '
            'lobby-footer-cta',
      );
    });

    testWidgets('pumped lobby surface exposes seat-map-hero and seat-grid',
        (tester) async {
      await _pumpHeroSurface(tester, state: _openLobbyState());

      expect(find.byKey(kSeatMapHeroKey), findsOneWidget);
      expect(find.byKey(kSeatGridKey), findsOneWidget);
      expect(find.byType(LobbyGrid), findsOneWidget);
    });
  });

  group('Slice M — empty seat is dashed Claim', () {
    testWidgets('empty seat uses seat-empty / seat-claim, dashed, Claim',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const LobbySpotMapSeat(
            index: 0,
            kind: LobbySpotMapKind.empty,
            statusLabel: 'Open',
          ),
        ),
      );

      expect(find.byKey(kSeatEmptyKey), findsOneWidget);
      expect(find.byKey(kSeatClaimKey), findsOneWidget);
      expect(find.text('Claim'), findsOneWidget);
      expect(find.text('OPEN'), findsNothing);

      final material = tester.widget<Material>(find.byKey(kSeatEmptyKey));
      final shape = material.shape as RoundedRectangleBorder;
      expect(
        shape.side.width,
        greaterThan(0),
        reason: 'empty seat keeps a visible outline',
      );
      expect(
        File('lib/lobbies_tab/widgets/lobby_spot_map_seat.dart')
            .readAsStringSync()
            .contains('dashed'),
        isTrue,
        reason: 'empty seat is dashed at arm\'s length, not a solid neon card',
      );
    });
  });

  group('Slice M — offered pulse once then static', () {
    test('offered spot pulses once, not a repeating controller', () {
      final src = File('lib/lobbies_tab/widgets/lobby_seat_affordance.dart')
          .readAsStringSync();
      expect(src.contains('seat-offered'), isTrue);
      expect(
        src.contains('controller.repeat()'),
        isFalse,
        reason: 'offered highlight pulses ONCE then stays static',
      );
    });

    testWidgets('deep-link spot_index offered seat uses seat-offered',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const OfferedSpotPulse(
            pulse: true,
            child: LobbySpotMapSeat(
              index: 2,
              kind: LobbySpotMapKind.peacock,
              statusLabel: 'Peacock',
            ),
          ),
        ),
      );

      expect(find.byKey(kSeatOfferedKey), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(kSeatOfferedKey), findsOneWidget);
    });
  });

  group('Slice M — seated avatar + name, no Orbitron; you stronger ring', () {
    testWidgets('seated seat is seat-seated with name, not Orbitron',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const LobbySpotMapSeat(
            index: 1,
            kind: LobbySpotMapKind.filled,
            statusLabel: 'Occupied',
            displayName: 'Alice',
          ),
        ),
      );

      expect(find.byKey(kSeatSeatedKey), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);

      final name = tester.widget<Text>(find.text('Alice'));
      expect(
        _isOrbitron(name.style),
        isFalse,
        reason: 'seated names are not Orbitron (no Orbitron snapshot)',
      );
    });

    testWidgets('your seat uses seat-you with a stronger ring than others',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              LobbySpotMapSeat(
                index: 0,
                kind: LobbySpotMapKind.filled,
                statusLabel: 'Occupied',
                displayName: 'You',
              ),
              LobbySpotMapSeat(
                index: 1,
                kind: LobbySpotMapKind.filled,
                statusLabel: 'Occupied',
                displayName: 'Alice',
              ),
            ],
          ),
        ),
      );

      expect(find.byKey(kSeatYouKey), findsOneWidget);
      expect(find.byKey(kSeatSeatedKey), findsWidgets);

      final you = tester.widget<Material>(find.byKey(kSeatYouKey));
      final other = tester.widget<Material>(
        find.byKey(kSeatSeatedKey).first,
      );
      final youSide = (you.shape as RoundedRectangleBorder).side;
      final otherSide = (other.shape as RoundedRectangleBorder).side;
      expect(
        youSide.width,
        greaterThan(otherSide.width),
        reason: 'you get a stronger ring than other seated spots',
      );
    });

    test('lease seated-name styles do not set Orbitron', () {
      final src = _readExisting([
        'lib/lobbies_tab/widgets/lobby_spot_map_seat.dart',
        'lib/lobbies_tab/widgets/lobby_seat_affordance.dart',
        'lib/lobbies_tab/spot_widgets.dart',
      ]);
      expect(src.contains('seat-seated'), isTrue);
      final nameBlock = src.contains('Orbitron') && src.contains('displayName');
      expect(
        nameBlock,
        isFalse,
        reason: 'no Orbitron on seated names',
      );
    });
  });

  group('Slice M — locked seat: lock glyph + snapshot mm:ss', () {
    testWidgets('locked seat keys seat-locked and shows snapshot mm:ss',
        (tester) async {
      const remaining = Duration(minutes: 3, seconds: 5);
      final snapshot = const LobbyReadyLockSnapshot(
        phase: LobbyReadyLockPhase.locked,
        seatedUids: ['u1', 'u2'],
        readyUids: ['u1', 'u2'],
      );
      expect(snapshot.isLocked, isTrue);

      await tester.pumpWidget(
        _wrap(
          LobbySpotMapSeat(
            index: 0,
            kind: LobbySpotMapKind.filled,
            statusLabel: 'Locked',
            displayName: 'Alice',
            timerLabel: formatLockMmSs(remaining),
          ),
        ),
      );

      expect(find.byKey(kSeatLockedKey), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.text(formatLockMmSs(remaining)), findsOneWidget);
      expect(find.text('03:05'), findsOneWidget);
    });

    test('seat-locked timer reads ready-lock snapshot, not peacock/spot machines',
        () {
      final src = _leaseSource();
      expect(src.contains('seat-locked'), isTrue);
      expect(
        src.contains('lastReadyLockSnapshot') ||
            src.contains('formatLockMmSs'),
        isTrue,
        reason: 'lock mm:ss comes from ready-lock snapshot only',
      );
      final grid = File('lib/lobbies_tab/widgets/lobby_grid.dart')
          .readAsStringSync();
      final lockedAt = grid.indexOf('seat-locked');
      expect(lockedAt, greaterThanOrEqualTo(0));
      final window = grid.substring(
        lockedAt,
        (lockedAt + 400).clamp(0, grid.length),
      );
      expect(
        window.contains('peacockTimer') ||
            window.contains('observeTimer') ||
            window.contains('timerService'),
        isFalse,
        reason: 'do not derive lock mm:ss from peacock/spot timer machines',
      );
    });
  });

  group('Slice M — one footer CTA from ready-lock snapshot', () {
    test('snapshot labels are I\'m Ready / Waiting on N / Lock / Locked', () {
      const you = 'u1';
      expect(
        lobbyFooterCtaLabelFromSnapshot(
          snapshot: const LobbyReadyLockSnapshot(
            phase: LobbyReadyLockPhase.open,
            seatedUids: ['u1', 'u2'],
            readyUids: [],
          ),
          uid: you,
        ),
        kFooterImReady,
      );
      expect(
        lobbyFooterCtaLabelFromSnapshot(
          snapshot: const LobbyReadyLockSnapshot(
            phase: LobbyReadyLockPhase.open,
            seatedUids: ['u1', 'u2', 'u3'],
            readyUids: ['u1'],
          ),
          uid: you,
        ),
        'Waiting on 2',
      );
      expect(
        lobbyFooterCtaLabelFromSnapshot(
          snapshot: const LobbyReadyLockSnapshot(
            phase: LobbyReadyLockPhase.open,
            seatedUids: ['u1', 'u2'],
            readyUids: ['u1', 'u2'],
          ),
          uid: you,
        ),
        kFooterLock,
      );
      expect(
        lobbyFooterCtaLabelFromSnapshot(
          snapshot: const LobbyReadyLockSnapshot(
            phase: LobbyReadyLockPhase.locked,
            seatedUids: ['u1', 'u2'],
            readyUids: ['u1', 'u2'],
          ),
          uid: you,
        ),
        kFooterLocked,
      );
    });

    test('lease files expose lobby-footer-cta with the four labels', () {
      final src = _leaseSource();
      expect(src.contains('lobby-footer-cta'), isTrue);
      expect(src.contains(kFooterImReady), isTrue);
      expect(src.contains('Waiting on'), isTrue);
      expect(src.contains("'$kFooterLock'") || src.contains('"$kFooterLock"'),
          isTrue);
      expect(src.contains(kFooterLocked), isTrue);
    });

    testWidgets('footer CTA is one button: I\'m Ready on an open own seat',
        (tester) async {
      await _pumpHeroSurface(
        tester,
        state: _openLobbyState(),
      );

      expect(find.byKey(kLobbyFooterCtaKey), findsOneWidget);
      expect(find.text(kFooterImReady), findsOneWidget);
      expect(find.byKey(kLobbyFooterCtaKey), findsOneWidget);
    });

    testWidgets('footer CTA reads Waiting on N from ready-lock snapshot',
        (tester) async {
      await _pumpHeroSurface(
        tester,
        state: _openLobbyState(
          spots: const ['u1', 'u2', null, null],
          statuses: const {'u1': 'Ready', 'u2': 'Occupied'},
        ),
      );

      final snap = resolveLobbyReadyLock(
        spots: const ['u1', 'u2', null, null],
        statuses: const {'u1': 'Ready', 'u2': 'Occupied'},
      );
      expect(find.byKey(kLobbyFooterCtaKey), findsOneWidget);
      expect(
        find.text(lobbyFooterCtaLabelFromSnapshot(snapshot: snap, uid: 'u1')),
        findsOneWidget,
      );
    });

    testWidgets('footer CTA is Lock then Locked from the snapshot',
        (tester) async {
      await _pumpHeroSurface(
        tester,
        state: _openLobbyState(
          spots: const ['u1', 'u2'],
          statuses: const {'u1': 'Ready', 'u2': 'Ready'},
        ),
      );

      expect(find.byKey(kLobbyFooterCtaKey), findsOneWidget);
      expect(
        find.text(kFooterLock).evaluate().isNotEmpty ||
            find.text(kFooterLocked).evaluate().isNotEmpty,
        isTrue,
        reason: 'all-ready snapshot is Lock (when you can) or Locked',
      );
    });
  });

  group('Slice M — order + no extra Ready + no neon card stack', () {
    test('seat grid is first, then footer CTA, then More', () {
      final src = _readExisting([
        'lib/lobbies_tab/lobbies_tab.dart',
        'lib/lobbies_tab/widgets/lobby_controls.dart',
        'lib/lobbies_tab/widgets/lobby_grid.dart',
      ]);
      final gridAt = src.indexOf('seat-grid');
      final heroAt = src.indexOf('seat-map-hero');
      final footerAt = src.indexOf('lobby-footer-cta');
      final moreAt = src.indexOf('more-actions');
      expect(gridAt, greaterThanOrEqualTo(0));
      expect(heroAt, greaterThanOrEqualTo(0));
      expect(footerAt, greaterThanOrEqualTo(0));
      expect(moreAt, greaterThanOrEqualTo(0));
      expect(
        gridAt < footerAt && footerAt < moreAt,
        isTrue,
        reason: 'order is seat grid → Ready/Lock footer → More',
      );
    });

    test('no extra Ready toggle outside lobby-footer-cta', () {
      final grid = File('lib/lobbies_tab/widgets/lobby_grid.dart')
          .readAsStringSync();
      expect(
        grid.contains('seated-spot-ready-button'),
        isFalse,
        reason: 'Ready lives on lobby-footer-cta, not a per-seat toggle',
      );
      expect(
        grid.contains('SeatedSpotReadyAffordance'),
        isFalse,
        reason: 'no extra Ready affordance on the seat map',
      );
    });

    testWidgets('pumped surface has no extra Ready toggle besides footer CTA',
        (tester) async {
      await _pumpHeroSurface(tester, state: _openLobbyState());

      expect(find.byKey(kLobbyFooterCtaKey), findsOneWidget);
      expect(find.byKey(const Key('seated-spot-ready-button')), findsNothing);
      expect(find.text('Ready'), findsNothing);
    });

    test('voice/share/clips are header icons or More, not a neon card stack',
        () {
      final controls =
          File('lib/lobbies_tab/widgets/lobby_controls.dart').readAsStringSync();
      final tab = File('lib/lobbies_tab/lobbies_tab.dart').readAsStringSync();
      expect(tab.contains('seat-grid') || tab.contains('seat-map-hero'), isTrue);
      expect(
        controls.contains('ClipFeedItem') ||
            controls.contains('ClipsTab') ||
            controls.contains('fontFamily: \'Orbitron\''),
        isFalse,
        reason: 'clips are not a second neon card stack under the grid',
      );
      expect(
        controls.contains('Card(') &&
            (controls.contains('Voice') || controls.contains('Share')),
        isFalse,
        reason: 'voice/share are header icon row or More, not neon Cards',
      );
    });

    testWidgets('no second stack of neon voice/share/clips cards after grid',
        (tester) async {
      await _pumpHeroSurface(tester, state: _openLobbyState());

      expect(find.byKey(kSeatGridKey), findsOneWidget);
      expect(find.byKey(const Key('more-voice')), findsNothing);
      expect(find.text('Win'), findsNothing);
      expect(find.text('Loss'), findsNothing);
      expect(find.text('Quick Join'), findsNothing);
    });
  });
}
