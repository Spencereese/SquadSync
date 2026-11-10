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

/// A locked call stops blocking the next one after this long. The database
/// applies it lazily, when someone calls the next spot.
const Duration spotLockMax = Duration(hours: 6);

/// How long a promoted "maybe later" check-in stays a starter. The stored
/// kind stays available_later. [until] on that row is the start of the hour.
const Duration spotLaterStarterWindow = Duration(minutes: 60);

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

/// Names of people who are in, in RSVP order. An unknown id stays "Someone".
List<String> spotInNames({
  required SpotCall call,
  required Map<String, String> namesById,
}) {
  return [
    for (final row in call.rsvps)
      if (row.response == SpotAnswer.rsvpIn) namesById[row.userId] ?? 'Someone',
  ];
}

/// Server refusal codes that mean In and Out should stop accepting taps.
bool spotRsvpClosedByServer(String? code) {
  return code == 'spot_join_closed' ||
      code == 'spot_full' ||
      code == 'spot_locked' ||
      code == 'spot_closed';
}

/// A sentence for a spot refusal. [action] picks the caller wording.
String spotErrorMessage(String? code, {String action = 'save'}) {
  switch (code) {
    case 'spot_full':
      return 'This spot is full.';
    case 'spot_join_closed':
      return 'The join window is closed.';
    case 'spot_locked':
      return action == 'cancel'
          ? 'This spot is locked. End it instead of canceling.'
          : 'This spot is locked.';
    case 'spot_already_open':
      return 'A spot is already open.';
    case 'spot_not_caller':
      switch (action) {
        case 'cancel':
          return 'Only the caller can cancel this spot.';
        case 'end':
          return 'Only the caller or the owner can end this spot.';
        case 'lock':
          return 'Only the caller or the owner can lock this spot.';
        default:
          return 'Only the caller or the owner can do that.';
      }
    case 'spot_not_member':
      return 'You are not in this squad.';
    case 'spot_not_locked':
      return 'Lock the spot before ending it.';
    case 'spot_signed_out':
      return 'Sign in to call a spot.';
    case 'spot_game_blank':
      return 'Type a game. Nothing was called.';
    case 'spot_missing':
      return 'That spot is gone.';
    case 'spot_closed':
      return 'That spot has ended.';
    case 'spot_response':
      return 'That response was not understood.';
    default:
      return 'That spot could not be saved.';
  }
}

/// The code inside a Postgrest message, when it is one of ours.
String? spotErrorCode(String message) {
  const codes = [
    'spot_join_closed',
    'spot_already_open',
    'spot_not_caller',
    'spot_not_member',
    'spot_not_locked',
    'spot_signed_out',
    'spot_game_blank',
    'spot_missing',
    'spot_response',
    'spot_closed',
    'spot_locked',
    'spot_full',
  ];
  for (final code in codes) {
    if (message.contains(code)) return code;
  }
  return null;
}
