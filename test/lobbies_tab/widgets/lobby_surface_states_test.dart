import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/screens/components/chat_info_actions.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_seat_affordance.dart';
import 'package:squad_sync/services/lobby_seat_status.dart';
import 'package:squad_sync/widgets/lobby_surface_feedback.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

LobbySeatStatus _peacockStatus() {
  return const LobbySeatStatus(
    chip: LobbySeatChipKind.peacock,
    seatIndex: 1,
    offerPending: false,
  );
}

void main() {
  group('Tonight strip', () {
    testWidgets('empty state when no lobby', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TonightActionsBlock(
            isEmpty: true,
            children: [],
          ),
        ),
      );

      expect(find.byKey(const Key('tonight-actions')), findsOneWidget);
      expect(find.byKey(const Key('tonight-empty')), findsOneWidget);
      expect(find.text('No lobby tonight'), findsOneWidget);
      expect(find.text(kTonightEmptyHint), findsOneWidget);
      expect(find.byKey(const Key('tonight-empty-hint')), findsOneWidget);
      expect(find.text("I'm on now"), findsNothing);
      expect(find.byKey(const Key('tonight-loading')), findsNothing);
      expect(find.byKey(const Key('tonight-error')), findsNothing);
      expect(find.byKey(const Key('tonight-retry')), findsNothing);
    });

    testWidgets('loading state from existing lobby AsyncValue', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TonightActionsBlock(
            isLoading: true,
            children: [],
          ),
        ),
      );

      expect(find.byKey(const Key('tonight-loading')), findsOneWidget);
      expect(find.text('Loading tonight...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('tonight-empty')), findsNothing);
      expect(find.byKey(const Key('tonight-error')), findsNothing);
    });

    testWidgets('error state surfaces lobby load failure', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          TonightActionsBlock(
            error: 'denied',
            onRetry: () => retried = true,
            children: const [],
          ),
        ),
      );

      expect(find.byKey(const Key('tonight-error')), findsOneWidget);
      expect(find.text("Couldn't load tonight"), findsOneWidget);
      expect(find.text(kLobbySurfaceErrorHint), findsOneWidget);
      expect(find.text('denied'), findsOneWidget);
      expect(find.byKey(const Key('tonight-retry')), findsOneWidget);
      expect(find.text(kLobbySurfaceRetryLabel), findsOneWidget);
      expect(find.byKey(const Key('tonight-empty')), findsNothing);
      expect(find.byKey(const Key('tonight-loading')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.byKey(const Key('tonight-retry')));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('offline is error + Retry, not empty or a hung spinner',
        (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          TonightActionsBlock(
            isOffline: true,
            onRetry: () => retried = true,
            children: const [],
          ),
        ),
      );

      expect(find.byKey(const Key('tonight-error')), findsOneWidget);
      expect(find.text(kLobbySurfaceOfflineCopy), findsOneWidget);
      expect(find.text(kLobbySurfaceErrorHint), findsOneWidget);
      expect(find.byKey(const Key('tonight-retry')), findsOneWidget);
      expect(find.text(kLobbySurfaceRetryLabel), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('tonight-empty')), findsNothing);
      expect(find.byKey(const Key('tonight-loading')), findsNothing);
      expect(find.text("I'm on now"), findsNothing);

      await tester.tap(find.byKey(const Key('tonight-retry')));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('offline load error copy stays arm length without dumping',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          TonightActionsBlock(
            error: Exception('SocketException: Failed host lookup'),
            onRetry: () {},
            children: const [],
          ),
        ),
      );

      expect(find.text(kLobbySurfaceOfflineCopy), findsOneWidget);
      expect(find.text(kLobbySurfaceRetryLabel), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('empty CTA is tappable at arm length', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          TonightActionsBlock(
            isEmpty: true,
            onEmptyAction: () => tapped = true,
            emptyActionLabel: "I'm on now",
            children: const [],
          ),
        ),
      );

      expect(find.byKey(const Key('tonight-empty-cta')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tonight-empty-cta')));
      await tester.pump();
      expect(tapped, isTrue);
    });

    test('error copy stays clean without dumping the raw error', () {
      expect(
        lobbySurfaceMessage(
          LobbySurfaceKind.tonight,
          LobbySurfacePhase.error,
        ),
        "Couldn't load tonight",
      );
      expect(
        lobbySurfaceHint(
          LobbySurfaceKind.tonight,
          LobbySurfacePhase.error,
        ),
        kLobbySurfaceErrorHint,
      );
      expect(
        lobbySurfaceMessage(
          LobbySurfaceKind.tonight,
          LobbySurfacePhase.error,
          isOffline: true,
        ),
        kLobbySurfaceOfflineCopy,
      );
      expect(lobbySurfaceErrorDetail('timeout'), 'timeout');
      expect(lobbySurfaceErrorDetail(Exception('denied')), 'denied');
    });

    test('tonightLobbyMissing is true without a lobby id', () {
      expect(tonightLobbyMissing(LobbyState.initial()), isTrue);
      final lobby = Lobby.create(
        name: 'Squad',
        gameName: 'Warzone',
        maxSpots: 4,
        createdBy: 'u1',
      ).copyWith(id: 'lobby-1');
      expect(
        tonightLobbyMissing(
          LobbyState.initial().copyWith(
            selectedLobbyId: 'lobby-1',
            currentLobby: lobby,
          ),
        ),
        isFalse,
      );
    });

    test('peacockCardMissing is true without a lobby or claimed seat', () {
      expect(peacockCardMissing(LobbyState.initial()), isTrue);
      final lobby = Lobby.create(
        name: 'Squad',
        gameName: 'Warzone',
        maxSpots: 4,
        createdBy: 'u1',
      ).copyWith(id: 'lobby-1');
      expect(
        peacockCardMissing(
          LobbyState.initial().copyWith(
            selectedLobbyId: 'lobby-1',
            currentLobby: lobby,
            currentGame: const {'name': 'Warzone', 'maxSpots': 4},
            gameLobbySpots: {
              'Warzone': [null, null, null, null],
            },
          ),
        ),
        isTrue,
      );
      expect(
        peacockCardMissing(
          LobbyState.initial().copyWith(
            selectedLobbyId: 'lobby-1',
            currentLobby: lobby,
            currentGame: const {'name': 'Warzone', 'maxSpots': 4},
            gameLobbySpots: {
              'Warzone': ['u1', null, null, null],
            },
          ),
        ),
        isFalse,
      );
    });

    test('peacock card empty / offline copy is arm length', () {
      expect(
        lobbySurfaceMessage(
          LobbySurfaceKind.peacockCard,
          LobbySurfacePhase.empty,
        ),
        'No active lobby',
      );
      expect(
        lobbySurfaceHint(
          LobbySurfaceKind.peacockCard,
          LobbySurfacePhase.empty,
        ),
        kPeacockCardEmptyHint,
      );
      expect(
        lobbySurfaceMessage(
          LobbySurfaceKind.peacockCard,
          LobbySurfacePhase.error,
          isOffline: true,
        ),
        kLobbySurfaceOfflineCopy,
      );
      expect(
        lobbySurfaceKey(
          LobbySurfaceKind.peacockCard,
          LobbySurfacePhase.empty,
        ),
        const Key('peacock-card-empty'),
      );
      expect(
        lobbySurfaceRetryKey(LobbySurfaceKind.peacockCard),
        const Key('peacock-card-retry'),
      );
    });
  });

  group('resolveLobbySurfacePhase', () {
    test('in-flight with no error is loading, not a settled empty', () {
      expect(
        resolveLobbySurfacePhase(isLoading: true, isEmpty: true),
        LobbySurfacePhase.loading,
      );
    });

    test('never-settled idle is empty, not a dead spinner', () {
      expect(
        resolveLobbySurfacePhase(isLoading: false, isEmpty: true),
        LobbySurfacePhase.empty,
      );
    });

    test('error with no lobby is error', () {
      expect(
        resolveLobbySurfacePhase(
          isLoading: false,
          error: 'denied',
          isEmpty: true,
        ),
        LobbySurfacePhase.error,
      );
    });

    test('offline with no lobby is error, not empty', () {
      expect(
        resolveLobbySurfacePhase(
          isLoading: false,
          isEmpty: true,
          isOffline: true,
        ),
        LobbySurfacePhase.error,
      );
      expect(
        resolveLobbySurfacePhase(
          isLoading: true,
          isEmpty: true,
          isOffline: true,
        ),
        LobbySurfacePhase.error,
      );
    });

    test('load failure wins over a hung spinner', () {
      expect(
        resolveLobbySurfacePhase(
          isLoading: true,
          error: 'timeout',
        ),
        LobbySurfacePhase.error,
      );
    });
  });

  group('lobbySurfacePhaseFromAsync', () {
    Lobby _lobby() => Lobby.create(
          name: 'Squad',
          gameName: 'Warzone',
          maxSpots: 4,
          createdBy: 'u1',
        ).copyWith(id: 'lobby-1');

    test('loading with no value is loading, not empty', () {
      expect(
        lobbySurfacePhaseFromAsync(
          const AsyncLoading<LobbyState>(),
          isEmpty: tonightLobbyMissing,
        ),
        LobbySurfacePhase.loading,
      );
    });

    test('settled lobby without an id is empty', () {
      expect(
        lobbySurfacePhaseFromAsync(
          AsyncData(LobbyState.initial()),
          isEmpty: tonightLobbyMissing,
        ),
        LobbySurfacePhase.empty,
      );
    });

    test('offline with no lobby is error, not empty', () {
      expect(
        lobbySurfacePhaseFromAsync(
          AsyncError<LobbyState>('offline', StackTrace.empty),
          isEmpty: tonightLobbyMissing,
        ),
        LobbySurfacePhase.error,
      );
      expect(
        lobbySurfacePhaseFromAsync(
          AsyncData(LobbyState.initial()),
          isEmpty: tonightLobbyMissing,
          isOffline: true,
        ),
        LobbySurfacePhase.error,
      );
    });

    test('cached lobby stays data when offline, not empty', () {
      expect(
        lobbySurfacePhaseFromAsync(
          AsyncData(
            LobbyState.initial().copyWith(
              selectedLobbyId: 'lobby-1',
              currentLobby: _lobby(),
            ),
          ),
          isEmpty: tonightLobbyMissing,
          isOffline: true,
        ),
        LobbySurfacePhase.data,
      );
    });

    test('lobbySurfaceIsOfflineError matches network drops', () {
      expect(lobbySurfaceIsOfflineError('offline'), isTrue);
      expect(
        lobbySurfaceIsOfflineError(
            Exception('SocketException: Failed host lookup')),
        isTrue,
      );
      expect(lobbySurfaceIsOfflineError('denied'), isFalse);
      expect(lobbySurfaceIsOfflineError(null), isFalse);
    });
  });

  group('peacock / LFG chips', () {
    testWidgets('empty idle chip when there is no seat status', (tester) async {
      await tester.pumpWidget(
        _wrap(const LobbySeatStatusChipSurface()),
      );

      expect(find.byKey(const Key('peacock-chip-empty')), findsOneWidget);
      expect(find.text('Idle'), findsOneWidget);
      expect(find.byKey(const Key('lobby-seat-status-chip')), findsNothing);
    });

    testWidgets('loading chip while lobby AsyncValue is loading',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const LobbySeatStatusChipSurface(isLoading: true)),
      );

      expect(find.byKey(const Key('peacock-chip-loading')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('peacock-chip-empty')), findsNothing);
      expect(find.byKey(const Key('lobby-seat-status-chip')), findsNothing);
    });

    testWidgets('error chip when lobby seat status fails', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          LobbySeatStatusChipSurface(
            error: 'timeout',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.byKey(const Key('peacock-chip-error')), findsOneWidget);
      expect(find.text("Couldn't load seat"), findsOneWidget);
      expect(find.text(kLobbySurfaceRetryLabel), findsOneWidget);
      expect(find.byKey(const Key('peacock-chip-retry')), findsOneWidget);
      expect(find.byKey(const Key('lobby-seat-status-chip')), findsNothing);

      await tester.tap(find.byKey(const Key('peacock-chip-retry')));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('data chip still shows peacock', (tester) async {
      await tester.pumpWidget(
        _wrap(LobbySeatStatusChipSurface(status: _peacockStatus())),
      );

      expect(find.byKey(const Key('lobby-seat-status-chip')), findsOneWidget);
      expect(find.text('peacock'), findsOneWidget);
      expect(find.byKey(const Key('peacock-chip-empty')), findsNothing);
    });
  });

  group('lock UI', () {
    testWidgets('empty Not locked when teammate is seated and not ready',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SeatedSpotReadyAffordance(
            isReady: false,
            isLocked: false,
            isOwnSeat: false,
          ),
        ),
      );

      expect(find.byKey(const Key('lock-empty')), findsOneWidget);
      expect(find.text('Not locked'), findsOneWidget);
      expect(find.byKey(const Key('seated-spot-locked-badge')), findsNothing);
      expect(find.byKey(const Key('seated-spot-ready-button')), findsNothing);
    });

    testWidgets('loading lock while lobby AsyncValue is loading',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SeatedSpotReadyAffordance(
            isReady: false,
            isLocked: false,
            isLoading: true,
          ),
        ),
      );

      expect(find.byKey(const Key('lock-loading')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('lock-empty')), findsNothing);
      expect(find.byKey(const Key('seated-spot-locked-badge')), findsNothing);
    });

    testWidgets('error lock when ready/lock state fails', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          SeatedSpotReadyAffordance(
            isReady: false,
            isLocked: false,
            error: 'denied',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.byKey(const Key('lock-error')), findsOneWidget);
      expect(find.text("Couldn't load lock"), findsOneWidget);
      expect(find.text(kLobbySurfaceRetryLabel), findsOneWidget);
      expect(find.byKey(const Key('lock-retry')), findsOneWidget);
      expect(find.byKey(const Key('seated-spot-locked-badge')), findsNothing);

      await tester.tap(find.byKey(const Key('lock-retry')));
      await tester.pump();
      expect(retried, isTrue);
    });
  });
}
