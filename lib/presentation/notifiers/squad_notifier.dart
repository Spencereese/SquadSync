import 'package:riverpod_annotation/riverpod_annotation.dart';
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

part 'squad_notifier.g.dart';

@riverpod
class SquadNotifier extends _$SquadNotifier {
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

  @override
  Future<SquadState> build() async {
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

    return await _loadSquadState();
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

  Future<void> startSpotTimer(String squadId, int spotIndex, Duration duration) async {
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

  Future<void> updateMemberStatus(String squadId, String userId, String status) async {
    await _updateMemberStatus(squadId, userId, status);
    state = await AsyncValue.guard(() => _loadSquadState());
  }

  Future<void> syncSquadData() async {
    await _syncSquadData();
    state = await AsyncValue.guard(() => _loadSquadState());
  }

  // Computed properties for game-scoped data
  Map<String, List<String?>> get gameSquadSpots => state.maybeWhen(
        data: (data) => data.gameSquadSpots,
        orElse: () => {},
      );

  Map<String, List<Map<String, dynamic>?>> get gameSpotTimers => state.maybeWhen(
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
      data: (data) => data.userSquads[squadId]?.memberUids.contains(userId) ?? false,
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
}