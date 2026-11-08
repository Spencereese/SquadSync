import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/screens/components/chat_info_actions.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_controls.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_grid.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';
import 'package:squad_sync/widgets/lobby_surface_feedback.dart';

/// Slice J reds: persist fail stays on the seat map + Tonight strip as a
/// slim banner (not a SnackBar). Copy is "Seat didn't save" + Retry.
/// Retry calls [LobbyNotifier.retrySeatWrite]; success dismisses, fail keeps.
///
/// Loop wires [lastSeatWriteError] (already on the notifier) into
/// [LobbyGrid] / [TonightActionsBlock]. Do not put this on SnackBar or
/// [tonight-retry] load-failure chrome.
const kSeatWriteErrorCopy = "Seat didn't save";
const kSeatWriteErrorBannerKey = Key('seat-write-error-banner');
const kSeatWriteRetryKey = Key('seat-write-retry');
const kSeatMapSeatWriteErrorKey = Key('seat-map-seat-write-error');
const kTonightSeatWriteErrorKey = Key('tonight-seat-write-error');

LobbyState _tonightLobbyState() {
  final lobby = Lobby.create(
    name: 'Tonight',
    gameName: 'Warzone',
    maxSpots: 4,
    createdBy: 'u1',
  ).copyWith(
    id: 'lobby-9',
    memberUids: const ['u1', 'u2'],
    spots: const ['u1', null, null, null],
    chatGroupId: 'chat-9',
  );
  return LobbyState.initial().copyWith(
    selectedLobbyId: 'lobby-9',
    currentLobby: lobby,
    currentGame: const {'name': 'Warzone', 'maxSpots': 4},
    gameLobbySpots: {
      'Warzone': ['u1', null, null, null],
    },
    memberDisplayNames: const {'u1': 'Alice'},
  );
}

class _SeatWriteHarnessNotifier extends LobbyNotifier {
  _SeatWriteHarnessNotifier({
    this.seedError,
    this.clearErrorOnRetry = true,
  });

  final Object? seedError;
  final bool clearErrorOnRetry;
  int retryCalls = 0;

  @override
  Future<LobbyState> build() async {
    lastSeatWriteError = seedError;
    return _tonightLobbyState();
  }

  @override
  Future<void> retrySeatWrite() async {
    retryCalls++;
    if (clearErrorOnRetry) {
      lastSeatWriteError = null;
    }
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current);
    }
  }
}

Finder _bannerOn(Finder surface) {
  return find.descendant(
    of: surface,
    matching: find.text(kSeatWriteErrorCopy),
  );
}

Finder _retryOn(Finder surface) {
  final keyed = find.descendant(
    of: surface,
    matching: find.byKey(kSeatWriteRetryKey),
  );
  if (keyed.evaluate().isNotEmpty) return keyed;
  return find.descendant(
    of: surface,
    matching: find.text(kLobbySurfaceRetryLabel),
  );
}

Future<void> _pumpSeatAndTonight(
  WidgetTester tester,
  _SeatWriteHarnessNotifier Function() create,
) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lobbyNotifierProvider.overrideWith(create),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              LobbyGrid(),
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

void _expectPersistentBanner({required Matcher matcher}) {
  expect(find.byKey(kSeatWriteErrorBannerKey), matcher);
  expect(find.text(kSeatWriteErrorCopy), matcher);
  expect(find.byType(SnackBar), findsNothing);
}

void main() {
  setUp(() {
    MatchmakingQueueTracker.resetInstance();
  });

  tearDown(() {
    MatchmakingQueueTracker.resetInstance();
  });

  testWidgets(
      'banner visible on seat map and Tonight when lastSeatWriteError is set',
      (tester) async {
    final notifier = _SeatWriteHarnessNotifier(
      seedError: Exception('persist failed'),
    );
    await _pumpSeatAndTonight(tester, () => notifier);

    expect(notifier.lastSeatWriteError, isNotNull);
    expect(find.byType(LobbyGrid), findsOneWidget);
    expect(find.byType(TonightActionsBlock), findsOneWidget);
    expect(find.byKey(const Key('tonight-actions')), findsOneWidget);
    expect(find.byKey(const Key('spot-map-seat-filled')), findsOneWidget);

    _expectPersistentBanner(matcher: findsWidgets);
    expect(_bannerOn(find.byType(LobbyGrid)), findsOneWidget);
    expect(_bannerOn(find.byType(TonightActionsBlock)), findsOneWidget);
    expect(find.byKey(kSeatMapSeatWriteErrorKey), findsOneWidget);
    expect(find.byKey(kTonightSeatWriteErrorKey), findsOneWidget);
    expect(find.byKey(kSeatWriteRetryKey), findsWidgets);
    expect(find.text(kLobbySurfaceRetryLabel), findsWidgets);
    expect(find.byKey(const Key('tonight-retry')), findsNothing);
    expect(find.byKey(const Key('tonight-error')), findsNothing);
  });

  testWidgets('banner hidden when lastSeatWriteError is null', (tester) async {
    final notifier = _SeatWriteHarnessNotifier();
    await _pumpSeatAndTonight(tester, () => notifier);

    expect(notifier.lastSeatWriteError, isNull);
    expect(find.byType(LobbyGrid), findsOneWidget);
    expect(find.byType(TonightActionsBlock), findsOneWidget);
    expect(find.text('Tonight'), findsOneWidget);

    expect(find.text(kSeatWriteErrorCopy), findsNothing);
    expect(find.byKey(kSeatWriteErrorBannerKey), findsNothing);
    expect(find.byKey(kSeatWriteRetryKey), findsNothing);
    expect(find.byKey(kSeatMapSeatWriteErrorKey), findsNothing);
    expect(find.byKey(kTonightSeatWriteErrorKey), findsNothing);
    expect(_bannerOn(find.byType(LobbyGrid)), findsNothing);
    expect(_bannerOn(find.byType(TonightActionsBlock)), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('tap Retry calls retrySeatWrite and success dismisses the banner',
      (tester) async {
    final notifier = _SeatWriteHarnessNotifier(
      seedError: Exception('persist failed'),
    );
    await _pumpSeatAndTonight(tester, () => notifier);

    expect(find.text(kSeatWriteErrorCopy), findsWidgets);
    expect(notifier.retryCalls, 0);

    await tester.tap(_retryOn(find.byType(LobbyGrid)));
    await tester.pump();
    await tester.pump();

    expect(notifier.retryCalls, 1);
    expect(notifier.lastSeatWriteError, isNull);
    expect(find.text(kSeatWriteErrorCopy), findsNothing);
    expect(find.byKey(kSeatWriteErrorBannerKey), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('failed retry keeps the Seat didn\'t save banner', (tester) async {
    final notifier = _SeatWriteHarnessNotifier(
      seedError: Exception('persist failed'),
      clearErrorOnRetry: false,
    );
    await _pumpSeatAndTonight(tester, () => notifier);

    await tester.tap(_retryOn(find.byType(TonightActionsBlock)));
    await tester.pump();
    await tester.pump();

    expect(notifier.retryCalls, 1);
    expect(notifier.lastSeatWriteError, isNotNull);
    expect(find.text(kSeatWriteErrorCopy), findsWidgets);
    expect(_bannerOn(find.byType(LobbyGrid)), findsOneWidget);
    expect(_bannerOn(find.byType(TonightActionsBlock)), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
