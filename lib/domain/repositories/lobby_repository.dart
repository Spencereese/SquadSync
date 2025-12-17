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

  // Match history
  Future<void> recordMatchResult({
    required String lobbyId,
    required String gameName,
    required String result,
    required List<String> playerUids,
    String? notes,
  });
  Future<Map<String, dynamic>> getLobbyStats(String lobbyId);

  // Invite management
  Future<void> createInvite(Map<String, dynamic> inviteData);

  // Peacock management
  Future<void> createPeacock(Map<String, dynamic> peacockData);
  Future<void> updateUserPeacock(
      String userId, Map<String, dynamic> peacockStatus);

  // Real-time streams
  Stream<Lobby?> getLobbyStream(String lobbyId);
  Stream<List<Lobby>> getUserLobbiesStream(String userId);
  Stream<List<Lobby>> getPublicLobbiesStream({
    bool? isActive,
    String? gameFocus,
    int limit,
    String orderBy,
    bool ascending,
  });
}
