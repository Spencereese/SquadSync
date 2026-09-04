import '../domain/entities/lobby.dart';
import '../domain/entities/lobby_state.dart';
import 'availability_on.dart';
import 'matchmaking_queue_machine.dart';

/// Who is On / Looking / In lobby — glance badges on friends / squad lists.
enum PresenceBadgeKind { on, looking, inLobby }

/// Snapshot of glance badges for one user.
class PresenceBadges {
  const PresenceBadges({
    this.isOn = false,
    this.isLooking = false,
    this.isInLobby = false,
  });

  static const empty = PresenceBadges();

  final bool isOn;
  final bool isLooking;
  final bool isInLobby;

  bool get isEmpty => !isOn && !isLooking && !isInLobby;

  bool get isNotEmpty => !isEmpty;

  /// Product order: On, Looking, In lobby.
  List<PresenceBadgeKind> get kinds => [
        if (isOn) PresenceBadgeKind.on,
        if (isLooking) PresenceBadgeKind.looking,
        if (isInLobby) PresenceBadgeKind.inLobby,
      ];

  @override
  bool operator ==(Object other) =>
      other is PresenceBadges &&
      other.isOn == isOn &&
      other.isLooking == isLooking &&
      other.isInLobby == isInLobby;

  @override
  int get hashCode => Object.hash(isOn, isLooking, isInLobby);
}

String presenceBadgeLabel(PresenceBadgeKind kind) {
  switch (kind) {
    case PresenceBadgeKind.on:
      return 'On';
    case PresenceBadgeKind.looking:
      return 'Looking';
    case PresenceBadgeKind.inLobby:
      return 'In lobby';
  }
}

String presenceBadgeKey(PresenceBadgeKind kind) {
  switch (kind) {
    case PresenceBadgeKind.on:
      return 'presence-badge-on';
    case PresenceBadgeKind.looking:
      return 'presence-badge-looking';
    case PresenceBadgeKind.inLobby:
      return 'presence-badge-in-lobby';
  }
}

/// uid / id / friend_uid from a friends or squad member row.
String? presenceUserIdFrom(Map<String, dynamic> row) {
  for (final key in ['uid', 'id', 'friend_uid', 'user_id']) {
    final text = row[key]?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

bool userIsInLobby({
  required String userId,
  Iterable<String> lobbyMemberUids = const [],
  Lobby? currentLobby,
  Map<String, Lobby> userLobbies = const {},
}) {
  final uid = userId.trim();
  if (uid.isEmpty) return false;
  for (final raw in lobbyMemberUids) {
    if (raw.trim() == uid) return true;
  }
  if (currentLobby != null) {
    for (final raw in currentLobby.memberUids) {
      if (raw.trim() == uid) return true;
    }
  }
  for (final lobby in userLobbies.values) {
    for (final raw in lobby.memberUids) {
      if (raw.trim() == uid) return true;
    }
  }
  return false;
}

bool _isLooking(MatchmakingQueueEntry lfg) =>
    lfg.phase == MatchmakingQueuePhase.looking;

/// Pure badge derivation from I-am-on + LFG looking + lobby membership.
PresenceBadges resolvePresenceBadges({
  required String? userId,
  bool isOn = false,
  MatchmakingQueueEntry lfg = MatchmakingQueueEntry.idle,
  Iterable<String> lobbyMemberUids = const [],
  Lobby? currentLobby,
  Map<String, Lobby> userLobbies = const {},
}) {
  final uid = userId?.trim();
  if (uid == null || uid.isEmpty) return PresenceBadges.empty;
  return PresenceBadges(
    isOn: isOn,
    isLooking: _isLooking(lfg),
    isInLobby: userIsInLobby(
      userId: uid,
      lobbyMemberUids: lobbyMemberUids,
      currentLobby: currentLobby,
      userLobbies: userLobbies,
    ),
  );
}

/// Live sources already shipped: on-store, matchmaking_queue, lobby state.
PresenceBadges resolvePresenceBadgesFromTrackers({
  required String? userId,
  LobbyState? lobbyState,
  MatchmakingQueueTracker? lfg,
  AvailabilityOnStore? onStore,
}) {
  final uid = userId?.trim();
  if (uid == null || uid.isEmpty) return PresenceBadges.empty;
  final looking = (lfg ?? MatchmakingQueueTracker.instance).stateFor(uid);
  final on = (onStore ?? availabilityOnStore).isOn(uid);
  return resolvePresenceBadges(
    userId: uid,
    isOn: on,
    lfg: looking,
    lobbyMemberUids: lobbyState?.lobbyMemberUids ?? const [],
    currentLobby: lobbyState?.currentLobby,
    userLobbies: lobbyState?.userLobbies ?? const {},
  );
}
