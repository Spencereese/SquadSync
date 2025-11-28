import 'package:riverpod/riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:squad_sync/domain/entities/squad_state.dart';
import 'package:squad_sync/domain/usecases/create_squad.dart';
import 'package:squad_sync/domain/usecases/join_squad.dart';
import 'package:squad_sync/domain/usecases/leave_squad.dart';
import 'package:squad_sync/domain/usecases/assign_spot.dart';
import 'package:squad_sync/domain/usecases/start_spot_timer.dart';
import 'package:squad_sync/domain/usecases/process_timers.dart';
import 'package:squad_sync/domain/usecases/manage_peacock_queue.dart';
import 'package:squad_sync/domain/usecases/update_member_status.dart';
import 'package:squad_sync/domain/usecases/load_squad_state.dart';
import 'package:squad_sync/domain/usecases/sync_squad_data.dart';
import 'package:squad_sync/core/injection.dart' as di;
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/timer_service.dart';

class SquadNotifier extends AutoDisposeAsyncNotifier<SquadState> {
  late final CreateSquad _createSquad;
  late final JoinSquad _joinSquad;
  late final LeaveSquad _leaveSquad;
  late final AssignSpot _assignSpot;
  late final StartSpotTimer _startSpotTimer;
  late final ProcessTimers _processTimers;
  late final ManagePeacockQueue _managePeacockQueue;
  late final UpdateMemberStatus _updateMemberStatus;
  late final LoadSquadState _loadSquadState;
  late final SyncSquadData _syncSquadData;
  late final TimerServiceNotifier _timerService;

  @override
  Future<SquadState> build() async {
    try {
      // Get dependencies from get_it
      _createSquad = di.getIt<CreateSquad>();
      _joinSquad = di.getIt<JoinSquad>();
      _leaveSquad = di.getIt<LeaveSquad>();
      _assignSpot = di.getIt<AssignSpot>();
      _startSpotTimer = di.getIt<StartSpotTimer>();
      _processTimers = di.getIt<ProcessTimers>();
      _managePeacockQueue = di.getIt<ManagePeacockQueue>();
      _updateMemberStatus = di.getIt<UpdateMemberStatus>();
      _loadSquadState = di.getIt<LoadSquadState>();
      _syncSquadData = di.getIt<SyncSquadData>();

      _timerService = ref.watch(timerServiceProvider.notifier);

      // Load state synchronously to ensure proper loading state transition
      return await _loadState();
    } catch (e) {
      debugPrint('Error initializing squad notifier: $e');
      return SquadState.initial();
    }
  }

  Future<SquadState> _loadState() async {
    try {
      debugPrint('SquadNotifier: Loading squad state...');
      // Add timeout to prevent indefinite hanging
      final state = await _loadSquadState.call().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint(
              'SquadNotifier: Load state timed out, using initial state');
          return SquadState.initial();
        },
      );
      debugPrint('SquadNotifier: Squad state loaded successfully');
      return state;
    } catch (e, stackTrace) {
      debugPrint('SquadNotifier: Error loading squad state: $e');
      debugPrint('SquadNotifier: Stack trace: $stackTrace');
      return SquadState.initial();
    }
  }

  Future<void> createSquad(String name, String gameName, int maxSpots) async {
    await _createSquad(name, gameName, maxSpots);
    state = await AsyncValue.guard(() => _loadSquadState());
  }

  Future<void> joinSquad(String squadId, String userId) async {
    await _joinSquad(squadId, userId);
    state = await AsyncValue.guard(() => _loadSquadState());
  }

  Future<void> leaveSquad(String squadId, String userId) async {
    await _leaveSquad(squadId, userId);
    state = await AsyncValue.guard(() => _loadSquadState());
  }

  Future<void> assignSpot(String squadId, int spotIndex, String? userId) async {
    await _assignSpot(squadId, spotIndex, userId);
    state = await AsyncValue.guard(() => _loadSquadState());
  }

  Future<void> startSpotTimer(
      String squadId, int spotIndex, Duration duration) async {
    await _startSpotTimer(squadId, spotIndex, duration);
    state = await AsyncValue.guard(() => _loadSquadState());
  }

  Future<void> processExpiredTimers() async {
    await _processTimers();
    state = await AsyncValue.guard(() => _loadSquadState());
  }

  Future<void> addToPeacockQueue(String userId, String gameName) async {
    await _managePeacockQueue.addToQueue(userId, gameName);
    state = await AsyncValue.guard(() => _loadSquadState());
  }

  Future<void> removeFromPeacockQueue(String userId) async {
    await _managePeacockQueue.removeFromQueue(userId);
    state = await AsyncValue.guard(() => _loadSquadState());
  }

  Future<void> processPeacockQueue() async {
    await _managePeacockQueue.processQueue();
    state = await AsyncValue.guard(() => _loadSquadState());
  }

  Future<void> updateMemberStatus(
      String squadId, String userId, String status) async {
    await _updateMemberStatus(squadId, userId, status);
    state = await AsyncValue.guard(() => _loadSquadState());
  }

  Future<void> syncSquadData() async {
    await _syncSquadData();
    state = await AsyncValue.guard(() => _loadSquadState());
  }

  // TODO: Implement setCurrentGame method
  Future<void> setCurrentGame(Map<String, dynamic>? game) async {
    // Placeholder implementation
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
  Map<String, List<String?>> get gameSquadSpots => state.maybeWhen(
        data: (data) => data.gameSquadSpots,
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
    return gameSquadSpots[gameName] ?? [];
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
          data.userSquads[squadId]?.memberUids.contains(userId) ?? false,
      orElse: () => false,
    );
  }

  int getActiveSquadMembersCount(String? squadId) {
    if (squadId == null) return 0;
    return state.maybeWhen(
      data: (data) => data.userSquads[squadId]?.memberUids.length ?? 0,
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

  // TODO: Implement claimSpot method
  Future<void> claimSpot(String gameName, int spotIndex) async {
    // TODO: Implement spot claiming
  }

  // TODO: Implement lockSpot method
  Future<void> lockSpot(String gameName, int spotIndex) async {
    // TODO: Implement spot locking
  }

  // TODO: Implement removeSpot method
  Future<void> removeSpot(String gameName, int spotIndex) async {
    // TODO: Implement spot removal
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
        data: (data) => data.squadMemberUids,
        orElse: () => [],
      );

  // TODO: Implement clearAllSpots method
  Future<void> clearAllSpots(String gameName) async {
    // TODO: Implement clearing all spots
  }

  // TODO: Implement resetTimers method
  Future<void> resetTimers(String gameName) async {
    // TODO: Implement timer reset
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
      final squadId = squadState.selectedSquadId;
      if (squadId != null) {
        final userId = FirebaseAuth.instance.currentUser!.uid;
        await _assignSpot(squadId, spotIndex, userId);
        // Start the timer
        await _timerService.startSpotTimer(
            gameName, userId, const Duration(minutes: 5));
        // Reload state
        state = await AsyncValue.guard(() => _loadSquadState());
      }
    }
  }

  Future<void> claimPeacockSpot(
      String lobbyId, String userId, String gameName) async {
    await _managePeacockQueue.addToQueue(userId, gameName);
  }

  Future<void> lockPeacockSpot(
      String lobbyId, String userId, String gameName) async {
    await _managePeacockQueue.removeFromQueue(userId);
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

  void setSelectedSquadId(String? squadId) {
    state = state.whenData(
        (squadState) => squadState.copyWith(selectedSquadId: squadId));
  }
}

final squadNotifierProvider =
    AutoDisposeAsyncNotifierProvider<SquadNotifier, SquadState>(
  () => SquadNotifier(),
);
