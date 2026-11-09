/// A code the squad owner can read out. Eight characters, no look-alike glyphs.
class SquadInvite {
  const SquadInvite({
    required this.code,
    required this.expiresAt,
    required this.squadId,
  });

  final String code;
  final DateTime expiresAt;
  final String squadId;

  String get shareText => 'Join my SquadSync squad. Code: $code';
}

enum JoinError {
  invalid,
  expired,
  full,
  alreadyInSquad,
  ownsSquadWithMembers,
  notEnabled,
}

/// What the join RPC decided. [joined] is the only path into the chat.
class JoinDecision {
  const JoinDecision.joined(this.squadId) : error = null, notEnabled = false;

  const JoinDecision.failed(this.error) : squadId = null, notEnabled = false;

  const JoinDecision.notEnabled()
    : squadId = null,
      error = JoinError.notEnabled,
      notEnabled = true;

  final String? squadId;
  final JoinError? error;
  final bool notEnabled;

  bool get joined => squadId != null;
}

JoinError? joinErrorFromCode(String? code) {
  return switch (code) {
    'invalid' => JoinError.invalid,
    'expired' => JoinError.expired,
    'full' => JoinError.full,
    'already_in_squad' => JoinError.alreadyInSquad,
    'owns_squad_with_members' => JoinError.ownsSquadWithMembers,
    _ => null,
  };
}

String joinErrorMessage(JoinError error) {
  return switch (error) {
    JoinError.invalid => 'That code is not valid. Nothing was joined.',
    JoinError.expired =>
      'That code has expired. Ask for a new one. Nothing was joined.',
    JoinError.full => 'That squad is full. Nothing was joined.',
    JoinError.alreadyInSquad =>
      'You are already in a squad. Nothing was changed.',
    JoinError.ownsSquadWithMembers =>
      'You own a squad that still has other people. Nothing was changed.',
    JoinError.notEnabled => 'Invites not enabled yet.',
  };
}
