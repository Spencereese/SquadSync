import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';

/// One-row seat write. Optimistic patch first; Realtime stays source of truth.
enum LobbySeatWriteKind {
  assignSpot,
  joinLobby,
  leaveSquad,
  startSpotTimer,
  clearAllSpots,
  callSpotForGame,
  processExpiredTimers,
}

class LobbySeatWrite {
  const LobbySeatWrite({
    required this.kind,
    required this.lobbyId,
    this.spotIndex,
    this.userId,
    this.duration,
  });

  final LobbySeatWriteKind kind;
  final String lobbyId;
  final int? spotIndex;
  final String? userId;
  final Duration? duration;
}

bool _isExpiredRemaining(Map<String, dynamic> timer) {
  final remaining = timer['remaining'];
  return remaining is num && remaining <= 0;
}

/// Patch [lobby] for a seat write. Never wipes a seat just claimed.
Lobby applySeatWriteToLobby(Lobby lobby, LobbySeatWrite write) {
  if (lobby.id != write.lobbyId) return lobby;
  switch (write.kind) {
    case LobbySeatWriteKind.assignSpot:
      final index = write.spotIndex ?? 0;
      final spots = List<String?>.from(lobby.spots);
      while (spots.length <= index) {
        spots.add(null);
      }
      spots[index] = write.userId;
      return lobby.copyWith(spots: spots);
    case LobbySeatWriteKind.joinLobby:
      final uid = write.userId;
      if (uid == null || uid.isEmpty || lobby.memberUids.contains(uid)) {
        return lobby;
      }
      return lobby.copyWith(memberUids: [...lobby.memberUids, uid]);
    case LobbySeatWriteKind.leaveSquad:
      final uid = write.userId;
      if (uid == null || uid.isEmpty) return lobby;
      return lobby.copyWith(
        memberUids: [
          for (final member in lobby.memberUids)
            if (member != uid) member,
        ],
      );
    case LobbySeatWriteKind.startSpotTimer:
      final index = write.spotIndex ?? 0;
      final duration = write.duration ?? Duration.zero;
      final timers = List<Map<String, dynamic>?>.from(lobby.spotTimers);
      while (timers.length <= index) {
        timers.add(null);
      }
      timers[index] = <String, dynamic>{
        'start_time': DateTime.now().toIso8601String(),
        'duration': duration.inSeconds,
        'spot_index': index,
      };
      return lobby.copyWith(spotTimers: timers);
    case LobbySeatWriteKind.clearAllSpots:
      return lobby.copyWith(
        spots: List<String?>.filled(lobby.spots.length, null),
      );
    case LobbySeatWriteKind.callSpotForGame:
      final assigned = applySeatWriteToLobby(
        lobby,
        LobbySeatWrite(
          kind: LobbySeatWriteKind.assignSpot,
          lobbyId: write.lobbyId,
          spotIndex: write.spotIndex,
          userId: write.userId,
        ),
      );
      return applySeatWriteToLobby(
        assigned,
        LobbySeatWrite(
          kind: LobbySeatWriteKind.startSpotTimer,
          lobbyId: write.lobbyId,
          spotIndex: write.spotIndex,
          duration: write.duration,
        ),
      );
    case LobbySeatWriteKind.processExpiredTimers:
      final spots = List<String?>.from(lobby.spots);
      final timers = List<Map<String, dynamic>?>.from(lobby.spotTimers);
      final count = spots.length > timers.length ? spots.length : timers.length;
      while (spots.length < count) {
        spots.add(null);
      }
      while (timers.length < count) {
        timers.add(null);
      }
      for (var i = 0; i < timers.length; i++) {
        final timer = timers[i];
        if (timer == null) continue;
        // Free only remaining:0 seats — do not infer expiry from start_time.
        if (_isExpiredRemaining(timer)) {
          spots[i] = null;
          timers[i] = null;
        }
      }
      return lobby.copyWith(spots: spots, spotTimers: timers);
  }
}

/// Overlay the seat write onto [state.currentLobby] and the matching
/// game spot / timer / member mirrors used by Ready-lock.
LobbyState applySeatWriteToState(LobbyState state, LobbySeatWrite write) {
  final lobby = state.currentLobby;
  if (lobby == null || lobby.id != write.lobbyId) return state;
  final nextLobby = applySeatWriteToLobby(lobby, write);
  var next = state.copyWith(currentLobby: nextLobby);
  final game = nextLobby.gameName;
  switch (write.kind) {
    case LobbySeatWriteKind.assignSpot:
    case LobbySeatWriteKind.clearAllSpots:
      if (game.isNotEmpty) {
        final spots = Map<String, List<String?>>.from(state.gameLobbySpots);
        spots[game] = nextLobby.spots;
        next = next.copyWith(gameLobbySpots: spots);
      }
      break;
    case LobbySeatWriteKind.startSpotTimer:
      if (game.isNotEmpty) {
        final timers = Map<String, List<Map<String, dynamic>?>>.from(
          state.gameSpotTimers,
        );
        timers[game] = nextLobby.spotTimers;
        next = next.copyWith(gameSpotTimers: timers);
      }
      break;
    case LobbySeatWriteKind.callSpotForGame:
    case LobbySeatWriteKind.processExpiredTimers:
      if (game.isNotEmpty) {
        final spots = Map<String, List<String?>>.from(state.gameLobbySpots);
        spots[game] = nextLobby.spots;
        final timers = Map<String, List<Map<String, dynamic>?>>.from(
          state.gameSpotTimers,
        );
        timers[game] = nextLobby.spotTimers;
        next = next.copyWith(gameLobbySpots: spots, gameSpotTimers: timers);
      }
      break;
    case LobbySeatWriteKind.joinLobby:
    case LobbySeatWriteKind.leaveSquad:
      next = next.copyWith(lobbyMemberUids: nextLobby.memberUids);
      break;
  }
  return next;
}
