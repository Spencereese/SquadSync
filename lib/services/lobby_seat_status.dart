import '../domain/entities/lobby_state.dart';
import '../presentation/notifiers/lobby_notifier.dart'
    show lobbyForSeatResolve, resolveNextFreeSpotIndex;
import 'matchmaking_queue_machine.dart';
import 'peacock_assignment_machine.dart';
import 'peacock_lifecycle_machine.dart';
import 'preferred_peacock_games.dart';

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
        return offerPending ? kTimerAssignedLabel : 'peacock';
      case LobbySeatChipKind.lock:
        return formatLockChipLabel(
          remaining: lockRemaining,
          queueAssigned: offerPending,
        );
    }
  }

  bool get showOfferBanner => offerPending;

  bool get pulseOfferedSpot => offerPending && seatIndex != null;
}

/// Pulse this [index] from live offer status or a deep-link `spot_index`.
/// Chat peacock card and notification taps share that query (ticket 35).
bool pulseOfferedSpotAt({
  required int index,
  LobbySeatStatus? status,
  int? highlightSpotIndex,
}) {
  if (highlightSpotIndex != null && highlightSpotIndex == index) return true;
  return status?.pulseOfferedSpot == true && status?.seatIndex == index;
}

/// Product journey from existing assignment + seat chip (ticket 14).
/// Idle with no chip is null — Expired / Declined are reducer terminals.
PeacockLifecyclePhase? resolvePeacockLifecycle({
  required PeacockAssignmentState peacock,
  LobbySeatStatus? seat,
}) {
  if (seat != null) {
    switch (seat.chip) {
      case LobbySeatChipKind.seated:
        return PeacockLifecyclePhase.seated;
      case LobbySeatChipKind.lock:
        if (timerRemainingIsExpired(seat.lockRemaining)) {
          return PeacockLifecyclePhase.expired;
        }
        return PeacockLifecyclePhase.lockIn;
      case LobbySeatChipKind.peacock:
        if (seat.offerPending) return PeacockLifecyclePhase.offered;
        return PeacockLifecyclePhase.waiting;
    }
  }
  switch (peacock.phase) {
    case PeacockAssignmentPhase.queued:
      return PeacockLifecyclePhase.waiting;
    case PeacockAssignmentPhase.assigned:
    case PeacockAssignmentPhase.notified:
      return PeacockLifecyclePhase.offered;
    case PeacockAssignmentPhase.idle:
      return null;
  }
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

/// process_expired_timers: remaining <= 0 frees the spot (expired).
/// Queue claim with a lock-in timer is assigned. Display only — server assigns.
const kTimerExpiredLabel = 'expired';
const kTimerAssignedLabel = 'assigned';

bool timerRemainingIsExpired(Duration? remaining) =>
    remaining != null && remaining <= Duration.zero;

/// Next-in-queue claim from process_expired_timers / peacock assign.
bool peacockPhaseIsAssigned(PeacockAssignmentState peacock) =>
    peacock.phase == PeacockAssignmentPhase.assigned ||
    peacock.phase == PeacockAssignmentPhase.notified;

Duration? remainingFromSpotTimer(Map<String, dynamic>? timer) {
  if (timer == null) return null;
  final raw = timer['remaining'];
  if (raw is int) return Duration(seconds: raw);
  if (raw is num) return Duration(seconds: raw.toInt());
  return null;
}

/// Client label aligned with process_expired_timers. Null when there is
/// no timer and no queue assignment to show.
String? formatTimerExpiryLabel({
  Duration? remaining,
  bool queueAssigned = false,
}) {
  if (timerRemainingIsExpired(remaining)) return kTimerExpiredLabel;
  if (queueAssigned) {
    if (remaining != null && remaining > Duration.zero) {
      return '$kTimerAssignedLabel ${formatLockMmSs(remaining)}';
    }
    return kTimerAssignedLabel;
  }
  if (remaining == null) return null;
  return formatLockMmSs(remaining);
}

String formatLockChipLabel({
  Duration? remaining,
  bool queueAssigned = false,
}) {
  if (timerRemainingIsExpired(remaining)) return kTimerExpiredLabel;
  if (queueAssigned) {
    if (remaining != null && remaining > Duration.zero) {
      return '$kTimerAssignedLabel ${formatLockMmSs(remaining)}';
    }
    return kTimerAssignedLabel;
  }
  return 'lock ${formatLockMmSs(remaining ?? Duration.zero)}';
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

bool _peacockOffered(
  PeacockAssignmentState peacock, {
  Set<String> preferredPeacockGames = const {},
}) {
  if (!peacockPhaseIsAssigned(peacock)) return false;
  return peacockOfferAllowed(
    gameName: peacock.gameName,
    preferredPeacockGames: preferredPeacockGames,
  );
}

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
/// Peacock offers (banner / pulse) honor [preferredPeacockGames]. Empty
/// preference is unfiltered. LFG offers are unchanged.
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
  Set<String> preferredPeacockGames = const {},
}) {
  if (userId == null || userId.isEmpty) return null;

  final offered = _peacockOffered(
        peacock,
        preferredPeacockGames: preferredPeacockGames,
      ) ||
      _lfgOffered(lfg);
  final held = spots.indexWhere((uid) => spotHeldByUser(uid, userId));
  final occupying = held >= 0;
  final occupant = occupying ? spots[held] : null;
  final calling = occupying && occupantIsCalling(occupant, occupantStatus);
  final hasLockClock = lockRemaining != null;
  final showLock = hasLockClock && (calling || offered);

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
  final preferred = lobbyState?.preferredPeacockGames.isNotEmpty == true
      ? lobbyState!.preferredPeacockGames
      : PreferredPeacockGamesStore.instance.snapshot;
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
    preferredPeacockGames: preferred,
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
