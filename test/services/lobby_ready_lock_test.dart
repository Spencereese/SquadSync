import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/notification_routes.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/managers/notification_manager.dart';
import 'package:squad_sync/services/lobby_ready_lock.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

Lobby _lobby({
  required String id,
  required List<String?> spots,
  Map<String, String> statuses = const {},
  String game = 'Warzone',
}) {
  return Lobby.create(
    name: 'Squad',
    gameName: game,
    maxSpots: spots.length,
    createdBy: 'u1',
  ).copyWith(
    id: id,
    spots: spots,
    statuses: statuses,
    memberUids: [
      for (final occupant in spots)
        if (seatedUidFromOccupant(occupant) != null)
          seatedUidFromOccupant(occupant)!,
    ],
  );
}

void main() {
  setUp(LobbyLockNotify.resetTestHooks);
  tearDown(LobbyLockNotify.resetTestHooks);

  group('seatedUidsFromSpots', () {
    test('skips empty, calling, and duplicates', () {
      expect(
        seatedUidsFromSpots(
          spots: ['u1', null, 'u2_calling', 'u1', '', 'u3'],
          statuses: const {'u2': 'Calling'},
        ),
        ['u1', 'u3'],
      );
    });

    test('uid_calling + Ready counts as seated', () {
      expect(
        seatedUidsFromSpots(
          spots: ['u1_calling', 'u2'],
          statuses: const {'u1': 'Ready'},
        ),
        ['u1', 'u2'],
      );
    });
  });

  group('resolveLobbyReadyLock', () {
    test('no seated spots stays open', () {
      final snap = resolveLobbyReadyLock(spots: [null, null]);
      expect(snap.phase, LobbyReadyLockPhase.open);
      expect(snap.isLocked, isFalse);
      expect(snap.seatedUids, isEmpty);
    });

    test('one seated not Ready stays open', () {
      final snap = resolveLobbyReadyLock(spots: ['u1', null]);
      expect(snap.isLocked, isFalse);
      expect(snap.seatedUids, ['u1']);
      expect(snap.readyUids, isEmpty);
    });

    test('all seated Ready locks the lobby', () {
      final snap = resolveLobbyReadyLock(
        spots: ['u1', 'u2', null],
        statuses: const {'u1': 'Ready', 'u2': 'Ready'},
      );
      expect(snap.phase, LobbyReadyLockPhase.locked);
      expect(snap.isLocked, isTrue);
      expect(snap.seatedUids, ['u1', 'u2']);
      expect(snap.readyUids, ['u1', 'u2']);
    });

    test('two seated one Ready stays open', () {
      final snap = resolveLobbyReadyLock(
        spots: ['u1', 'u2'],
        statuses: const {'u1': 'Ready'},
      );
      expect(snap.isLocked, isFalse);
      expect(snap.readyUids, ['u1']);
    });

    test('calling occupant is not required for lock', () {
      final snap = resolveLobbyReadyLock(
        spots: ['u1', 'u2_calling'],
        statuses: const {'u1': 'Ready', 'u2': 'Calling'},
      );
      expect(snap.seatedUids, ['u1']);
      expect(snap.isLocked, isTrue);
    });
  });

  group('reduceLobbyReadyLock', () {
    test('toggle Ready on a seated spot', () {
      final next = reduceLobbyReadyLock(
        spots: ['u1', 'u2'],
        statuses: const {},
        userId: 'u1',
        ready: true,
      );
      expect(next.isReady('u1'), isTrue);
      expect(next.isLocked, isFalse);
      expect(next.canToggleReady, isTrue);
    });

    test('last seated Ready locks', () {
      final next = reduceLobbyReadyLock(
        spots: ['u1', 'u2'],
        statuses: const {'u1': 'Ready'},
        userId: 'u2',
        ready: true,
      );
      expect(next.isLocked, isTrue);
      expect(next.readyUids, ['u1', 'u2']);
    });

    test('solo seated Ready locks', () {
      final next = reduceLobbyReadyLock(
        spots: ['u1', null],
        userId: 'u1',
        ready: true,
      );
      expect(next.isLocked, isTrue);
    });

    test('Ready true when already locked is a no-op', () {
      final next = reduceLobbyReadyLock(
        spots: ['u1', 'u2'],
        statuses: const {'u1': 'Ready', 'u2': 'Ready'},
        userId: 'u1',
        ready: true,
      );
      expect(next.isLocked, isTrue);
      expect(next.isReady('u1'), isTrue);
    });

    test('un-ready when locked unlocks', () {
      final next = reduceLobbyReadyLock(
        spots: ['u1', 'u2'],
        statuses: const {'u1': 'Ready', 'u2': 'Ready'},
        userId: 'u1',
        ready: false,
      );
      expect(next.isLocked, isFalse);
      expect(next.canUnlock, isFalse);
      expect(next.isReady('u1'), isFalse);
      expect(next.isReady('u2'), isTrue);
    });

    test('calling user cannot toggle Ready', () {
      final next = reduceLobbyReadyLock(
        spots: ['u1_calling', 'u2'],
        statuses: const {'u1': 'Calling'},
        userId: 'u1',
        ready: true,
      );
      expect(next.seatedUids, ['u2']);
      expect(next.isReady('u1'), isFalse);
      expect(next.isLocked, isFalse);
    });
  });

  group('justLockedLobby', () {
    test('true only on open → locked', () {
      const open = LobbyReadyLockSnapshot(
        phase: LobbyReadyLockPhase.open,
        seatedUids: ['u1'],
        readyUids: [],
      );
      const locked = LobbyReadyLockSnapshot(
        phase: LobbyReadyLockPhase.locked,
        seatedUids: ['u1'],
        readyUids: ['u1'],
      );
      expect(justLockedLobby(before: open, after: locked), isTrue);
      expect(justLockedLobby(before: locked, after: locked), isFalse);
      expect(justLockedLobby(before: locked, after: open), isFalse);
      expect(justUnlockedLobby(before: locked, after: open), isTrue);
      expect(justUnlockedLobby(before: open, after: locked), isFalse);
      expect(justUnlockedLobby(before: locked, after: locked), isFalse);
    });
  });

  group('ready-check timeout', () {
    final started = DateTime.utc(2026, 9, 5, 12, 0, 0);

    test('clears Ready when the window elapses while still open', () {
      final next = reduceReadyCheckTimeout(
        spots: ['u1', 'u2'],
        statuses: const {'u1': 'Ready'},
        now: started.add(kReadyCheckTimeout),
        startedAt: started,
      );
      expect(next.isLocked, isFalse);
      expect(next.readyUids, isEmpty);
      expect(next.seatedUids, ['u1', 'u2']);
    });

    test('does not clear Ready before the deadline', () {
      final next = reduceReadyCheckTimeout(
        spots: ['u1', 'u2'],
        statuses: const {'u1': 'Ready'},
        now: started.add(kReadyCheckTimeout - const Duration(seconds: 1)),
        startedAt: started,
      );
      expect(next.readyUids, ['u1']);
    });

    test('locked lobby ignores timeout', () {
      final next = reduceReadyCheckTimeout(
        spots: ['u1', 'u2'],
        statuses: const {'u1': 'Ready', 'u2': 'Ready'},
        now: started.add(const Duration(minutes: 5)),
        startedAt: started,
      );
      expect(next.isLocked, isTrue);
      expect(next.readyUids, ['u1', 'u2']);
    });
  });

  group('late join', () {
    const locked = LobbyReadyLockSnapshot(
      phase: LobbyReadyLockPhase.locked,
      seatedUids: ['u1', 'u2'],
      readyUids: ['u1', 'u2'],
    );

    test('seated Occupied late join unlocks', () {
      final after = resolveLobbyReadyLock(
        spots: ['u1', 'u2', 'u3'],
        statuses: const {'u1': 'Ready', 'u2': 'Ready'},
      );
      expect(after.isLocked, isFalse);
      expect(after.seatedUids, ['u1', 'u2', 'u3']);
      expect(lateJoinUnlocks(before: locked, after: after), isTrue);
      expect(justUnlockedLobby(before: locked, after: after), isTrue);
    });

    test('calling late join does not unlock', () {
      final after = resolveLobbyReadyLock(
        spots: ['u1', 'u2', 'u3_calling'],
        statuses: const {'u1': 'Ready', 'u2': 'Ready', 'u3': 'Calling'},
      );
      expect(after.isLocked, isTrue);
      expect(after.seatedUids, ['u1', 'u2']);
      expect(lateJoinUnlocks(before: locked, after: after), isFalse);
    });

    test('late join as Ready stays locked', () {
      final after = resolveLobbyReadyLock(
        spots: ['u1', 'u2', 'u3'],
        statuses: const {'u1': 'Ready', 'u2': 'Ready', 'u3': 'Ready'},
      );
      expect(after.isLocked, isTrue);
      expect(lateJoinUnlocks(before: locked, after: after), isFalse);
    });

    test('late join during an open ready-check stays open and includes them',
        () {
      const open = LobbyReadyLockSnapshot(
        phase: LobbyReadyLockPhase.open,
        seatedUids: ['u1', 'u2'],
        readyUids: ['u1'],
      );
      final after = resolveLobbyReadyLock(
        spots: ['u1', 'u2', 'u3'],
        statuses: const {'u1': 'Ready'},
      );
      expect(after.isLocked, isFalse);
      expect(after.seatedUids, ['u1', 'u2', 'u3']);
      expect(lateJoinUnlocks(before: open, after: after), isFalse);
    });

    test('empty spots stay claimable while locked', () {
      expect(emptySpotAllowsLateJoin(locked), isTrue);
      expect(emptySpotAllowsLateJoin(LobbyReadyLockSnapshot.empty), isTrue);
    });
  });

  group('lobbyLockNotifyRecipients / planLobbyLockNotify', () {
    test('drops actor, blanks, and duplicates (no FCM-to-self)', () {
      expect(
        lobbyLockNotifyRecipients(
          seatedUids: ['u1', 'u2', ' u2 ', '', 'u3', 'u1'],
          actorUid: 'u1',
        ),
        ['u2', 'u3'],
      );
      expect(
        lobbyLockNotifyRecipients(seatedUids: ['me'], actorUid: 'me'),
        isEmpty,
      );
    });

    test('builds NotificationManager payload that routes to /squad', () {
      final plan = planLobbyLockNotify(
        seatedUids: const ['u1', 'u2', 'u3'],
        actorUid: 'u2',
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
      );

      expect(plan.recipientUids, ['u1', 'u3']);
      expect(plan.title, 'Squad locked');
      expect(plan.body, "Everyone's ready for Warzone — go in the game");
      expect(plan.data['type'], kLobbyLockedType);
      expect(plan.data['lobby_id'], 'lobby-9');
      expect(plan.data['game_name'], 'Warzone');
      expect(plan.data['from_uid'], 'u2');
      expect(
        NotificationRoutes.locationFor(plan.data),
        '/squad/Warzone?lobby_id=lobby-9',
      );
      expect(
        NotificationManager.payloadFor(
          type: kLobbyLockedType,
          lobbyId: 'lobby-9',
          gameName: 'Warzone',
        )['type'],
        kLobbyLockedType,
      );
      expect(
        planPeacockSelfNotify(
          notificationId: 'n1',
          currentUid: 'u2',
          isForeground: true,
          locallyPresentedIds: {},
        ).wouldDoubleNotifySelf,
        isFalse,
      );
    });
  });

  group('LobbyLockNotify.send', () {
    test('sends to seated members through sendToUsers hook', () async {
      String? sentTitle;
      List<String>? sentUids;
      Map<String, dynamic>? sentData;
      LobbyLockNotify.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        sentTitle = title;
        sentUids = recipientUids;
        sentData = data;
      };

      final result = await LobbyLockNotify.send(
        planLobbyLockNotify(
          seatedUids: const ['u1', 'u2'],
          actorUid: 'u1',
          lobbyId: 'lobby-9',
          gameName: 'Warzone',
        ),
      );

      expect(result.status, LobbyLockNotifyStatus.sent);
      expect(result.recipientUids, ['u2']);
      expect(sentTitle, 'Squad locked');
      expect(sentUids, ['u2']);
      expect(sentData!['type'], kLobbyLockedType);
      expect(
        NotificationRoutes.locationFor(sentData!),
        '/squad/Warzone?lobby_id=lobby-9',
      );
    });

    test('unlock notify reuses sendToUsers and routes to /squad', () async {
      List<String>? sentUids;
      Map<String, dynamic>? sentData;
      String? sentTitle;
      LobbyLockNotify.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        sentTitle = title;
        sentUids = recipientUids;
        sentData = data;
      };

      final result = await LobbyLockNotify.send(
        planLobbyUnlockNotify(
          seatedUids: const ['u1', 'u2'],
          actorUid: 'u1',
          lobbyId: 'lobby-9',
          gameName: 'Warzone',
        ),
      );

      expect(result.status, LobbyLockNotifyStatus.sent);
      expect(sentTitle, 'Squad unlocked');
      expect(sentUids, ['u2']);
      expect(sentData!['type'], kLobbyUnlockedType);
      expect(
        NotificationRoutes.locationFor(sentData!),
        '/squad/Warzone?lobby_id=lobby-9',
      );
    });

    test('timeout notify reuses sendToUsers and routes to /squad', () async {
      List<String>? sentUids;
      Map<String, dynamic>? sentData;
      LobbyLockNotify.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        sentUids = recipientUids;
        sentData = data;
      };

      final result = await LobbyLockNotify.send(
        planLobbyReadyTimeoutNotify(
          seatedUids: const ['u1', 'u2'],
          actorUid: 'u1',
          lobbyId: 'lobby-9',
          gameName: 'Warzone',
        ),
      );

      expect(result.status, LobbyLockNotifyStatus.sent);
      expect(sentUids, ['u2']);
      expect(sentData!['type'], kLobbyReadyTimeoutType);
      expect(
        NotificationRoutes.locationFor(sentData!),
        '/squad/Warzone?lobby_id=lobby-9',
      );
    });

    test('solo seated lock is selfOnly (no FCM-to-self)', () async {
      var sent = false;
      LobbyLockNotify.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        sent = true;
      };

      final result = await LobbyLockNotify.send(
        planLobbyLockNotify(
          seatedUids: const ['u1'],
          actorUid: 'u1',
          lobbyId: 'lobby-9',
        ),
      );
      expect(result.status, LobbyLockNotifyStatus.selfOnly);
      expect(sent, isFalse);
    });
  });

  group('resolveLobbyReadyLockFromState', () {
    test('reads spots and statuses from lobby state', () {
      final lobby = _lobby(
        id: 'lobby-9',
        spots: ['u1', 'u2', null],
        statuses: const {'u1': 'Ready', 'u2': 'Ready'},
      );
      final state = LobbyState.initial().copyWith(
        currentLobby: lobby,
        currentGame: const {'name': 'Warzone'},
        gameLobbySpots: {
          'Warzone': ['u1', 'u2', null],
        },
        gameStatuses: {
          'Warzone': {'u1': 'Ready', 'u2': 'Ready'},
        },
      );
      final snap = resolveLobbyReadyLockFromState(state, gameName: 'Warzone');
      expect(snap.isLocked, isTrue);
      expect(snap.seatedUids, ['u1', 'u2']);
    });
  });
}
