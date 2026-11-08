import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/data/repositories/matchmaking_queue_repository.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/services/availability_on.dart';
import 'package:squad_sync/services/availability_ping.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';
import 'package:squad_sync/services/presence_badges.dart';

class _MemoryQueueRepo implements MatchmakingQueueRepository {
  final Map<String, MatchmakingQueueEntry> rows =
      <String, MatchmakingQueueEntry>{};
  final StreamController<MatchmakingQueueChange> controller =
      StreamController<MatchmakingQueueChange>.broadcast();

  @override
  Future<void> upsert(String userId, MatchmakingQueueEntry entry) async {
    rows[userId] = entry;
  }

  @override
  Future<void> remove(String userId) async {
    rows.remove(userId);
  }

  @override
  Future<Map<String, MatchmakingQueueEntry>> fetchActive() async =>
      Map<String, MatchmakingQueueEntry>.from(rows);

  @override
  Stream<MatchmakingQueueChange> watch() => controller.stream;

  @override
  Future<void> dispose() async {
    await controller.close();
  }
}

Lobby _lobby({
  required String id,
  required List<String> members,
}) {
  return Lobby.create(
    name: 'Squad',
    gameName: 'Warzone',
    maxSpots: 8,
    createdBy: members.first,
  ).copyWith(
    id: id,
    memberUids: members,
  );
}

void main() {
  late AvailabilityOnStore onStore;
  late MatchmakingQueueTracker lfg;

  setUp(() {
    onStore = AvailabilityOnStore(
      clock: () => DateTime.utc(2026, 9, 4, 12),
    );
    lfg = MatchmakingQueueTracker();
    resetAvailabilityOnStore();
    MatchmakingQueueTracker.resetInstance();
  });

  tearDown(() {
    resetAvailabilityOnStore();
    MatchmakingQueueTracker.resetInstance();
  });

  group('resolvePresenceBadges', () {
    test('empty uid has no badges', () {
      expect(resolvePresenceBadges(userId: null), PresenceBadges.empty);
      expect(resolvePresenceBadges(userId: '  '), PresenceBadges.empty);
    });

    test('On comes from I-am-on store, not LFG', () {
      final badges = resolvePresenceBadges(
        userId: 'u1',
        isOn: true,
        lfg: MatchmakingQueueEntry.idle,
      );
      expect(badges.isOn, isTrue);
      expect(badges.isLooking, isFalse);
      expect(badges.isInLobby, isFalse);
      expect(badges.kinds, [PresenceBadgeKind.on]);
      expect(presenceBadgeLabel(PresenceBadgeKind.on), 'On');
    });

    test('Looking is matchmaking_queue looking only', () {
      final looking = reduceMatchmakingQueue(
        current: MatchmakingQueueEntry.idle,
        event: MatchmakingQueueEvent.startLooking,
      );
      final matched = reduceMatchmakingQueue(
        current: looking,
        event: MatchmakingQueueEvent.matchFound,
        lobbyId: 'lobby-1',
      );
      expect(
        resolvePresenceBadges(userId: 'u1', lfg: looking).isLooking,
        isTrue,
      );
      expect(
        resolvePresenceBadges(userId: 'u1', lfg: matched).isLooking,
        isFalse,
      );
      expect(presenceBadgeLabel(PresenceBadgeKind.looking), 'Looking');
    });

    test('In lobby reads lobby membership, not spots', () {
      final lobby = _lobby(id: 'lobby-1', members: ['u1', 'u2']);
      expect(
        resolvePresenceBadges(
          userId: 'u2',
          currentLobby: lobby,
        ).isInLobby,
        isTrue,
      );
      expect(
        resolvePresenceBadges(
          userId: 'u3',
          lobbyMemberUids: ['u3'],
        ).isInLobby,
        isTrue,
      );
      expect(
        resolvePresenceBadges(
          userId: 'u4',
          userLobbies: {'lobby-1': lobby},
        ).isInLobby,
        isFalse,
      );
      expect(presenceBadgeLabel(PresenceBadgeKind.inLobby), 'In lobby');
    });

    test('all three badges stack in On / Looking / In lobby order', () {
      final looking = reduceMatchmakingQueue(
        current: MatchmakingQueueEntry.idle,
        event: MatchmakingQueueEvent.startLooking,
      );
      final badges = resolvePresenceBadges(
        userId: 'u1',
        isOn: true,
        lfg: looking,
        lobbyMemberUids: ['u1'],
      );
      expect(badges.kinds, [
        PresenceBadgeKind.on,
        PresenceBadgeKind.looking,
        PresenceBadgeKind.inLobby,
      ]);
    });
  });

  group('resolvePresenceBadgesFromTrackers', () {
    test('reads on-store, LFG tracker, and lobby state', () {
      onStore.markOn('u-on');
      lfg.startLooking('u-look');
      final lobby = _lobby(id: 'lobby-1', members: ['u-in']);
      final state = LobbyState.initial().copyWith(
        lobbyMemberUids: ['u-in'],
        currentLobby: lobby,
        userLobbies: {'lobby-1': lobby},
      );

      expect(
        resolvePresenceBadgesFromTrackers(
          userId: 'u-on',
          lobbyState: state,
          lfg: lfg,
          onStore: onStore,
        ),
        const PresenceBadges(isOn: true),
      );
      expect(
        resolvePresenceBadgesFromTrackers(
          userId: 'u-look',
          lobbyState: state,
          lfg: lfg,
          onStore: onStore,
        ),
        const PresenceBadges(isLooking: true),
      );
      expect(
        resolvePresenceBadgesFromTrackers(
          userId: 'u-in',
          lobbyState: state,
          lfg: lfg,
          onStore: onStore,
        ),
        const PresenceBadges(isInLobby: true),
      );
    });

    test('drops Looking after cancel / match so it does not stay stale', () {
      lfg.startLooking('u-look');
      expect(
        resolvePresenceBadgesFromTrackers(
          userId: 'u-look',
          lfg: lfg,
          onStore: onStore,
        ).isLooking,
        isTrue,
      );
      lfg.cancelLooking('u-look');
      expect(
        resolvePresenceBadgesFromTrackers(
          userId: 'u-look',
          lfg: lfg,
          onStore: onStore,
        ).isLooking,
        isFalse,
      );

      lfg.startLooking('u-match');
      lfg.matchFound('u-match', lobbyId: 'lobby-1');
      expect(
        resolvePresenceBadgesFromTrackers(
          userId: 'u-match',
          lfg: lfg,
          onStore: onStore,
        ).isLooking,
        isFalse,
      );
    });

    test('live currentLobby overlays stale membership caches', () {
      final live = _lobby(id: 'lobby-1', members: ['u-in']);
      final stale = _lobby(id: 'lobby-1', members: ['u-in', 'u-left']);
      final other = _lobby(id: 'lobby-2', members: ['u-other']);
      final state = LobbyState.initial().copyWith(
        lobbyMemberUids: ['u-in', 'u-left', 'u-other'],
        currentLobby: live,
        userLobbies: {'lobby-1': stale, 'lobby-2': other},
      );

      expect(
        resolvePresenceBadgesFromTrackers(
          userId: 'u-in',
          lobbyState: state,
          lfg: lfg,
          onStore: onStore,
        ).isInLobby,
        isTrue,
      );
      expect(
        resolvePresenceBadgesFromTrackers(
          userId: 'u-left',
          lobbyState: state,
          lfg: lfg,
          onStore: onStore,
        ).isInLobby,
        isFalse,
      );
      expect(
        resolvePresenceBadgesFromTrackers(
          userId: 'u-other',
          lobbyState: state,
          lfg: lfg,
          onStore: onStore,
        ).isInLobby,
        isTrue,
      );
    });

    test('maps squad display name to uid for glance badges', () {
      final lobby = _lobby(id: 'lobby-1', members: ['u-in']);
      final state = LobbyState.initial().copyWith(
        currentLobby: lobby,
        memberDisplayNames: {'u-in': 'Sam'},
      );
      expect(
        resolvePresenceBadgesFromTrackers(
          userId: 'Sam',
          lobbyState: state,
          lfg: lfg,
          onStore: onStore,
        ).isInLobby,
        isTrue,
      );
    });
  });

  group('refreshPresenceSources', () {
    test('sweeps expired On and hydrates looking from the queue repo', () async {
      var now = DateTime.utc(2026, 9, 4, 12);
      final store = AvailabilityOnStore(clock: () => now);
      store.markOn('u-on');
      now = now.add(kAvailabilityOnDuration + const Duration(seconds: 1));

      final repo = _MemoryQueueRepo();
      await repo.upsert(
        'u-look',
        const MatchmakingQueueEntry(phase: MatchmakingQueuePhase.looking),
      );
      final tracker = MatchmakingQueueTracker(repository: repo);

      await refreshPresenceSources(lfg: tracker, onStore: store);

      expect(store.isOn('u-on'), isFalse);
      expect(tracker.stateFor('u-look').phase, MatchmakingQueuePhase.looking);

      await repo.dispose();
    });
  });

  group('AvailabilityOnStore', () {
    test('markOn then isOn until expiry', () {
      var now = DateTime.utc(2026, 9, 4, 12);
      final store = AvailabilityOnStore(clock: () => now);
      store.markOn('u1');
      expect(store.isOn('u1'), isTrue);
      now = now.add(kAvailabilityOnDuration - const Duration(seconds: 1));
      expect(store.isOn('u1'), isTrue);
      now = now.add(const Duration(seconds: 2));
      expect(store.isOn('u1'), isFalse);
    });

    test('sweepExpired notifies so On does not stay stale', () {
      var now = DateTime.utc(2026, 9, 4, 12);
      var notified = 0;
      final store = AvailabilityOnStore(clock: () => now);
      store.addListener(() => notified++);
      store.markOn('u1');
      expect(notified, 1);
      now = now.add(kAvailabilityOnDuration + const Duration(seconds: 1));
      expect(store.isOn('u1'), isFalse);
      expect(store.sweepExpired(), 1);
      expect(notified, 2);
      expect(store.sweepExpired(), 0);
    });

    test('observePayload marks from_uid on availability_ping only', () {
      onStore.observePayload({
        'type': kAvailabilityPingType,
        'from_uid': 'u9',
      });
      expect(onStore.isOn('u9'), isTrue);

      onStore.observePayload({
        'type': 'peacock_assigned',
        'from_uid': 'u8',
      });
      expect(onStore.isOn('u8'), isFalse);
    });

    test('observeAvailabilityPingPayload marks the shared store', () {
      observeAvailabilityPingPayload({
        'type': 'availability_ping',
        'from_uid': 'friend-1',
        'user_id': 'friend-1',
      });
      expect(availabilityOnStore.isOn('friend-1'), isTrue);
    });
  });

  group('resolvePresenceHealth', () {
    test('loading is reconnecting even with live signals', () {
      expect(
        resolvePresenceHealth(isLoading: true, hasLiveSignals: true),
        PresenceHealth.reconnecting,
      );
      expect(
        resolvePresenceHealth(isLoading: true, hasLiveSignals: false),
        PresenceHealth.reconnecting,
      );
    });

    test('settled empty is offline', () {
      expect(
        resolvePresenceHealth(isLoading: false, hasLiveSignals: false),
        PresenceHealth.offline,
      );
    });

    test('device offline with no signals is offline', () {
      expect(
        resolvePresenceHealth(
          isLoading: false,
          isOffline: true,
          hasLiveSignals: false,
        ),
        PresenceHealth.offline,
      );
    });

    test('error or stale keeps last signals as stale, not a spinner', () {
      expect(
        resolvePresenceHealth(
          isLoading: false,
          error: 'timeout',
          hasLiveSignals: true,
        ),
        PresenceHealth.stale,
      );
      expect(
        resolvePresenceHealth(
          isLoading: false,
          error: 'timeout',
          hasLiveSignals: false,
        ),
        PresenceHealth.stale,
      );
      expect(
        resolvePresenceHealth(
          isLoading: false,
          isStale: true,
          hasLiveSignals: true,
        ),
        PresenceHealth.stale,
      );
      expect(
        resolvePresenceHealth(
          isLoading: false,
          isOffline: true,
          hasLiveSignals: true,
        ),
        PresenceHealth.stale,
      );
    });

    test('live signals with no error stay live', () {
      expect(
        resolvePresenceHealth(isLoading: false, hasLiveSignals: true),
        PresenceHealth.live,
      );
    });
  });

  group('presence health chips', () {
    test('offline / stale / reconnecting labels and keys', () {
      expect(presenceBadgeLabel(PresenceBadgeKind.offline), 'Offline');
      expect(presenceBadgeLabel(PresenceBadgeKind.stale), 'Stale');
      expect(
        presenceBadgeLabel(PresenceBadgeKind.reconnecting),
        'Reconnecting',
      );
      expect(presenceBadgeKey(PresenceBadgeKind.offline), 'presence-badge-offline');
      expect(presenceBadgeKey(PresenceBadgeKind.stale), 'presence-badge-stale');
      expect(
        presenceBadgeKey(PresenceBadgeKind.reconnecting),
        'presence-badge-reconnecting',
      );
    });

    test('idle uid maps to Offline, not an empty strip', () {
      final badges = resolvePresenceBadgesFromTrackers(
        userId: 'u-idle',
        lfg: lfg,
        onStore: onStore,
      );
      expect(badges.hasLiveSignals, isFalse);
      expect(badges.health, PresenceHealth.offline);
      expect(badges.kinds, [PresenceBadgeKind.offline]);
      expect(badges.isEmpty, isFalse);
    });

    test('hydrate error maps idle presence to Stale', () {
      final badges = resolvePresenceBadgesFromTrackers(
        userId: 'u-idle',
        lfg: lfg,
        onStore: onStore,
        error: 'offline',
      );
      expect(badges.health, PresenceHealth.stale);
      expect(badges.kinds, [PresenceBadgeKind.stale]);
    });

    test('On survives stale overlay in product order', () {
      onStore.markOn('u-on');
      final badges = resolvePresenceBadgesFromTrackers(
        userId: 'u-on',
        lfg: lfg,
        onStore: onStore,
        isStale: true,
      );
      expect(badges.kinds, [
        PresenceBadgeKind.on,
        PresenceBadgeKind.stale,
      ]);
    });

    test('loading maps to Reconnecting without dropping On', () {
      onStore.markOn('u-on');
      final badges = resolvePresenceBadgesFromTrackers(
        userId: 'u-on',
        lfg: lfg,
        onStore: onStore,
        isLoading: true,
      );
      expect(badges.kinds, [
        PresenceBadgeKind.on,
        PresenceBadgeKind.reconnecting,
      ]);
    });

    test('empty uid stays empty so the strip does not fake Offline', () {
      expect(
        resolvePresenceBadgesFromTrackers(
          userId: null,
          lfg: lfg,
          onStore: onStore,
          isLoading: true,
        ),
        PresenceBadges.empty,
      );
    });
  });

  group('presence reconnect toast', () {
    test('fires on cold lobby reconnect, not a live background hydrate', () {
      expect(
        shouldShowPresenceReconnectToast(
          previous: null,
          current: PresenceHealth.reconnecting,
          lobbyReconnect: true,
        ),
        isTrue,
      );
      expect(
        shouldShowPresenceReconnectToast(
          previous: PresenceHealth.reconnecting,
          current: PresenceHealth.reconnecting,
          lobbyReconnect: true,
        ),
        isFalse,
      );
      expect(
        shouldShowPresenceReconnectToast(
          previous: PresenceHealth.live,
          current: PresenceHealth.reconnecting,
          lobbyReconnect: false,
        ),
        isFalse,
      );
      expect(
        shouldShowPresenceReconnectToast(
          previous: PresenceHealth.offline,
          current: PresenceHealth.reconnecting,
          lobbyReconnect: false,
        ),
        isFalse,
      );
      expect(
        shouldShowPresenceReconnectToast(
          previous: PresenceHealth.stale,
          current: PresenceHealth.reconnecting,
          lobbyReconnect: false,
        ),
        isTrue,
      );
      expect(
        shouldShowPresenceReconnectToast(
          previous: PresenceHealth.offline,
          current: PresenceHealth.offline,
          lobbyReconnect: true,
        ),
        isFalse,
      );
    });

    test('copy is arm length and gate claims once per cooldown', () {
      expect(kPresenceReconnectingCopy, 'Reconnecting...');
      expect(kPresenceReconnectToastKey, 'presence-reconnect-toast');
      final gate = PresenceReconnectToastGate();
      final t = DateTime.utc(2026, 9, 6, 12);
      expect(gate.claim(now: t), isTrue);
      expect(gate.claim(now: t.add(const Duration(seconds: 1))), isFalse);
      expect(
        gate.claim(now: t.add(kPresenceReconnectToastCooldown)),
        isTrue,
      );
    });
  });

  group('stale presence cleanup', () {
    test('keeps last-known On before the stale timeout', () {
      final since = DateTime.utc(2026, 9, 6, 12);
      final badges = clearStalePresenceAfterTimeout(
        badges: const PresenceBadges(
          isOn: true,
          health: PresenceHealth.stale,
        ),
        staleSince: since,
        now: since.add(kPresenceStaleTimeout - const Duration(seconds: 1)),
      );
      expect(badges.isOn, isTrue);
      expect(badges.health, PresenceHealth.stale);
      expect(badges.kinds, [
        PresenceBadgeKind.on,
        PresenceBadgeKind.stale,
      ]);
    });

    test('clears last-known live signals after the stale timeout', () {
      final since = DateTime.utc(2026, 9, 6, 12);
      final badges = clearStalePresenceAfterTimeout(
        badges: const PresenceBadges(
          isOn: true,
          isLooking: true,
          health: PresenceHealth.stale,
        ),
        staleSince: since,
        now: since.add(kPresenceStaleTimeout),
      );
      expect(badges.hasLiveSignals, isFalse);
      expect(badges.health, PresenceHealth.offline);
      expect(badges.kinds, [PresenceBadgeKind.offline]);
      expect(badges.isEmpty, isFalse);
    });

    test('empty strip stays empty through stale cleanup', () {
      expect(
        clearStalePresenceAfterTimeout(
          badges: PresenceBadges.empty,
          staleSince: DateTime.utc(2026, 9, 6, 12),
          now: DateTime.utc(2026, 9, 6, 13),
        ),
        PresenceBadges.empty,
      );
    });

    test('resolve drops On after stale timeout and keeps it before', () {
      onStore.markOn('u-on');
      final since = DateTime.utc(2026, 9, 6, 12);
      expect(
        resolvePresenceBadgesFromTrackers(
          userId: 'u-on',
          lfg: lfg,
          onStore: onStore,
          isStale: true,
          staleSince: since,
          now: since.add(kPresenceStaleTimeout - const Duration(seconds: 1)),
        ).kinds,
        [
          PresenceBadgeKind.on,
          PresenceBadgeKind.stale,
        ],
      );
      expect(
        resolvePresenceBadgesFromTrackers(
          userId: 'u-on',
          lfg: lfg,
          onStore: onStore,
          isStale: true,
          staleSince: since,
          now: since.add(kPresenceStaleTimeout),
        ).kinds,
        [PresenceBadgeKind.offline],
      );
    });

    test('stale-since is last live plus LFG live window', () {
      final lastLive = DateTime.utc(2026, 9, 6, 12);
      expect(
        presenceStaleSince(
          health: PresenceHealth.stale,
          lastLiveAt: lastLive,
        ),
        lastLive.add(kLfgListStaleAfter),
      );
      expect(
        presenceStaleSince(
          health: PresenceHealth.live,
          lastLiveAt: lastLive,
        ),
        isNull,
      );
    });
  });

  group('empty presence strip', () {
    test('blank uid is empty, not Offline or Reconnecting', () {
      expect(
        resolvePresenceBadgesFromTrackers(
          userId: '  ',
          lfg: lfg,
          onStore: onStore,
          isLoading: true,
          isStale: true,
          error: 'offline',
        ),
        PresenceBadges.empty,
      );
      expect(PresenceBadges.empty.isEmpty, isTrue);
      expect(kPresenceEmptyStripKey, 'presence-empty');
    });
  });

  group('presenceUserIdFrom', () {
    test('prefers uid then id then friend_uid', () {
      expect(presenceUserIdFrom({'uid': 'a', 'id': 'b'}), 'a');
      expect(presenceUserIdFrom({'id': 'b'}), 'b');
      expect(presenceUserIdFrom({'friend_uid': 'c'}), 'c');
      expect(presenceUserIdFrom({'name': 'Sam'}), isNull);
    });
  });

  group('resolvePresenceUserId', () {
    test('returns uid, or maps a display name', () {
      expect(resolvePresenceUserId(userId: null), isNull);
      expect(resolvePresenceUserId(userId: '  '), isNull);
      expect(
        resolvePresenceUserId(
          userId: 'Sam',
          memberDisplayNames: {'u-in': 'Sam'},
        ),
        'u-in',
      );
      expect(
        resolvePresenceUserId(
          userId: 'u-in',
          memberDisplayNames: {'u-in': 'Sam'},
        ),
        'u-in',
      );
    });
  });
}
