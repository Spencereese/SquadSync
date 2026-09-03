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
  final uid = currentUid;
  if (uid == null || uid.isEmpty) {
    return const PeacockSelfNotifyPlan(
      showLocal: false,
      sendFcmToSelf: false,
      recipientUids: [],
    );
  }
  return PeacockSelfNotifyPlan(
    showLocal: false,
    sendFcmToSelf: true,
    recipientUids: [uid],
  );
}
