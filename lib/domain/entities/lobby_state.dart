import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:squad_sync/domain/entities/lobby.dart';

part 'lobby_state.freezed.dart';
part 'lobby_state.g.dart';

/// Unified LobbyState with sub-states for spots/timers/peacock, current lobby, and memberships
@freezed // Disable DiagnosticableTreeMixin - has bugs in Freezed 3.0
class LobbyState with _$LobbyState {
  const factory LobbyState({
    required bool isInitialized,
    required bool isInitialDataLoaded,
    required String displayName,
    String? profileImage,

    // Spots, timers, and peacock queue (from LobbyNotifier)
    required Map<String, List<String?>> gameLobbySpots,
    required Map<String, List<Map<String, dynamic>?>> gameSpotTimers,
    required Map<String, Map<String, String>> gameStatuses,
    required Map<String, String> globalStatuses,
    required List<String> peacockQueue,
    required Map<String, Map<String, dynamic>?> peacockTimers,
    required Map<String, Duration> peacockTimerStates,
    required Set<String> preferredPeacockGames,
    required Map<String, Duration> spotTimerStates,

    // Current lobby tracking (from CurrentLobbyNotifier)
    String? selectedLobbyId,
    Lobby? currentLobby,
    Map<String, dynamic>? currentLobbyData,
    Map<String, dynamic>? currentGame,

    // User's lobby memberships (from UserSquadsNotifier concept)
    required List<String> userLobbyIds,
    required Map<String, Lobby> userLobbies,
    required List<String> lobbyMemberUids,
    required Map<String, String> memberDisplayNames,
    Map<String, String?>? memberProfileImages,

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
    required Set<String> mutedGames,
    required Set<String> hiddenGames,
    required List<Map<String, dynamic>> scheduledTimes,
    required bool hasNewAvailability,

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
