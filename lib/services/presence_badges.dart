import '../domain/entities/lobby.dart';
import '../domain/entities/lobby_state.dart';
import 'availability_on.dart';
import 'matchmaking_queue_machine.dart';

/// Who is On / Looking / In lobby — glance badges on friends / squad lists.
/// Health chips (offline / stale / reconnecting) sit after live signals.
enum PresenceBadgeKind { on, looking, inLobby, offline, stale, reconnecting }

/// Connection health for the presence strip. Not a fourth live signal.
enum PresenceHealth { live, stale, offline, reconnecting }

/// Snapshot of glance badges for one user.
class PresenceBadges {
  const PresenceBadges({
    this.isOn = false,
    this.isLooking = false,
    this.isInLobby = false,
    this.health = PresenceHealth.live,
  });

  static const empty = PresenceBadges();

  final bool isOn;
  final bool isLooking;
  final bool isInLobby;
  final PresenceHealth health;

  bool get hasLiveSignals => isOn || isLooking || isInLobby;

  bool get isEmpty => kinds.isEmpty;

  bool get isNotEmpty => !isEmpty;

  PresenceBadges copyWith({
    bool? isOn,
    bool? isLooking,
    bool? isInLobby,
    PresenceHealth? health,
  }) {
    return PresenceBadges(
      isOn: isOn ?? this.isOn,
      isLooking: isLooking ?? this.isLooking,
      isInLobby: isInLobby ?? this.isInLobby,
      health: health ?? this.health,
    );
  }

  /// Product order: On, Looking, In lobby, then health.
  List<PresenceBadgeKind> get kinds => [
        if (isOn) PresenceBadgeKind.on,
        if (isLooking) PresenceBadgeKind.looking,
        if (isInLobby) PresenceBadgeKind.inLobby,
        if (health == PresenceHealth.offline && !hasLiveSignals)
          PresenceBadgeKind.offline,
        if (health == PresenceHealth.stale) PresenceBadgeKind.stale,
        if (health == PresenceHealth.reconnecting)
          PresenceBadgeKind.reconnecting,
      ];

  @override
  bool operator ==(Object other) =>
      other is PresenceBadges &&
      other.isOn == isOn &&
      other.isLooking == isLooking &&
      other.isInLobby == isInLobby &&
      other.health == health;

  @override
  int get hashCode => Object.hash(isOn, isLooking, isInLobby, health);
}

String presenceBadgeLabel(PresenceBadgeKind kind) {
  switch (kind) {
    case PresenceBadgeKind.on:
      return 'On';
    case PresenceBadgeKind.looking:
      return 'Looking';
    case PresenceBadgeKind.inLobby:
      return 'In lobby';
    case PresenceBadgeKind.offline:
      return 'Offline';
    case PresenceBadgeKind.stale:
      return 'Stale';
    case PresenceBadgeKind.reconnecting:
      return 'Reconnecting';
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
    case PresenceBadgeKind.offline:
      return 'presence-badge-offline';
    case PresenceBadgeKind.stale:
      return 'presence-badge-stale';
    case PresenceBadgeKind.reconnecting:
      return 'presence-badge-reconnecting';
  }
}

/// Pure health mapper. Loading beats stale/offline so the strip never
/// pretends a hung fetch is a live empty.
PresenceHealth resolvePresenceHealth({
  required bool isLoading,
  Object? error,
  bool isOffline = false,
  bool hasLiveSignals = false,
  bool isStale = false,
}) {
  if (isLoading) return PresenceHealth.reconnecting;
  if (error != null || isStale) return PresenceHealth.stale;
  if (isOffline) {
    return hasLiveSignals ? PresenceHealth.stale : PresenceHealth.offline;
  }
  if (!hasLiveSignals) return PresenceHealth.offline;
  return PresenceHealth.live;
}

/// uid / id / friend_uid from a friends or squad member row.
String? presenceUserIdFrom(Map<String, dynamic> row) {
  for (final key in ['uid', 'id', 'friend_uid', 'user_id']) {
    final text = row[key]?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

/// Friends / squad rows may pass a uid or a display name.
String? resolvePresenceUserId({
  required String? userId,
  Map<String, String> memberDisplayNames = const {},
}) {
  final raw = userId?.trim();
  if (raw == null || raw.isEmpty) return null;
  if (memberDisplayNames.containsKey(raw)) return raw;
  for (final entry in memberDisplayNames.entries) {
    if (entry.value.trim() == raw) return entry.key;
  }
  return raw;
}

bool userIsInLobby({
  required String userId,
  Iterable<String> lobbyMemberUids = const [],
  Lobby? currentLobby,
  Map<String, Lobby> userLobbies = const {},
}) {
  final uid = userId.trim();
  if (uid.isEmpty) return false;

  // Live currentLobby overlays a stale userLobbies copy of the same id
  // and the flattened lobbyMemberUids cache.
  final currentId = currentLobby?.id;
  if (currentLobby != null) {
    for (final raw in currentLobby.memberUids) {
      if (raw.trim() == uid) return true;
    }
  }
  var sawLobbyObject = currentLobby != null;
  for (final lobby in userLobbies.values) {
    sawLobbyObject = true;
    if (currentId != null && lobby.id == currentId) continue;
    for (final raw in lobby.memberUids) {
      if (raw.trim() == uid) return true;
    }
  }
  if (sawLobbyObject) return false;
  for (final raw in lobbyMemberUids) {
    if (raw.trim() == uid) return true;
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
///
/// [isLoading] / [error] / [isOffline] / [isStale] map reconnecting /
/// stale / offline onto the strip. Empty uid stays empty (no fake Offline).
PresenceBadges resolvePresenceBadgesFromTrackers({
  required String? userId,
  LobbyState? lobbyState,
  MatchmakingQueueTracker? lfg,
  AvailabilityOnStore? onStore,
  bool isLoading = false,
  Object? error,
  bool isOffline = false,
  bool isStale = false,
}) {
  final uid = resolvePresenceUserId(
    userId: userId,
    memberDisplayNames: lobbyState?.memberDisplayNames ?? const {},
  );
  if (uid == null || uid.isEmpty) return PresenceBadges.empty;
  final tracker = lfg ?? MatchmakingQueueTracker.instance;
  final looking = tracker.stateFor(uid);
  final on = (onStore ?? availabilityOnStore).isOn(uid);
  final badges = resolvePresenceBadges(
    userId: uid,
    isOn: on,
    lfg: looking,
    lobbyMemberUids: lobbyState?.lobbyMemberUids ?? const [],
    currentLobby: lobbyState?.currentLobby,
    userLobbies: lobbyState?.userLobbies ?? const {},
  );
  final health = resolvePresenceHealth(
    isLoading: isLoading || tracker.isHydrating,
    error: error ?? tracker.hydrateError,
    isOffline: isOffline,
    hasLiveSignals: badges.hasLiveSignals,
    isStale: isStale || tracker.hasStaleQueue,
  );
  return badges.copyWith(health: health);
}

/// Drop expired On windows and hydrate LFG looking. Reuses ticket 5 sources.
/// Resume / pull-to-refresh passes [force] so a stale queue can recover.
Future<void> refreshPresenceSources({
  MatchmakingQueueTracker? lfg,
  AvailabilityOnStore? onStore,
  bool force = false,
}) async {
  (onStore ?? availabilityOnStore).sweepExpired();
  await (lfg ?? MatchmakingQueueTracker.instance).ensureHydratedAndSubscribed(
    force: force,
  );
}
