import '../core/notification_routes.dart';

/// Product peacock journey (ticket 35).
///
/// Waiting → Offered → Lock-in → Seated, with Expired / Declined as
/// terminal alternatives to Seated. This overlay is unit-testable copy
/// of the live path; [reducePeacockAssignment] stays production XOR
/// truth and lobby chip / pulse stay [resolveLobbySeatStatus].
///
/// | Product phase | Live helpers |
/// | --- | --- |
/// | Waiting | [PeacockAssignmentPhase.queued] / peacock chip |
/// | Offered | assigned / notified + offer banner + pulse |
/// | Lock-in | lock chip + remaining timer / `_calling` |
/// | Seated | occupying a seat (not calling) |
/// | Expired | [PeacockAssignmentEvent.expire] / timer remaining ≤ 0 |
/// | Declined | [declineOfferedSeat] (LFG cancel + peacock expire) |
///
/// Chat peacock card taps and notification deep links share
/// [NotificationRoutes.locationFor] / [locationForDeepLink] — offered
/// routes include `spot_index` so the lobby pulses that seat.
enum PeacockLifecyclePhase {
  idle,
  waiting,
  offered,
  lockIn,
  seated,
  expired,
  declined,
}

enum PeacockLifecycleEvent {
  joinQueue,
  offer,
  lockIn,
  seat,
  expire,
  decline,
}

/// Snapshot of one user's product peacock journey.
class PeacockLifecycleState {
  const PeacockLifecycleState({
    this.phase = PeacockLifecyclePhase.idle,
    this.lobbyId,
    this.gameName,
    this.spotIndex,
  });

  static const idle = PeacockLifecycleState();

  final PeacockLifecyclePhase phase;
  final String? lobbyId;
  final String? gameName;

  /// 0-based offered / seated index. Carried on the lobby route as
  /// `spot_index` so the same parse highlights the offered spot.
  final int? spotIndex;

  /// `/squad?lobby_id=&spot_index=` once a lobby is offered. Same table
  /// as notification `peacock_assigned` (ticket 33).
  String? get routeLocation {
    switch (phase) {
      case PeacockLifecyclePhase.offered:
      case PeacockLifecyclePhase.lockIn:
      case PeacockLifecyclePhase.seated:
        if (lobbyId == null || lobbyId!.isEmpty) return null;
        return NotificationRoutes.locationFor({
          'type': 'peacock_assigned',
          'lobby_id': lobbyId,
          if (gameName != null && gameName!.isNotEmpty) 'game_name': gameName,
          if (spotIndex != null) 'spot_index': spotIndex,
        });
      case PeacockLifecyclePhase.idle:
      case PeacockLifecyclePhase.waiting:
      case PeacockLifecyclePhase.expired:
      case PeacockLifecyclePhase.declined:
        return null;
    }
  }

  PeacockLifecycleState copyWith({
    PeacockLifecyclePhase? phase,
    String? lobbyId,
    String? gameName,
    int? spotIndex,
    bool clearOffer = false,
  }) {
    return PeacockLifecycleState(
      phase: phase ?? this.phase,
      lobbyId: clearOffer ? null : (lobbyId ?? this.lobbyId),
      gameName: clearOffer ? null : (gameName ?? this.gameName),
      spotIndex: clearOffer ? null : (spotIndex ?? this.spotIndex),
    );
  }
}

/// Reduce the product peacock journey. Pure; no I/O.
///
/// Waiting → Offered → Lock-in → Seated. Expire / Decline leave the
/// offer without seating. Join from idle / expired / declined starts
/// Waiting again. Does not call [planPeacockSelfNotify].
PeacockLifecycleState reducePeacockLifecycle({
  required PeacockLifecycleState current,
  required PeacockLifecycleEvent event,
  String? lobbyId,
  String? gameName,
  int? spotIndex,
}) {
  switch (event) {
    case PeacockLifecycleEvent.joinQueue:
      if (current.phase == PeacockLifecyclePhase.idle ||
          current.phase == PeacockLifecyclePhase.expired ||
          current.phase == PeacockLifecyclePhase.declined) {
        return const PeacockLifecycleState(
          phase: PeacockLifecyclePhase.waiting,
        );
      }
      return current;

    case PeacockLifecycleEvent.offer:
      if (current.phase != PeacockLifecyclePhase.waiting &&
          current.phase != PeacockLifecyclePhase.idle) {
        return current;
      }
      return PeacockLifecycleState(
        phase: PeacockLifecyclePhase.offered,
        lobbyId: lobbyId ?? current.lobbyId,
        gameName: gameName ?? current.gameName,
        spotIndex: spotIndex ?? current.spotIndex,
      );

    case PeacockLifecycleEvent.lockIn:
      if (current.phase != PeacockLifecyclePhase.offered) {
        return current;
      }
      return current.copyWith(
        phase: PeacockLifecyclePhase.lockIn,
        lobbyId: lobbyId,
        gameName: gameName,
        spotIndex: spotIndex,
      );

    case PeacockLifecycleEvent.seat:
      if (current.phase != PeacockLifecyclePhase.offered &&
          current.phase != PeacockLifecyclePhase.lockIn) {
        return current;
      }
      return current.copyWith(
        phase: PeacockLifecyclePhase.seated,
        lobbyId: lobbyId,
        gameName: gameName,
        spotIndex: spotIndex,
      );

    case PeacockLifecycleEvent.expire:
      if (current.phase == PeacockLifecyclePhase.waiting ||
          current.phase == PeacockLifecyclePhase.offered ||
          current.phase == PeacockLifecyclePhase.lockIn) {
        return PeacockLifecycleState(
          phase: PeacockLifecyclePhase.expired,
          lobbyId: current.lobbyId,
          gameName: current.gameName,
          spotIndex: current.spotIndex,
        );
      }
      return current;

    case PeacockLifecycleEvent.decline:
      if (current.phase == PeacockLifecyclePhase.offered ||
          current.phase == PeacockLifecyclePhase.lockIn) {
        return PeacockLifecycleState(
          phase: PeacockLifecyclePhase.declined,
          lobbyId: current.lobbyId,
          gameName: current.gameName,
          spotIndex: current.spotIndex,
        );
      }
      return current;
  }
}
