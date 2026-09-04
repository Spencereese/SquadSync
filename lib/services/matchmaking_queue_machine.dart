import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/notification_routes.dart';
import '../data/repositories/matchmaking_queue_repository.dart';
import 'peacock_assignment_machine.dart';
import 'supabase_service.dart';

/// Product phases for the Looking-for-Squad matchmaking queue.
///
/// idle → looking → matched → joined.
/// Join with a lobby may hand off to [PeacockAssignmentTracker.assignSpot]
/// — this machine does not implement a parallel peacock notify XOR.
/// LFG UI claims a seat via [LobbyNotifier.assignPeacockSpot] first, then
/// [MatchmakingQueueTracker.joinMatched] with [handoffToPeacock] false
/// so assign is a single reduce.
enum MatchmakingQueuePhase {
  idle,
  looking,
  matched,
  joined,
}

enum MatchmakingQueueEvent {
  startLooking,
  cancelLooking,
  matchFound,
  joinMatched,
  expire,
}

/// Snapshot of one user's matchmaking-queue entry.
class MatchmakingQueueEntry {
  const MatchmakingQueueEntry({
    this.phase = MatchmakingQueuePhase.idle,
    this.squadId,
    this.lobbyId,
    this.gameName,
    this.matchedUserId,
    this.notificationId,
    this.queuedAt,
  });

  static const idle = MatchmakingQueueEntry();

  final MatchmakingQueuePhase phase;
  final String? squadId;
  final String? lobbyId;
  final String? gameName;
  final String? matchedUserId;
  final String? notificationId;

  /// FIFO stamp. Hydrate uses `matchmaking_queue.created_at`.
  final DateTime? queuedAt;

  /// True once a match has a lobby the player can join / lock.
  bool get hasJoinTarget =>
      (phase == MatchmakingQueuePhase.matched ||
          phase == MatchmakingQueuePhase.joined) &&
      lobbyId != null &&
      lobbyId!.isNotEmpty;

  /// `/squad` location once a lobby is matched. Null while idle/looking
  /// or when the match is a player pair with no lobby yet.
  String? get routeLocation {
    if (!hasJoinTarget) return null;
    return NotificationRoutes.locationFor({
      'type': 'lfg_matched',
      if (lobbyId != null) 'lobby_id': lobbyId,
      if (gameName != null) 'game_name': gameName,
    });
  }

  MatchmakingQueueEntry copyWith({
    MatchmakingQueuePhase? phase,
    String? squadId,
    String? lobbyId,
    String? gameName,
    String? matchedUserId,
    String? notificationId,
    DateTime? queuedAt,
    bool clearMatch = false,
  }) {
    return MatchmakingQueueEntry(
      phase: phase ?? this.phase,
      squadId: clearMatch ? null : (squadId ?? this.squadId),
      lobbyId: clearMatch ? null : (lobbyId ?? this.lobbyId),
      gameName: clearMatch ? null : (gameName ?? this.gameName),
      matchedUserId: clearMatch ? null : (matchedUserId ?? this.matchedUserId),
      notificationId:
          clearMatch ? null : (notificationId ?? this.notificationId),
      queuedAt: clearMatch ? null : (queuedAt ?? this.queuedAt),
    );
  }
}

/// Reduce a matchmaking-queue entry. Pure; no I/O.
MatchmakingQueueEntry reduceMatchmakingQueue({
  required MatchmakingQueueEntry current,
  required MatchmakingQueueEvent event,
  String? squadId,
  String? lobbyId,
  String? gameName,
  String? matchedUserId,
  String? notificationId,
}) {
  switch (event) {
    case MatchmakingQueueEvent.startLooking:
      if (current.phase == MatchmakingQueuePhase.idle ||
          current.phase == MatchmakingQueuePhase.joined) {
        return MatchmakingQueueEntry(
          phase: MatchmakingQueuePhase.looking,
          squadId: squadId ?? current.squadId,
          gameName: gameName ?? current.gameName,
          queuedAt: DateTime.now().toUtc(),
        );
      }
      return current;

    case MatchmakingQueueEvent.cancelLooking:
      if (current.phase == MatchmakingQueuePhase.looking ||
          current.phase == MatchmakingQueuePhase.matched) {
        return MatchmakingQueueEntry.idle;
      }
      return current;

    case MatchmakingQueueEvent.matchFound:
      if (current.phase != MatchmakingQueuePhase.looking &&
          current.phase != MatchmakingQueuePhase.idle) {
        return current;
      }
      return MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.matched,
        squadId: squadId ?? current.squadId,
        lobbyId: lobbyId ?? current.lobbyId,
        gameName: gameName ?? current.gameName,
        matchedUserId: matchedUserId ?? current.matchedUserId,
        notificationId: notificationId ?? current.notificationId,
      );

    case MatchmakingQueueEvent.joinMatched:
      if (current.phase != MatchmakingQueuePhase.matched) {
        return current;
      }
      return current.copyWith(phase: MatchmakingQueuePhase.joined);

    case MatchmakingQueueEvent.expire:
      return MatchmakingQueueEntry.idle;
  }
}

/// Result of [MatchmakingQueueTracker.joinMatched].
///
/// [handedOffToPeacock] means peacock is assigned for this user (this
/// call or a prior [LobbyNotifier.assignPeacockSpot]) — not a second
/// notify XOR.
class MatchmakingHandoff {
  const MatchmakingHandoff({
    required this.state,
    required this.handedOffToPeacock,
    this.peacockState,
  });

  final MatchmakingQueueEntry state;
  final bool handedOffToPeacock;
  final PeacockAssignmentState? peacockState;
}

/// Owns per-user Looking-for-Squad phases.
///
/// Looking is persisted on [MatchmakingQueueRepository] (`matchmaking_queue`)
/// so app kill does not wipe the queue. Realtime hydrates other sessions.
/// Join/leave looking reduce **after** the matching remote write succeeds
/// ([startLookingAfter] / [cancelLookingAfter]). Match-into-lobby hands
/// off to [PeacockAssignmentTracker.assignSpot] unless the caller already
/// assigned via [LobbyNotifier.assignPeacockSpot] ([handoffToPeacock]
/// false, or peacock already assigned — never a second reduce).
class MatchmakingQueueTracker extends ChangeNotifier {
  MatchmakingQueueTracker({
    PeacockAssignmentTracker? peacock,
    MatchmakingQueueRepository? repository,
  })  : _peacockOverride = peacock,
        _repository = repository;

  /// Shared by chat LFG and any lobby match handoff.
  static MatchmakingQueueTracker instance = MatchmakingQueueTracker();

  final PeacockAssignmentTracker? _peacockOverride;
  MatchmakingQueueRepository? _repository;
  final Map<String, MatchmakingQueueEntry> _byUser =
      <String, MatchmakingQueueEntry>{};
  StreamSubscription<MatchmakingQueueChange>? _watchSub;
  bool _hydrated = false;
  bool _hydrating = false;
  bool _applyingRemote = false;

  PeacockAssignmentTracker get _peacock =>
      _peacockOverride ?? PeacockAssignmentTracker.instance;

  MatchmakingQueueRepository? get repository => _repository;

  void bindRepository(MatchmakingQueueRepository? repository) {
    _repository = repository;
  }

  /// Immutable view of tracked users. Idle users are omitted.
  Map<String, MatchmakingQueueEntry> get snapshot =>
      Map<String, MatchmakingQueueEntry>.unmodifiable(_byUser);

  MatchmakingQueueEntry stateFor(String userId) =>
      _byUser[userId] ?? MatchmakingQueueEntry.idle;

  /// First looking user in FIFO ([queuedAt], then insertion).
  String? nextLookingUserId({String? except}) {
    String? bestId;
    DateTime? bestAt;
    var index = 0;
    var bestIndex = 0;
    for (final entry in _byUser.entries) {
      final atIndex = index++;
      if (entry.value.phase != MatchmakingQueuePhase.looking) continue;
      if (except != null && entry.key == except) continue;
      final at = entry.value.queuedAt;
      if (bestId == null) {
        bestId = entry.key;
        bestAt = at;
        bestIndex = atIndex;
        continue;
      }
      if (at != null && (bestAt == null || at.isBefore(bestAt))) {
        bestId = entry.key;
        bestAt = at;
        bestIndex = atIndex;
        continue;
      }
      if (at == null && bestAt == null && atIndex < bestIndex) {
        bestId = entry.key;
        bestIndex = atIndex;
      }
    }
    return bestId;
  }

  /// Users already matched/joined into [lobbyId] (seat reservation).
  int matchedCountForLobby(String lobbyId) {
    if (lobbyId.isEmpty) return 0;
    var count = 0;
    for (final entry in _byUser.values) {
      if (entry.lobbyId != lobbyId) continue;
      if (entry.phase == MatchmakingQueuePhase.matched ||
          entry.phase == MatchmakingQueuePhase.joined) {
        count++;
      }
    }
    return count;
  }

  MatchmakingQueueEntry apply({
    required String userId,
    required MatchmakingQueueEvent event,
    String? squadId,
    String? lobbyId,
    String? gameName,
    String? matchedUserId,
    String? notificationId,
  }) {
    final next = reduceMatchmakingQueue(
      current: stateFor(userId),
      event: event,
      squadId: squadId,
      lobbyId: lobbyId,
      gameName: gameName,
      matchedUserId: matchedUserId,
      notificationId: notificationId,
    );
    final installed = _install(userId, next);
    if (!_applyingRemote) {
      unawaited(persistCurrent(userId));
    }
    return installed;
  }

  MatchmakingQueueEntry _install(String userId, MatchmakingQueueEntry next) {
    if (next.phase == MatchmakingQueuePhase.idle) {
      _byUser.remove(userId);
    } else {
      _byUser[userId] = next;
    }
    notifyListeners();
    return next;
  }

  /// Apply a Realtime / hydrate row. Does not persist and does not peacock.
  void applyRemote(String userId, MatchmakingQueueEntry? entry) {
    _applyingRemote = true;
    try {
      _install(userId, entry ?? MatchmakingQueueEntry.idle);
    } finally {
      _applyingRemote = false;
    }
  }

  Future<void> persistCurrent(String userId) async {
    final repo = _repository;
    if (repo == null || userId.isEmpty) return;
    final entry = stateFor(userId);
    if (entry.phase == MatchmakingQueuePhase.idle) {
      await repo.remove(userId);
      return;
    }
    await repo.upsert(userId, entry);
  }

  Future<void> persistUsers(Iterable<String> userIds) async {
    for (final uid in userIds) {
      await persistCurrent(uid);
    }
  }

  /// Fetch persisted rows then subscribe. Idempotent. No peacock assign.
  Future<void> ensureHydratedAndSubscribed() async {
    _repository ??=
        MatchmakingQueueRepositoryImpl(client: SupabaseService.maybeClient);
    await hydrateFromRepository();
    _bindRealtime();
  }

  Future<void> hydrateFromRepository() async {
    final repo = _repository;
    if (repo == null || _hydrated || _hydrating) return;
    _hydrating = true;
    try {
      final rows = await repo.fetchActive();
      _applyingRemote = true;
      for (final entry in rows.entries) {
        _install(entry.key, entry.value);
      }
      _hydrated = true;
    } finally {
      _applyingRemote = false;
      _hydrating = false;
    }
  }

  void _bindRealtime() {
    final repo = _repository;
    if (repo == null || _watchSub != null) return;
    _watchSub = repo.watch().listen((change) {
      applyRemote(change.userId, change.entry);
    });
  }

  /// Reduce [startLooking] after [remoteWrite] succeeds (notify friends,
  /// then persist looking so app kill does not wipe the queue).
  Future<MatchmakingQueueEntry> startLookingAfter(
    Future<void> Function() remoteWrite, {
    required String userId,
    String? squadId,
    String? gameName,
  }) async {
    await remoteWrite();
    final next = startLooking(userId, squadId: squadId, gameName: gameName);
    await persistCurrent(userId);
    return next;
  }

  MatchmakingQueueEntry startLooking(
    String userId, {
    String? squadId,
    String? gameName,
  }) =>
      apply(
        userId: userId,
        event: MatchmakingQueueEvent.startLooking,
        squadId: squadId,
        gameName: gameName,
      );

  /// Reduce [cancelLooking] after [remoteWrite] succeeds. v1 has no
  /// remote row — callers pass an empty write.
  Future<MatchmakingQueueEntry> cancelLookingAfter(
    Future<void> Function() remoteWrite, {
    required String userId,
  }) async {
    await remoteWrite();
    final next = cancelLooking(userId);
    await persistCurrent(userId);
    return next;
  }

  MatchmakingQueueEntry cancelLooking(String userId) => apply(
        userId: userId,
        event: MatchmakingQueueEvent.cancelLooking,
      );

  MatchmakingQueueEntry matchFound(
    String userId, {
    String? lobbyId,
    String? gameName,
    String? matchedUserId,
    String? notificationId,
    String? squadId,
  }) =>
      apply(
        userId: userId,
        event: MatchmakingQueueEvent.matchFound,
        lobbyId: lobbyId,
        gameName: gameName,
        matchedUserId: matchedUserId,
        notificationId: notificationId,
        squadId: squadId,
      );

  /// Pair looking users, or assign the next looking user into [lobbyId].
  ///
  /// Lobby-aware: only match into [lobbyId] when [lobbyHasFreeSeat] is true
  /// (default true when a lobby id is passed, so existing callers keep
  /// matching). A full lobby falls through to pairing. Never peacock-assigns.
  List<String> processQueue({
    String? lobbyId,
    String? gameName,
    bool? lobbyHasFreeSeat,
  }) {
    final hasLobby = lobbyId != null && lobbyId.isNotEmpty;
    final canSeat = lobbyHasFreeSeat ?? hasLobby;
    if (hasLobby && canSeat) {
      final uid = nextLookingUserId();
      if (uid == null) return const <String>[];
      matchFound(uid, lobbyId: lobbyId, gameName: gameName);
      return <String>[uid];
    }
    final first = nextLookingUserId();
    if (first == null) return const <String>[];
    final second = nextLookingUserId(except: first);
    if (second == null) return const <String>[];
    matchFound(first, matchedUserId: second, gameName: gameName);
    matchFound(second, matchedUserId: first, gameName: gameName);
    return <String>[first, second];
  }

  /// Live-path process: [processQueue] then persist matched rows.
  Future<List<String>> processQueueAndPersist({
    String? lobbyId,
    String? gameName,
    bool? lobbyHasFreeSeat,
  }) async {
    final matched = processQueue(
      lobbyId: lobbyId,
      gameName: gameName,
      lobbyHasFreeSeat: lobbyHasFreeSeat,
    );
    await persistUsers(matched);
    return matched;
  }

  /// looking/matched → joined, then peacock [assignSpot] when a lobby
  /// is present and [handoffToPeacock] is true.
  ///
  /// Pass [handoffToPeacock] false when the caller already assigned
  /// through [LobbyNotifier.assignPeacockSpot] (single reduce). Already
  /// assigned/notified peacock is never reduced again. Does not call
  /// [PeacockAssignmentTracker.notifySelf].
  MatchmakingHandoff joinMatched(
    String userId, {
    bool handoffToPeacock = true,
  }) {
    final before = stateFor(userId);
    final after = apply(
      userId: userId,
      event: MatchmakingQueueEvent.joinMatched,
    );
    if (before.phase != MatchmakingQueuePhase.matched ||
        after.phase != MatchmakingQueuePhase.joined) {
      return MatchmakingHandoff(state: after, handedOffToPeacock: false);
    }
    final existingPeacock = _peacock.stateFor(userId);
    final alreadyHandedOff =
        existingPeacock.phase == PeacockAssignmentPhase.assigned ||
            existingPeacock.phase == PeacockAssignmentPhase.notified;
    if (alreadyHandedOff || !handoffToPeacock) {
      return MatchmakingHandoff(
        state: after,
        handedOffToPeacock: alreadyHandedOff,
        peacockState: alreadyHandedOff ? existingPeacock : null,
      );
    }
    final lobbyId = after.lobbyId;
    if (lobbyId == null || lobbyId.isEmpty) {
      return MatchmakingHandoff(state: after, handedOffToPeacock: false);
    }
    final peacockState = _peacock.assignSpot(
      userId,
      lobbyId: lobbyId,
      gameName: after.gameName,
      notificationId: after.notificationId,
    );
    final handedOff = peacockState.phase == PeacockAssignmentPhase.assigned ||
        peacockState.phase == PeacockAssignmentPhase.notified;
    return MatchmakingHandoff(
      state: after,
      handedOffToPeacock: handedOff,
      peacockState: peacockState,
    );
  }

  MatchmakingQueueEntry expire(String userId) => apply(
        userId: userId,
        event: MatchmakingQueueEvent.expire,
      );

  void clear() {
    _byUser.clear();
    notifyListeners();
  }

  @visibleForTesting
  static void resetInstance() {
    instance._watchSub?.cancel();
    instance = MatchmakingQueueTracker();
  }
}

/// Occupied seats (including `_calling`) do not count as free.
int countFreeLobbySpots(List<String?> spots, {int? maxSpots}) {
  final cap = maxSpots ?? spots.length;
  var free = 0;
  for (var i = 0; i < cap; i++) {
    final uid = i < spots.length ? spots[i] : null;
    if (uid == null || uid.isEmpty) free++;
  }
  return free;
}

/// True when the lobby has a seat that is not already reserved by a
/// matched/joined queue row.
bool lobbyHasFreeSeatForMatchmaking({
  required List<String?> spots,
  int? maxSpots,
  required int alreadyMatchedToLobby,
}) {
  return countFreeLobbySpots(spots, maxSpots: maxSpots) > alreadyMatchedToLobby;
}
