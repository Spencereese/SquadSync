import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/repositories/lobby_repository.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:squad_sync/services/auth_service_supabase.dart';
import 'package:squad_sync/services/supabase_service.dart';
import 'package:squad_sync/core/realtime_subscribe.dart';
import 'package:squad_sync/services/error_handling_service.dart';
import 'package:squad_sync/services/constitution_manager.dart';
import 'package:squad_sync/domain/entities/constitution.dart';

import '../../notification_service.dart';
import '../../services/lobby_ready_lock.dart';
import '../../services/matchmaking_queue_machine.dart';
import '../../services/peacock_assignment_machine.dart';
import '../../services/peacock_lock_live_activity.dart';
import '../../services/preferred_peacock_games.dart';
import '../../services/session_rating_machine.dart';
import '../../services/squad_analytics.dart';
import 'offline_first_mixin.dart';
import 'timer_management_notifier.dart';
import 'game_state_notifier.dart';

/// Refactored LobbyNotifier - Core lobby coordination
/// Handles:
/// - Lobby spots management and member status tracking
/// - Peacock queue handling
/// - Current lobby real-time tracking
/// - User's lobby memberships
/// Delegates to:
/// - TimerManagementNotifier for timer orchestration
/// - GameStateNotifier for game selection logic
class LobbyNotifier extends AsyncNotifier<LobbyState> with OfflineFirstMixin {
  late final LobbyRepository _repository;
  late final ErrorHandlingService _errorHandler;
  late final ConstitutionManager _constitutionManager;

  StreamSubscription? _currentLobbySubscription;
  StreamSubscription? _userLobbiesSubscription;
  int _lobbyChannelErrorRetries = 0;
  String? _currentSubscribedLobbyId;
  Timer? _readyCheckTimer;
  DateTime? _readyCheckStartedAt;
  LobbyReadyLockSnapshot? _lastReadyLockSnapshot;

  @override
  Future<LobbyState> build() async {
    // Bind required deps BEFORE offline init / load so a swallowed failure
    // never leaves late fields unset (LateInitializationError on later calls).
    _repository = ref.read(lobbyRepositoryProvider);
    _constitutionManager = ref.read(constitutionManagerProvider);
    _errorHandler = ref.read(errorHandlingServiceProvider);

    _bindPeacockQueueProcessor();
    await PreferredPeacockGamesStore.instance.load();
    final matchmakingRepo = ref.read(matchmakingQueueRepositoryProvider);
    MatchmakingQueueTracker.instance.bindRepository(matchmakingRepo);
    unawaited(_bindMatchmakingQueue());
    ref.onDispose(() {
      _currentLobbySubscription?.cancel();
      _userLobbiesSubscription?.cancel();
      _disarmReadyCheckTimer();
      disposeOfflineFirst();
      if (identical(_peacock.queueProcessor, processPeacockQueue)) {
        _peacock.queueProcessor = null;
      }
    });

    try {
      await initializeOfflineFirst();
      return await _loadState();
    } catch (e) {
      debugPrint('Error initializing lobby notifier: $e');
      // Deps are already bound; return a safe default state.
      return LobbyState.initial();
    }
  }

  Future<LobbyState> _loadState() async {
    try {
      debugPrint('LobbyNotifier: Loading lobby state...');

      // Load state with performance monitoring and retry logic
      final initialState = await _errorHandler.withRetryAndMonitoring(
        operation: () => _loadPersistedLobbyState().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint(
                'LobbyNotifier: Load state timed out, using initial state');
            return LobbyState.initial();
          },
        ),
        operationName: 'loadLobbyState',
        maxAttempts: 2,
        slowThreshold: const Duration(milliseconds: 500),
      );

      debugPrint('LobbyNotifier: Lobby state loaded successfully');

      // Set up real-time subscriptions
      _setupSubscriptions(initialState);

      return await syncPreferredPeacockGames(initialState);
    } catch (e, stackTrace) {
      await _errorHandler.handleError(
        error: e,
        operation: 'loadLobbyState',
        stackTrace: stackTrace,
        showSnackBar: false, // Don't show error on initial load
      );
      return LobbyState.initial();
    }
  }

  Future<LobbyState> _loadPersistedLobbyState() async {
    final loaded = await _repository.loadLobbyState();
    return syncPreferredPeacockGames(loaded);
  }

  /// Toggle a Preferred Peacock Game chip. Persists across sessions.
  Future<void> togglePreferredPeacockGame(String gameName) async {
    await PreferredPeacockGamesStore.instance.toggle(gameName);
    final current = state.valueOrNull;
    if (current == null) return;
    final next = current.copyWith(
      preferredPeacockGames: PreferredPeacockGamesStore.instance.snapshot,
    );
    state = AsyncData(next);
    try {
      await _repository.saveLobbyState(next);
    } catch (e) {
      debugPrint('preferred peacock games save skipped: $e');
    }
  }

  /// Set up Supabase real-time subscriptions for current lobby and user lobbies
  void _setupSubscriptions(LobbyState initialState) {
    final currentUser = AuthServiceSupabase().currentUser;
    if (currentUser == null) return;

    // Subscribe to user's lobbies for membership tracking
    _userLobbiesSubscription?.cancel();
    _userLobbiesSubscription =
        _repository.getUserLobbiesStream(currentUser.id).listen(
      (lobbies) {
        final currentState = state.valueOrNull;
        if (currentState == null) return;

        // Update userLobbies map and userLobbyIds list
        final lobbiesMap = {for (var lobby in lobbies) lobby.id: lobby};
        final lobbyIds = lobbies.map((l) => l.id).toList();

        // Collect all member UIDs and display names from user's lobbies
        final allMemberUids = <String>{};
        final displayNames =
            Map<String, String>.from(currentState.memberDisplayNames);

        for (final lobby in lobbies) {
          allMemberUids.addAll(lobby.memberUids);
        }

        // Update state with new lobby memberships
        state = AsyncData(currentState.copyWith(
          userLobbies: lobbiesMap,
          userLobbyIds: lobbyIds,
          lobbyMemberUids: allMemberUids.toList(),
          memberDisplayNames: displayNames,
        ));

        // Fetch display names for all collected member UIDs
        _fetchDisplayNamesForMembers(allMemberUids.toList());

        debugPrint('📡 User lobbies updated: ${lobbies.length} lobbies');
      },
      onError: (error) {
        debugPrint('❌ Error in user lobbies stream: $error');
      },
    );

    // Subscribe to current lobby if one is selected
    if (initialState.selectedLobbyId != null) {
      _subscribeToCurrentLobby(initialState.selectedLobbyId!);
    }
  }

  void _resubscribeCurrentLobbyOnce(String lobbyId) {
    if (!shouldResubscribeAfterChannelError(_lobbyChannelErrorRetries)) {
      debugPrint('Lobby channel dead after resubscribe');
      return;
    }
    _lobbyChannelErrorRetries++;
    _subscribeToCurrentLobby(lobbyId);
  }

  /// Subscribe to real-time updates for a specific lobby
  void _subscribeToCurrentLobby(String lobbyId) {
    if (_currentSubscribedLobbyId != lobbyId) {
      _lobbyChannelErrorRetries = 0;
      _currentSubscribedLobbyId = lobbyId;
    }
    _currentLobbySubscription?.cancel();
    _currentLobbySubscription = _repository.getLobbyStream(lobbyId).listen(
      (lobby) {
        final currentState = state.valueOrNull;
        if (currentState == null || lobby == null) return;

        // Update current lobby data
        state = AsyncData(currentState.copyWith(
          currentLobby: lobby,
          gameLobbySpots: {lobby.gameName: lobby.spots},
          gameSpotTimers: {lobby.gameName: lobby.spotTimers},
          gameStatuses: {lobby.gameName: lobby.statuses},
        ));

        // Fetch display names for any new members
        _fetchDisplayNamesForMembers(lobby.memberUids);

        debugPrint(
            '📡 Current lobby updated: ${lobby.name} (${lobby.memberUids.length} members)');
        unawaited(_processLobbyAwareMatchmaking(lobby));
        // Stream is not the notify actor (the Ready/unlock/late-join
        // writer already sent). Reconcile timer + live activity only.
        unawaited(reconcileReadyLock(notify: false, gameName: lobby.gameName));
      },
      onError: (error) {
        debugPrint('❌ Error in current lobby stream: $error');
        // Handle RealtimeSubscribeException gracefully
        if (error is RealtimeSubscribeException) {
          debugPrint('❌ RealtimeSubscribeException: ${error.status}');
          if (isDeadRealtimeStatus(error.status)) {
            debugPrint('❌ Lobby channel dead; resubscribing once');
            _resubscribeCurrentLobbyOnce(lobbyId);
          }
        }
      },
    );
  }

  /// Fetch display names and profile images for members and update state (private internal method)
  Future<void> _fetchDisplayNamesForMembers(List<String> memberUids) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    final displayNames =
        Map<String, String>.from(currentState.memberDisplayNames);
    final profileImages =
        Map<String, String?>.from(currentState.memberProfileImages ?? {});
    bool hasUpdates = false;

    for (final uid in memberUids) {
      if (!displayNames.containsKey(uid)) {
        try {
          final userResponse = await SupabaseService.client
              .from('users')
              .select('display_name, photo_url')
              .eq('uid', uid)
              .maybeSingle();

          if (userResponse != null) {
            displayNames[uid] =
                userResponse['display_name'] as String? ?? 'Unknown User';
            profileImages[uid] = userResponse['photo_url'] as String?;
            hasUpdates = true;
          }
        } catch (e) {
          debugPrint('Error fetching display name for $uid: $e');
          displayNames[uid] = 'Unknown User';
          profileImages[uid] = null;
          hasUpdates = true;
        }
      }
    }

    if (hasUpdates) {
      state = AsyncData(currentState.copyWith(
        memberDisplayNames: displayNames,
        memberProfileImages: profileImages,
      ));
    }
  }

  /// Public method to fetch display names for a list of UIDs (for external callers like chat screen)
  Future<void> fetchDisplayNamesForUids(List<String> uids) async {
    await _fetchDisplayNamesForMembers(uids);
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
      state = await AsyncValue.guard(() => _loadPersistedLobbyState());

      return lobbyId;
    } catch (e, stackTrace) {
      await _errorHandler.handleError(
        error: e,
        operation: 'createLobby',
        stackTrace: stackTrace,
        showSnackBar: false, // Let caller handle UI feedback
      );
      rethrow;
    }
  }

  /// Create a public lobby for Discovery
  Future<String> createPublicLobby({
    required String name,
    required String gameName,
    required int maxSpots,
    String? description,
  }) async {
    try {
      debugPrint(
          '🎮 Creating public lobby: name=$name, game=$gameName, maxSpots=$maxSpots');

      final lobby = await _repository.createLobby(name, gameName, maxSpots);
      final lobbyId = lobby.id;

      // Update lobby with public flag and description
      await SupabaseService.client.from('lobbies').update({
        'is_public': true,
        'description': description,
        'is_active': true,
        'last_activity': DateTime.now().toIso8601String(),
      }).eq('id', lobbyId);

      debugPrint('✅ Public lobby created: $lobbyId');

      // Reload state to include new lobby
      state = await AsyncValue.guard(() => _loadPersistedLobbyState());

      return lobbyId;
    } catch (e, stackTrace) {
      await _errorHandler.handleError(
        error: e,
        operation: 'createPublicLobby',
        stackTrace: stackTrace,
        showSnackBar: false, // Let caller handle UI feedback
      );
      rethrow;
    }
  }

  Future<void> joinLobby(String squadId, String userId) async {
    await _repository.joinLobby(squadId, userId);
    state = await AsyncValue.guard(() => _loadPersistedLobbyState());
    unawaited(SquadAnalytics.logLobbyJoin(
      source: 'code',
      gameName: state.valueOrNull?.currentGame?['name'] as String?,
    ));
  }

  Future<void> leaveSquad(String squadId, String userId) async {
    await _repository.leaveLobby(squadId, userId);
    state = await AsyncValue.guard(() => _loadPersistedLobbyState());
  }

  Future<void> assignSpot(String squadId, int spotIndex, String? userId) async {
    await _repository.assignSpot(squadId, spotIndex, userId);
    state = await AsyncValue.guard(() => _loadPersistedLobbyState());
    await reconcileReadyLock(
      actorUid: userId ?? '',
      notify: true,
    );
  }

  Future<void> startSpotTimer(
      String squadId, int spotIndex, Duration duration) async {
    await _repository.startSpotTimer(squadId, spotIndex, duration);
    state = await AsyncValue.guard(() => _loadPersistedLobbyState());
  }

  Future<void> processExpiredTimers() async {
    // Delegate to TimerManagementNotifier
    final timerNotifier = ref.read(timerManagementNotifierProvider.notifier);
    await timerNotifier.processExpiredTimers();
    state = await AsyncValue.guard(() => _loadPersistedLobbyState());
  }

  PeacockAssignmentTracker get _peacock => PeacockAssignmentTracker.instance;

  void _bindPeacockQueueProcessor() {
    _peacock.queueProcessor = processPeacockQueue;
  }

  /// Persist LFG looking + lobby-aware [processQueue]. Does not peacock-assign.
  Future<void> _bindMatchmakingQueue() async {
    final tracker = MatchmakingQueueTracker.instance;
    await tracker.ensureHydratedAndSubscribed();
    final lobby = state.valueOrNull?.currentLobby;
    if (lobby != null) {
      await _processLobbyAwareMatchmaking(lobby);
    }
  }

  Future<void> _processLobbyAwareMatchmaking(Lobby lobby) async {
    final tracker = MatchmakingQueueTracker.instance;
    final hasFree = lobbyHasFreeSeatForMatchmaking(
      spots: lobby.spots,
      maxSpots: lobby.maxSpots,
      alreadyMatchedToLobby: tracker.matchedCountForLobby(lobby.id),
    );
    await tracker.processQueueAndPersist(
      lobbyId: lobby.id,
      gameName: lobby.gameName,
      lobbyHasFreeSeat: hasFree,
    );
  }

  /// Reduce [event] for [userId] after the matching repository call succeeds.
  PeacockAssignmentState _reducePeacock({
    required String userId,
    required PeacockAssignmentEvent event,
    String? lobbyId,
    String? gameName,
    String? notificationId,
    int? spotIndex,
  }) {
    return _peacock.apply(
      userId: userId,
      event: event,
      lobbyId: lobbyId,
      gameName: gameName,
      notificationId: notificationId,
      spotIndex: spotIndex,
    );
  }

  Future<void> addToPeacockQueue(String userId, String gameName) async {
    _bindPeacockQueueProcessor();
    await _repository.addToPeacockQueue(userId, gameName);
    _reducePeacock(
      userId: userId,
      event: PeacockAssignmentEvent.joinQueue,
    );
    state = await AsyncValue.guard(() => _loadPersistedLobbyState());
  }

  Future<void> removeFromPeacockQueue(String userId) async {
    _bindPeacockQueueProcessor();
    final phase = _peacock.stateFor(userId).phase;
    await _repository.removeFromPeacockQueue(userId);
    if (phase == PeacockAssignmentPhase.queued) {
      _reducePeacock(
        userId: userId,
        event: PeacockAssignmentEvent.leaveQueue,
      );
    } else if (phase == PeacockAssignmentPhase.assigned ||
        phase == PeacockAssignmentPhase.notified) {
      _reducePeacock(
        userId: userId,
        event: PeacockAssignmentEvent.expire,
      );
    }
    state = await AsyncValue.guard(() => _loadPersistedLobbyState());
  }

  /// Process the peacock queue. Selects the next queued uid when one is not
  /// passed, persists via the repository, then [assignSpot] on the tracker
  /// so product phase never lags on a bare stub call.
  Future<String?> processPeacockQueue({
    String? assignedUserId,
    String? lobbyId,
    String? gameName,
    String? notificationId,
  }) async {
    _bindPeacockQueueProcessor();
    final uid = assignedUserId ?? _peacock.nextQueuedUserId();
    await _repository.processPeacockQueue();
    if (uid != null) {
      final before = _peacock.stateFor(uid);
      _reducePeacock(
        userId: uid,
        event: PeacockAssignmentEvent.assignSpot,
        lobbyId: lobbyId ?? state.valueOrNull?.selectedLobbyId,
        gameName: gameName ?? before.gameName,
        notificationId: notificationId,
      );
      final after = _peacock.stateFor(uid);
      if (after.phase == PeacockAssignmentPhase.assigned &&
          before.phase != PeacockAssignmentPhase.assigned &&
          before.phase != PeacockAssignmentPhase.notified) {
        unawaited(SquadAnalytics.logPeacockOffer(
          source: 'peacock_queue',
          gameName: after.gameName,
        ));
      }
    }
    state = await AsyncValue.guard(() => _loadPersistedLobbyState());
    return uid;
  }

  /// First empty seat for [lobbyId] / [gameName], or null when lobby
  /// spots are unknown or full. Reuses [userId]'s existing seat.
  int? nextFreeSpotIndex({
    String? lobbyId,
    String? gameName,
    String? userId,
  }) {
    final lobbyState = state.valueOrNull;
    if (lobbyState == null) return null;
    return resolveNextFreeSpotFromLobbyState(
      state: lobbyState,
      lobbyId: lobbyId,
      gameName: gameName,
      userId: userId,
    );
  }

  /// Assign a peacock spot: repository [assignSpot] first when a seat
  /// is known (explicit [spotIndex] or the next free seat from lobby
  /// state), then reduce so a repo failure does not leave a phantom
  /// phase. Returns the claimed index, or null for phase-only handoff.
  Future<int?> assignPeacockSpot({
    required String userId,
    required String lobbyId,
    String? gameName,
    String? notificationId,
    int? spotIndex,
  }) async {
    _bindPeacockQueueProcessor();
    final claimed = spotIndex ??
        nextFreeSpotIndex(
          lobbyId: lobbyId,
          gameName: gameName,
          userId: userId,
        );
    if (claimed != null) {
      await assignSpot(lobbyId, claimed, userId);
    }
    _reducePeacock(
      userId: userId,
      event: PeacockAssignmentEvent.assignSpot,
      lobbyId: lobbyId,
      gameName: gameName,
      notificationId: notificationId,
      spotIndex: claimed,
    );
    return claimed;
  }

  /// Expire/cancel/timeout a peacock assignment.
  void expirePeacockAssignment(String userId) {
    _reducePeacock(
      userId: userId,
      event: PeacockAssignmentEvent.expire,
    );
  }

  Future<void> updateMemberStatus(
      String squadId, String userId, String status) async {
    await _repository.updateMemberStatus(squadId, userId, status);
    state = await AsyncValue.guard(() => _loadPersistedLobbyState());
  }

  Future<void> syncSquadData() async {
    await _repository.syncLobbyData();
    state = await AsyncValue.guard(() => _loadPersistedLobbyState());
  }

  Future<void> setCurrentGame(Map<String, dynamic>? game) async {
    final currentState = state;
    if (currentState is AsyncData && currentState.value != null) {
      debugPrint(
          'Setting current game: ${game?['name']}, coverUrl: ${game?['coverUrl']}');
      final updatedState = currentState.value!.copyWith(currentGame: game);
      state = AsyncValue.data(updatedState);

      // Sync with GameStateNotifier
      final gameStateNotifier = ref.read(gameStateNotifierProvider.notifier);
      await gameStateNotifier.setCurrentGame(game);
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
                .eq('uid', uid)
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
                    .eq('uid', cleanUid)
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
          state = await AsyncValue.guard(() => _loadPersistedLobbyState());
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

          // Delegate timer management to TimerManagementNotifier
          final timerNotifier =
              ref.read(timerManagementNotifierProvider.notifier);
          await timerNotifier.startSpotTimer(
              squadId, gameName, spotIndex, userId, const Duration(minutes: 5));

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
          state = await AsyncValue.guard(() => _loadPersistedLobbyState());
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

      // Delegate timer cancellation to TimerManagementNotifier
      final timerNotifier = ref.read(timerManagementNotifierProvider.notifier);
      await timerNotifier.stopSpotTimer(gameName, userId);

      // Calling → Ready on this seated spot, then Lock if everyone is Ready.
      await applySeatedReady(
        userId: userId,
        ready: true,
        gameName: gameName,
      );
    }
  }

  /// Toggle Ready on the caller's seated spot. When every seated member
  /// is Ready, the lobby Locks and seated members are notified.
  /// While locked, the same tap unlocks (Ready → Occupied).
  Future<SeatedReadyResult?> toggleSeatedReady({
    required String userId,
    String? gameName,
    int? spotIndex,
  }) async {
    final squadState = state.valueOrNull;
    if (squadState == null) return null;
    final game = gameName ?? squadState.currentGame?['name'] as String? ?? '';
    final spots = spotsForReadyLock(squadState, gameName: game);
    final statuses = mergeLobbyMemberStatuses(squadState, gameName: game);
    var snapshot = resolveLobbyReadyLock(spots: spots, statuses: statuses);

    final uid = userId.trim();
    if (uid.isEmpty) return null;
    if (spotIndex != null) {
      if (spotIndex < 0 || spotIndex >= spots.length) return null;
      if (seatedUidFromOccupant(spots[spotIndex]) != uid) return null;
    }
    if (!snapshot.seatedUids.contains(uid)) return null;

    if (readyCheckTimedOut(
      snapshot: snapshot,
      now: DateTime.now(),
      startedAt: _readyCheckStartedAt,
    )) {
      final timedOut = await timeoutReadyCheck();
      if (timedOut != null) snapshot = timedOut.snapshot;
    }

    if (snapshot.isLocked) {
      return applySeatedReady(
        userId: uid,
        ready: false,
        gameName: game,
      );
    }

    return applySeatedReady(
      userId: uid,
      ready: !snapshot.isReady(uid),
      gameName: game,
    );
  }

  /// Persist Ready / Occupied on a seated member, then Lock + notify
  /// when all seated are Ready. Live path for [toggleSeatedReady] and
  /// [lockSpot] (no scaffold).
  Future<SeatedReadyResult?> applySeatedReady({
    required String userId,
    required bool ready,
    String? gameName,
  }) async {
    final squadState = state.valueOrNull;
    if (squadState == null) return null;
    final lobbyId = squadState.selectedLobbyId ?? squadState.currentLobby?.id;
    if (lobbyId == null || lobbyId.isEmpty) return null;

    final game = gameName ?? squadState.currentGame?['name'] as String? ?? '';
    final spots = spotsForReadyLock(squadState, gameName: game);
    final statuses = mergeLobbyMemberStatuses(squadState, gameName: game);
    final before = resolveLobbyReadyLock(spots: spots, statuses: statuses);
    final status = ready ? kSeatedReadyStatus : kSeatedNotReadyStatus;
    final patched = Map<String, String>.from(statuses)..[userId] = status;
    final after = resolveLobbyReadyLock(spots: spots, statuses: patched);
    final lockedNow = justLockedLobby(before: before, after: after);
    final unlockedNow = justUnlockedLobby(before: before, after: after);

    try {
      await _repository.updateMemberStatus(lobbyId, userId, status);
    } catch (e) {
      debugPrint('LobbyNotifier: failed to set seated Ready: $e');
      rethrow;
    }

    _applyMemberStatusLocally(
      userId: userId,
      status: status,
      gameName: game,
    );

    _lastReadyLockSnapshot = after;
    _syncReadyCheckTimer(after, armedByReady: ready && after.isReady(userId));

    if (lockedNow || unlockedNow) {
      try {
        await LobbyLockNotify.send(
          lockedNow
              ? planLobbyLockNotify(
                  seatedUids: after.seatedUids,
                  actorUid: userId,
                  lobbyId: lobbyId,
                  gameName: game.isEmpty ? null : game,
                )
              : planLobbyUnlockNotify(
                  seatedUids: after.seatedUids,
                  actorUid: userId,
                  lobbyId: lobbyId,
                  gameName: game.isEmpty ? null : game,
                ),
        );
      } catch (e) {
        debugPrint('LobbyNotifier: lobby lock notify failed: $e');
      }
    }

    try {
      await PeacockLockLiveActivity.syncFromReadyLock(
        snapshot: after,
        lobbyId: lobbyId,
        gameName: game.isEmpty ? null : game,
      );
    } catch (e) {
      debugPrint('LobbyNotifier: peacock lock live activity failed: $e');
    }

    if (ready) {
      unawaited(SquadAnalytics.logReadyCheck(
        seatedCount: after.seatedUids.length,
        readyCount: after.readyUids.length,
        outcome: lockedNow ? 'locked' : 'ready',
      ));
    }
    if (lockedNow) {
      unawaited(SquadAnalytics.logPeacockLock(
        seatedCount: after.seatedUids.length,
        readyCount: after.readyUids.length,
      ));
    }

    return SeatedReadyResult(
      snapshot: after,
      justLocked: lockedNow,
      justUnlocked: unlockedNow,
    );
  }

  /// Clear Ready flags when the ready-check window elapses without a lock.
  Future<SeatedReadyResult?> timeoutReadyCheck({
    DateTime? now,
    DateTime? startedAt,
  }) async {
    final squadState = state.valueOrNull;
    if (squadState == null) return null;
    final lobbyId = squadState.selectedLobbyId ?? squadState.currentLobby?.id;
    if (lobbyId == null || lobbyId.isEmpty) return null;

    final game = squadState.currentGame?['name'] as String? ?? '';
    final spots = spotsForReadyLock(squadState, gameName: game);
    final statuses = mergeLobbyMemberStatuses(squadState, gameName: game);
    final before = resolveLobbyReadyLock(spots: spots, statuses: statuses);
    final clock = now ?? DateTime.now();
    final started = startedAt ?? _readyCheckStartedAt;
    final after = reduceReadyCheckTimeout(
      spots: spots,
      statuses: statuses,
      now: clock,
      startedAt: started,
    );
    if (!readyCheckTimedOut(
      snapshot: before,
      now: clock,
      startedAt: started,
    )) {
      return SeatedReadyResult(
        snapshot: before,
        justLocked: false,
        changed: false,
      );
    }

    for (final uid in before.readyUids) {
      try {
        await _repository.updateMemberStatus(
          lobbyId,
          uid,
          kSeatedNotReadyStatus,
        );
      } catch (e) {
        debugPrint('LobbyNotifier: failed to timeout Ready for $uid: $e');
      }
      _applyMemberStatusLocally(
        userId: uid,
        status: kSeatedNotReadyStatus,
        gameName: game,
      );
    }

    _lastReadyLockSnapshot = after;
    _disarmReadyCheckTimer();

    try {
      final actor = AuthServiceSupabase().currentUser?.id ?? '';
      await LobbyLockNotify.send(
        planLobbyReadyTimeoutNotify(
          seatedUids: after.seatedUids,
          actorUid: actor,
          lobbyId: lobbyId,
          gameName: game.isEmpty ? null : game,
        ),
      );
    } catch (e) {
      debugPrint('LobbyNotifier: ready-check timeout notify failed: $e');
    }

    try {
      await PeacockLockLiveActivity.syncFromReadyLock(
        snapshot: after,
        lobbyId: lobbyId,
        gameName: game.isEmpty ? null : game,
      );
    } catch (e) {
      debugPrint('LobbyNotifier: peacock lock live activity failed: $e');
    }

    unawaited(SquadAnalytics.logReadyCheck(
      seatedCount: after.seatedUids.length,
      readyCount: after.readyUids.length,
      outcome: 'timeout',
    ));

    return SeatedReadyResult(
      snapshot: after,
      justLocked: false,
      timedOut: true,
    );
  }

  /// Recompute Ready/Lock after seats change (late join / leave).
  ///
  /// [notify] is true on the acting client (assign / claim). Stream
  /// updates pass false so seated FCM is not sent twice.
  Future<SeatedReadyResult?> reconcileReadyLock({
    String actorUid = '',
    String? gameName,
    bool notify = false,
  }) async {
    final squadState = state.valueOrNull;
    if (squadState == null) return null;
    final lobbyId = squadState.selectedLobbyId ?? squadState.currentLobby?.id;
    final game = gameName ?? squadState.currentGame?['name'] as String? ?? '';
    final after = resolveLobbyReadyLockFromState(squadState, gameName: game);
    final before = _lastReadyLockSnapshot ?? after;
    _lastReadyLockSnapshot = after;

    if (readyCheckTimedOut(
      snapshot: after,
      now: DateTime.now(),
      startedAt: _readyCheckStartedAt,
    )) {
      return timeoutReadyCheck();
    }

    _syncReadyCheckTimer(after);

    final unlockedNow = justUnlockedLobby(before: before, after: after);
    final lockedNow = justLockedLobby(before: before, after: after);
    final lateJoin = lateJoinUnlocks(before: before, after: after);

    if (notify &&
        lobbyId != null &&
        lobbyId.isNotEmpty &&
        (unlockedNow || lockedNow)) {
      try {
        await LobbyLockNotify.send(
          lockedNow
              ? planLobbyLockNotify(
                  seatedUids: after.seatedUids,
                  actorUid: actorUid,
                  lobbyId: lobbyId,
                  gameName: game.isEmpty ? null : game,
                )
              : planLobbyUnlockNotify(
                  seatedUids: after.seatedUids,
                  actorUid: actorUid,
                  lobbyId: lobbyId,
                  gameName: game.isEmpty ? null : game,
                ),
        );
      } catch (e) {
        debugPrint('LobbyNotifier: ready-lock reconcile notify failed: $e');
      }
    }

    if (lobbyId != null && lobbyId.isNotEmpty) {
      try {
        await PeacockLockLiveActivity.syncFromReadyLock(
          snapshot: after,
          lobbyId: lobbyId,
          gameName: game.isEmpty ? null : game,
        );
      } catch (e) {
        debugPrint('LobbyNotifier: peacock lock live activity failed: $e');
      }
    }

    if (lockedNow) {
      unawaited(SquadAnalytics.logPeacockLock(
        seatedCount: after.seatedUids.length,
        readyCount: after.readyUids.length,
      ));
    }

    return SeatedReadyResult(
      snapshot: after,
      justLocked: lockedNow,
      justUnlocked: unlockedNow,
      changed: unlockedNow || lockedNow || lateJoin,
    );
  }

  Duration? readyCheckRemaining({DateTime? now}) {
    final started = _readyCheckStartedAt;
    if (started == null) return null;
    final left =
        started.add(kReadyCheckTimeout).difference(now ?? DateTime.now());
    if (left.isNegative) return Duration.zero;
    return left;
  }

  void _syncReadyCheckTimer(
    LobbyReadyLockSnapshot snapshot, {
    bool armedByReady = false,
  }) {
    if (snapshot.isLocked || snapshot.readyUids.isEmpty) {
      _disarmReadyCheckTimer();
      return;
    }
    if (armedByReady) {
      _armReadyCheckTimer();
    }
  }

  void _armReadyCheckTimer() {
    if (_readyCheckTimer != null && _readyCheckTimer!.isActive) return;
    _readyCheckStartedAt ??= DateTime.now();
    final remaining = readyCheckRemaining() ?? kReadyCheckTimeout;
    if (remaining <= Duration.zero) {
      unawaited(timeoutReadyCheck());
      return;
    }
    _readyCheckTimer = Timer(remaining, () {
      unawaited(timeoutReadyCheck());
    });
  }

  void _disarmReadyCheckTimer() {
    _readyCheckTimer?.cancel();
    _readyCheckTimer = null;
    _readyCheckStartedAt = null;
  }

  Future<void> _patchSpotLocally({
    required int spotIndex,
    required String? occupant,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final lobby = current.currentLobby;
    if (lobby == null) return;
    final spots = List<String?>.from(lobby.spots);
    while (spots.length <= spotIndex) {
      spots.add(null);
    }
    spots[spotIndex] = occupant;
    final game = lobby.gameName;
    final gameSpots = Map<String, List<String?>>.from(current.gameLobbySpots);
    if (game.isNotEmpty) {
      gameSpots[game] = spots;
    }
    state = AsyncData(
      current.copyWith(
        currentLobby: lobby.copyWith(spots: spots),
        gameLobbySpots: gameSpots,
      ),
    );
  }

  void _applyMemberStatusLocally({
    required String userId,
    required String status,
    required String gameName,
  }) {
    final current = state.valueOrNull;
    if (current == null) return;
    final global = Map<String, String>.from(current.globalStatuses);
    global[userId] = status;
    final gameStatuses =
        Map<String, Map<String, String>>.from(current.gameStatuses);
    if (gameName.isNotEmpty) {
      final perGame = Map<String, String>.from(gameStatuses[gameName] ?? {});
      perGame[userId] = status;
      gameStatuses[gameName] = perGame;
    }
    final lobby = current.currentLobby;
    state = AsyncData(
      current.copyWith(
        globalStatuses: global,
        gameStatuses: gameStatuses,
        currentLobby: lobby == null
            ? lobby
            : lobby.copyWith(
                statuses: {...lobby.statuses, userId: status},
              ),
      ),
    );
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
          final timerNotifier =
              ref.read(timerManagementNotifierProvider.notifier);
          await timerNotifier.stopSpotTimer(gameName, userId);
        }
        // Reload state
        state = await AsyncValue.guard(() => _loadPersistedLobbyState());
      }
    }
  }

  /// Records a win for the current lobby.
  ///
  /// [sessionRating] is reduced then encoded into existing
  /// `match_history.notes` (no new table). Skip / unrated leaves notes null.
  Future<void> recordWin(
    String lobbyId, {
    SessionRatingState? sessionRating,
  }) async {
    try {
      final currentState = state.value;
      if (currentState == null) return;

      final lobby = currentState.userLobbies.values.firstWhere(
        (l) => l.id == lobbyId,
        orElse: () => throw Exception('Lobby not found'),
      );

      final rating = _reduceEndedSessionRating(
        sessionRating,
        lobbyId: lobbyId,
        gameName: lobby.gameName,
        result: 'win',
      );
      final notes = notesForSessionRating(rating);

      await _repository.recordMatchResult(
        lobbyId: lobbyId,
        gameName: lobby.gameName,
        result: 'win',
        playerUids: lobby.memberUids,
        notes: notes,
      );
      _appendMatchToHistory(
        lobbyId: lobbyId,
        gameName: lobby.gameName,
        result: 'win',
        playerUids: lobby.memberUids,
        rating: rating,
      );
      unawaited(SquadAnalytics.logSessionRate(
        stars: rating.stars,
        result: 'win',
        skipped: !rating.isRated,
      ));

      debugPrint('LobbyNotifier: ✅ Win recorded for lobby $lobbyId');
    } catch (e, stackTrace) {
      debugPrint('LobbyNotifier: ❌ ERROR recording win: $e');
      await _errorHandler.handleError(
        error: e,
        operation: 'recordWin',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Records a loss for the current lobby. Same notes path as [recordWin].
  Future<void> recordLoss(
    String lobbyId, {
    SessionRatingState? sessionRating,
  }) async {
    try {
      final currentState = state.value;
      if (currentState == null) return;

      final lobby = currentState.userLobbies.values.firstWhere(
        (l) => l.id == lobbyId,
        orElse: () => throw Exception('Lobby not found'),
      );

      final rating = _reduceEndedSessionRating(
        sessionRating,
        lobbyId: lobbyId,
        gameName: lobby.gameName,
        result: 'loss',
      );
      final notes = notesForSessionRating(rating);

      await _repository.recordMatchResult(
        lobbyId: lobbyId,
        gameName: lobby.gameName,
        result: 'loss',
        playerUids: lobby.memberUids,
        notes: notes,
      );
      _appendMatchToHistory(
        lobbyId: lobbyId,
        gameName: lobby.gameName,
        result: 'loss',
        playerUids: lobby.memberUids,
        rating: rating,
      );
      unawaited(SquadAnalytics.logSessionRate(
        stars: rating.stars,
        result: 'loss',
        skipped: !rating.isRated,
      ));

      debugPrint('LobbyNotifier: ✅ Loss recorded for lobby $lobbyId');
    } catch (e, stackTrace) {
      debugPrint('LobbyNotifier: ❌ ERROR recording loss: $e');
      await _errorHandler.handleError(
        error: e,
        operation: 'recordLoss',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  SessionRatingState _reduceEndedSessionRating(
    SessionRatingState? sessionRating, {
    required String lobbyId,
    required String gameName,
    required String result,
  }) {
    final current = sessionRating ?? SessionRatingState.unrated;
    final resolvedStars = sessionStarsFromSheet(
      stars: current.stars,
      vibes: current.vibes,
      comms: current.comms,
      gunny: current.gunny,
      wingman: current.wingman,
    );
    final event = isValidSessionStars(resolvedStars)
        ? SessionRatingEvent.rate
        : SessionRatingEvent.skip;
    return reduceSessionRating(
      current: current,
      event: event,
      stars: current.stars,
      vibes: current.vibes,
      comms: current.comms,
      gunny: current.gunny,
      wingman: current.wingman,
      lobbyId: lobbyId,
      raterUid: current.raterUid,
      matchId: current.matchId,
      gameName: gameName,
      result: result,
      comment: current.comment,
      ratedAt: current.ratedAt,
      clip: current.clip,
    );
  }

  /// Get lobby statistics (W/L record)
  Future<Map<String, dynamic>> getLobbyStats(String lobbyId) async {
    try {
      return await _repository.getLobbyStats(lobbyId);
    } catch (e) {
      debugPrint('LobbyNotifier: ❌ ERROR fetching lobby stats: $e');
      return {
        'total_matches': 0,
        'wins': 0,
        'losses': 0,
        'draws': 0,
        'win_rate': 0.0,
      };
    }
  }

  /// Match rows from `match_history` for [lobbyId] (newest first).
  Future<List<Map<String, dynamic>>> getMatchHistory(String lobbyId) async {
    try {
      return await _repository.getMatchHistory(lobbyId);
    } catch (e) {
      debugPrint('LobbyNotifier: ❌ ERROR fetching match history: $e');
      return const [];
    }
  }

  void _appendMatchToHistory({
    required String lobbyId,
    required String gameName,
    required String result,
    required List<String> playerUids,
    required SessionRatingState rating,
  }) {
    final current = state.value;
    if (current == null) return;
    final now = DateTime.now().toUtc();
    final rows = [
      for (final row in current.gameHistory) Map<String, dynamic>.from(row),
    ];
    final existingIndex = rows.indexWhere(
      (row) =>
          row['lobby_id']?.toString() == lobbyId &&
          isRecentMatchHistoryRow(row, now: now),
    );
    final base = existingIndex >= 0
        ? rows[existingIndex]
        : <String, dynamic>{
            'lobby_id': lobbyId,
            'created_at': now.toIso8601String(),
          };
    final row = applySessionRatingToMatchRow(
      row: {
        ...base,
        'lobby_id': lobbyId,
        'game_name': gameName,
        'result': result,
        'player_uids': List<String>.from(playerUids),
      },
      rating: rating,
    );
    if (existingIndex >= 0) {
      rows[existingIndex] = row;
    } else {
      rows.insert(0, row);
    }
    state = AsyncData(current.copyWith(gameHistory: rows));
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
        state = await AsyncValue.guard(() => _loadPersistedLobbyState());
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
        // Delegate timer reset to TimerManagementNotifier
        final timerNotifier =
            ref.read(timerManagementNotifierProvider.notifier);
        await timerNotifier.resetTimersForGame(
            gameName, squadState.gameLobbySpots);

        // Reload state
        state = await AsyncValue.guard(() => _loadPersistedLobbyState());
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

      // Ratings persist via UserNotifier / Supabase users table.
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

        // Delegate timer management to TimerManagementNotifier
        final timerNotifier =
            ref.read(timerManagementNotifierProvider.notifier);
        await timerNotifier.startSpotTimer(
            squadId, gameName, spotIndex, userId, const Duration(minutes: 5));

        // Reload state
        state = await AsyncValue.guard(() => _loadPersistedLobbyState());
      }
    }
  }

  Future<void> claimPeacockSpot(
      String lobbyId, String userId, String gameName) async {
    await addToPeacockQueue(userId, gameName);
  }

  Future<void> lockPeacockSpot(
      String lobbyId, String userId, String gameName) async {
    await removeFromPeacockQueue(userId);
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

  void setSelectedLobbyId(String? lobbyId) {
    state = state.whenData(
        (currentState) => currentState.copyWith(selectedLobbyId: lobbyId));

    // Update current lobby subscription
    if (lobbyId != null) {
      _subscribeToCurrentLobby(lobbyId);
    } else {
      _currentLobbySubscription?.cancel();
      _currentSubscribedLobbyId = null;
      _lobbyChannelErrorRetries = 0;
    }
  }

  // ========== Methods from CurrentLobbyNotifier ==========

  /// Claim a spot in the current lobby (simplified version for CurrentLobbyNotifier compatibility)
  Future<void> claimSpotSimple(int spotIndex) async {
    final currentState = state.valueOrNull;
    final lobby = currentState?.currentLobby;
    if (lobby == null) return;

    final uid = AuthServiceSupabase().currentUser?.id;
    if (uid == null) return;

    final currentClaim =
        spotIndex < lobby.spots.length ? lobby.spots[spotIndex] : null;

    // Can only claim if spot is null or already claimed by this user
    if (currentClaim != null && currentClaim != uid) return;

    // Check if within maxSpots
    if (spotIndex >= lobby.maxSpots) return;

    // Use repository to assign spot
    await _repository.assignSpot(lobby.id, spotIndex, uid);
    await _patchSpotLocally(spotIndex: spotIndex, occupant: uid);
    await reconcileReadyLock(actorUid: uid, notify: true);
  }

  /// Unclaim a spot in the current lobby (simplified version for CurrentLobbyNotifier compatibility)
  Future<void> unclaimSpotSimple(int spotIndex) async {
    final currentState = state.valueOrNull;
    final lobby = currentState?.currentLobby;
    if (lobby == null) return;

    final uid = AuthServiceSupabase().currentUser?.id;
    if (uid == null) return;

    final currentClaim =
        spotIndex < lobby.spots.length ? lobby.spots[spotIndex] : null;

    // Can only unclaim own spot
    if (currentClaim != uid) return;

    // Use repository to clear spot
    await _repository.assignSpot(lobby.id, spotIndex, null);
  }

  /// Update user status in the current lobby
  Future<void> updateStatus(String status) async {
    final currentState = state.valueOrNull;
    final lobby = currentState?.currentLobby;
    if (lobby == null) return;

    final uid = AuthServiceSupabase().currentUser?.id;
    if (uid == null) return;

    // Use repository to update member status
    await _repository.updateMemberStatus(lobby.id, uid, status);
  }

  /// Update last activity timestamp for the current lobby
  Future<void> updateLastActivity() async {
    final currentState = state.valueOrNull;
    final lobby = currentState?.currentLobby;
    if (lobby == null) return;

    // Track lobby activity event
    await _repository.trackLobbyEvent('activity_update', {
      'lobbyId': lobby.id,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Leave the current lobby
  Future<void> leaveLobby() async {
    final currentState = state.valueOrNull;
    final lobby = currentState?.currentLobby;
    if (lobby == null) return;

    final uid = AuthServiceSupabase().currentUser?.id;
    if (uid == null) return;

    // Use repository to leave lobby
    await _repository.leaveLobby(lobby.id, uid);

    // Clear current lobby selection
    setSelectedLobbyId(null);
  }

  /// Delete a lobby (only when all spots are empty and user leaves screen)
  Future<void> deleteLobby(String lobbyId) async {
    try {
      await _repository.deleteLobby(lobbyId);

      // Reload state to remove deleted lobby
      state = await AsyncValue.guard(() => _loadPersistedLobbyState());

      debugPrint('✅ Lobby $lobbyId deleted successfully');
    } catch (e, stackTrace) {
      await _errorHandler.handleError(
        error: e,
        operation: 'deleteLobby',
        stackTrace: stackTrace,
        showSnackBar: false,
      );
      rethrow;
    }
  }

  /// Create lobby with constitution rules applied
  Future<String> createLobbyWithConstitution({
    required String chatGroupId,
    required String gameName,
    required int maxSpots,
    required List<String> tags,
    required String visibility,
    String? embeddedMessageId,
  }) async {
    try {
      debugPrint('🎮 Creating lobby with constitution...');

      // Get active constitution
      final constitution =
          await _constitutionManager.getActiveConstitution(chatGroupId);

      // Create base lobby
      final lobbyId = await createLobby(
        chatGroupId: chatGroupId,
        gameName: gameName,
        maxSpots: maxSpots,
        isPublic: visibility == 'public',
      );

      // Update lobby with tags, visibility, and constitution rules
      await ref.read(supabaseClientProvider).from('lobbies').update({
        'tags': tags,
        'visibility': visibility,
        'constitution_rules': constitution?.rules ?? {},
        'embedded_message_id': embeddedMessageId,
        'chat_group_id': chatGroupId,
      }).eq('id', lobbyId);

      debugPrint('✅ Lobby created with constitution: $lobbyId');

      // Reload state
      state = await AsyncValue.guard(() => _loadPersistedLobbyState());

      return lobbyId;
    } catch (e, stackTrace) {
      await _errorHandler.handleError(
        error: e,
        operation: 'createLobbyWithConstitution',
        stackTrace: stackTrace,
        showSnackBar: false,
      );
      rethrow;
    }
  }

  /// Send lobby invite as embedded message in chat
  Future<String> sendLobbyInviteMessage({
    required String lobbyId,
    required String chatGroupId,
  }) async {
    try {
      final currentUser = AuthServiceSupabase().currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get lobby data
      final lobbyData = await SupabaseService.client
          .from('lobbies')
          .select()
          .eq('id', lobbyId)
          .single();

      // Send system message with lobby embed
      final messageResponse = await SupabaseService.client
          .from('chat_messages')
          .insert({
            'chat_group_id': chatGroupId,
            'sender_uid': currentUser.id,
            'message_type': 'system',
            'content': '🎮 New lobby created',
            'metadata': {
              'lobby_id': lobbyId,
              'game_name': lobbyData['game_name'],
              'tags': lobbyData['tags'],
              'visibility': lobbyData['visibility'],
              'max_spots':
                  lobbyData['max_spots'] ?? lobbyData['lobby_spots'].length,
            },
          })
          .select()
          .single();

      final messageId = messageResponse['id'] as String;

      // Update lobby with embedded message ID
      await SupabaseService.client
          .from('lobbies')
          .update({'embedded_message_id': messageId}).eq('id', lobbyId);

      debugPrint('✅ Lobby invite message sent: $messageId');
      return messageId;
    } catch (e) {
      debugPrint('Error sending lobby invite: $e');
      rethrow;
    }
  }

  /// Record a constitution violation (called by timer system)
  Future<void> recordViolation({
    required String lobbyId,
    required String chatGroupId,
    required String userUid,
    required String ruleType,
    Map<String, dynamic>? violationData,
  }) async {
    try {
      await _constitutionManager.recordViolation(
        lobbyId: lobbyId,
        chatGroupId: chatGroupId,
        userUid: userUid,
        ruleType: ruleType,
        violationData: violationData,
      );

      debugPrint('📝 Violation recorded: $ruleType for user $userUid');
    } catch (e) {
      debugPrint('Error recording violation: $e');
    }
  }

  /// Get constitution templates for group settings
  Future<List<ConstitutionTemplate>> getConstitutionTemplates() async {
    return await _constitutionManager.getTemplates();
  }

  /// Create constitution from template
  Future<ChatConstitution?> createConstitutionFromTemplate({
    required String chatGroupId,
    required String templateId,
    required String createdBy,
  }) async {
    return await _constitutionManager.createFromTemplate(
      chatGroupId: chatGroupId,
      templateId: templateId,
      createdBy: createdBy,
    );
  }

  /// Create vote for constitution changes
  Future<ConstitutionVote?> createConstitutionVote({
    required String constitutionId,
    required String chatGroupId,
    required String proposedBy,
    required Map<String, dynamic> proposedRules,
    double voteThreshold = 0.5,
  }) async {
    return await _constitutionManager.createVote(
      constitutionId: constitutionId,
      chatGroupId: chatGroupId,
      proposedBy: proposedBy,
      proposedRules: proposedRules,
      voteThreshold: voteThreshold,
    );
  }

  /// Get active votes for a chat group
  Future<List<ConstitutionVote>> getActiveVotes(String chatGroupId) async {
    return await _constitutionManager.getActiveVotes(chatGroupId);
  }
}

final lobbyNotifierProvider = AsyncNotifierProvider<LobbyNotifier, LobbyState>(
  LobbyNotifier.new,
);

// ========== Compatibility Providers ==========

/// Provider for current lobby ID (Riverpod 3.0 compatible)
/// Watches lobbyNotifier's selectedLobbyId
final currentLobbyIdProvider = Provider<String?>((ref) {
  return ref.watch(lobbyNotifierProvider.select(
    (asyncState) => asyncState.valueOrNull?.selectedLobbyId,
  ));
});

/// Provider for current lobby (compatibility with old currentLobbyProvider)
final currentLobbyProvider = Provider<AsyncValue<Lobby?>>((ref) {
  final lobbyState = ref.watch(lobbyNotifierProvider);
  return lobbyState.when(
    data: (state) => AsyncData(state.currentLobby),
    loading: () => const AsyncLoading(),
    error: (error, stack) => AsyncError(error, stack),
  );
});

bool _isSpotOccupied(String? uid) => uid != null && uid.isNotEmpty;

bool _spotHeldBy(String? occupant, String userId) {
  if (occupant == null || occupant.isEmpty) return false;
  return occupant == userId || occupant == '${userId}_calling';
}

/// First empty seat, or the next index when [spots] is shorter than
/// [maxSpots]. Reuses [userId]'s existing seat. Null when unknown/full.
int? resolveNextFreeSpotIndex({
  List<String?>? spots,
  int? maxSpots,
  String? userId,
}) {
  if (spots == null && maxSpots == null) return null;
  final list = spots ?? const <String?>[];
  if (userId != null && userId.isNotEmpty) {
    final existing = list.indexWhere((uid) => _spotHeldBy(uid, userId));
    if (existing >= 0) return existing;
  }
  final free = list.indexWhere((uid) => !_isSpotOccupied(uid));
  if (free >= 0) return free;
  final cap = maxSpots ?? list.length;
  if (list.length < cap) return list.length;
  return null;
}

Lobby? lobbyForSeatResolve(LobbyState state, String? lobbyId) {
  if (lobbyId == null || lobbyId.isEmpty) return null;
  final current = state.currentLobby;
  if (current != null &&
      (current.id == lobbyId || current.chatGroupId == lobbyId)) {
    return current;
  }
  final byId = state.userLobbies[lobbyId];
  if (byId != null) return byId;
  for (final lobby in state.userLobbies.values) {
    if (lobby.chatGroupId == lobbyId) return lobby;
  }
  return null;
}

/// Prefer [currentLobby] / [LobbyState.userLobbies], then game-scoped spots.
int? resolveNextFreeSpotFromLobbyState({
  required LobbyState state,
  String? lobbyId,
  String? gameName,
  String? userId,
}) {
  final lobby = lobbyForSeatResolve(state, lobbyId);
  if (lobby != null) {
    return resolveNextFreeSpotIndex(
      spots: lobby.spots,
      maxSpots: lobby.maxSpots,
      userId: userId,
    );
  }
  if (gameName != null && gameName.isNotEmpty) {
    final spots = state.gameLobbySpots[gameName];
    if (spots != null) {
      return resolveNextFreeSpotIndex(spots: spots, userId: userId);
    }
  }
  return null;
}
