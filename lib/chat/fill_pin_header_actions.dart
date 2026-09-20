import 'package:flutter/material.dart';

import '../services/coming_hold_machine.dart';
import '../services/fill_pin_live_activity.dart';

/// Friend-visible Sit / Coming / Can't on the Fill PIN header.
const kFillPinSitKey = Key('fill-pin-sit');
const kFillPinComingKey = Key('fill-pin-coming');
const kFillPinCantKey = Key('fill-pin-cant');

const kFillPinHeaderSitLabel = kFillPinLiveActivitySitLabel;
const kFillPinHeaderComingLabel = kFillPinLiveActivityComingLabel;
const kFillPinHeaderCantLabel = kFillPinLiveActivityCantLabel;

const kFillPinSpotOpenNudgeKey = Key('fill-pin-spot-open-nudge');

/// Friend-visible cue when Coming frees a seat (expire / Can't).
/// Idle / Sit / Coming-with-time stay quiet.
String? fillPinSpotOpenNudgeCue(ComingHoldState? hold) {
  if (hold == null || !hold.shouldNudgeSpotOpen) return null;
  return 'Spot open';
}

/// Header Sit / Coming / Can't → existing LA apply (300s hold, no auto-sit).
Future<ComingHoldState> applyFillPinHeaderAction({
  required String actionId,
  required String chatGroupId,
  String? pinId,
  void Function()? onSpotOpenNudge,
}) {
  if (onSpotOpenNudge == null) {
    return FillPinLiveActivity.applyIncomingChannelArgs({
      'actionId': actionId,
      'chatGroupId': chatGroupId,
      'pinId': pinId,
    });
  }
  return FillPinLiveActivity.applyChannelAction(
    actionId: actionId,
    chatGroupId: chatGroupId,
    pinId: pinId,
    onSpotOpenNudge: onSpotOpenNudge,
  );
}

/// Pin-header cue. Reads [shouldNudgeSpotOpen] from [hold] or LA debug hold.
class FillPinSpotOpenNudgeCue extends StatelessWidget {
  const FillPinSpotOpenNudgeCue({super.key, this.hold});

  final ComingHoldState? hold;

  @override
  Widget build(BuildContext context) {
    final cue = fillPinSpotOpenNudgeCue(
      hold ?? FillPinLiveActivity.debugHold,
    );
    if (cue == null) return const SizedBox.shrink();
    return Text(
      cue,
      key: kFillPinSpotOpenNudgeKey,
      style: const TextStyle(color: Colors.white70, fontSize: 11),
    );
  }
}
