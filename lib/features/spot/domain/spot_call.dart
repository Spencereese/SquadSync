/// A server-owned spot call. The join window is five minutes from the call,
/// stamped by the database. This phone only reads that instant.
class SpotCall {
  SpotCall({
    required this.id,
    required this.squadId,
    required this.callerId,
    required this.game,
    required DateTime startsAt,
    required DateTime calledAt,
    required DateTime joinUntil,
    DateTime? lockedAt,
    this.lockedBy,
    required this.rsvps,
  }) : startsAt = startsAt.toUtc(),
       calledAt = calledAt.toUtc(),
       joinUntil = joinUntil.toUtc(),
       lockedAt = lockedAt?.toUtc();

  final String id;
  final String squadId;
  final String callerId;
  final String game;
  final DateTime startsAt;
  final DateTime calledAt;
  final DateTime joinUntil;
  final DateTime? lockedAt;
  final String? lockedBy;
  final List<SpotRsvp> rsvps;

  SpotPhase phaseAt(DateTime clock) {
    if (lockedAt != null) return SpotPhase.locked;
    if (clock.toUtc().isBefore(joinUntil)) return SpotPhase.open;
    return SpotPhase.expired;
  }

  int get inCount =>
      rsvps.where((row) => row.response == SpotAnswer.rsvpIn).length;

  bool starter(String userId) {
    for (final row in rsvps) {
      if (row.userId == userId) return row.starter;
    }
    return false;
  }
}

enum SpotPhase { open, locked, expired }

enum SpotAnswer { rsvpIn, rsvpOut }

class SpotRsvp {
  const SpotRsvp({
    required this.userId,
    required this.response,
    required this.starter,
  });

  final String userId;
  final SpotAnswer response;
  final bool starter;
}

/// How long is left in the join window. Zero once the server instant has passed.
Duration spotRemaining(SpotCall call, DateTime clock) {
  final left = call.joinUntil.difference(clock.toUtc());
  if (left.isNegative) return Duration.zero;
  return left;
}

String spotCountdown(Duration remaining) {
  final minutes = remaining.inMinutes;
  final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds left';
}

/// Honest sentence for the home strip.
String spotStatusLine({required SpotCall? call, required DateTime clock}) {
  if (call == null) return 'No spot called.';
  switch (call.phaseAt(clock)) {
    case SpotPhase.locked:
      return 'Locked. ${call.inCount} in.';
    case SpotPhase.expired:
      return 'Join window closed. Starters stay in.';
    case SpotPhase.open:
      return '${spotCountdown(spotRemaining(call, clock))} to join ${call.game}.';
  }
}
