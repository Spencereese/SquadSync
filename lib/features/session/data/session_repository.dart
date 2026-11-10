import 'package:squadsync/features/session/domain/squad_session.dart';

class SessionBoard {
  const SessionBoard({this.enabled = false, this.sessions = const []});

  final bool enabled;
  final List<SquadSession> sessions;

  static const notEnabled = SessionBoard();
}

class SessionNotEnabled implements Exception {
  const SessionNotEnabled();
}

/// Scheduled sessions. A missing table is [SessionBoard.notEnabled], not an error.
abstract class SessionRepository {
  Future<SessionBoard> load({required String squadId});

  Future<SquadSession> create({
    required String squadId,
    required String game,
    required DateTime startsAt,
    Duration? duration,
    String? note,
  });

  Future<void> update({
    required String sessionId,
    required String game,
    required DateTime startsAt,
    Duration? duration,
    String? note,
  });

  Future<void> cancel({required String sessionId});

  Future<void> rsvp({required String sessionId, required SessionAnswer answer});

  /// Live changes. An empty stream is fine. Resume and pull-to-refresh
  /// still load the list. RSVP deletes are not filtered by squad.
  Stream<SessionChange> watch({required String squadId});
}

/// A realtime session event. [always] is a squad-filtered insert or update.
/// Anything else reloads only when [sessionId] is already on screen, or when
/// the payload did not name an id.
class SessionChange {
  const SessionChange.squad() : sessionId = null, always = true;

  const SessionChange.maybe(this.sessionId) : always = false;

  final String? sessionId;
  final bool always;
}

bool sessionChangeReloads(SessionChange change, Iterable<String> knownIds) {
  if (change.always) return true;
  final id = change.sessionId;
  if (id == null || id.isEmpty) return true;
  for (final known in knownIds) {
    if (known == id) return true;
  }
  return false;
}
