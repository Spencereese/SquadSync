import 'package:riverpod/riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/domain/repositories/lobby_repository.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:squad_sync/services/auth_service_supabase.dart';
import 'package:squad_sync/services/supabase_service.dart';
import '../../services/timer_service.dart';
import '../../notification_service.dart';

class LobbyNotifier extends AutoDisposeAsyncNotifier<LobbyState> {
  late final LobbyRepository _repository;
  late final TimerServiceNotifier _timerService;

  @override
  Future<LobbyState> build() async {
    try {
      // Get repository from provider
      _repository = ref.read(lobbyRepositoryProvider);
      _timerService = ref.watch(timerServiceProvider.notifier);

      // Load state synchronously to ensure proper loading state transition
      return await _loadState();
    } catch (e) {
      debugPrint('Error initializing squad notifier: $e');
      return LobbyState.initial();
    }
  }

  Future<LobbyState> _loadState() async {
    try {
      debugPrint('SquadNotifier: Loading squad state...');
      // Add timeout to prevent indefinite hanging
      final state = await _repository.loadLobbyState().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint(
              'SquadNotifier: Load state timed out, using initial state');
          return LobbyState.initial();
        },
      );
      debugPrint('SquadNotifier: Squad state loaded successfully');
      return state;
    } catch (e, stackTrace) {
      debugPrint('SquadNotifier: Error loading squad state: $e');
      debugPrint('SquadNotifier: Stack trace: $stackTrace');
      return LobbyState.initial();
    }
  }

  Future<void> createSquad(String name, String gameName, int maxSpots) async {
    await _repository.createLobby(name, gameName, maxSpots);
    state = await AsyncValue.guard(() => _repository.loadLobbyState());
  }

  /// Create a lobby linked to a chat group
  ///
  /// [chatGroupId] - The chat group ID to link this lobby to
  /// [gameName] - The game for this lobby
  /// [maxSpots] - Maximum number of spots (default: 8)
  /// [isPublic] - Whether this lobby is discoverable (default: false)
  ///
  /// Returns the created lobby ID
  Future<String> createLobby({
    required String chatGroupId,
    required String gameName,
    required int maxSpots,
    bool isPublic = false,
  }) async {
    try {
      debugPrint(
          '🎮 Creating lobby: chatGroupId=$chatGroupId, game=$gameName, maxSpots=$maxSpots, isPublic=$isPublic');

      // Note: chatGroupId linking needs to be handled separately
      final lobby = await _repository.createLobby('Lobby', gameName, maxSpots);
      final lobbyId = lobby.id;

      debugPrint('✅ Lobby created: $lobbyId');

      // Send notifications to chat group members (or all if public)
      try {
        if (chatGroupId.isNotEmpty) {
          // Get chat group member UIDs
          final chatGroupResponse = await SupabaseService.client
              .from('chat_groups')
              .select('member_uids')
              .eq('id', chatGroupId)
              .maybeSingle();

          if (chatGroupResponse != null) {
            final memberUids =
                (chatGroupResponse['member_uids'] as List<dynamic>?)
                        ?.cast<String>() ??
                    [];

            final currentUserId = AuthServiceSupabase().currentUser?.id;
            // Exclude current user from notifications
            final recipientUids =
                memberUids.where((uid) => uid != currentUserId).toList();

            if (recipientUids.isNotEmpty) {
              await NotificationService.sendNotificationToUsers(
                title: 'New Lobby Created!',
                body: 'A new $gameName lobby has been created',
                recipientUids: recipientUids,
                data: {
                  'type': 'lobby_created',
                  'lobby_id': lobbyId,
                  'game_name': gameName,
                  'chat_group_id': chatGroupId,
                },
              );
              debugPrint(
                  '📬 Sent lobby creation notifications to ${recipientUids.length} members');
            }
          }
        } else if (isPublic) {
          debugPrint(
              '📢 Public lobby created, notifications skipped (no specific recipients)');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to send lobby creation notifications: $e');
        // Don't fail the lobby creation if notifications fail
      }

      // Reload state to include new lobby
      state = await AsyncValue.guard(() => _repository.loadLobbyState());

      return lobbyId;
    } catch (e) {
      debugPrint('❌ Error creating lobby: $e');
      rethrow;
    }
  }

  Future<void> joinSquad(String squadId, String userId) async {
    await _repository.joinLobby(squadId, userId);
    state = await AsyncValue.guard(() => _repository.loadLobbyState());
  }

  Future<void> leaveSquad(String squadId, String userId) async {
    await _repository.leaveLobby(squadId, userId);
    state = await AsyncValue.guard(() => _repository.loadLobbyState());
  }

  Future<void> assignSpot(String squadId, int spotIndex, String? userId) async {
    await _repository.assignSpot(squadId, spotIndex, userId);
    state = await AsyncValue.guard(() => _repository.loadLobbyState());
  }

  Future<void> startSpotTimer(
      String squadId, int spotIndex, Duration duration) async {
    await _repository.startSpotTimer(squadId, spotIndex, duration);
    state = await AsyncValue.guard(() => _repository.loadLobbyState());
  }

  Future<void> processExpiredTimers() async {
    await _repository.processExpiredTimers();
    state = await AsyncValue.guard(() => _repository.loadLobbyState());
  }

  Future<void> addToPeacockQueue(String userId, String gameName) async {
    await _repository.addToPeacockQueue(userId, gameName);
    state = await AsyncValue.guard(() => _repository.loadLobbyState());
  }

  Future<void> removeFromPeacockQueue(String userId) async {
    await _repository.removeFromPeacockQueue(userId);
    state = await AsyncValue.guard(() => _repository.loadLobbyState());
  }

  Future<void> processPeacockQueue() async {
    await _repository.processPeacockQueue();
    state = await AsyncValue.guard(() => _repository.loadLobbyState());
  }

  Future<void> updateMemberStatus(
      String squadId, String userId, String status) async {
    await _repository.updateMemberStatus(squadId, userId, status);
    state = await AsyncValue.guard(() => _repository.loadLobbyState());
  }

  Future<void> syncSquadData() async {
    await _repository.syncLobbyData();
    state = await AsyncValue.guard(() => _repository.loadLobbyState());
  }

  Future<void> setCurrentGame(Map<String, dynamic>? game) async {
    final currentState = state;
    if (currentState is AsyncData && currentState.value != null) {
      debugPrint(
          'Setting current game: ${game?['name']}, coverUrl: ${game?['coverUrl']}');
      final updatedState = currentState.value!.copyWith(currentGame: game);
      state = AsyncValue.data(updatedState);
    }
  }

  // Update lobby members and fetch their display names
  Future<void> updateLobbyMembers(List<String> memberUids) async {
    final currentState = state;
    if (currentState is AsyncData && currentState.value != null) {
      try {
        // Fetch display names from Supabase users table
        final Map<String, String> displayNames = {};

        for (final uid in memberUids) {
          try {
            final userResponse = await SupabaseService.client
                .from('users')
                .select('display_name')
                .eq('id', uid)
                .maybeSingle();

            if (userResponse != null) {
              displayNames[uid] =
                  userResponse['display_name'] as String? ?? 'Unknown User';
            } else {
              displayNames[uid] = 'Unknown User';
            }
          } catch (e) {
            debugPrint('Error fetching display name for $uid: $e');
            displayNames[uid] = 'Unknown User';
          }
        }

        // Also fetch display names for any spot claimants
        final allGameSpots = currentState.value!.gameLobbySpots;
        for (final gameSpots in allGameSpots.values) {
          for (final spotUid in gameSpots) {
            if (spotUid != null && !displayNames.containsKey(spotUid)) {
              final cleanUid = spotUid.replaceAll('_calling', '');
              try {
                final userResponse = await SupabaseService.client
                    .from('users')
                    .select('display_name')
                    .eq('id', cleanUid)
                    .maybeSingle();

                if (userResponse != null) {
                  displayNames[cleanUid] =
                      userResponse['display_name'] as String? ?? 'Unknown User';
                } else {
                  displayNames[cleanUid] = 'Unknown User';
                }
              } catch (e) {
                debugPrint('Error fetching display name for $cleanUid: $e');
                displayNames[cleanUid] = 'Unknown User';
              }
            }
          }
        }

        // Update state with new member UIDs and display names
        final updatedState = currentState.value!.copyWith(
          lobbyMemberUids: memberUids,
          memberDisplayNames: {
            ...currentState.value!.memberDisplayNames,
            ...displayNames,
          },
        );
        state = AsyncValue.data(updatedState);
      } catch (e) {
        debugPrint('Error updating lobby members: $e');
      }
    }
  }

  // TODO: Implement addToPeacock method (alias for addToPeacockQueue)
  Future<void> addToPeacock(String userId) async {
    await addToPeacockQueue(userId, ''); // TODO: Pass proper game name
  }

  // TODO: Implement removeFromPeacock method (alias for removeFromPeacockQueue)
  Future<void> removeFromPeacock(String gameName, [String? userId]) async {
    // TODO: Implement with game context
    if (userId != null) {
      await removeFromPeacockQueue(userId);
    }
  }

  // Computed properties for game-scoped data
  Map<String, List<String?>> get gameLobbySpots => state.maybeWhen(
        data: (data) => data.gameLobbySpots,
        orElse: () => {},
      );

  Map<String, List<Map<String, dynamic>?>> get gameSpotTimers =>
      state.maybeWhen(
        data: (data) => data.gameSpotTimers,
        orElse: () => {},
      );

  Map<String, Map<String, String>> get gameStatuses => state.maybeWhen(
        data: (data) => data.gameStatuses,
        orElse: () => {},
      );

  Map<String, String> get globalStatuses => state.maybeWhen(
        data: (data) => data.globalStatuses,
        orElse: () => {},
      );

  List<String> get peacockQueue => state.maybeWhen(
        data: (data) => data.peacockQueue,
        orElse: () => [],
      );

  Map<String, Duration> get spotTimerStates => state.maybeWhen(
        data: (data) => data.spotTimerStates,
        orElse: () => {},
      );

  Map<String, Duration> get peacockTimerStates => state.maybeWhen(
        data: (data) => data.peacockTimerStates,
        orElse: () => {},
      );

  // Helper methods
  String getDisplayNameForUid(String uid) {
    return state.maybeWhen(
      data: (data) => data.memberDisplayNames[uid] ?? 'Unknown User',
      orElse: () => 'Unknown User',
    );
  }

  List<String?> getSquadSpots(String gameName) {
    return gameLobbySpots[gameName] ?? [];
  }

  List<Map<String, dynamic>?> getSquadSpotTimers(String gameName) {
    return gameSpotTimers[gameName] ?? [];
  }

  Map<String, String> getSquadStatuses(String gameName) {
    return gameStatuses[gameName] ?? {};
  }

  bool isUserInSquad(String userId, String? squadId) {
    if (squadId == null) return false;
    return state.maybeWhen(
      data: (data) =>
          data.userLobbies[squadId]?.memberUids.contains(userId) ?? false,
      orElse: () => false,
    );
  }

  int getActiveSquadMembersCount(String? squadId) {
    if (squadId == null) return 0;
    return state.maybeWhen(
      data: (data) => data.userLobbies[squadId]?.memberUids.length ?? 0,
      orElse: () => 0,
    );
  }

  String getSquadHealthStatus(String? squadId) {
    if (squadId == null) return 'unknown';
    final memberCount = getActiveSquadMembersCount(squadId);
    if (memberCount == 0) return 'empty';
    if (memberCount < 3) return 'forming';
    return 'active';
  }

  Future<void> claimSpot(String gameName, int spotIndex) async {
    debugPrint('claimSpot called: game=$gameName, spotIndex=$spotIndex');
    final currentState = state;
    if (currentState is AsyncData && currentState.value != null) {
      final squadState = currentState.value!;
      var squadId = squadState.selectedLobbyId;
      final authService = AuthServiceSupabase();
      final userId = authService.currentUser?.id;

      debugPrint('squadId: $squadId, userId: $userId');

      // If no lobby is selected, create one for this game
      if (squadId == null && userId != null && gameName.isNotEmpty) {
        debugPrint(
            '⚠️ No lobby selected, creating new lobby for game: $gameName');
        try {
          // Create a new lobby
          final newLobby = await _repository.createLobby(
            '$gameName Lobby',
            gameName,
            4, // Default squad size
          );

          squadId = newLobby.id;
          // Set this as the selected lobby
          setSelectedLobbyId(squadId);
          debugPrint('✅ Created and selected new lobby: $squadId');

          // Reload the lobby data to reflect the new lobby
          state = await AsyncValue.guard(() => _repository.loadLobbyState());
        } catch (e) {
          debugPrint('❌ Error creating lobby: $e');
          return;
        }
      }

      if (squadId != null && userId != null) {
        // Verify lobby exists in database before claiming spot
        try {
          debugPrint('🔍 Checking if lobby exists: $squadId');
          final lobbyResponse = await SupabaseService.client
              .from('lobbies')
              .select()
              .eq('id', squadId)
              .maybeSingle();

          if (lobbyResponse == null) {
            debugPrint('⚠️ Lobby not found in database, creating...');
            // Lobby doesn't exist - create it using the squadId as name
            await _repository.createLobby(squadId, gameName, 8);
            debugPrint('✅ Lobby created for group: $squadId');
          } else {
            debugPrint('✅ Lobby exists, proceeding with spot claim');
          }
        } catch (e) {
          debugPrint('❌ Error checking/creating lobby: $e');
          // If lobby check/creation fails, show error and return
          return;
        }

        // Update local state immediately for responsive UI
        final updatedSpots =
            Map<String, List<String?>>.from(squadState.gameLobbySpots);
        updatedSpots[gameName] =
            List<String?>.from(updatedSpots[gameName] ?? []);

        // Ensure the list is large enough
        while (updatedSpots[gameName]!.length <= spotIndex) {
          updatedSpots[gameName]!.add(null);
        }

        // Set the spot with calling status
        updatedSpots[gameName]![spotIndex] = '${userId}_calling';

        debugPrint('Updated spots for $gameName: ${updatedSpots[gameName]}');

        // Update global status
        final updatedGlobalStatuses =
            Map<String, String>.from(squadState.globalStatuses);
        updatedGlobalStatuses[userId] = 'Calling';

        // Update state immediately
        state = AsyncValue.data(squadState.copyWith(
          gameLobbySpots: updatedSpots,
          globalStatuses: updatedGlobalStatuses,
        ));

        debugPrint('State updated locally, making async calls...');

        // Then make async calls
        try {
          await _repository.assignSpot(squadId, spotIndex, userId);
          // Start the timer
          await _timerService.startSpotTimer(
              gameName, userId, const Duration(minutes: 5));
          debugPrint('Spot claimed successfully');

          // Send notification to other lobby members
          try {
            final lobbyResponse = await SupabaseService.client
                .from('lobbies')
                .select('member_uids, chat_group_id')
                .eq('id', squadId)
                .maybeSingle();

            if (lobbyResponse != null) {
              final memberUids =
                  (lobbyResponse['member_uids'] as List<dynamic>?)
                          ?.cast<String>() ??
                      [];
              final recipientUids =
                  memberUids.where((uid) => uid != userId).toList();

              if (recipientUids.isNotEmpty) {
                final currentUserName = squadState.displayName;
                await NotificationService.sendNotificationToUsers(
                  title: 'Spot Claimed!',
                  body: '$currentUserName claimed a spot in $gameName',
                  recipientUids: recipientUids,
                  data: {
                    'type': 'spot_claimed',
                    'lobby_id': squadId,
                    'game_name': gameName,
                    'spot_index': spotIndex.toString(),
                  },
                );
                debugPrint(
                    '📬 Sent spot claim notifications to ${recipientUids.length} members');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Failed to send spot claim notifications: $e');
            // Don't fail the spot claim if notifications fail
          }
        } catch (e) {
          debugPrint('Error claiming spot: $e');
          // Reload state to reflect actual state if error occurred
          state = await AsyncValue.guard(() => _repository.loadLobbyState());
        }
      } else {
        debugPrint('Cannot claim spot: squadId or userId is null');
      }
    } else {
      debugPrint('Cannot claim spot: state is not ready');
    }
  }

  Future<void> lockSpot(String gameName, int spotIndex) async {
    final currentState = state;
    if (currentState is AsyncData) {
      final squadState = currentState.value!;
      final authService = AuthServiceSupabase();
      final userId = authService.currentUser?.id;
      if (userId == null) return;
      // Cancel the timer
      final timerKey = 'spot_${gameName}_$userId';
      await _timerService.stopTimer(timerKey);
      // Update status to Ready
      await _repository.updateMemberStatus(
          squadState.selectedLobbyId!, userId, 'Ready');
      // Reload state
      state = await AsyncValue.guard(() => _repository.loadLobbyState());
    }
  }

  Future<void> removeSpot(String gameName, int spotIndex) async {
    final currentState = state;
    if (currentState is AsyncData) {
      final squadState = currentState.value!;
      final squadId = squadState.selectedLobbyId;
      if (squadId != null) {
        final authService = AuthServiceSupabase();
        final userId = authService.currentUser?.id;
        if (userId == null) return;
        await _repository.assignSpot(squadId, spotIndex, null);
        // Cancel timer if user is removing their own spot
        final spots = squadState.gameLobbySpots[gameName] ?? [];
        if (spotIndex < spots.length && spots[spotIndex] == userId) {
          final timerKey = 'spot_${gameName}_$userId';
          await _timerService.stopTimer(timerKey);
        }
        // Reload state
        state = await AsyncValue.guard(() => _repository.loadLobbyState());
      }
    }
  }

  // TODO: Implement recordWin method
  Future<void> recordWin(List<String> playerUids) async {
    // TODO: Implement win recording
  }

  // TODO: Implement recordLoss method
  Future<void> recordLoss(List<String> playerUids) async {
    // TODO: Implement loss recording
  }

  // TODO: Implement addBan method
  Future<void> addBan(String userId, String reason) async {
    // TODO: Implement ban adding
  }

  // TODO: Implement getFilteredMembers getter
  List<String> get getFilteredMembers => state.maybeWhen(
        data: (data) => data.lobbyMemberUids,
        orElse: () => [],
      );

  // Clear all spots for a specific game
  Future<void> clearAllSpots(String gameName) async {
    final currentState = state;
    if (currentState is AsyncData && currentState.value != null) {
      final squadState = currentState.value!;
      final lobbyId = squadState.selectedLobbyId;
      if (lobbyId == null) return;

      try {
        // Clear all spots in the database
        final spots = squadState.gameLobbySpots[gameName] ?? [];
        for (int i = 0; i < spots.length; i++) {
          await _repository.assignSpot(lobbyId, i, null);
        }

        // Reload state
        state = await AsyncValue.guard(() => _repository.loadLobbyState());
      } catch (e) {
        debugPrint('Error clearing all spots: $e');
      }
    }
  }

  // Reset all timers for a specific game
  Future<void> resetTimers(String gameName) async {
    final currentState = state;
    if (currentState is AsyncData && currentState.value != null) {
      final squadState = currentState.value!;

      try {
        // Stop all active timers for this game
        final spots = squadState.gameLobbySpots[gameName] ?? [];
        for (int i = 0; i < spots.length; i++) {
          final spotUid = spots[i];
          if (spotUid != null) {
            final timerKey =
                'spot_${gameName}_${spotUid.replaceAll('_calling', '')}';
            await _timerService.stopTimer(timerKey);
          }
        }

        // Reload state
        state = await AsyncValue.guard(() => _repository.loadLobbyState());
      } catch (e) {
        debugPrint('Error resetting timers: $e');
      }
    }
  }

  // Update tilt enabled setting
  void updateTiltEnabled(bool enabled) {
    state = state.maybeWhen(
      data: (data) => AsyncValue.data(data.copyWith(tiltEnabled: enabled)),
      orElse: () => state,
    );
  }

  // Update profile image
  void updateProfileImage(String? imageUrl) {
    state = state.maybeWhen(
      data: (data) => AsyncValue.data(data.copyWith(profileImage: imageUrl)),
      orElse: () => state,
    );
  }

  // Update display name
  void updateDisplayName(String? name) {
    state = state.maybeWhen(
      data: (data) =>
          AsyncValue.data(data.copyWith(displayName: name ?? 'Unknown User')),
      orElse: () => state,
    );
  }

  // Reset state
  void reset() {
    state = const AsyncValue.loading();
  }

  // Clear notifications for a tab
  void clearNotifications(int tabIndex) {
    // TODO: Implement notification clearing
  }

  Future<void> leaveChatGroup(String groupId) async {
    // Stub implementation
  }

  void updateTypingStatus(String user, bool isTyping) {
    // Stub implementation
  }

  Future<void> submitComplaint({
    required String submittedBy,
    required String targetMember,
    required String reason,
    required String category,
    List<String>? squadMembers,
  }) async {
    // TODO: Implement submit complaint using appropriate usecase
    // For now, stub
  }

  Future<void> submitRatings(String playerUid, Map<String, int> ratings) async {
    final currentState = state.value;
    if (currentState != null) {
      final updatedDailyRatings =
          Map<String, Map<String, int>>.from(currentState.dailyRatings);
      final updatedAllTimeRatings =
          Map<String, Map<String, int>>.from(currentState.allTimeRatings);

      // Update daily ratings
      updatedDailyRatings[playerUid] = ratings;

      // Update all-time ratings (accumulate)
      final existingAllTime = updatedAllTimeRatings[playerUid] ?? {};
      final newAllTime = Map<String, int>.from(existingAllTime);
      ratings.forEach((category, rating) {
        newAllTime[category] = (newAllTime[category] ?? 0) + rating;
      });
      updatedAllTimeRatings[playerUid] = newAllTime;

      // Update state
      state = AsyncData(currentState.copyWith(
        dailyRatings: updatedDailyRatings,
        allTimeRatings: updatedAllTimeRatings,
      ));

      // TODO: Persist to Firestore
      // await _firestoreManager.updateFirestore({'dailyRatings': updatedDailyRatings, 'allTimeRatings': updatedAllTimeRatings});
    }
  }

  Future<void> callSpotForGame(int spotIndex, String gameName) async {
    final currentState = state;
    if (currentState is AsyncData) {
      final squadState = currentState.value!;
      final squadId = squadState.selectedLobbyId;
      if (squadId != null) {
        final authService = AuthServiceSupabase();
        final userId = authService.currentUser?.id;
        if (userId == null) return;
        await _repository.assignSpot(squadId, spotIndex, userId);
        // Start the timer
        await _timerService.startSpotTimer(
            gameName, userId, const Duration(minutes: 5));
        // Reload state
        state = await AsyncValue.guard(() => _repository.loadLobbyState());
      }
    }
  }

  Future<void> claimPeacockSpot(
      String lobbyId, String userId, String gameName) async {
    await _repository.addToPeacockQueue(userId, gameName);
  }

  Future<void> lockPeacockSpot(
      String lobbyId, String userId, String gameName) async {
    await _repository.removeFromPeacockQueue(userId);
  }

  Future<List<Map<String, dynamic>>> getSquadAlerts(String squadId) async {
    return [];
  }

  Future<void> sendGameAlert(String squadId, String userId, String alertType,
      {String? specificGame, List<String>? pinnedGames}) async {
    // TODO
  }

  Future<void> clearGameAlerts(String squadId, String userId) async {
    // TODO
  }

  Future<void> closeLobby(String lobbyId) async {
    // TODO
  }

  void setSelectedLobbyId(String? squadId) {
    state = state.whenData(
        (squadState) => squadState.copyWith(selectedLobbyId: squadId));
  }
}

final lobbyNotifierProvider =
    AutoDisposeAsyncNotifierProvider<LobbyNotifier, LobbyState>(
  () => LobbyNotifier(),
);
