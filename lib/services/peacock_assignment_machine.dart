import 'package:flutter/foundation.dart';

import '../core/notification_routes.dart';
import 'peacock_self_notify.dart';

export 'peacock_self_notify.dart';

/// Product phases for a peacock assignment.
///
/// idle → queued → assigned → notified.
/// Notify is local XOR FCM-to-self ([planPeacockSelfNotify]).
enum PeacockAssignmentPhase {
  idle,
  queued,
  assigned,
  notified,
}

enum PeacockAssignmentEvent {
  joinQueue,
  leaveQueue,
  assignSpot,
  notifySelf,
  expire,
}

/// Snapshot of one user's peacock assignment.
class PeacockAssignmentState {
  const PeacockAssignmentState({
    this.phase = PeacockAssignmentPhase.idle,
    this.lobbyId,
    this.gameName,
    this.notificationId,
    this.spotIndex,
    this.showedLocal = false,
    this.sentFcmToSelf = false,
  });

  static const idle = PeacockAssignmentState();

  final PeacockAssignmentPhase phase;
  final String? lobbyId;
  final String? gameName;
  final String? notificationId;

  /// 0-based offered seat. Carried on [routeLocation] as `spot_index`.
  final int? spotIndex;
  final bool showedLocal;
  final bool sentFcmToSelf;

  /// True if this snapshot would both present locally and FCM the same uid.
  bool get wouldDoubleNotifySelf => showedLocal && sentFcmToSelf;

  /// `/squad` location once a lobby is assigned. Null while idle/queued.
  /// Same table as chat peacock card / notification taps (ticket 33);
  /// `spot_index` highlights the offered seat (ticket 35).
  String? get routeLocation {
    if (phase != PeacockAssignmentPhase.assigned &&
        phase != PeacockAssignmentPhase.notified) {
      return null;
    }
    return NotificationRoutes.locationFor({
      'type': 'peacock_assigned',
      if (lobbyId != null) 'lobby_id': lobbyId,
      if (gameName != null) 'game_name': gameName,
      if (spotIndex != null) 'spot_index': spotIndex,
    });
  }

  PeacockAssignmentState copyWith({
    PeacockAssignmentPhase? phase,
    String? lobbyId,
    String? gameName,
    String? notificationId,
    int? spotIndex,
    bool? showedLocal,
    bool? sentFcmToSelf,
    bool clearAssignment = false,
  }) {
    return PeacockAssignmentState(
      phase: phase ?? this.phase,
      lobbyId: clearAssignment ? null : (lobbyId ?? this.lobbyId),
      gameName: clearAssignment ? null : (gameName ?? this.gameName),
      notificationId:
          clearAssignment ? null : (notificationId ?? this.notificationId),
      spotIndex: clearAssignment ? null : (spotIndex ?? this.spotIndex),
      showedLocal: clearAssignment ? false : (showedLocal ?? this.showedLocal),
      sentFcmToSelf:
          clearAssignment ? false : (sentFcmToSelf ?? this.sentFcmToSelf),
    );
  }
}

/// Reduce a peacock assignment. Never local+FCM-to-self for one id.
PeacockAssignmentState reducePeacockAssignment({
  required PeacockAssignmentState current,
  required PeacockAssignmentEvent event,
  String? lobbyId,
  String? gameName,
  String? notificationId,
  int? spotIndex,
  bool isForeground = true,
  String? currentUid,
}) {
  switch (event) {
    case PeacockAssignmentEvent.joinQueue:
      if (current.phase == PeacockAssignmentPhase.idle ||
          current.phase == PeacockAssignmentPhase.notified) {
        return const PeacockAssignmentState(
          phase: PeacockAssignmentPhase.queued,
        );
      }
      return current;

    case PeacockAssignmentEvent.leaveQueue:
      if (current.phase == PeacockAssignmentPhase.queued) {
        return PeacockAssignmentState.idle;
      }
      return current;

    case PeacockAssignmentEvent.assignSpot:
      if (current.phase != PeacockAssignmentPhase.queued &&
          current.phase != PeacockAssignmentPhase.idle) {
        return current;
      }
      return PeacockAssignmentState(
        phase: PeacockAssignmentPhase.assigned,
        lobbyId: lobbyId ?? current.lobbyId,
        gameName: gameName ?? current.gameName,
        notificationId: notificationId ?? current.notificationId,
        spotIndex: spotIndex ?? current.spotIndex,
      );

    case PeacockAssignmentEvent.notifySelf:
      if (current.phase != PeacockAssignmentPhase.assigned &&
          current.phase != PeacockAssignmentPhase.notified) {
        return current;
      }
      final id = notificationId ?? current.notificationId ?? '';
      final alreadyHandled = <String>{
        if (current.notificationId != null &&
            (current.showedLocal || current.sentFcmToSelf))
          current.notificationId!,
      };
      final plan = planPeacockSelfNotify(
        notificationId: id,
        currentUid: currentUid,
        isForeground: isForeground,
        locallyPresentedIds: alreadyHandled,
      );
      return current.copyWith(
        phase: PeacockAssignmentPhase.notified,
        notificationId: id.isEmpty ? current.notificationId : id,
        showedLocal: current.showedLocal || plan.showLocal,
        sentFcmToSelf: current.sentFcmToSelf || plan.sendFcmToSelf,
      );

    case PeacockAssignmentEvent.expire:
      return PeacockAssignmentState.idle;
  }
}

/// This-event notify flags from [PeacockAssignmentTracker.notifySelf].
///
/// [plan] is the XOR decision the reducer just applied — not a second
/// [planPeacockSelfNotify] call.
class PeacockNotifyDispatch {
  const PeacockNotifyDispatch({
    required this.state,
    required this.plan,
  });

  final PeacockAssignmentState state;
  final PeacockSelfNotifyPlan plan;

  bool get showedLocal => plan.showLocal;
  bool get sentFcmToSelf => plan.sendFcmToSelf;
}

/// Production peacock queue process (LobbyNotifier.processPeacockQueue).
/// Timer cleanup calls this so the next assign is never a repository stub.
typedef PeacockQueueProcess = Future<String?> Function({
  String? assignedUserId,
  String? lobbyId,
  String? gameName,
  String? notificationId,
});

/// Owns per-user peacock phases. Production join/leave/assign/notify/expire
/// reduce through here so [PeacockAssignmentPhase] is the product truth.
class PeacockAssignmentTracker {
  PeacockAssignmentTracker();

  /// Shared by lobby peacock paths and the notification service.
  static PeacockAssignmentTracker instance = PeacockAssignmentTracker();

  final Map<String, PeacockAssignmentState> _byUser =
      <String, PeacockAssignmentState>{};

  /// Wired by [LobbyNotifier] to its peacock-aware process path.
  PeacockQueueProcess? queueProcessor;

  /// Immutable view of tracked users. Idle users are omitted.
  Map<String, PeacockAssignmentState> get snapshot =>
      Map<String, PeacockAssignmentState>.unmodifiable(_byUser);

  PeacockAssignmentState stateFor(String userId) =>
      _byUser[userId] ?? PeacockAssignmentState.idle;

  /// First queued user in insertion order, or null if the queue is empty.
  String? nextQueuedUserId() {
    for (final entry in _byUser.entries) {
      if (entry.value.phase == PeacockAssignmentPhase.queued) {
        return entry.key;
      }
    }
    return null;
  }

  PeacockAssignmentState apply({
    required String userId,
    required PeacockAssignmentEvent event,
    String? lobbyId,
    String? gameName,
    String? notificationId,
    int? spotIndex,
    bool isForeground = true,
    String? currentUid,
  }) {
    final next = reducePeacockAssignment(
      current: stateFor(userId),
      event: event,
      lobbyId: lobbyId,
      gameName: gameName,
      notificationId: notificationId,
      spotIndex: spotIndex,
      isForeground: isForeground,
      currentUid: currentUid,
    );
    if (next.phase == PeacockAssignmentPhase.idle) {
      _byUser.remove(userId);
    } else {
      _byUser[userId] = next;
    }
    return next;
  }

  PeacockAssignmentState joinQueue(String userId) => apply(
        userId: userId,
        event: PeacockAssignmentEvent.joinQueue,
      );

  PeacockAssignmentState leaveQueue(String userId) => apply(
        userId: userId,
        event: PeacockAssignmentEvent.leaveQueue,
      );

  PeacockAssignmentState assignSpot(
    String userId, {
    String? lobbyId,
    String? gameName,
    String? notificationId,
    int? spotIndex,
  }) =>
      apply(
        userId: userId,
        event: PeacockAssignmentEvent.assignSpot,
        lobbyId: lobbyId,
        gameName: gameName,
        notificationId: notificationId,
        spotIndex: spotIndex,
      );

  /// Reduce [PeacockAssignmentEvent.notifySelf]. [plan] is the XOR result
  /// for this event (machine already called [planPeacockSelfNotify]).
  PeacockNotifyDispatch notifySelf(
    String userId, {
    required bool isForeground,
    String? currentUid,
    String? notificationId,
  }) {
    final before = stateFor(userId);
    final after = apply(
      userId: userId,
      event: PeacockAssignmentEvent.notifySelf,
      isForeground: isForeground,
      currentUid: currentUid,
      notificationId: notificationId,
    );
    final showedLocal = after.showedLocal && !before.showedLocal;
    final sentFcmToSelf = after.sentFcmToSelf && !before.sentFcmToSelf;
    final uid = currentUid ?? userId;
    final plan = PeacockSelfNotifyPlan(
      showLocal: showedLocal,
      sendFcmToSelf: sentFcmToSelf,
      recipientUids:
          sentFcmToSelf && uid.isNotEmpty ? <String>[uid] : const <String>[],
    );
    return PeacockNotifyDispatch(state: after, plan: plan);
  }

  PeacockAssignmentState expire(String userId) => apply(
        userId: userId,
        event: PeacockAssignmentEvent.expire,
      );

  void clear() => _byUser.clear();

  @visibleForTesting
  static void resetInstance() {
    instance = PeacockAssignmentTracker();
  }
}
