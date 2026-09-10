import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/fill_pin_thread_header.dart';
import 'package:squad_sync/services/coming_hold_machine.dart';
import 'package:squad_sync/services/fill_pin_live_activity.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// Widget Extension + App Intents for Fill PIN lock-screen buttons.
/// Taps must reach [FillPinLiveActivity.applyChannelAction] only.
void main() {
  setUp(FillPinLiveActivity.resetTestHooks);
  tearDown(FillPinLiveActivity.resetTestHooks);

  Future<String?> capture(FillPinLiveActivityPlan plan) async {
    return plan.op == FillPinLiveActivityOp.start ? 'act-pin-1' : plan.payload.activityId;
  }

  group('incoming lock-screen action uses applyChannelAction', () {
    test('Coming from inbox starts 300s hold and does not sit', () async {
      FillPinLiveActivity.invokeHook = capture;
      FillPinLiveActivity.currentUidHook = () => 'u9';

      await FillPinLiveActivity.syncFromThread(
        chatGroupId: 'group-1',
        snapshot: const FillPinSnapshot(
          lobbyId: 'pin-1',
          gameName: 'Warzone',
          seated: 1,
          maxSpots: 4,
          seatedUids: ['u1'],
        ),
      );

      final hold = await FillPinLiveActivity.applyIncomingChannelArgs({
        'actionId': 'coming',
        'chatGroupId': 'group-1',
        'pinId': 'pin-1',
      });

      expect(hold.phase, ComingHoldPhase.coming);
      expect(hold.remaining, kComingHoldDuration);
      expect(hold.phase, isNot(ComingHoldPhase.seated));
      expect(hold.userId, 'u9');
    });

    test('Sit from inbox takes the seat (I\'m in)', () async {
      FillPinLiveActivity.invokeHook = capture;
      FillPinLiveActivity.currentUidHook = () => 'u2';

      final hold = await FillPinLiveActivity.applyIncomingChannelArgs({
        'actionId': 'sit',
        'chatGroupId': 'group-1',
        'pinId': 'pin-1',
      });

      expect(hold.phase, ComingHoldPhase.seated);
      expect(hold.holdsSeat, isTrue);
    });

    test('Can\'t from Coming releases via the same reducer', () async {
      FillPinLiveActivity.invokeHook = capture;
      await FillPinLiveActivity.applyIncomingChannelArgs({
        'actionId': 'coming',
        'chatGroupId': 'group-1',
        'pinId': 'pin-1',
      });
      final released = await FillPinLiveActivity.applyIncomingChannelArgs({
        'actionId': 'cant',
        'chatGroupId': 'group-1',
        'pinId': 'pin-1',
      });

      expect(released.phase, ComingHoldPhase.released);
      expect(released.seatFreed, isTrue);
    });
  });

  group('widget extension + intents are in-repo', () {
    test('PeacockLockWidget shows Sit / Coming / Can\'t', () {
      final ui = File('ios/PeacockLockWidget/PeacockLockWidget.swift')
          .readAsStringSync();
      expect(ui.contains('FillPinLiveActivityWidget'), isTrue);
      expect(ui.contains('FillPinLockScreenIntent'), isTrue);
      expect(ui.contains('widgetURL'), isTrue);
      expect(ui.contains('Sit'), isTrue);
      expect(ui.contains('Coming'), isTrue);
      expect(ui.contains("Can't") || ui.contains('cant'), isTrue);
    });

    test('intents enqueue onto the existing LA channel inbox', () {
      final intents =
          File('ios/Shared/FillPinLiveActivityIntents.swift').readAsStringSync();
      expect(intents.contains('FillPinActionInbox.enqueue'), isTrue);
      expect(intents.contains('actionId: "sit"'), isTrue);
      expect(intents.contains('actionId: "coming"'), isTrue);
      expect(intents.contains('actionId: "cant"'), isTrue);
      expect(intents.contains('FirebaseMessaging'), isFalse);

      final relay =
          File('ios/Runner/PeacockLockLiveActivity.swift').readAsStringSync();
      expect(relay.contains('fillPinAction'), isTrue);
      expect(relay.contains('drainFillPinActions'), isTrue);
      expect(
        File('lib/services/fill_pin_live_activity.dart')
            .readAsStringSync()
            .contains('applyIncomingChannelArgs'),
        isTrue,
      );
    });

    test('pbxproj embeds PeacockLockWidget — Runner bundle unchanged', () {
      final pbx =
          File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(
        pbx.contains(
          'PRODUCT_BUNDLE_IDENTIFIER = com.example.codSquadApp.PeacockLockWidget;',
        ),
        isTrue,
      );
      expect(
        pbx.contains('PRODUCT_BUNDLE_IDENTIFIER = com.example.codSquadApp;'),
        isTrue,
      );
      expect(pbx.contains('Embed Foundation Extensions'), isTrue);
      expect(
        pbx.contains('group.com.example.codSquadApp') ||
            File('ios/Runner/Runner.entitlements')
                .readAsStringSync()
                .contains('group.com.example.codSquadApp'),
        isTrue,
      );
    });

    test('XOR stays one notify path — no second FCM send', () {
      expect(
        planPeacockSelfNotify(
          notificationId: 'n1',
          currentUid: 'u1',
          isForeground: true,
          locallyPresentedIds: {},
        ).wouldDoubleNotifySelf,
        isFalse,
      );
      expect(
        File('lib/services/fill_pin_live_activity.dart')
            .readAsStringSync()
            .contains('planPeacockSelfNotify'),
        isTrue,
      );
      expect(
        File('ios/Shared/FillPinLiveActivityIntents.swift')
            .readAsStringSync()
            .contains('FirebaseMessaging'),
        isFalse,
      );
    });

    test('forbidden files stay untouched by this slice', () {
      expect(
        File('lib/presentation/notifiers/lobby_notifier.dart')
            .readAsStringSync()
            .contains('PeacockLockWidget'),
        isFalse,
      );
      expect(
        File('lib/chat/screens/chat_info_screen.dart')
            .readAsStringSync()
            .contains('fill_pin_live_activity'),
        isFalse,
      );
      expect(
        File('lib/chat/message_bubble.dart')
            .readAsStringSync()
            .contains('fill_pin_live_activity'),
        isFalse,
      );
    });
  });
}
