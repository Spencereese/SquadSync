import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/widgets/peacock_card.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/core/notification_routes.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/widgets/lobby_surface_feedback.dart';

void main() {
  const lobbyId = 'lobby-9';
  const game = 'Warzone';
  const spotIndex = 2;
  const highlighted = '/squad/Warzone?lobby_id=lobby-9&spot_index=2';

  LobbyState filled({
    String id = lobbyId,
    String gameName = game,
    List<String?> spots = const ['u1', null, null, null],
  }) {
    final lobby = Lobby.create(
      name: 'Squad',
      gameName: gameName,
      maxSpots: 4,
      createdBy: 'u1',
    ).copyWith(id: id);
    return LobbyState.initial().copyWith(
      selectedLobbyId: id,
      currentLobby: lobby,
      currentGame: {'name': gameName, 'maxSpots': 4},
      gameLobbySpots: {gameName: spots},
    );
  }

  group('peacock card same-router as notification path', () {
    test('card URL, payload, and tap share NotificationRoutes location', () {
      final fromCard = locationForDeepLink(
        peacockCardDeepLink(
          lobbyId: lobbyId,
          gameName: game,
          spotIndex: spotIndex,
        ),
      );
      final fromNotify = NotificationRoutes.locationFor(
        peacockCardNotificationPayload(
          lobbyId: lobbyId,
          gameName: game,
          spotIndex: spotIndex,
        ),
      );
      expect(fromCard, highlighted);
      expect(fromNotify, highlighted);
      expect(fromCard, fromNotify);

      String? opened;
      openPeacockCard(
        lobbyId: lobbyId,
        gameName: game,
        spotIndex: spotIndex,
        go: (location) => opened = location,
      );
      expect(opened, highlighted);
      expect(
        opened,
        NotificationRoutes.locationFor({
          'type': 'peacock_assigned',
          'lobby_id': lobbyId,
          'game_name': game,
          'spot_index': spotIndex,
        }),
      );
    });

    test('empty card tap is empty squad, same as missing-id notification', () {
      String? fromCard;
      openPeacockCard(go: (location) => fromCard = location);
      expect(fromCard, '/squad');
      expect(
        NotificationRoutes.locationFor({'type': 'peacock_assigned'}),
        '/squad',
      );
      expect(
        locationForDeepLink(peacockCardDeepLink()),
        NotificationRoutes.locationFor(peacockCardNotificationPayload()),
      );
    });

    test('offline card tap does not navigate', () {
      String? opened;
      openPeacockCard(
        lobbyId: lobbyId,
        gameName: game,
        spotIndex: spotIndex,
        isOffline: true,
        go: (location) => opened = location,
      );
      expect(opened, isNull);
    });
  });

  group('peacockCardMissing / snapshot', () {
    test('initial lobby is empty, not an error', () {
      expect(peacockCardMissing(null), isTrue);
      expect(peacockCardMissing(LobbyState.initial()), isTrue);
      expect(peacockCardSnapshot(LobbyState.initial()).claimed, 0);
      expect(peacockCardSnapshot(LobbyState.initial()).gameName, isNull);
    });

    test('lobby without claimed seats is empty', () {
      expect(
        peacockCardMissing(filled(spots: const [null, null, null, null])),
        isTrue,
      );
    });

    test('claimed seat is a filled card', () {
      final state = filled();
      expect(peacockCardMissing(state), isFalse);
      final snapshot = peacockCardSnapshot(state);
      expect(snapshot.lobbyId, lobbyId);
      expect(snapshot.gameName, game);
      expect(snapshot.claimed, 1);
      expect(snapshot.maxSpots, 4);
      expect(
        peacockCardTitle(gameName: game, claimed: 1, maxSpots: 4),
        'Your Active Lobby: Warzone - 1/4 spots',
      );
    });

    test('offline with missing lobby is error, not empty', () {
      expect(
        lobbySurfacePhaseFromAsync(
          AsyncError<LobbyState>(
            Exception('SocketException: Failed host lookup'),
            StackTrace.empty,
          ),
          isEmpty: peacockCardMissing,
        ),
        LobbySurfacePhase.error,
      );
      expect(
        lobbySurfacePhaseFromAsync(
          AsyncData(LobbyState.initial()),
          isEmpty: peacockCardMissing,
        ),
        LobbySurfacePhase.empty,
      );
    });
  });
}
