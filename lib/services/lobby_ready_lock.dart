import 'package:flutter/foundation.dart';

import '../domain/entities/lobby_state.dart';
import '../managers/notification_manager.dart';
import '../notification_service.dart';

/// Payload type when a lobby locks. Taps reuse [NotificationRoutes].
const kLobbyLockedType = 'lobby_locked';

/// Payload type when a locked lobby opens again (unlock / late join).
const kLobbyUnlockedType = 'lobby_unlocked';

/// Payload type when a Ready-check deadline fires without a lock.
const kLobbyReadyTimeoutType = 'lobby_ready_timeout';

/// First seated Ready starts this window. All Ready before it locks;
/// otherwise Ready flags clear back to Occupied. Not a new phase.
const kReadyCheckTimeout = Duration(seconds: 60);

/// Member status written through existing `updateMemberStatus`.
const kSeatedReadyStatus = 'Ready';
const kSeatedNotReadyStatus = 'Occupied';

const String _callingSuffix = '_calling';

/// Ready / Lock on seated spots. Not a new product machine — derived
/// from existing lobby spots + member statuses.
enum LobbyReadyLockPhase { open, locked }

/// Snapshot of seated Ready and whether the lobby is Locked.
class LobbyReadyLockSnapshot {
  const LobbyReadyLockSnapshot({
    required this.phase,
    required this.seatedUids,
    required this.readyUids,
  });

  static const empty = LobbyReadyLockSnapshot(
    phase: LobbyReadyLockPhase.open,
    seatedUids: [],
    readyUids: [],
  );

  final LobbyReadyLockPhase phase;
  final List<String> seatedUids;
  final List<String> readyUids;

  bool get isLocked => phase == LobbyReadyLockPhase.locked;

  bool isReady(String uid) => readyUids.contains(uid);

  /// Ready toggle while open. Unlock uses [canUnlock] on a locked seat.
  bool get canToggleReady => !isLocked;

  bool get canUnlock => isLocked;
}

class SeatedReadyResult {
  const SeatedReadyResult({
    required this.snapshot,
    required this.justLocked,
    this.justUnlocked = false,
    this.timedOut = false,
    this.changed = true,
  });

  final LobbyReadyLockSnapshot snapshot;
  final bool justLocked;
  final bool justUnlocked;
  final bool timedOut;
  final bool changed;

  String? get snackbarMessage {
    if (justLocked) return 'Squad locked — go in the game';
    if (justUnlocked) return 'Squad unlocked';
    if (timedOut) return 'Ready check timed out';
    return null;
  }
}

class LobbyLockNotifyPlan {
  const LobbyLockNotifyPlan({
    required this.recipientUids,
    required this.title,
    required this.body,
    required this.data,
  });

  final List<String> recipientUids;
  final String title;
  final String body;
  final Map<String, dynamic> data;
}

enum LobbyLockNotifyStatus { sent, noSeated, selfOnly }

class LobbyLockNotifyResult {
  const LobbyLockNotifyResult({
    required this.status,
    this.recipientUids = const [],
  });

  final LobbyLockNotifyStatus status;
  final List<String> recipientUids;

  bool get sent => status == LobbyLockNotifyStatus.sent;
}

/// Strip `_calling` from a spot occupant. Null / blank → null.
String? seatedUidFromOccupant(String? occupant) {
  if (occupant == null) return null;
  final raw = occupant.trim();
  if (raw.isEmpty) return null;
  if (raw.endsWith(_callingSuffix)) {
    final uid = raw.substring(0, raw.length - _callingSuffix.length);
    return uid.isEmpty ? null : uid;
  }
  return raw;
}

bool occupantIsCallingSpot(String? occupant, String? status) {
  if (occupant != null && occupant.endsWith(_callingSuffix)) {
    return status != kSeatedReadyStatus;
  }
  return status == 'Calling';
}

/// Occupying a seat and not still Calling. Ready-after-Lock-in
/// (`uid_calling` + Ready) counts as seated.
bool occupantIsSeated(String? occupant, String? status) {
  final uid = seatedUidFromOccupant(occupant);
  if (uid == null) return false;
  return !occupantIsCallingSpot(occupant, status);
}

bool isSeatedReadyStatus(String? status) =>
    status == kSeatedReadyStatus || status == 'Locked';

Map<String, String> mergeLobbyMemberStatuses(
  LobbyState state, {
  String? gameName,
}) {
  final game = gameName ?? state.currentGame?['name'] as String?;
  return <String, String>{
    ...state.globalStatuses,
    if (game != null && game.isNotEmpty) ...?state.gameStatuses[game],
    ...?state.currentLobby?.statuses,
  };
}

List<String?> spotsForReadyLock(
  LobbyState state, {
  String? gameName,
}) {
  final game = gameName ?? state.currentGame?['name'] as String?;
  if (game != null && game.isNotEmpty) {
    final fromGame = state.gameLobbySpots[game];
    if (fromGame != null && fromGame.isNotEmpty) return fromGame;
  }
  final lobby = state.currentLobby;
  if (lobby != null) return lobby.spots;
  return const <String?>[];
}

/// Seated uids in seat order. Calling occupants omitted. Duplicates dropped.
List<String> seatedUidsFromSpots({
  required List<String?> spots,
  Map<String, String> statuses = const {},
}) {
  final seen = <String>{};
  final out = <String>[];
  for (final occupant in spots) {
    final uid = seatedUidFromOccupant(occupant);
    if (uid == null) continue;
    final status = statuses[uid] ?? statuses[occupant ?? ''];
    if (!occupantIsSeated(occupant, status)) continue;
    if (!seen.add(uid)) continue;
    out.add(uid);
  }
  return out;
}

/// Recipients for a lock notify: seated members except the actor.
/// Empty / whitespace / duplicates dropped. Never FCM-to-self.
List<String> lobbyLockNotifyRecipients({
  required Iterable<String> seatedUids,
  required String actorUid,
}) {
  final actor = actorUid.trim();
  final seen = <String>{};
  final out = <String>[];
  for (final raw in seatedUids) {
    final uid = raw.trim();
    if (uid.isEmpty || uid == actor) continue;
    if (!seen.add(uid)) continue;
    out.add(uid);
  }
  return out;
}

/// Derive Ready / Lock from spots + statuses. Pure; no I/O.
LobbyReadyLockSnapshot resolveLobbyReadyLock({
  required List<String?> spots,
  Map<String, String> statuses = const {},
}) {
  final seated = seatedUidsFromSpots(spots: spots, statuses: statuses);
  if (seated.isEmpty) return LobbyReadyLockSnapshot.empty;

  final ready = <String>[];
  for (final uid in seated) {
    if (isSeatedReadyStatus(statuses[uid])) ready.add(uid);
  }
  final locked = ready.length == seated.length;
  return LobbyReadyLockSnapshot(
    phase: locked ? LobbyReadyLockPhase.locked : LobbyReadyLockPhase.open,
    seatedUids: seated,
    readyUids: ready,
  );
}

LobbyReadyLockSnapshot resolveLobbyReadyLockFromState(
  LobbyState state, {
  String? gameName,
}) {
  return resolveLobbyReadyLock(
    spots: spotsForReadyLock(state, gameName: gameName),
    statuses: mergeLobbyMemberStatuses(state, gameName: gameName),
  );
}

/// Apply a Ready / Occupied toggle for one seated uid, then recompute Lock.
///
/// Returns the current snapshot unchanged when [userId] is not seated,
/// [ready] matches the current flag, or the lobby is locked and [ready]
/// is true (already locked). Un-ready while locked unlocks — same derived
/// open/locked phases, no new machine.
LobbyReadyLockSnapshot reduceLobbyReadyLock({
  required List<String?> spots,
  Map<String, String> statuses = const {},
  required String userId,
  required bool ready,
}) {
  final uid = userId.trim();
  final current = resolveLobbyReadyLock(spots: spots, statuses: statuses);
  if (uid.isEmpty) return current;
  if (!current.seatedUids.contains(uid)) return current;
  if (current.isLocked && ready) return current;
  if (current.isReady(uid) == ready) return current;

  final nextStatuses = Map<String, String>.from(statuses);
  nextStatuses[uid] = ready ? kSeatedReadyStatus : kSeatedNotReadyStatus;
  return resolveLobbyReadyLock(spots: spots, statuses: nextStatuses);
}

bool justLockedLobby({
  required LobbyReadyLockSnapshot before,
  required LobbyReadyLockSnapshot after,
}) =>
    !before.isLocked && after.isLocked;

bool justUnlockedLobby({
  required LobbyReadyLockSnapshot before,
  required LobbyReadyLockSnapshot after,
}) =>
    before.isLocked && !after.isLocked;

/// Seated uids in [seatedAfter] that were not in [seatedBefore].
List<String> newlySeatedUids({
  required Iterable<String> seatedBefore,
  required Iterable<String> seatedAfter,
}) {
  final before = seatedBefore.toSet();
  final out = <String>[];
  for (final uid in seatedAfter) {
    if (uid.isEmpty || before.contains(uid)) continue;
    out.add(uid);
  }
  return out;
}

/// Late join unlocks when a new seated uid appears while the lobby was
/// locked and that uid is not Ready. Calling occupants are not seated,
/// so a Call does not unlock; sitting Occupied does.
bool lateJoinUnlocks({
  required LobbyReadyLockSnapshot before,
  required LobbyReadyLockSnapshot after,
}) {
  if (!justUnlockedLobby(before: before, after: after)) return false;
  return newlySeatedUids(
    seatedBefore: before.seatedUids,
    seatedAfter: after.seatedUids,
  ).isNotEmpty;
}

/// Empty seats stay claimable during lock so a late join can sit.
bool emptySpotAllowsLateJoin(LobbyReadyLockSnapshot snapshot) =>
    snapshot.phase == LobbyReadyLockPhase.open ||
    snapshot.phase == LobbyReadyLockPhase.locked;

bool readyCheckTimedOut({
  required LobbyReadyLockSnapshot snapshot,
  required DateTime now,
  DateTime? startedAt,
  Duration timeout = kReadyCheckTimeout,
}) {
  if (snapshot.isLocked) return false;
  if (snapshot.readyUids.isEmpty) return false;
  if (startedAt == null) return false;
  return !now.isBefore(startedAt.add(timeout));
}

/// Clear Ready → Occupied when the ready-check window elapses without a
/// lock. Locked snapshots and checks with no Ready are unchanged.
LobbyReadyLockSnapshot reduceReadyCheckTimeout({
  required List<String?> spots,
  Map<String, String> statuses = const {},
  required DateTime now,
  DateTime? startedAt,
  Duration timeout = kReadyCheckTimeout,
}) {
  final current = resolveLobbyReadyLock(spots: spots, statuses: statuses);
  if (!readyCheckTimedOut(
    snapshot: current,
    now: now,
    startedAt: startedAt,
    timeout: timeout,
  )) {
    return current;
  }
  final nextStatuses = Map<String, String>.from(statuses);
  for (final uid in current.readyUids) {
    nextStatuses[uid] = kSeatedNotReadyStatus;
  }
  return resolveLobbyReadyLock(spots: spots, statuses: nextStatuses);
}

LobbyLockNotifyPlan planLobbyLockNotify({
  required Iterable<String> seatedUids,
  required String actorUid,
  String? lobbyId,
  String? gameName,
}) {
  return planLobbyReadyLockNotify(
    type: kLobbyLockedType,
    title: 'Squad locked',
    bodyOpen: "Everyone's ready — go in the game",
    bodyGame: (game) => "Everyone's ready for $game — go in the game",
    seatedUids: seatedUids,
    actorUid: actorUid,
    lobbyId: lobbyId,
    gameName: gameName,
  );
}

/// Unlock / late-join notify. Same [LobbyLockNotify] sender as lock.
LobbyLockNotifyPlan planLobbyUnlockNotify({
  required Iterable<String> seatedUids,
  required String actorUid,
  String? lobbyId,
  String? gameName,
}) {
  return planLobbyReadyLockNotify(
    type: kLobbyUnlockedType,
    title: 'Squad unlocked',
    bodyOpen: 'Lobby is open — Ready up again',
    bodyGame: (game) => '$game is open — Ready up again',
    seatedUids: seatedUids,
    actorUid: actorUid,
    lobbyId: lobbyId,
    gameName: gameName,
  );
}

/// Ready-check timeout notify. Same [LobbyLockNotify] sender as lock.
LobbyLockNotifyPlan planLobbyReadyTimeoutNotify({
  required Iterable<String> seatedUids,
  required String actorUid,
  String? lobbyId,
  String? gameName,
}) {
  return planLobbyReadyLockNotify(
    type: kLobbyReadyTimeoutType,
    title: 'Ready check timed out',
    bodyOpen: 'Not everyone readied in time',
    bodyGame: (game) => 'Not everyone readied for $game in time',
    seatedUids: seatedUids,
    actorUid: actorUid,
    lobbyId: lobbyId,
    gameName: gameName,
  );
}

LobbyLockNotifyPlan planLobbyReadyLockNotify({
  required String type,
  required String title,
  required String bodyOpen,
  required String Function(String game) bodyGame,
  required Iterable<String> seatedUids,
  required String actorUid,
  String? lobbyId,
  String? gameName,
}) {
  final recipients = lobbyLockNotifyRecipients(
    seatedUids: seatedUids,
    actorUid: actorUid,
  );
  final game = _nonEmpty(gameName);
  final body = game == null ? bodyOpen : bodyGame(game);
  final data = NotificationManager.payloadFor(
    type: type,
    lobbyId: lobbyId,
    gameName: gameName,
    payload: {
      'from_uid': actorUid,
      'user_id': actorUid,
    },
  );
  return LobbyLockNotifyPlan(
    recipientUids: recipients,
    title: title,
    body: body,
    data: data,
  );
}

/// Lock notify. Live path: seated Ready toggle + [LobbyNotifier.lockSpot].
///
/// Sends through [NotificationService.sendNotificationToUsers] so taps
/// share [NotificationRoutes] with peacock / LFG. Recipients never include
/// the actor (no FCM-to-self). Not a second notification presenter.
class LobbyLockNotify {
  LobbyLockNotify._();

  /// Test hook. Production sends via [NotificationService.sendNotificationToUsers].
  @visibleForTesting
  static Future<void> Function({
    required String title,
    required String body,
    required List<String> recipientUids,
    Map<String, dynamic>? data,
  })? sendToUsersHook;

  @visibleForTesting
  static void resetTestHooks() {
    sendToUsersHook = null;
  }

  static Future<LobbyLockNotifyResult> send(LobbyLockNotifyPlan plan) async {
    if (plan.recipientUids.isEmpty) {
      return const LobbyLockNotifyResult(
        status: LobbyLockNotifyStatus.selfOnly,
      );
    }
    final send = sendToUsersHook ?? NotificationService.sendNotificationToUsers;
    await send(
      title: plan.title,
      body: plan.body,
      recipientUids: plan.recipientUids,
      data: plan.data,
    );
    return LobbyLockNotifyResult(
      status: LobbyLockNotifyStatus.sent,
      recipientUids: plan.recipientUids,
    );
  }
}

String? _nonEmpty(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
