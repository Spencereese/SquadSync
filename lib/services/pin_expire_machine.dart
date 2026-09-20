/// PIN WAVE P1 — pin lifetime reducer.
///
/// Default pin life is [kPinExpireDefault] (45 min). Overrides inside
/// [kPinExpireWindowMin]–[kPinExpireWindowMax] (45–60) are accepted;
/// anything outside clamps to the default. Owner may end early via
/// [PinExpireEvent.ownerEnd] → [PinExpirePhase.endedEarly].
library;

/// Default pin lifetime (45 minutes).
const Duration kPinExpireDefault = Duration(minutes: 45);

/// Inclusive lower bound of the accepted lifetime window.
const Duration kPinExpireWindowMin = Duration(minutes: 45);

/// Inclusive upper bound of the accepted lifetime window.
const Duration kPinExpireWindowMax = Duration(minutes: 60);

enum PinExpirePhase {
  idle,
  live,
  expired,
  endedEarly,
}

enum PinExpireEvent {
  start,
  tick,
  ownerEnd,
}

/// Snapshot of one pin's lifetime.
class PinExpireState {
  const PinExpireState({
    this.phase = PinExpirePhase.idle,
    this.pinId,
    this.ownerId,
    this.remaining = Duration.zero,
  });

  static const idle = PinExpireState();

  final PinExpirePhase phase;
  final String? pinId;
  final String? ownerId;
  final Duration remaining;

  bool get isLive => phase == PinExpirePhase.live;

  bool get isExpired => phase == PinExpirePhase.expired;

  bool get ownerEndedEarly => phase == PinExpirePhase.endedEarly;

  PinExpireState copyWith({
    PinExpirePhase? phase,
    String? pinId,
    String? ownerId,
    Duration? remaining,
  }) {
    return PinExpireState(
      phase: phase ?? this.phase,
      pinId: pinId ?? this.pinId,
      ownerId: ownerId ?? this.ownerId,
      remaining: remaining ?? this.remaining,
    );
  }
}

Duration _resolveLifetime(Duration? lifetime) {
  if (lifetime == null) return kPinExpireDefault;
  if (lifetime < kPinExpireWindowMin || lifetime > kPinExpireWindowMax) {
    return kPinExpireDefault;
  }
  return lifetime;
}

/// Reduce a pin lifetime. Pure; no I/O.
PinExpireState reducePinExpire({
  required PinExpireState current,
  required PinExpireEvent event,
  String? pinId,
  String? ownerId,
  Duration? lifetime,
  Duration? elapsed,
}) {
  switch (event) {
    case PinExpireEvent.start:
      return PinExpireState(
        phase: PinExpirePhase.live,
        pinId: pinId ?? current.pinId,
        ownerId: ownerId ?? current.ownerId,
        remaining: _resolveLifetime(lifetime),
      );

    case PinExpireEvent.tick:
      if (current.phase != PinExpirePhase.live) {
        return current;
      }
      final nextRemaining = current.remaining - (elapsed ?? Duration.zero);
      if (nextRemaining > Duration.zero) {
        return current.copyWith(remaining: nextRemaining);
      }
      return current.copyWith(
        phase: PinExpirePhase.expired,
        remaining: Duration.zero,
      );

    case PinExpireEvent.ownerEnd:
      if (current.phase != PinExpirePhase.live) {
        return current;
      }
      return current.copyWith(phase: PinExpirePhase.endedEarly);
  }
}
