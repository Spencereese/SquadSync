import 'dart:async';
import 'package:squad_sync/data/datasources/lobby_local_datasource.dart';
import 'package:squad_sync/data/datasources/lobby_remote_datasource.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/domain/repositories/lobby_repository.dart';

class LobbyRepositoryImpl implements LobbyRepository {
  final LobbyLocalDataSource _localDataSource;
  final LobbyRemoteDataSource _remoteDataSource;

  LobbyRepositoryImpl(this._localDataSource, this._remoteDataSource);

  @override
  Future<Lobby> createLobby(String name, String gameName, int maxSpots) async {
    final userId = 'current_user_id'; // This would come from auth service
    final lobby = Lobby.create(
      name: name,
      gameName: gameName,
      maxSpots: maxSpots,
      createdBy: userId,
    );

    // Save to remote first
    final createdLobby = await _remoteDataSource.createLobby(squad);

    // Cache locally
    await _localDataSource.saveSquad(createdSquad);

    return createdLobby;
  }

  @override
  Future<Lobby?> getLobby(String lobbyId) async {
    // Try local cache first
    final localSquad = await _localDataSource.getLobby(lobbyId);
    if (localSquad != null) {
      return localSquad;
    }

    // Fetch from remote
    final remoteSquad = await _remoteDataSource.getLobby(lobbyId);
    if (remoteSquad != null) {
      await _localDataSource.saveSquad(remoteSquad);
    }

    return remoteSquad;
  }

  @override
  Future<Lobby?> getLobbyByInviteCode(String inviteCode) async {
    // Fetch from remote (invite codes are not cached locally typically)
    return await _remoteDataSource.getLobbyByInviteCode(inviteCode);
  }

  @override
  Future<List<Lobby>> getUserLobbies(String userId) async {
    // Try local cache first
    final localSquads = await _localDataSource.getUserLobbies(userId);
    if (localSquads.isNotEmpty) {
      return localSquads;
    }

    // Fetch from remote
    final remoteSquads = await _remoteDataSource.getUserLobbies(userId);

    // Cache locally
    for (final squad in remoteSquads) {
      await _localDataSource.saveSquad(squad);
    }

    return remoteSquads;
  }

  @override
  Future<void> deleteLobby(String lobbyId) async {
    await _remoteDataSource.deleteLobby(lobbyId);
    await _localDataSource.deleteLobby(lobbyId);
  }

  @override
  Future<void> joinLobby(String lobbyId, String userId) async {
    await _remoteDataSource.joinLobby(lobbyId, userId);
    // Local cache will be updated via sync
  }

  @override
  Future<void> leaveLobby(String lobbyId, String userId) async {
    await _remoteDataSource.leaveLobby(lobbyId, userId);
    // Local cache will be updated via sync
  }

  @override
  Future<void> kickMember(
      String lobbyId, String memberId, String kickedBy) async {
    await _remoteDataSource.kickMember(lobbyId, memberId, kickedBy);
  }

  @override
  Future<void> assignSpot(String lobbyId, int spotIndex, String? userId) async {
    await _remoteDataSource.assignSpot(lobbyId, spotIndex, userId);
  }

  @override
  Future<void> startSpotTimer(
      String lobbyId, int spotIndex, Duration duration) async {
    await _remoteDataSource.startSpotTimer(lobbyId, spotIndex, duration);
  }

  @override
  Future<void> cancelSpotTimer(String lobbyId, int spotIndex) async {
    await _remoteDataSource.cancelSpotTimer(lobbyId, spotIndex);
  }

  @override
  Future<void> processExpiredTimers() async {
    await _remoteDataSource.processExpiredTimers();
  }

  @override
  Stream<Map<String, Duration>> getSpotTimerStates(String lobbyId) {
    // This would combine local timer calculations with remote updates
    // For now, return empty stream
    return Stream.value({});
  }

  @override
  Stream<Map<String, Duration>> getPeacockTimerStates() {
    // This would track peacock queue timers
    return Stream.value({});
  }

  @override
  Future<void> addToPeacockQueue(String userId, String gameName) async {
    // This would be implemented with proper queue management
    // For now, just track the event
    await _remoteDataSource.trackLobbyEvent('peacock_queue_joined', {
      'userId': userId,
      'gameName': gameName,
    });
  }

  @override
  Future<void> removeFromPeacockQueue(String userId) async {
    await _remoteDataSource.trackLobbyEvent('peacock_queue_left', {
      'userId': userId,
    });
  }

  @override
  Future<void> processPeacockQueue() async {
    // Queue processing logic would go here
  }

  @override
  Future<void> updateMemberStatus(
      String lobbyId, String userId, String status) async {
    // Update in remote (this would be a more complex operation)
    // For now, just track the event
    await _remoteDataSource.trackLobbyEvent('status_updated', {
      'lobbyId': lobbyId,
      'userId': userId,
      'status': status,
    });
  }

  @override
  Future<void> updateGlobalStatus(String userId, String status) async {
    await _remoteDataSource.trackLobbyEvent('global_status_updated', {
      'userId': userId,
      'status': status,
    });
  }

  @override
  Future<LobbyState> loadLobbyState() async {
    final state = await _localDataSource.loadLobbyState();
    return state ?? LobbyState.initial();
  }

  @override
  Future<void> saveLobbyState(LobbyState state) async {
    await _localDataSource.saveLobbyState(state);
  }

  @override
  Future<void> syncLobbyData() async {
    // Implement delta sync with conflict resolution
    // This is a complex operation that would compare timestamps and UIDs
  }

  @override
  Future<void> purgeOldData() async {
    await _localDataSource.purgeOldData();
  }

  @override
  Future<void> trackLobbyEvent(String event, Map<String, dynamic> data) async {
    await _remoteDataSource.trackLobbyEvent(event, data);
  }
}
