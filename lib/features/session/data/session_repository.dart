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
  Stream<void> watch({required String squadId});
}
