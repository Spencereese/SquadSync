import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/services/availability_on.dart';
import 'package:squad_sync/services/availability_ping.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';
import 'package:squad_sync/services/presence_badges.dart';

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

  group('presenceUserIdFrom', () {
    test('prefers uid then id then friend_uid', () {
      expect(presenceUserIdFrom({'uid': 'a', 'id': 'b'}), 'a');
      expect(presenceUserIdFrom({'id': 'b'}), 'b');
      expect(presenceUserIdFrom({'friend_uid': 'c'}), 'c');
      expect(presenceUserIdFrom({'name': 'Sam'}), isNull);
    });
  });
}
