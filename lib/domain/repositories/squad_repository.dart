import 'package:squad_sync/domain/entities/squad.dart';
import 'package:squad_sync/domain/entities/squad_state.dart';

abstract class SquadRepository {
  // Squad lifecycle
  Future<Squad> createSquad(String name, String gameName, int maxSpots);
  Future<Squad?> getSquad(String squadId);
  Future<Squad?> getSquadByInviteCode(String inviteCode);
  Future<List<Squad>> getUserSquads(String userId);
  Future<void> deleteSquad(String squadId);

  // Squad membership
  Future<void> joinSquad(String squadId, String userId);
  Future<void> leaveSquad(String squadId, String userId);
  Future<void> kickMember(String squadId, String memberId, String kickedBy);

  // Spot management
  Future<void> assignSpot(String squadId, int spotIndex, String? userId);
  Future<void> startSpotTimer(String squadId, int spotIndex, Duration duration);
  Future<void> cancelSpotTimer(String squadId, int spotIndex);

  // Timer processing (hybrid client-server)
  Future<void> processExpiredTimers();
  Stream<Map<String, Duration>> getSpotTimerStates(String squadId);
  Stream<Map<String, Duration>> getPeacockTimerStates();

  // Peacock queue management
  Future<void> addToPeacockQueue(String userId, String gameName);
  Future<void> removeFromPeacockQueue(String userId);
  Future<void> processPeacockQueue();

  // Member status
  Future<void> updateMemberStatus(String squadId, String userId, String status);
  Future<void> updateGlobalStatus(String userId, String status);

  // State management
  Future<SquadState> loadSquadState();
  Future<void> saveSquadState(SquadState state);

  // Sync and persistence
  Future<void> syncSquadData();
  Future<void> purgeOldData();

  // Analytics
  Future<void> trackSquadEvent(String event, Map<String, dynamic> data);
}
