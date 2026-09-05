import 'package:flutter/material.dart';
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
    offerPending: true,
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
      expect(find.text("I'm on now"), findsNothing);
      expect(find.byKey(const Key('tonight-loading')), findsNothing);
      expect(find.byKey(const Key('tonight-error')), findsNothing);
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
      await tester.pumpWidget(
        _wrap(
          const TonightActionsBlock(
            error: 'offline',
            children: [],
          ),
        ),
      );

      expect(find.byKey(const Key('tonight-error')), findsOneWidget);
      expect(find.text("Couldn't load tonight: offline"), findsOneWidget);
      expect(find.byKey(const Key('tonight-empty')), findsNothing);
      expect(find.byKey(const Key('tonight-loading')), findsNothing);
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
  });

  group('peacock / LFG chips', () {
    testWidgets('empty idle chip when there is no seat status', (tester) async {
      await tester.pumpWidget(
        _wrap(const LobbySeatStatusChipSurface()),
      );

      expect(find.byKey(const Key('peacock-chip-empty')), findsOneWidget);
      expect(find.text('idle'), findsOneWidget);
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
      await tester.pumpWidget(
        _wrap(const LobbySeatStatusChipSurface(error: 'timeout')),
      );

      expect(find.byKey(const Key('peacock-chip-error')), findsOneWidget);
      expect(find.text("Couldn't load seat: timeout"), findsOneWidget);
      expect(find.byKey(const Key('lobby-seat-status-chip')), findsNothing);
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
      await tester.pumpWidget(
        _wrap(
          const SeatedSpotReadyAffordance(
            isReady: false,
            isLocked: false,
            error: 'denied',
          ),
        ),
      );

      expect(find.byKey(const Key('lock-error')), findsOneWidget);
      expect(find.text("Couldn't load lock: denied"), findsOneWidget);
      expect(find.byKey(const Key('seated-spot-locked-badge')), findsNothing);
    });
  });
}
