import '../domain/entities/lobby_state.dart';
import '../presentation/notifiers/lobby_notifier.dart'
    show lobbyForSeatResolve, resolveNextFreeSpotIndex;
import 'matchmaking_queue_machine.dart';
import 'peacock_assignment_machine.dart';

/// Lobby status chip: seated / peacock / lock mm:ss.
///
/// Derived from existing [PeacockAssignmentState] + LFG tracker + lobby
/// spots/timers. Not a new product machine — [reducePeacockAssignment]
/// and [reduceMatchmakingQueue] stay the reducers.
enum LobbySeatChipKind {
  seated,
  peacock,
  lock,
}

/// Snapshot of chip / pulse / offer-banner copy for one user.
class LobbySeatStatus {
  const LobbySeatStatus({
    required this.chip,
    this.seatIndex,
    this.lockRemaining,
    this.offerPending = false,
  });

  final LobbySeatChipKind chip;

  /// 0-based seat. Null when the offered/held seat is unknown.
  final int? seatIndex;
  final Duration? lockRemaining;

  /// True when peacock assigned/notified or LFG matched with a lobby,
  /// and the user is not already seated.
  final bool offerPending;

  int? get seatNumber => seatIndex == null ? null : seatIndex! + 1;

  String get chipLabel {
    switch (chip) {
      case LobbySeatChipKind.seated:
        return 'seated';
      case LobbySeatChipKind.peacock:
        return 'peacock';
      case LobbySeatChipKind.lock:
        return 'lock ${formatLockMmSs(lockRemaining ?? Duration.zero)}';
    }
  }

  bool get showOfferBanner => offerPending;

  bool get pulseOfferedSpot => offerPending && seatIndex != null;
}

/// `Claim seat N` when [seatIndex] is known; otherwise `Claim seat`.
String claimSeatCopy(int? seatIndex) {
  if (seatIndex == null) return 'Claim seat';
  return 'Claim seat ${seatIndex + 1}';
}

/// Snackbar after LFG join / peacock handoff. Replaces
/// "Handed off — claim spot in lobby".
String lfgJoinSnackbarMessage({
  int? claimedSpot,
  required bool handedOff,
}) {
  if (claimedSpot != null || handedOff) return claimSeatCopy(claimedSpot);
  return 'Squad joined';
}

String formatLockMmSs(Duration remaining) {
  final clamped = remaining.isNegative ? Duration.zero : remaining;
  final minutes = clamped.inMinutes;
  final seconds = clamped.inSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

bool spotHeldByUser(String? occupant, String userId) {
  if (occupant == null || occupant.isEmpty || userId.isEmpty) return false;
  return occupant == userId || occupant == '${userId}_calling';
}

bool occupantIsCalling(String? occupant, String? occupantStatus) {
  if (occupant != null && occupant.endsWith('_calling')) return true;
  return occupantStatus == 'Calling';
}

/// First held seat, else next free when an offer is pending.
int? resolveOfferedSeatIndex({
  required List<String?> spots,
  int? maxSpots,
  required String userId,
  required bool offerPending,
}) {
  if (userId.isEmpty) return null;
  final held = spots.indexWhere((uid) => spotHeldByUser(uid, userId));
  if (held >= 0) return held;
  if (!offerPending) return null;
  return resolveNextFreeSpotIndex(
    spots: spots,
    maxSpots: maxSpots,
    userId: userId,
  );
}

bool _peacockOffered(PeacockAssignmentState peacock) =>
    peacock.phase == PeacockAssignmentPhase.assigned ||
    peacock.phase == PeacockAssignmentPhase.notified;

bool _lfgOffered(MatchmakingQueueEntry lfg) =>
    lfg.phase == MatchmakingQueuePhase.matched && lfg.hasJoinTarget;

bool _inPeacockOrLfg(
  PeacockAssignmentState peacock,
  MatchmakingQueueEntry lfg,
) {
  if (peacock.phase == PeacockAssignmentPhase.queued ||
      peacock.phase == PeacockAssignmentPhase.assigned ||
      peacock.phase == PeacockAssignmentPhase.notified) {
    return true;
  }
  return lfg.phase == MatchmakingQueuePhase.looking ||
      lfg.phase == MatchmakingQueuePhase.matched ||
      lfg.phase == MatchmakingQueuePhase.joined;
}

/// Chip + pulse + banner flags from existing peacock + LFG + spots.
///
/// Returns null when the user is idle (no chip).
LobbySeatStatus? resolveLobbySeatStatus({
  required String? userId,
  required PeacockAssignmentState peacock,
  required MatchmakingQueueEntry lfg,
  List<String?> spots = const [],
  int? maxSpots,
  Duration? lockRemaining,
  String? occupantStatus,
}) {
  if (userId == null || userId.isEmpty) return null;

  final offered = _peacockOffered(peacock) || _lfgOffered(lfg);
  final held = spots.indexWhere((uid) => spotHeldByUser(uid, userId));
  final occupying = held >= 0;
  final occupant = occupying ? spots[held] : null;
  final calling = occupying && occupantIsCalling(occupant, occupantStatus);
  final lockTick = lockRemaining != null && lockRemaining > Duration.zero;
  final showLock = lockTick && (calling || offered);

  final seatIndex = resolveOfferedSeatIndex(
    spots: spots,
    maxSpots: maxSpots,
    userId: userId,
    offerPending: offered,
  );

  final LobbySeatChipKind? kind;
  if (showLock) {
    kind = LobbySeatChipKind.lock;
  } else if (occupying) {
    kind = LobbySeatChipKind.seated;
  } else if (_inPeacockOrLfg(peacock, lfg)) {
    kind = LobbySeatChipKind.peacock;
  } else {
    kind = null;
  }
  if (kind == null) return null;

  final seated = kind == LobbySeatChipKind.seated;
  return LobbySeatStatus(
    chip: kind,
    seatIndex: seatIndex,
    lockRemaining: showLock ? lockRemaining : null,
    offerPending: offered && !seated,
  );
}

List<String?> spotsForSeatStatus(
  LobbyState? state, {
  String? lobbyId,
  String? gameName,
}) {
  if (state == null) return const <String?>[];
  final id = lobbyId ?? state.selectedLobbyId ?? state.currentLobby?.id;
  final lobby = lobbyForSeatResolve(state, id);
  if (lobby != null) return lobby.spots;
  final game = gameName ?? state.currentGame?['name'] as String?;
  if (game != null && game.isNotEmpty) {
    return state.gameLobbySpots[game] ?? const <String?>[];
  }
  return const <String?>[];
}

int? maxSpotsForSeatStatus(LobbyState? state, {String? lobbyId}) {
  if (state == null) return null;
  final id = lobbyId ?? state.selectedLobbyId ?? state.currentLobby?.id;
  final lobby = lobbyForSeatResolve(state, id);
  if (lobby != null) return lobby.maxSpots;
  final raw = state.currentGame?['maxSpots'];
  if (raw is int) return raw;
  return null;
}

Duration? lockRemainingForUser({
  required LobbyState state,
  required String userId,
  String? gameName,
  int? seatIndex,
}) {
  final game = gameName ?? state.currentGame?['name'] as String?;
  if (game != null && game.isNotEmpty) {
    final fromSpot = state.spotTimerStates['spot_${game}_$userId'];
    if (fromSpot != null && fromSpot > Duration.zero) return fromSpot;
  }
  final fromPeacock = state.peacockTimerStates[userId];
  if (fromPeacock != null && fromPeacock > Duration.zero) return fromPeacock;
  if (game != null && seatIndex != null) {
    final timers = state.gameSpotTimers[game];
    if (timers != null && seatIndex >= 0 && seatIndex < timers.length) {
      final remaining = timers[seatIndex]?['remaining'];
      if (remaining is int && remaining > 0) {
        return Duration(seconds: remaining);
      }
    }
  }
  return null;
}

String? occupantStatusForUser({
  required LobbyState state,
  required String userId,
  String? gameName,
}) {
  final global = state.globalStatuses[userId];
  if (global != null && global.isNotEmpty) return global;
  final game = gameName ?? state.currentGame?['name'] as String?;
  if (game != null && game.isNotEmpty) {
    final fromGame = state.gameStatuses[game]?[userId];
    if (fromGame != null && fromGame.isNotEmpty) return fromGame;
  }
  final fromLobby = state.currentLobby?.statuses[userId];
  if (fromLobby != null && fromLobby.isNotEmpty) return fromLobby;
  return null;
}

/// Live-path resolve: existing peacock + LFG trackers + lobby state.
LobbySeatStatus? resolveLobbySeatStatusFromTrackers({
  required String? userId,
  LobbyState? lobbyState,
  PeacockAssignmentTracker? peacock,
  MatchmakingQueueTracker? lfg,
  String? lobbyId,
  String? gameName,
}) {
  if (userId == null || userId.isEmpty) return null;
  final peacockState =
      (peacock ?? PeacockAssignmentTracker.instance).stateFor(userId);
  final lfgState = (lfg ?? MatchmakingQueueTracker.instance).stateFor(userId);
  final spots = spotsForSeatStatus(
    lobbyState,
    lobbyId: lobbyId ?? peacockState.lobbyId ?? lfgState.lobbyId,
    gameName: gameName ?? peacockState.gameName ?? lfgState.gameName,
  );
  final maxSpots = maxSpotsForSeatStatus(
    lobbyState,
    lobbyId: lobbyId ?? peacockState.lobbyId ?? lfgState.lobbyId,
  );
  final held = spots.indexWhere((uid) => spotHeldByUser(uid, userId));
  final lockRemaining = lobbyState == null
      ? null
      : lockRemainingForUser(
          state: lobbyState,
          userId: userId,
          gameName: gameName ?? peacockState.gameName ?? lfgState.gameName,
          seatIndex: held >= 0 ? held : null,
        );
  final occupantStatus = lobbyState == null
      ? null
      : occupantStatusForUser(
          state: lobbyState,
          userId: userId,
          gameName: gameName ?? peacockState.gameName ?? lfgState.gameName,
        );
  return resolveLobbySeatStatus(
    userId: userId,
    peacock: peacockState,
    lfg: lfgState,
    spots: spots,
    maxSpots: maxSpots,
    lockRemaining: lockRemaining,
    occupantStatus: occupantStatus,
  );
}

/// Decline: LFG [cancelLooking] (looking/matched) + peacock expire.
/// Does not notify — XOR stays [planPeacockSelfNotify] on assign/notify.
void declineOfferedSeat({
  required String userId,
  MatchmakingQueueTracker? lfg,
  required void Function(String userId) expirePeacock,
}) {
  final tracker = lfg ?? MatchmakingQueueTracker.instance;
  final entry = tracker.stateFor(userId);
  if (entry.phase == MatchmakingQueuePhase.looking ||
      entry.phase == MatchmakingQueuePhase.matched) {
    tracker.cancelLooking(userId);
  }
  expirePeacock(userId);
}
