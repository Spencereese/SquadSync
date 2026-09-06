import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/notification_routes.dart';
import '../data/repositories/matchmaking_queue_repository.dart';
import 'peacock_assignment_machine.dart';
import 'squad_analytics.dart';
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
        queuedAt: current.queuedAt,
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
  Object? _hydrateError;
  DateTime? _lastHydratedAt;
  final Map<String, int> _persistGen = <String, int>{};
  final Map<String, Future<void>> _persistTail = <String, Future<void>>{};

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

  bool get isHydrated => _hydrated;
  bool get isHydrating => _hydrating;
  Object? get hydrateError => _hydrateError;
  DateTime? get lastHydratedAt => _lastHydratedAt;

  /// True when hydrate failed or the last successful fetch is older than
  /// [kLfgListStaleAfter]. Idle never-hydrated is not stale.
  bool get hasStaleQueue {
    if (_hydrateError != null) return _hydrated || lookingUserIds.isNotEmpty;
    final at = _lastHydratedAt;
    if (at == null) return false;
    return DateTime.now().toUtc().difference(at) >= kLfgListStaleAfter;
  }

  /// Users currently in [MatchmakingQueuePhase.looking], FIFO.
  List<String> get lookingUserIds {
    final ids = <String>[];
    for (final entry in _byUser.entries) {
      if (entry.value.phase == MatchmakingQueuePhase.looking) {
        ids.add(entry.key);
      }
    }
    return ids;
  }

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
    final before = stateFor(userId);
    final next = reduceMatchmakingQueue(
      current: before,
      event: event,
      squadId: squadId,
      lobbyId: lobbyId,
      gameName: gameName,
      matchedUserId: matchedUserId,
      notificationId: notificationId,
    );
    final installed = _install(userId, next);
    if (!_applyingRemote) {
      unawaited(_persistQuietly(userId));
      if (event == MatchmakingQueueEvent.startLooking &&
          installed.phase == MatchmakingQueuePhase.looking &&
          before.phase != MatchmakingQueuePhase.looking) {
        unawaited(SquadAnalytics.logLfgEnqueue(
          gameName: installed.gameName,
        ));
      }
      if (event == MatchmakingQueueEvent.matchFound &&
          installed.phase == MatchmakingQueuePhase.matched &&
          before.phase != MatchmakingQueuePhase.matched) {
        unawaited(SquadAnalytics.logPeacockOffer(
          source: 'lfg',
          gameName: installed.gameName,
        ));
      }
      if (event == MatchmakingQueueEvent.joinMatched &&
          installed.phase == MatchmakingQueuePhase.joined &&
          before.phase == MatchmakingQueuePhase.matched) {
        unawaited(SquadAnalytics.logLobbyJoin(
          source: 'lfg',
          gameName: installed.gameName,
        ));
      }
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
  /// Stale looking after a local dequeue is ignored (enqueue→dequeue race).
  void applyRemote(String userId, MatchmakingQueueEntry? entry) {
    final already = _applyingRemote;
    _applyingRemote = true;
    try {
      if (!shouldApplyRemoteQueueEntry(
        local: stateFor(userId),
        remote: entry,
      )) {
        return;
      }
      _install(userId, entry ?? MatchmakingQueueEntry.idle);
    } finally {
      if (!already) _applyingRemote = false;
    }
  }

  /// Serialize per-user writes so a late looking upsert cannot overwrite
  /// a dequeue. Reads the live row immediately before the remote write.
  Future<void> persistCurrent(String userId) {
    final repo = _repository;
    if (repo == null || userId.isEmpty) return Future<void>.value();
    final gen = (_persistGen[userId] ?? 0) + 1;
    _persistGen[userId] = gen;
    final previous = _persistTail[userId] ?? Future<void>.value();
    final done = () async {
      try {
        await previous;
      } catch (_) {}
      if (_persistGen[userId] != gen) return;
      final entry = stateFor(userId);
      if (entry.phase == MatchmakingQueuePhase.idle) {
        await repo.remove(userId);
        return;
      }
      await repo.upsert(userId, entry);
    }();
    _persistTail[userId] = done;
    return done;
  }

  Future<void> _persistQuietly(String userId) async {
    try {
      await persistCurrent(userId);
    } catch (_) {}
  }

  /// Flush in-flight looking / matched / idle writes. Tests only.
  @visibleForTesting
  Future<void> waitForPendingPersists() async {
    final pending = _persistTail.values.toList(growable: false);
    for (final future in pending) {
      try {
        await future;
      } catch (_) {}
    }
  }

  Future<void> persistUsers(Iterable<String> userIds) async {
    for (final uid in userIds) {
      await persistCurrent(uid);
    }
  }

  /// Fetch persisted rows then subscribe. Idempotent. No peacock assign.
  /// [force] re-fetches so a stale / failed queue can recover.
  Future<void> ensureHydratedAndSubscribed({bool force = false}) async {
    _repository ??=
        MatchmakingQueueRepositoryImpl(client: SupabaseService.maybeClient);
    await hydrateFromRepository(force: force);
    cleanupStaleEntries();
    _bindRealtime();
  }

  Future<void> hydrateFromRepository({bool force = false}) async {
    final repo = _repository;
    if (repo == null || _hydrating) return;
    if (_hydrated && !force && _hydrateError == null) return;
    _hydrating = true;
    _hydrateError = null;
    notifyListeners();
    try {
      final rows = await repo.fetchActive();
      for (final entry in rows.entries) {
        applyRemote(entry.key, entry.value);
      }
      _hydrated = true;
      _lastHydratedAt = DateTime.now().toUtc();
      _hydrateError = null;
    } catch (e) {
      _hydrateError = e;
    } finally {
      _hydrating = false;
      notifyListeners();
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
  /// Empty queue is a no-op (no match, no persist, no error).
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

  /// In-memory expire of stale looking rows, then persist remove.
  /// Stub: no sweeper table. Empty queue is a no-op.
  List<String> cleanupStaleEntries({
    DateTime? now,
    Duration? after,
  }) {
    final at = now ?? DateTime.now().toUtc();
    final ttl = after ?? kLfgStaleEntryAfter;
    final ids = staleMatchmakingUserIds(
      snapshot,
      now: at,
      after: ttl,
    );
    for (final id in ids) {
      expire(id);
    }
    return ids;
  }

  void clear() {
    _byUser.clear();
    _persistGen.clear();
    _persistTail.clear();
    notifyListeners();
  }

  @visibleForTesting
  static void resetInstance() {
    instance._watchSub?.cancel();
    instance = MatchmakingQueueTracker();
  }
}

/// How long a successful LFG hydrate stays "live" before the row is stale.
const kLfgListStaleAfter = Duration(minutes: 2);

/// How long a looking row may sit before [cleanupStaleEntries] expires it.
/// Stub: in-memory expire + existing persist remove. No sweeper table.
const kLfgStaleEntryAfter = Duration(minutes: 15);

const kLfgListEmptyCopy = 'No one looking right now';
const kLfgListEmptyHint = 'Tap Looking for Squad to join the queue.';
const kLfgListErrorCopy = "Couldn't load looking";
const kLfgListErrorHint = 'Check your connection and try again.';
const kLfgListStaleCopy = 'Queue may be out of date';
const kLfgListStaleHint = 'Showing the last known queue.';
const kLfgListReconnectingCopy = 'Reconnecting to queue...';

enum LfgListPhase { data, empty, loading, error, stale }

/// Snapshot of the LFG / matchmaking_queue list for empty / error / stale UI.
class LfgListView {
  const LfgListView({
    required this.phase,
    this.lookingUserIds = const <String>[],
    this.error,
  });

  static const empty = LfgListView(phase: LfgListPhase.empty);

  final LfgListPhase phase;
  final List<String> lookingUserIds;
  final Object? error;

  int get lookingCount => lookingUserIds.length;
}

/// Empty / error / stale / reconnecting for the LFG list. Loading only
/// while a hydrate is in flight with no rows yet — never a settled spinner.
LfgListPhase resolveLfgListPhase({
  required bool isHydrating,
  required bool isHydrated,
  Object? error,
  required int lookingCount,
  bool isOffline = false,
  bool isStale = false,
}) {
  final hasRows = lookingCount > 0;
  if (isHydrating && !hasRows && !isHydrated) return LfgListPhase.loading;
  if ((error != null || isOffline) && !hasRows) return LfgListPhase.error;
  if (error != null || isOffline || (isStale && hasRows)) {
    return LfgListPhase.stale;
  }
  if (!hasRows) return LfgListPhase.empty;
  return LfgListPhase.data;
}

LfgListView resolveLfgList({
  required Map<String, MatchmakingQueueEntry> snapshot,
  required bool isHydrating,
  required bool isHydrated,
  Object? error,
  bool isOffline = false,
  bool isStale = false,
}) {
  final looking = <String>[];
  for (final entry in snapshot.entries) {
    if (entry.value.phase == MatchmakingQueuePhase.looking) {
      looking.add(entry.key);
    }
  }
  return LfgListView(
    phase: resolveLfgListPhase(
      isHydrating: isHydrating,
      isHydrated: isHydrated,
      error: error,
      lookingCount: looking.length,
      isOffline: isOffline,
      isStale: isStale,
    ),
    lookingUserIds: looking,
    error: error,
  );
}

LfgListView resolveLfgListFromTracker(
  MatchmakingQueueTracker tracker, {
  bool isOffline = false,
}) {
  return resolveLfgList(
    snapshot: tracker.snapshot,
    isHydrating: tracker.isHydrating,
    isHydrated: tracker.isHydrated,
    error: tracker.hydrateError,
    isOffline: isOffline,
    isStale: tracker.hasStaleQueue,
  );
}

Key lfgListKey(LfgListPhase phase) {
  switch (phase) {
    case LfgListPhase.empty:
      return const Key('lfg-queue-empty');
    case LfgListPhase.loading:
      return const Key('lfg-queue-reconnecting');
    case LfgListPhase.error:
      return const Key('lfg-queue-error');
    case LfgListPhase.stale:
      return const Key('lfg-queue-stale');
    case LfgListPhase.data:
      return const Key('lfg-queue-status');
  }
}

String lfgListMessage(
  LfgListPhase phase, {
  int lookingCount = 0,
}) {
  switch (phase) {
    case LfgListPhase.empty:
      return kLfgListEmptyCopy;
    case LfgListPhase.loading:
      return kLfgListReconnectingCopy;
    case LfgListPhase.error:
      return kLfgListErrorCopy;
    case LfgListPhase.stale:
      return kLfgListStaleCopy;
    case LfgListPhase.data:
      if (lookingCount == 1) return '1 looking';
      return '$lookingCount looking';
  }
}

String? lfgListHint(LfgListPhase phase) {
  switch (phase) {
    case LfgListPhase.empty:
      return kLfgListEmptyHint;
    case LfgListPhase.error:
      return kLfgListErrorHint;
    case LfgListPhase.stale:
      return kLfgListStaleHint;
    case LfgListPhase.loading:
    case LfgListPhase.data:
      return null;
  }
}

/// idle < looking < matched < joined. Used to drop stale enqueue echoes.
int matchmakingPhaseRank(MatchmakingQueuePhase phase) {
  switch (phase) {
    case MatchmakingQueuePhase.idle:
      return 0;
    case MatchmakingQueuePhase.looking:
      return 1;
    case MatchmakingQueuePhase.matched:
      return 2;
    case MatchmakingQueuePhase.joined:
      return 3;
  }
}

/// True when a Realtime / hydrate row should replace [local].
///
/// A looking (or idle-delete) echo after a local dequeue is ignored so a
/// late enqueue persist cannot undo match/join. Remote rows that are
/// further along still apply (other-session dequeue).
bool shouldApplyRemoteQueueEntry({
  required MatchmakingQueueEntry local,
  MatchmakingQueueEntry? remote,
}) {
  if (remote == null || remote.phase == MatchmakingQueuePhase.idle) {
    return local.phase != MatchmakingQueuePhase.matched &&
        local.phase != MatchmakingQueuePhase.joined;
  }
  if (local.phase == MatchmakingQueuePhase.idle) return true;
  return matchmakingPhaseRank(remote.phase) >=
      matchmakingPhaseRank(local.phase);
}

/// Looking rows older than [after] are stale. Matched/joined/idle are not.
bool isStaleMatchmakingEntry(
  MatchmakingQueueEntry entry, {
  required DateTime now,
  Duration after = kLfgStaleEntryAfter,
}) {
  if (entry.phase != MatchmakingQueuePhase.looking) return false;
  final queuedAt = entry.queuedAt;
  if (queuedAt == null) return false;
  return now.toUtc().difference(queuedAt.toUtc()) >= after;
}

/// User ids whose looking row is past [after]. Empty snapshot is empty.
List<String> staleMatchmakingUserIds(
  Map<String, MatchmakingQueueEntry> snapshot, {
  required DateTime now,
  Duration after = kLfgStaleEntryAfter,
}) {
  final ids = <String>[];
  for (final entry in snapshot.entries) {
    if (isStaleMatchmakingEntry(entry.value, now: now, after: after)) {
      ids.add(entry.key);
    }
  }
  return ids;
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
