import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:squad_sync/domain/entities/squad.dart';

part 'squad_state.freezed.dart';
part 'squad_state.g.dart';

@freezed
class SquadState with _$SquadState {
  const factory SquadState({
    required bool isInitialized,
    required bool isInitialDataLoaded,
    required String displayName,
    String? profileImage,
    Map<String, String?>? memberProfileImages,

    // Game-specific data
    required Map<String, List<String?>> gameSquadSpots,
    required Map<String, List<Map<String, dynamic>?>> gameSpotTimers,
    required Map<String, Map<String, String>> gameStatuses,
    required Map<String, String> globalStatuses,

    // Squad data
    required List<String> squadMemberUids,
    required Map<String, String> memberDisplayNames,
    required List<String> userSquadIds,
    String? selectedSquadId,
    required Map<String, Squad> userSquads,
    Map<String, dynamic>? currentSquadData,

    // UI state
    required Map<String, bool> typing,
    required bool tiltEnabled,
    required bool hasNewSquadSpot,
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

    // Analytics and tracking
    required DateTime lastSyncTimestamp,
    required Map<String, dynamic> analyticsMetrics,
  }) = _SquadState;

  factory SquadState.fromJson(Map<String, dynamic> json) =>
      _$SquadStateFromJson(json);

  factory SquadState.initial() => SquadState(
        isInitialized: false,
        isInitialDataLoaded: false,
        displayName: 'Unknown User',
        memberProfileImages: {},
        gameSquadSpots: {},
        gameSpotTimers: {},
        gameStatuses: {},
        globalStatuses: {},
        squadMemberUids: [],
        memberDisplayNames: {},
        userSquadIds: [],
        userSquads: {},
        typing: {},
        tiltEnabled: false,
        hasNewSquadSpot: false,
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
        lastSyncTimestamp: DateTime.now(),
        analyticsMetrics: {},
      );
}