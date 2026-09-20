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

/// Header Sit / Coming / Can't → existing LA apply (300s hold, no auto-sit).
Future<ComingHoldState> applyFillPinHeaderAction({
  required String actionId,
  required String chatGroupId,
  String? pinId,
}) {
  return FillPinLiveActivity.applyIncomingChannelArgs({
    'actionId': actionId,
    'chatGroupId': chatGroupId,
    'pinId': pinId,
  });
}
