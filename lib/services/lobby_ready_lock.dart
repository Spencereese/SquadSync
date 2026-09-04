import 'package:flutter/foundation.dart';

import '../domain/entities/lobby_state.dart';
import '../managers/notification_manager.dart';
import '../notification_service.dart';

/// Payload type when a lobby locks. Taps reuse [NotificationRoutes].
const kLobbyLockedType = 'lobby_locked';

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

  bool get canToggleReady => !isLocked;
}

class SeatedReadyResult {
  const SeatedReadyResult({
    required this.snapshot,
    required this.justLocked,
    this.changed = true,
  });

  final LobbyReadyLockSnapshot snapshot;
  final bool justLocked;
  final bool changed;

  String? get snackbarMessage =>
      justLocked ? 'Squad locked — go in the game' : null;
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
/// the lobby is already locked, or [ready] matches the current flag.
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
  if (current.isLocked) return current;
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

LobbyLockNotifyPlan planLobbyLockNotify({
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
  const title = 'Squad locked';
  final body = game == null
      ? "Everyone's ready — go in the game"
      : "Everyone's ready for $game — go in the game";
  final data = NotificationManager.payloadFor(
    type: kLobbyLockedType,
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
