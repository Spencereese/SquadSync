import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:squad_sync/domain/entities/lobby.dart';

part 'lobby_state.freezed.dart';
part 'lobby_state.g.dart';

@freezed
class LobbyState with _$LobbyState {
  const factory LobbyState({
    required bool isInitialized,
    required bool isInitialDataLoaded,
    required String displayName,
    String? profileImage,
    Map<String, String?>? memberProfileImages,

    // Game-specific data
    required Map<String, List<String?>> gameLobbySpots,
    required Map<String, List<Map<String, dynamic>?>> gameSpotTimers,
    required Map<String, Map<String, String>> gameStatuses,
    required Map<String, String> globalStatuses,

    // Lobby data
    required List<String> lobbyMemberUids,
    required Map<String, String> memberDisplayNames,
    required List<String> userLobbyIds,
    String? selectedLobbyId,
    required Map<String, Lobby> userLobbies,
    Map<String, dynamic>? currentLobbyData,

    // UI state
    required Map<String, bool> typing,
    required bool tiltEnabled,
    required bool hasNewLobbySpot,
    required bool hasUnreadMessages,

    // Game data
    required List<Map<String, dynamic>> gameHistory,
    required Map<String, String?> preferredModes,
    required Map<String, Map<String, bool>> userBlocks,
    required Map<String, Map<String, int>> dailyBanVotes,
    required Map<String, List<Map<String, dynamic>>> bans,
    required List<Map<String, dynamic>> availableGames,
    required Map<String, List<Map<String, dynamic>>> gameLobbies,
    required Set<String> preferredPeacockGames,
    required Set<String> mutedGames,
    required Set<String> hiddenGames,
    required Map<String, Map<String, dynamic>?> peacockTimers,
    required List<String> peacockQueue,
    required List<Map<String, dynamic>> scheduledTimes,
    required bool hasNewAvailability,

    // Current game
    Map<String, dynamic>? currentGame,

    // Timer states
    required Map<String, Duration> spotTimerStates,
    required Map<String, Duration> peacockTimerStates,

    // Ratings
    required Map<String, Map<String, int>> dailyRatings,
    required Map<String, Map<String, int>> allTimeRatings,
    required Map<String, dynamic> analyticsMetrics,

    // Analytics and tracking
    required DateTime lastSyncTimestamp,
  }) = _LobbyState;

  factory LobbyState.fromJson(Map<String, dynamic> json) =>
      _$LobbyStateFromJson(json);

  factory LobbyState.initial() => LobbyState(
        isInitialized: true,
        isInitialDataLoaded: true,
        displayName: 'Unknown User',
        memberProfileImages: {},
        gameLobbySpots: {},
        gameSpotTimers: {},
        gameStatuses: {},
        globalStatuses: {},
        lobbyMemberUids: [],
        memberDisplayNames: {},
        userLobbyIds: [],
        userLobbies: {},
        typing: {},
        tiltEnabled: false,
        hasNewLobbySpot: false,
        hasUnreadMessages: false,
        gameHistory: [],
        preferredModes: {},
        userBlocks: {},
        dailyBanVotes: {},
        bans: {},
        availableGames: [],
        gameLobbies: {},
        preferredPeacockGames: {},
        mutedGames: {},
        hiddenGames: {},
        peacockTimers: {},
        peacockQueue: [],
        scheduledTimes: [],
        hasNewAvailability: false,
        spotTimerStates: {},
        peacockTimerStates: {},
        dailyRatings: {},
        allTimeRatings: {},
        lastSyncTimestamp: DateTime.now(),
        analyticsMetrics: {},
      );
}

extension LobbyStateExtension on LobbyState {
  bool canRateMember(String player) {
    // TODO: Implement logic to check if player can be rated
    // For now, allow rating if player is in lobby
    return lobbyMemberUids.contains(player);
  }

  Future<void> submitRatings(String player, Map<String, int> ratings) async {
    // TODO: Implement submit ratings using usecase
    // For now, stub
  }
}
