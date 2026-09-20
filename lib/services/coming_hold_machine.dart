/// PIN WAVE P1 — Coming seat-hold reducer.
///
/// Coming holds a seat for [kComingHoldDuration] (5:00). Friends must
/// open the app and tap **I'm in** ([ComingHoldEvent.sit]) or **Can't**
/// ([ComingHoldEvent.release]). [ComingHoldEvent.tick] never auto-sits;
/// expire frees the seat. Spot-open nudge is a bool plus an optional
/// [onSpotOpenNudge] stub — UI wiring is later.
library;

/// Coming holds a seat for five minutes.
const Duration kComingHoldDuration = Duration(seconds: 300);

enum ComingHoldPhase {
  idle,
  coming,
  seated,
  released,
  expired,
}

enum ComingHoldEvent {
  startComing,
  tick,
  sit,
  release,
}

/// Snapshot of one Coming seat-hold.
class ComingHoldState {
  const ComingHoldState({
    this.phase = ComingHoldPhase.idle,
    this.seatIndex,
    this.pinId,
    this.userId,
    this.remaining = Duration.zero,
    this.shouldNudgeSpotOpen = false,
  });

  static const idle = ComingHoldState();

  final ComingHoldPhase phase;
  final int? seatIndex;
  final String? pinId;
  final String? userId;
  final Duration remaining;
  final bool shouldNudgeSpotOpen;

  /// Seat is reserved while Coming or after **I'm in**.
  bool get holdsSeat =>
      phase == ComingHoldPhase.coming || phase == ComingHoldPhase.seated;

  /// Seat is back in the pool after expire or **Can't**.
  bool get seatFreed =>
      phase == ComingHoldPhase.expired || phase == ComingHoldPhase.released;

  ComingHoldState copyWith({
    ComingHoldPhase? phase,
    int? seatIndex,
    String? pinId,
    String? userId,
    Duration? remaining,
    bool? shouldNudgeSpotOpen,
  }) {
    return ComingHoldState(
      phase: phase ?? this.phase,
      seatIndex: seatIndex ?? this.seatIndex,
      pinId: pinId ?? this.pinId,
      userId: userId ?? this.userId,
      remaining: remaining ?? this.remaining,
      shouldNudgeSpotOpen: shouldNudgeSpotOpen ?? this.shouldNudgeSpotOpen,
    );
  }
}

/// Reduce a Coming seat-hold. Pure; no I/O.
///
/// [onSpotOpenNudge] is an optional stub fired when the seat frees
/// (expire or **Can't**). Chat / Tonight UI is out of scope.
ComingHoldState reduceComingHold({
  required ComingHoldState current,
  required ComingHoldEvent event,
  int? seatIndex,
  String? pinId,
  String? userId,
  Duration? elapsed,
  void Function()? onSpotOpenNudge,
}) {
  switch (event) {
    case ComingHoldEvent.startComing:
      return ComingHoldState(
        phase: ComingHoldPhase.coming,
        seatIndex: seatIndex ?? current.seatIndex,
        pinId: pinId ?? current.pinId,
        userId: userId ?? current.userId,
        remaining: kComingHoldDuration,
        shouldNudgeSpotOpen: false,
      );

    case ComingHoldEvent.tick:
      if (current.phase != ComingHoldPhase.coming) {
        return current;
      }
      final nextRemaining = current.remaining - (elapsed ?? Duration.zero);
      if (nextRemaining > Duration.zero) {
        return current.copyWith(
          remaining: nextRemaining,
          shouldNudgeSpotOpen: false,
        );
      }
      onSpotOpenNudge?.call();
      return current.copyWith(
        phase: ComingHoldPhase.expired,
        remaining: Duration.zero,
        shouldNudgeSpotOpen: true,
      );

    case ComingHoldEvent.sit:
      if (current.phase != ComingHoldPhase.coming) {
        return current;
      }
      return current.copyWith(
        phase: ComingHoldPhase.seated,
        shouldNudgeSpotOpen: false,
      );

    case ComingHoldEvent.release:
      if (current.phase != ComingHoldPhase.coming) {
        return current;
      }
      onSpotOpenNudge?.call();
      return current.copyWith(
        phase: ComingHoldPhase.released,
        remaining: Duration.zero,
        shouldNudgeSpotOpen: true,
      );
  }
}
