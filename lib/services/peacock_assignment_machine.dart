import '../core/notification_routes.dart';
import 'peacock_notification_service.dart';

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
    this.showedLocal = false,
    this.sentFcmToSelf = false,
  });

  static const idle = PeacockAssignmentState();

  final PeacockAssignmentPhase phase;
  final String? lobbyId;
  final String? gameName;
  final String? notificationId;
  final bool showedLocal;
  final bool sentFcmToSelf;

  /// True if this snapshot would both present locally and FCM the same uid.
  bool get wouldDoubleNotifySelf => showedLocal && sentFcmToSelf;

  /// `/squad` location once a lobby is assigned. Null while idle/queued.
  String? get routeLocation {
    if (phase != PeacockAssignmentPhase.assigned &&
        phase != PeacockAssignmentPhase.notified) {
      return null;
    }
    return NotificationRoutes.locationFor({
      'type': 'peacock_assigned',
      if (lobbyId != null) 'lobby_id': lobbyId,
      if (gameName != null) 'game_name': gameName,
    });
  }

  PeacockAssignmentState copyWith({
    PeacockAssignmentPhase? phase,
    String? lobbyId,
    String? gameName,
    String? notificationId,
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
      );

    case PeacockAssignmentEvent.notifySelf:
      if (current.phase != PeacockAssignmentPhase.assigned &&
          current.phase != PeacockAssignmentPhase.notified) {
        return current;
      }
      final id = notificationId ?? current.notificationId ?? '';
      final alreadyLocal = <String>{
        if (current.showedLocal && current.notificationId != null)
          current.notificationId!,
      };
      final plan = planPeacockSelfNotify(
        notificationId: id,
        currentUid: currentUid,
        isForeground: isForeground,
        locallyPresentedIds: alreadyLocal,
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
