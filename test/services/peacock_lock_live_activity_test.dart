import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/core/notification_routes.dart';
import 'package:squad_sync/services/lobby_ready_lock.dart';
import 'package:squad_sync/services/peacock_lock_live_activity.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// Records home-widget / Live Activity payload mocks. No native I/O.
class FakePeacockLockWidgetUpdater {
  PeacockLockLiveActivityPayload? lastPayload;
  PeacockLockLiveActivityPhase? previousPhase;
  final plans = <PeacockLockLiveActivityPlan>[];
  String nextActivityId = 'act-1';

  bool get isEmpty => lastPayload == null;

  Map<String, dynamic>? get lastChannelArgs => lastPayload?.toChannelArgs();

  PeacockLockWidgetView view({DateTime? now}) {
    final payload = lastPayload;
    if (payload == null) return PeacockLockWidgetView.empty;
    return resolvePeacockLockWidgetView(
      payload: payload,
      previousPhase: previousPhase,
      now: now,
    );
  }

  Future<String?> apply(PeacockLockLiveActivityPlan plan) async {
    plans.add(plan);
    previousPhase = lastPayload?.phase;
    switch (plan.op) {
      case PeacockLockLiveActivityOp.none:
        return lastPayload?.activityId;
      case PeacockLockLiveActivityOp.start:
        lastPayload = plan.payload.copyWith(activityId: nextActivityId);
        return nextActivityId;
      case PeacockLockLiveActivityOp.update:
        lastPayload = plan.payload;
        return plan.payload.activityId ?? lastPayload?.activityId;
      case PeacockLockLiveActivityOp.end:
        lastPayload = null;
        return null;
    }
  }
}

const _open = LobbyReadyLockSnapshot(
  phase: LobbyReadyLockPhase.open,
  seatedUids: ['u1', 'u2'],
  readyUids: ['u1'],
);

const _locked = LobbyReadyLockSnapshot(
  phase: LobbyReadyLockPhase.locked,
  seatedUids: ['u1', 'u2'],
  readyUids: ['u1', 'u2'],
);

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

  group('home widget payload mock — lock / unlock', () {
    test('lock peacock writes locked on the widget payload mock', () async {
      final widget = FakePeacockLockWidgetUpdater();
      final clock = DateTime.utc(2026, 9, 6, 12);
      final plan = planPeacockLockLiveActivity(
        snapshot: _locked,
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        now: clock,
      );

      expect(plan.op, PeacockLockLiveActivityOp.start);
      expect(plan.payload.isLocked, isTrue);
      expect(plan.payload.toChannelArgs()['locked'], isTrue);
      expect(plan.payload.toChannelArgs()['phase'], 'locked');
      expect(
        resolvePeacockLockWidgetView(payload: plan.payload),
        PeacockLockWidgetView.locked,
      );

      await widget.apply(plan);
      expect(widget.view(), PeacockLockWidgetView.locked);
      expect(widget.lastChannelArgs!['locked'], isTrue);
      expect(widget.lastChannelArgs!['title'], 'Squad locked');
      expect(widget.lastPayload!.updatedAt, clock);
    });

    test('unlock peacock clears locked on the widget payload mock', () async {
      final widget = FakePeacockLockWidgetUpdater();
      await widget.apply(
        planPeacockLockLiveActivity(
          snapshot: _locked,
          lobbyId: 'lobby-9',
          gameName: 'Warzone',
        ),
      );
      expect(widget.lastChannelArgs!['locked'], isTrue);

      final unlocked = planPeacockLockLiveActivity(
        snapshot: _open,
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        currentActivityId: widget.lastPayload!.activityId,
      );

      expect(unlocked.op, PeacockLockLiveActivityOp.update);
      expect(unlocked.payload.isLocked, isFalse);
      expect(unlocked.payload.phase, PeacockLockLiveActivityPhase.ready);
      expect(unlocked.payload.toChannelArgs()['locked'], isFalse);
      expect(unlocked.payload.toChannelArgs()['phase'], 'ready');
      expect(
        resolvePeacockLockWidgetView(
          payload: unlocked.payload,
          previousPhase: PeacockLockLiveActivityPhase.locked,
        ),
        PeacockLockWidgetView.unlocked,
      );

      await widget.apply(unlocked);
      expect(widget.view(), PeacockLockWidgetView.unlocked);
      expect(widget.lastChannelArgs!['locked'], isFalse);
      expect(widget.lastChannelArgs!['title'], isNot('Squad locked'));
    });

    test('unlock with no seated ends the widget as unlocked / cleared', () {
      final plan = planPeacockLockLiveActivity(
        snapshot: LobbyReadyLockSnapshot.empty,
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        currentActivityId: 'act-1',
      );

      expect(plan.op, PeacockLockLiveActivityOp.end);
      expect(plan.payload.isLocked, isFalse);
      expect(plan.payload.phase, PeacockLockLiveActivityPhase.ended);
      expect(plan.payload.body, 'Warzone unlocked');
      expect(plan.payload.toChannelArgs()['locked'], isFalse);
      expect(
        resolvePeacockLockWidgetView(
          payload: plan.payload,
          op: plan.op,
          previousPhase: PeacockLockLiveActivityPhase.locked,
        ),
        PeacockLockWidgetView.unlocked,
      );
    });

    test('syncFromReadyLock lock then unlock clears the live payload',
        () async {
      final widget = FakePeacockLockWidgetUpdater();
      PeacockLockLiveActivity.invokeHook = widget.apply;

      await PeacockLockLiveActivity.syncFromReadyLock(
        snapshot: _locked,
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
      );
      expect(widget.lastChannelArgs!['locked'], isTrue);
      expect(PeacockLockLiveActivity.debugActivityId, 'act-1');

      await PeacockLockLiveActivity.syncFromReadyLock(
        snapshot: _open,
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
      );
      expect(widget.view(), PeacockLockWidgetView.unlocked);
      expect(widget.lastChannelArgs!['locked'], isFalse);
      expect(PeacockLockLiveActivity.debugActivityId, 'act-1');
    });
  });

  group('home widget payload mock — empty', () {
    test('no lobby is empty, not a hung locked widget', () {
      final plan = planPeacockLockLiveActivity(
        snapshot: _locked,
        lobbyId: '  ',
      );

      expect(plan.op, PeacockLockLiveActivityOp.none);
      expect(plan.payload.isLocked, isFalse);
      expect(
        resolvePeacockLockWidgetView(payload: plan.payload, op: plan.op),
        PeacockLockWidgetView.empty,
      );
      expect(
        resolvePeacockLockWidgetView(
          payload: PeacockLockLiveActivityPayload.empty,
        ),
        PeacockLockWidgetView.empty,
      );
    });

    test('no active peacock / no seated is empty when nothing is live',
        () async {
      final widget = FakePeacockLockWidgetUpdater();
      final plan = planPeacockLockLiveActivity(
        snapshot: LobbyReadyLockSnapshot.empty,
        lobbyId: 'lobby-9',
      );

      expect(plan.shouldInvoke, isFalse);
      expect(
        resolvePeacockLockWidgetView(payload: plan.payload, op: plan.op),
        PeacockLockWidgetView.empty,
      );

      await widget.apply(plan);
      expect(widget.isEmpty, isTrue);
      expect(widget.view(), PeacockLockWidgetView.empty);
      expect(widget.lastChannelArgs, isNull);
    });

    test('empty payload round-trips through the channel mock', () {
      final args = PeacockLockLiveActivityPayload.empty.toChannelArgs();
      final restored = PeacockLockLiveActivityPayload.fromChannelArgs(args);
      expect(restored.lobbyId, isEmpty);
      expect(restored.phase, PeacockLockLiveActivityPhase.ended);
      expect(restored.isLocked, isFalse);
      expect(restored.seatedCount, 0);
      expect(args['locked'], isFalse);
    });
  });

  group('home widget payload mock — stale', () {
    final clock = DateTime.utc(2026, 9, 6, 12);

    test('fresh payload is not stale', () {
      final payload = PeacockLockLiveActivityPayload(
        lobbyId: 'lobby-9',
        phase: PeacockLockLiveActivityPhase.locked,
        seatedCount: 2,
        readyCount: 2,
        activityId: 'act-1',
        updatedAt: clock,
      );
      expect(payload.isStaleAt(clock), isFalse);
      expect(
        payload.isStaleAt(
          clock.add(kPeacockLockWidgetStaleTimeout - const Duration(seconds: 1)),
        ),
        isFalse,
      );
      expect(
        resolvePeacockLockWidgetView(payload: payload, now: clock),
        PeacockLockWidgetView.locked,
      );
      expect(
        planStalePeacockLockWidget(lastPayload: payload, now: clock).op,
        PeacockLockLiveActivityOp.none,
      );
    });

    test('outdated payload is marked stale then cleared when live', () async {
      final widget = FakePeacockLockWidgetUpdater();
      final payload = PeacockLockLiveActivityPayload(
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        phase: PeacockLockLiveActivityPhase.locked,
        seatedCount: 2,
        readyCount: 2,
        activityId: 'act-1',
        updatedAt: clock,
      );
      widget.lastPayload = payload;

      final staleAt = clock.add(kPeacockLockWidgetStaleTimeout);
      expect(payload.isStaleAt(staleAt), isTrue);
      expect(
        resolvePeacockLockWidgetView(payload: payload, now: staleAt),
        PeacockLockWidgetView.stale,
      );

      final plan = planStalePeacockLockWidget(
        lastPayload: payload,
        now: staleAt,
      );
      expect(plan.op, PeacockLockLiveActivityOp.end);
      expect(plan.payload.phase, PeacockLockLiveActivityPhase.ended);
      expect(plan.payload.isLocked, isFalse);
      expect(plan.payload.toChannelArgs()['locked'], isFalse);

      await widget.apply(plan);
      expect(widget.isEmpty, isTrue);
      expect(widget.view(), PeacockLockWidgetView.empty);
    });

    test('stale payload with nothing live stays empty, not a hung widget', () {
      final payload = PeacockLockLiveActivityPayload(
        lobbyId: 'lobby-9',
        phase: PeacockLockLiveActivityPhase.locked,
        seatedCount: 2,
        readyCount: 2,
        updatedAt: clock,
      );
      final staleAt = clock.add(kPeacockLockWidgetStaleTimeout);
      final plan = planStalePeacockLockWidget(
        lastPayload: payload,
        now: staleAt,
      );
      expect(plan.op, PeacockLockLiveActivityOp.none);
      expect(plan.shouldInvoke, isFalse);
      expect(
        resolvePeacockLockWidgetView(payload: payload, now: staleAt),
        PeacockLockWidgetView.stale,
      );
    });

    test('syncStaleWidget ends the live helper when the payload expired',
        () async {
      final widget = FakePeacockLockWidgetUpdater();
      PeacockLockLiveActivity.invokeHook = widget.apply;
      await widget.apply(
        planPeacockLockLiveActivity(
          snapshot: _locked,
          lobbyId: 'lobby-9',
          now: clock,
        ),
      );
      expect(widget.lastPayload, isNotNull);

      await PeacockLockLiveActivity.syncStaleWidget(
        lastPayload: widget.lastPayload!,
        now: clock.add(kPeacockLockWidgetStaleTimeout),
      );
      expect(widget.isEmpty, isTrue);
      expect(PeacockLockLiveActivity.debugActivityId, isNull);
      expect(widget.plans.last.op, PeacockLockLiveActivityOp.end);
    });

    test('channel mock carries staleAt for the native payload', () {
      final payload = PeacockLockLiveActivityPayload(
        lobbyId: 'lobby-9',
        phase: PeacockLockLiveActivityPhase.locked,
        seatedCount: 1,
        readyCount: 1,
        updatedAt: clock,
      );
      final args = payload.toChannelArgs();
      expect(args['updatedAt'], clock.toIso8601String());
      expect(
        args['staleAt'],
        clock.add(kPeacockLockWidgetStaleTimeout).toIso8601String(),
      );
      final restored = PeacockLockLiveActivityPayload.fromChannelArgs(args);
      expect(restored.updatedAt, clock);
      expect(restored.isStaleAt(clock.add(kPeacockLockWidgetStaleTimeout)),
          isTrue);
    });
  });
}
