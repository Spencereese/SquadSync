import '../domain/entities/lobby.dart';
import 'matchmaking_queue_machine.dart';

/// Discovery swipe is not a public Tinder-style launch.
///
/// The card deck shows only when the squad is looking for a fill
/// (Looking for Squad + an open seat) AND the viewer has a squad vouch
/// (membership or an explicit vouch). Hidden / gated otherwise.

const kDiscoverySwipeGateTitle = 'Fill swipe is gated';

const kDiscoverySwipeNeedFillCopy =
    'Turn on Looking for Squad with an open seat first.';

const kDiscoverySwipeNeedVouchCopy =
    'A squadmate has to vouch before fill swipe opens.';

const kDiscoverySwipeNeedBothCopy =
    'Fill swipe stays off until this squad is looking for a fill and a squadmate vouches.';

enum DiscoverySwipeGateReason {
  open,
  notLookingForFill,
  missingSquadVouch,
  bothMissing,
}

/// One squadmate attesting that [vouchedUserId] may use fill swipe.
class SquadVouch {
  const SquadVouch({
    required this.squadId,
    required this.vouchedUserId,
    required this.voucherUserId,
  });

  final String squadId;
  final String vouchedUserId;
  final String voucherUserId;
}

class DiscoverySwipeGate {
  const DiscoverySwipeGate({
    required this.lookingForFill,
    required this.hasSquadVouch,
  });

  static const closed = DiscoverySwipeGate(
    lookingForFill: false,
    hasSquadVouch: false,
  );

  static const open = DiscoverySwipeGate(
    lookingForFill: true,
    hasSquadVouch: true,
  );

  final bool lookingForFill;
  final bool hasSquadVouch;

  bool get canShowSwipe => lookingForFill && hasSquadVouch;

  DiscoverySwipeGateReason get reason {
    if (canShowSwipe) return DiscoverySwipeGateReason.open;
    if (!lookingForFill && !hasSquadVouch) {
      return DiscoverySwipeGateReason.bothMissing;
    }
    if (!lookingForFill) return DiscoverySwipeGateReason.notLookingForFill;
    return DiscoverySwipeGateReason.missingSquadVouch;
  }

  String get message {
    switch (reason) {
      case DiscoverySwipeGateReason.open:
        return '';
      case DiscoverySwipeGateReason.notLookingForFill:
        return kDiscoverySwipeNeedFillCopy;
      case DiscoverySwipeGateReason.missingSquadVouch:
        return kDiscoverySwipeNeedVouchCopy;
      case DiscoverySwipeGateReason.bothMissing:
        return kDiscoverySwipeNeedBothCopy;
    }
  }
}

/// Empty / unoccupied seats. Existing [Lobby.spots]; no new table.
int openSpotCount(Iterable<String?> spots) {
  var count = 0;
  for (final spot in spots) {
    if (spot == null || spot.isEmpty) count++;
  }
  return count;
}

/// Looking-for-fill: LFG looking AND at least one open seat.
bool resolveLookingForFill({
  required MatchmakingQueueEntry lfg,
  int openSpots = 0,
}) {
  if (lfg.phase != MatchmakingQueuePhase.looking) return false;
  return openSpots > 0;
}

/// Squad-vouch: already in the squad, or an explicit vouch from a squadmate.
bool resolveSquadVouch({
  required String userId,
  String? squadId,
  Iterable<String> squadMemberIds = const [],
  Iterable<SquadVouch> vouches = const [],
}) {
  final uid = userId.trim();
  if (uid.isEmpty) return false;
  for (final member in squadMemberIds) {
    if (member == uid) return true;
  }
  final sid = squadId?.trim() ?? '';
  for (final vouch in vouches) {
    if (vouch.vouchedUserId != uid) continue;
    if (sid.isEmpty || vouch.squadId == sid) return true;
  }
  return false;
}

DiscoverySwipeGate resolveDiscoverySwipeGate({
  required bool lookingForFill,
  required bool hasSquadVouch,
}) {
  return DiscoverySwipeGate(
    lookingForFill: lookingForFill,
    hasSquadVouch: hasSquadVouch,
  );
}

/// Live sources already shipped: LFG tracker + current lobby spots/members.
DiscoverySwipeGate resolveDiscoverySwipeGateFromContext({
  required String? userId,
  MatchmakingQueueEntry lfg = MatchmakingQueueEntry.idle,
  Lobby? lobby,
  Iterable<SquadVouch> vouches = const [],
}) {
  final uid = userId?.trim() ?? '';
  final lookingForFill = resolveLookingForFill(
    lfg: lfg,
    openSpots: openSpotCount(lobby?.spots ?? const <String?>[]),
  );
  final hasSquadVouch = resolveSquadVouch(
    userId: uid,
    squadId: lobby?.id,
    squadMemberIds: lobby?.memberUids ?? const [],
    vouches: vouches,
  );
  return resolveDiscoverySwipeGate(
    lookingForFill: lookingForFill,
    hasSquadVouch: hasSquadVouch,
  );
}
