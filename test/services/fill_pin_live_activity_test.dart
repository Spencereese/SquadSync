import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/fill_pin_thread_header.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/services/coming_hold_machine.dart';
import 'package:squad_sync/services/fill_pin_live_activity.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';
import 'package:squad_sync/services/pin_expire_machine.dart';

/// PIN WAVE P2 — Fill PIN Live Activity Sit / Coming / Can't.
///
/// Lock-screen payload + action mapping. Coming is 300s via
/// [reduceComingHold] and never auto-sits. Tap reuses the chat deep link.
class FakeFillPinLiveActivityUpdater {
  FillPinLiveActivityPayload? lastPayload;
  final plans = <FillPinLiveActivityPlan>[];
  String nextActivityId = 'act-pin-1';

  Future<String?> apply(FillPinLiveActivityPlan plan) async {
    plans.add(plan);
    switch (plan.op) {
      case FillPinLiveActivityOp.none:
        return lastPayload?.activityId;
      case FillPinLiveActivityOp.start:
        lastPayload = plan.payload.copyWith(activityId: nextActivityId);
        return nextActivityId;
      case FillPinLiveActivityOp.update:
        lastPayload = plan.payload;
        return plan.payload.activityId ?? lastPayload?.activityId;
      case FillPinLiveActivityOp.end:
        lastPayload = null;
        return null;
    }
  }
}

FillPinSnapshot _snapshot({
  String lobbyId = 'pin-1',
  String gameName = 'Warzone',
  int seated = 1,
  int maxSpots = 4,
}) {
  return FillPinSnapshot(
    lobbyId: lobbyId,
    gameName: gameName,
    seated: seated,
    maxSpots: maxSpots,
    seatedUids: List<String>.generate(seated, (i) => 'u${i + 1}'),
  );
}

void main() {
  setUp(FillPinLiveActivity.resetTestHooks);
  tearDown(FillPinLiveActivity.resetTestHooks);

  group('planFillPinLiveActivity — Sit / Coming / Can\'t + mm:ss', () {
    test('active pin starts with Sit / Coming / Can\'t and no hold', () {
      final plan = planFillPinLiveActivity(
        chatGroupId: 'group-1',
        snapshot: _snapshot(),
      );

      expect(plan.op, FillPinLiveActivityOp.start);
      expect(plan.payload.phase, FillPinLiveActivityPhase.open);
      expect(plan.payload.actionLabels, ['Sit', 'Coming', "Can't"]);
      expect(plan.payload.actionIds, ['sit', 'coming', 'cant']);
      expect(plan.payload.holdLabel, isEmpty);
      expect(plan.payload.title, 'Warzone 1/4');
      expect(plan.payload.body, "Sit · Coming · Can't");
    });

    test('Coming hold shows mm:ss from 5:00 toward 0', () {
      expect(formatComingHoldMmSs(kComingHoldDuration), '5:00');
      expect(formatComingHoldMmSs(const Duration(seconds: 299)), '4:59');
      expect(formatComingHoldMmSs(const Duration(seconds: 61)), '1:01');
      expect(formatComingHoldMmSs(Duration.zero), '0:00');

      const hold = ComingHoldState(
        phase: ComingHoldPhase.coming,
        pinId: 'pin-1',
        remaining: Duration(seconds: 300),
      );
      final plan = planFillPinLiveActivity(
        chatGroupId: 'group-1',
        snapshot: _snapshot(),
        hold: hold,
      );

      expect(plan.payload.phase, FillPinLiveActivityPhase.coming);
      expect(plan.payload.holdLabel, '5:00');
      expect(plan.payload.body, 'Coming 5:00');
      expect(plan.payload.actionLabels, ['Sit', 'Coming', "Can't"]);
    });

    test('tap deep link lands on the thread + pin', () {
      final plan = planFillPinLiveActivity(
        chatGroupId: 'group-1',
        snapshot: _snapshot(lobbyId: 'pin-1'),
      );
      final link = plan.payload.deepLink;

      expect(link, contains('codsquadapp://chat/group-1'));
      expect(link, contains('pin_id=pin-1'));
      expect(link, contains('lobby_id=pin-1'));
      expect(locationForDeepLink(link), '/chat/group-1');

      String? opened;
      openFillPinLiveActivity(
        chatGroupId: 'group-1',
        pinId: 'pin-1',
        lobbyId: 'pin-1',
        go: (location) => opened = location,
      );
      expect(opened, '/chat/group-1');
    });

    test('missing snapshot or expired pin ends a live activity', () {
      final ended = planFillPinLiveActivity(
        chatGroupId: 'group-1',
        snapshot: null,
        currentActivityId: 'act-1',
      );
      expect(ended.op, FillPinLiveActivityOp.end);
      expect(ended.payload.phase, FillPinLiveActivityPhase.ended);
      expect(ended.payload.actions, isEmpty);

      final expiredPin = planFillPinLiveActivity(
        chatGroupId: 'group-1',
        snapshot: _snapshot(),
        expire: const PinExpireState(
          phase: PinExpirePhase.expired,
          pinId: 'pin-1',
        ),
        currentActivityId: 'act-1',
      );
      expect(expiredPin.op, FillPinLiveActivityOp.end);
    });
  });

  group('applyFillPinLiveActivityAction — no auto-sit; Coming is 300s', () {
    test('Coming starts a 300s hold and does not sit', () {
      final next = applyFillPinLiveActivityAction(
        action: FillPinLiveActivityAction.coming,
        current: ComingHoldState.idle,
        seatIndex: 2,
        pinId: 'pin-1',
        userId: 'u9',
      );

      expect(next.phase, ComingHoldPhase.coming);
      expect(next.remaining, kComingHoldDuration);
      expect(next.holdsSeat, isTrue);
      expect(next.phase, isNot(ComingHoldPhase.seated));
      expect(kComingHoldDuration, const Duration(seconds: 300));
    });

    test('Sit from idle takes the seat (I\'m in) without leaving a hold', () {
      final next = applyFillPinLiveActivityAction(
        action: FillPinLiveActivityAction.sit,
        current: ComingHoldState.idle,
        seatIndex: 1,
        pinId: 'pin-1',
        userId: 'u1',
      );

      expect(next.phase, ComingHoldPhase.seated);
      expect(next.holdsSeat, isTrue);
      expect(next.seatFreed, isFalse);
      expect(next.seatIndex, 1);
      expect(next.userId, 'u1');
    });

    test('Sit while Coming is I\'m in via reduceComingHold', () {
      final coming = applyFillPinLiveActivityAction(
        action: FillPinLiveActivityAction.coming,
        current: ComingHoldState.idle,
        seatIndex: 0,
        userId: 'u1',
      );
      final seated = applyFillPinLiveActivityAction(
        action: FillPinLiveActivityAction.sit,
        current: coming,
      );

      expect(seated.phase, ComingHoldPhase.seated);
      expect(seated.holdsSeat, isTrue);
    });

    test('Can\'t from Coming releases the seat and fires the nudge stub', () {
      var nudged = false;
      final coming = applyFillPinLiveActivityAction(
        action: FillPinLiveActivityAction.coming,
        current: ComingHoldState.idle,
        seatIndex: 3,
      );
      final released = applyFillPinLiveActivityAction(
        action: FillPinLiveActivityAction.cant,
        current: coming,
        onSpotOpenNudge: () => nudged = true,
      );

      expect(released.phase, ComingHoldPhase.released);
      expect(released.seatFreed, isTrue);
      expect(released.holdsSeat, isFalse);
      expect(released.shouldNudgeSpotOpen, isTrue);
      expect(nudged, isTrue);
    });

    test('tick to t=0 frees the seat and never auto-sits', () {
      var nudged = false;
      var hold = applyFillPinLiveActivityAction(
        action: FillPinLiveActivityAction.coming,
        current: ComingHoldState.idle,
        seatIndex: 1,
        pinId: 'pin-1',
      );

      hold = tickFillPinComingHold(
        current: hold,
        elapsed: const Duration(seconds: 120),
      );
      expect(hold.phase, ComingHoldPhase.coming);
      expect(hold.remaining, const Duration(seconds: 180));
      expect(formatComingHoldMmSs(hold.remaining), '3:00');
      expect(hold.phase, isNot(ComingHoldPhase.seated));

      hold = tickFillPinComingHold(
        current: hold,
        elapsed: const Duration(seconds: 180),
        onSpotOpenNudge: () => nudged = true,
      );
      expect(hold.phase, ComingHoldPhase.expired);
      expect(hold.remaining, Duration.zero);
      expect(hold.seatFreed, isTrue);
      expect(hold.holdsSeat, isFalse);
      expect(hold.shouldNudgeSpotOpen, isTrue);
      expect(nudged, isTrue);
      expect(hold.phase, isNot(ComingHoldPhase.seated));
    });

    test('Coming ticks never auto-sit across the 5:00 window', () {
      var hold = applyFillPinLiveActivityAction(
        action: FillPinLiveActivityAction.coming,
        current: ComingHoldState.idle,
      );
      for (var i = 0; i < 5; i++) {
        hold = tickFillPinComingHold(
          current: hold,
          elapsed: const Duration(seconds: 30),
        );
        expect(hold.phase, ComingHoldPhase.coming);
        expect(hold.phase, isNot(ComingHoldPhase.seated));
      }
      expect(hold.remaining, const Duration(seconds: 150));
    });
  });

  group('FillPinLiveActivity.syncFromThread', () {
    test('start → Coming update (5:00) → end', () async {
      final widget = FakeFillPinLiveActivityUpdater();
      FillPinLiveActivity.invokeHook = widget.apply;
      final snapshot = _snapshot();

      await FillPinLiveActivity.syncFromThread(
        chatGroupId: 'group-1',
        snapshot: snapshot,
      );
      expect(FillPinLiveActivity.debugActivityId, 'act-pin-1');
      expect(widget.lastPayload!.actionLabels, ['Sit', 'Coming', "Can't"]);

      await FillPinLiveActivity.applyChannelAction(
        actionId: 'coming',
        chatGroupId: 'group-1',
        snapshot: snapshot,
        seatIndex: 1,
        userId: 'u1',
      );
      expect(FillPinLiveActivity.debugHold.phase, ComingHoldPhase.coming);
      expect(widget.lastPayload!.holdLabel, '5:00');
      expect(widget.lastPayload!.phase, FillPinLiveActivityPhase.coming);

      await FillPinLiveActivity.syncFromThread(
        chatGroupId: 'group-1',
        snapshot: null,
      );
      expect(FillPinLiveActivity.debugActivityId, isNull);
      expect(
        widget.plans.map((p) => p.op),
        [
          FillPinLiveActivityOp.start,
          FillPinLiveActivityOp.update,
          FillPinLiveActivityOp.end,
        ],
      );
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
      final src =
          File('lib/services/fill_pin_live_activity.dart').readAsStringSync();
      expect(src.contains('planPeacockSelfNotify'), isTrue);
      expect(src.contains('FirebaseMessaging'), isFalse);
    });
  });

  group('channel payload round-trip', () {
    test('coming payload keeps actions + hold + deep link', () {
      const hold = ComingHoldState(
        phase: ComingHoldPhase.coming,
        pinId: 'pin-1',
        remaining: Duration(seconds: 125),
      );
      final plan = planFillPinLiveActivity(
        chatGroupId: 'group-1',
        snapshot: _snapshot(),
        hold: hold,
        currentActivityId: 'act-9',
      );
      final restored = FillPinLiveActivityPayload.fromChannelArgs(
        plan.payload.toChannelArgs(),
      );

      expect(restored.phase, FillPinLiveActivityPhase.coming);
      expect(restored.holdLabel, '2:05');
      expect(restored.actionIds, ['sit', 'coming', 'cant']);
      expect(locationForDeepLink(restored.deepLink), '/chat/group-1');
      expect(plan.payload.toChannelArgs()['actions'], ['Sit', 'Coming', "Can't"]);
    });
  });

  group('P1 fill-pin surfaces not dual-edited', () {
    test('header / chip / badge / machines stay the P1 files', () {
      expect(
        File('lib/chat/fill_pin_thread_header.dart').existsSync(),
        isTrue,
      );
      expect(File('lib/chat/fill_pin_group_row_badge.dart').existsSync(), isTrue);
      expect(File('lib/core/fill_pin_suggestion_parser.dart').existsSync(), isTrue);
      expect(File('lib/services/coming_hold_machine.dart').existsSync(), isTrue);
      expect(File('lib/services/pin_expire_machine.dart').existsSync(), isTrue);
      final header =
          File('lib/chat/fill_pin_thread_header.dart').readAsStringSync();
      expect(header.contains('comingCountdown'), isTrue);
      expect(header.contains('resolveFillPinForThread'), isTrue);
    });
  });
}
