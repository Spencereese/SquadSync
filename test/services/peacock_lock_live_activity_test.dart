import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/core/notification_routes.dart';
import 'package:squad_sync/services/lobby_ready_lock.dart';
import 'package:squad_sync/services/peacock_lock_live_activity.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

void main() {
  setUp(PeacockLockLiveActivity.resetTestHooks);
  tearDown(PeacockLockLiveActivity.resetTestHooks);

  group('planPeacockLockLiveActivity', () {
    test('starts a ready payload when seated and no activity', () {
      final plan = planPeacockLockLiveActivity(
        snapshot: const LobbyReadyLockSnapshot(
          phase: LobbyReadyLockPhase.open,
          seatedUids: ['u1', 'u2'],
          readyUids: ['u1'],
        ),
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
      );

      expect(plan.op, PeacockLockLiveActivityOp.start);
      expect(plan.payload.phase, PeacockLockLiveActivityPhase.ready);
      expect(plan.payload.seatedCount, 2);
      expect(plan.payload.readyCount, 1);
      expect(plan.payload.title, 'Squad ready');
      expect(plan.payload.body, '1 of 2 ready for Warzone');
      expect(plan.payload.deepLink, 'codsquadapp://lobby/lobby-9');
      expect(
        locationForDeepLink(plan.payload.deepLink),
        '/squad?lobby_id=lobby-9',
      );
    });

    test('starts a locked payload when all seated Ready', () {
      final plan = planPeacockLockLiveActivity(
        snapshot: const LobbyReadyLockSnapshot(
          phase: LobbyReadyLockPhase.locked,
          seatedUids: ['u1', 'u2'],
          readyUids: ['u1', 'u2'],
        ),
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
      );

      expect(plan.op, PeacockLockLiveActivityOp.start);
      expect(plan.payload.phase, PeacockLockLiveActivityPhase.locked);
      expect(plan.payload.title, 'Squad locked');
      expect(
        plan.payload.body,
        "Everyone's ready for Warzone — go in the game",
      );
      expect(plan.payload.toChannelArgs()['phase'], 'locked');
      expect(plan.payload.toChannelArgs()['lobbyId'], 'lobby-9');
      expect(
        NotificationRoutes.locationFor({
          'type': kLobbyLockedType,
          'lobby_id': 'lobby-9',
          'game_name': 'Warzone',
        }),
        locationForDeepLink(plan.payload.deepLink),
      );
    });

    test('updates when an activity id is already live', () {
      final plan = planPeacockLockLiveActivity(
        snapshot: const LobbyReadyLockSnapshot(
          phase: LobbyReadyLockPhase.locked,
          seatedUids: ['u1', 'u2'],
          readyUids: ['u1', 'u2'],
        ),
        lobbyId: 'lobby-9',
        currentActivityId: 'act-1',
      );

      expect(plan.op, PeacockLockLiveActivityOp.update);
      expect(plan.payload.activityId, 'act-1');
      expect(plan.payload.toChannelArgs()['activityId'], 'act-1');
    });

    test('ends when seated is empty and an activity is live', () {
      final plan = planPeacockLockLiveActivity(
        snapshot: LobbyReadyLockSnapshot.empty,
        lobbyId: 'lobby-9',
        currentActivityId: 'act-1',
      );

      expect(plan.op, PeacockLockLiveActivityOp.end);
      expect(plan.payload.phase, PeacockLockLiveActivityPhase.ended);
      expect(plan.payload.activityId, 'act-1');
    });

    test('no-ops when seated is empty and nothing is live', () {
      final plan = planPeacockLockLiveActivity(
        snapshot: LobbyReadyLockSnapshot.empty,
        lobbyId: 'lobby-9',
      );
      expect(plan.op, PeacockLockLiveActivityOp.none);
      expect(plan.shouldInvoke, isFalse);
    });

    test('no-ops when lobby id is blank', () {
      final plan = planPeacockLockLiveActivity(
        snapshot: const LobbyReadyLockSnapshot(
          phase: LobbyReadyLockPhase.locked,
          seatedUids: ['u1'],
          readyUids: ['u1'],
        ),
        lobbyId: '  ',
      );
      expect(plan.op, PeacockLockLiveActivityOp.none);
    });
  });

  group('PeacockLockLiveActivity.syncFromReadyLock', () {
    test('start then update then end on the live helper', () async {
      final ops = <PeacockLockLiveActivityOp>[];
      PeacockLockLiveActivity.invokeHook = (plan) async {
        ops.add(plan.op);
        if (plan.op == PeacockLockLiveActivityOp.start) return 'act-1';
        return plan.payload.activityId;
      };

      const open = LobbyReadyLockSnapshot(
        phase: LobbyReadyLockPhase.open,
        seatedUids: ['u1', 'u2'],
        readyUids: ['u1'],
      );
      const locked = LobbyReadyLockSnapshot(
        phase: LobbyReadyLockPhase.locked,
        seatedUids: ['u1', 'u2'],
        readyUids: ['u1', 'u2'],
      );

      await PeacockLockLiveActivity.syncFromReadyLock(
        snapshot: open,
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
      );
      expect(PeacockLockLiveActivity.debugActivityId, 'act-1');

      await PeacockLockLiveActivity.syncFromReadyLock(
        snapshot: locked,
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
      );
      await PeacockLockLiveActivity.syncFromReadyLock(
        snapshot: LobbyReadyLockSnapshot.empty,
        lobbyId: 'lobby-9',
      );

      expect(ops, [
        PeacockLockLiveActivityOp.start,
        PeacockLockLiveActivityOp.update,
        PeacockLockLiveActivityOp.end,
      ]);
      expect(PeacockLockLiveActivity.debugActivityId, isNull);
    });

    test('does not send FCM-to-self (XOR stays planPeacockSelfNotify)', () {
      expect(
        planPeacockSelfNotify(
          notificationId: 'n1',
          currentUid: 'u1',
          isForeground: true,
          locallyPresentedIds: {},
        ).wouldDoubleNotifySelf,
        isFalse,
      );
    });
  });
}
