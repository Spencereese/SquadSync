import 'package:flutter/widgets.dart';

/// Local XOR FCM-to-self for one peacock assignment.
class PeacockSelfNotifyPlan {
  const PeacockSelfNotifyPlan({
    required this.showLocal,
    required this.sendFcmToSelf,
    required this.recipientUids,
  });

  final bool showLocal;
  final bool sendFcmToSelf;
  final List<String> recipientUids;

  /// True if this plan would both present locally and FCM the same uid.
  bool get wouldDoubleNotifySelf =>
      showLocal && sendFcmToSelf && recipientUids.isNotEmpty;
}

/// Stable identity for one peacock event (cache / XOR / mark-sent).
///
/// Prefers `event_id` (Realtime insert and FCM data share it) then
/// `notification_id` then the row `id`. Nested `data` is consulted so
/// FCM-shaped maps and Realtime rows collapse to the same key.
String? peacockEventId(Map<String, dynamic> record) {
  final data = _nestedData(record);
  return _nonEmpty(record['event_id']) ??
      _nonEmpty(data['event_id']) ??
      _nonEmpty(record['notification_id']) ??
      _nonEmpty(data['notification_id']) ??
      _nonEmpty(record['id']) ??
      _nonEmpty(data['id']);
}

/// Owner uid on a peacock_notifications row or FCM data map.
String? peacockRecordUid(Map<String, dynamic> record) {
  final data = _nestedData(record);
  return _nonEmpty(record['user_uid']) ??
      _nonEmpty(record['userUid']) ??
      _nonEmpty(data['user_uid']) ??
      _nonEmpty(data['userUid']);
}

/// Skip another user's peacock event. Missing owner or missing current uid
/// keeps the existing handle path (Realtime is already filtered to self).
bool peacockEventIsForCurrentUid({
  required Map<String, dynamic> record,
  required String? currentUid,
}) {
  final owner = peacockRecordUid(record);
  final self = currentUid?.trim();
  if (owner == null || self == null || self.isEmpty) return true;
  return owner == self;
}

/// FCM recipients for peacock self-notify. Never includes anyone but
/// [currentUid], and never includes [currentUid] when [showLocal] (XOR).
List<String> peacockSelfUidRecipients({
  required Iterable<String> candidateUids,
  required String? currentUid,
  bool showLocal = false,
}) {
  if (showLocal) return const [];
  final self = currentUid?.trim();
  if (self == null || self.isEmpty) return const [];
  final seen = <String>{};
  final out = <String>[];
  for (final raw in candidateUids) {
    final uid = raw.trim();
    if (uid.isEmpty || uid != self) continue;
    if (!seen.add(uid)) continue;
    out.add(uid);
  }
  return out;
}

/// Visible-enough for a local peacock banner. iOS Control Center and the app
/// switcher use [AppLifecycleState.inactive] while the UI can still be on
/// screen — FCM-to-self only when paused, hidden, or detached.
bool peacockLifecycleIsForeground(AppLifecycleState? state) {
  switch (state) {
    case null:
    case AppLifecycleState.resumed:
    case AppLifecycleState.inactive:
      return true;
    case AppLifecycleState.paused:
    case AppLifecycleState.hidden:
    case AppLifecycleState.detached:
      return false;
  }
}

/// One alert per assignment: in-app Realtime shows local; FCM only when
/// paused/hidden/detached and that [notificationId] was not already presented.
PeacockSelfNotifyPlan planPeacockSelfNotify({
  required String notificationId,
  required String? currentUid,
  required bool isForeground,
  required Set<String> locallyPresentedIds,
}) {
  if (locallyPresentedIds.contains(notificationId)) {
    return const PeacockSelfNotifyPlan(
      showLocal: false,
      sendFcmToSelf: false,
      recipientUids: [],
    );
  }
  if (isForeground) {
    return const PeacockSelfNotifyPlan(
      showLocal: true,
      sendFcmToSelf: false,
      recipientUids: [],
    );
  }
  final recipients = peacockSelfUidRecipients(
    candidateUids: [if (currentUid != null) currentUid],
    currentUid: currentUid,
  );
  if (recipients.isEmpty) {
    return const PeacockSelfNotifyPlan(
      showLocal: false,
      sendFcmToSelf: false,
      recipientUids: [],
    );
  }
  return PeacockSelfNotifyPlan(
    showLocal: false,
    sendFcmToSelf: true,
    recipientUids: recipients,
  );
}

Map<String, dynamic> _nestedData(Map<String, dynamic> record) {
  final raw = record['data'];
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const <String, dynamic>{};
}

String? _nonEmpty(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}
