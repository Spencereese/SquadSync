import 'package:flutter/material.dart';

import '../notification_service.dart';
import '../services/fill_pin_nudge_audience.dart';

/// Compact Need-one on the Fill PIN header.
const kFillPinNeedOneKey = Key('fill-pin-need-one');
const kFillPinNeedOneLabel = 'Need one';

/// Audience via [fillPinNudgeAudience], send via the one notify pipeline.
Future<void> nudgeFillPinNeedOne({
  required Iterable<String> memberUids,
  Iterable<String> sitUids = const [],
  Iterable<String> comingUids = const [],
  Iterable<String> cantUids = const [],
  String title = kFillPinNeedOneLabel,
  String body = kFillPinNeedOneLabel,
}) async {
  final audience = fillPinNudgeAudience(
    memberUids: memberUids,
    sitUids: sitUids,
    comingUids: comingUids,
    cantUids: cantUids,
  );
  await NotificationService.sendNotificationToUsers(
    title: title,
    body: body,
    recipientUids: audience.toList(),
  );
}
