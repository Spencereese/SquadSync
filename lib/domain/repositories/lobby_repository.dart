import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';

abstract class LobbyRepository {
  // Lobby lifecycle
  Future<Lobby> createLobby(String name, String gameName, int maxSpots);
  Future<Lobby?> getLobby(String lobbyId);
  Future<Lobby?> getLobbyByInviteCode(String inviteCode);
  Future<List<Lobby>> getUserLobbies(String userId);
  Future<void> deleteLobby(String lobbyId);

  // Lobby membership
  Future<void> joinLobby(String lobbyId, String userId);
  Future<void> leaveLobby(String lobbyId, String userId);
  Future<void> kickMember(String lobbyId, String memberId, String kickedBy);

  // Spot management
  Future<void> assignSpot(String lobbyId, int spotIndex, String? userId);
  Future<void> startSpotTimer(String lobbyId, int spotIndex, Duration duration);
  Future<void> cancelSpotTimer(String lobbyId, int spotIndex);

  // Timer processing (hybrid client-server)
  Future<void> processExpiredTimers();
  Stream<Map<String, Duration>> getSpotTimerStates(String lobbyId);
  Stream<Map<String, Duration>> getPeacockTimerStates();

  // Peacock queue management
  Future<void> addToPeacockQueue(String userId, String gameName);
  Future<void> removeFromPeacockQueue(String userId);
  Future<void> processPeacockQueue();

  // Member status
  Future<void> updateMemberStatus(String lobbyId, String userId, String status);
  Future<void> updateGlobalStatus(String userId, String status);

  // State management
  Future<LobbyState> loadLobbyState();
  Future<void> saveLobbyState(LobbyState state);

  // Sync and persistence
  Future<void> syncLobbyData();
  Future<void> purgeOldData();

  // Analytics
  Future<void> trackLobbyEvent(String event, Map<String, dynamic> data);
}
