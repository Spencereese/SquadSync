import 'package:squadsync/features/spot/domain/spot_call.dart';

/// Server-owned spot calls. A missing table is [SpotNotEnabled].
abstract class SpotRepository {
  Future<SpotCall?> load({required String squadId});

  Future<SpotCall> callSpot({
    required String squadId,
    required String game,
    required DateTime startsAt,
  });

  Future<void> rsvp({required String callId, required SpotAnswer answer});

  Future<void> lock({required String callId});

  /// Caller or owner, and only after the call is locked.
  Future<void> end({required String callId});

  /// Caller only, and only before the call is locked.
  Future<void> cancel({required String callId});

  /// Live rows for this squad, plus deletes.
  /// A delete payload has the primary key only, so it is not filtered by
  /// squad. [SpotChange.deletedCallId] is that key. The listener reloads
  /// only when [reloadAfterSpotEvent] says the id is the call on screen.
  /// Resume and pull-to-refresh do not need this stream.
  Stream<SpotChange> watch({required String squadId});
}

/// A spot insert, update, or delete.
class SpotChange {
  const SpotChange({this.deletedCallId, this.rsvpCallId});

  /// Set for a call delete or an RSVP delete. Null for an insert or update
  /// of a call in this squad.
  final String? deletedCallId;

  /// Set for an RSVP insert or update. The row includes call_id.
  final String? rsvpCallId;
}

/// Realtime DELETE rows do not include squad_id, so the subscription is
/// unfiltered and this decides whether to reload. A missing id reloads,
/// because the event cannot be matched. An id that is not the call on
/// screen does not. An RSVP for another call does not.
bool reloadAfterSpotEvent({
  required String? knownCallId,
  required SpotChange change,
}) {
  final deleted = change.deletedCallId;
  if (deleted != null) {
    final id = deleted.trim();
    if (id.isEmpty) return true;
    final known = knownCallId?.trim() ?? '';
    if (known.isEmpty) return false;
    return id == known;
  }
  final rsvpCallId = change.rsvpCallId?.trim() ?? '';
  if (rsvpCallId.isNotEmpty) {
    final known = knownCallId?.trim() ?? '';
    if (known.isEmpty) return false;
    return rsvpCallId == known;
  }
  return true;
}

class SpotNotEnabled implements Exception {
  const SpotNotEnabled();
}
