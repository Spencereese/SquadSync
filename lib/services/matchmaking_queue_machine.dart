import 'package:flutter/foundation.dart';

import '../core/notification_routes.dart';
import 'peacock_assignment_machine.dart';

/// Product phases for the Looking-for-Squad matchmaking queue.
///
/// idle → looking → matched → joined.
/// Join with a lobby hands off to [PeacockAssignmentTracker.assignSpot]
/// — this machine does not implement a parallel peacock notify XOR.
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
  });

  static const idle = MatchmakingQueueEntry();

  final MatchmakingQueuePhase phase;
  final String? squadId;
  final String? lobbyId;
  final String? gameName;
  final String? matchedUserId;
  final String? notificationId;

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
/// [handedOffToPeacock] means the existing peacock assign path ran for
/// this user — not a second notify XOR.
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

/// Owns per-user Looking-for-Squad phases. v1 is in-memory: a shared
/// `matchmaking_queue` table is parked behind Spencer (no migrations here).
///
/// Join/leave looking reduce **after** the matching remote write succeeds
/// ([startLookingAfter] / [cancelLookingAfter]). Match-into-lobby hands
/// off to [PeacockAssignmentTracker.assignSpot].
class MatchmakingQueueTracker extends ChangeNotifier {
  MatchmakingQueueTracker({PeacockAssignmentTracker? peacock})
      : _peacockOverride = peacock;

  /// Shared by chat LFG and any lobby match handoff.
  static MatchmakingQueueTracker instance = MatchmakingQueueTracker();

  final PeacockAssignmentTracker? _peacockOverride;
  final Map<String, MatchmakingQueueEntry> _byUser =
      <String, MatchmakingQueueEntry>{};

  PeacockAssignmentTracker get _peacock =>
      _peacockOverride ?? PeacockAssignmentTracker.instance;

  /// Immutable view of tracked users. Idle users are omitted.
  Map<String, MatchmakingQueueEntry> get snapshot =>
      Map<String, MatchmakingQueueEntry>.unmodifiable(_byUser);

  MatchmakingQueueEntry stateFor(String userId) =>
      _byUser[userId] ?? MatchmakingQueueEntry.idle;

  /// First looking user in insertion order, or null if the queue is empty.
  String? nextLookingUserId({String? except}) {
    for (final entry in _byUser.entries) {
      if (entry.value.phase != MatchmakingQueuePhase.looking) continue;
      if (except != null && entry.key == except) continue;
      return entry.key;
    }
    return null;
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
    if (next.phase == MatchmakingQueuePhase.idle) {
      _byUser.remove(userId);
    } else {
      _byUser[userId] = next;
    }
    notifyListeners();
    return next;
  }

  /// Reduce [startLooking] after [remoteWrite] succeeds (notify friends,
  /// or a no-op when there is no remote table yet).
  Future<MatchmakingQueueEntry> startLookingAfter(
    Future<void> Function() remoteWrite, {
    required String userId,
    String? squadId,
    String? gameName,
  }) async {
    await remoteWrite();
    return startLooking(userId, squadId: squadId, gameName: gameName);
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
    return cancelLooking(userId);
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
  /// With a lobby: FIFO looking user → matched (join target set).
  /// Without: two looking users pair on [matchedUserId] (no lobby yet).
  List<String> processQueue({String? lobbyId, String? gameName}) {
    if (lobbyId != null && lobbyId.isNotEmpty) {
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

  /// looking/matched → joined, then peacock [assignSpot] when a lobby
  /// is present. Does not call [PeacockAssignmentTracker.notifySelf].
  MatchmakingHandoff joinMatched(String userId) {
    final before = stateFor(userId);
    final after = apply(
      userId: userId,
      event: MatchmakingQueueEvent.joinMatched,
    );
    if (before.phase != MatchmakingQueuePhase.matched ||
        after.phase != MatchmakingQueuePhase.joined) {
      return MatchmakingHandoff(state: after, handedOffToPeacock: false);
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
    instance = MatchmakingQueueTracker();
  }
}
