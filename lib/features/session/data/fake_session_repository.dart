import 'dart:async';

import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/session/data/session_repository.dart';
import 'package:squadsync/features/session/domain/squad_session.dart';

class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({
    this.enabled = false,
    this.userId = 'spencer',
    this.ownerId = 'spencer',
    List<SquadSession>? sessions,
  }) : sessions = List<SquadSession>.of(sessions ?? const []) {
    _next = this.sessions.length + 1;
  }

  bool enabled;
  String userId;
  String ownerId;
  final List<SquadSession> sessions;
  final _changes = StreamController<void>.broadcast();
  var _next = 1;

  @override
  Future<SessionBoard> load({required String squadId}) async {
    if (!enabled) return SessionBoard.notEnabled;
    return SessionBoard(
      enabled: true,
      sessions: [
        for (final session in sessions)
          if (session.squadId == squadId) session,
      ],
    );
  }

  @override
  Future<SquadSession> create({
    required String squadId,
    required String game,
    required DateTime startsAt,
    Duration? duration,
    String? note,
  }) async {
    if (!enabled) throw const SessionNotEnabled();
    final label = game.trim();
    if (label.isEmpty) {
      throw const RepositoryFailure('Type a game. Nothing was scheduled.');
    }
    final session = SquadSession(
      id: 'session-$_next',
      squadId: squadId,
      creatorId: userId,
      game: label,
      startsAt: startsAt,
      duration: duration,
      note: _note(note),
    );
    _next++;
    sessions.add(session);
    _changes.add(null);
    return session;
  }

  @override
  Future<void> update({
    required String sessionId,
    required String game,
    required DateTime startsAt,
    Duration? duration,
    String? note,
  }) async {
    final current = _editable(sessionId);
    _replace(
      current,
      SquadSession(
        id: current.id,
        squadId: current.squadId,
        creatorId: current.creatorId,
        game: game.trim(),
        startsAt: startsAt,
        duration: duration,
        note: _note(note),
        cancelledAt: current.cancelledAt,
        rsvps: current.rsvps,
      ),
    );
  }

  @override
  Future<void> cancel({required String sessionId}) async {
    final current = _editable(sessionId);
    _replace(
      current,
      SquadSession(
        id: current.id,
        squadId: current.squadId,
        creatorId: current.creatorId,
        game: current.game,
        startsAt: current.startsAt,
        duration: current.duration,
        note: current.note,
        cancelledAt: DateTime.utc(2026, 11, 10),
        rsvps: current.rsvps,
      ),
    );
  }

  @override
  Future<void> rsvp({
    required String sessionId,
    required SessionAnswer answer,
  }) async {
    final current = _find(sessionId);
    final next = [
      for (final row in current.rsvps)
        if (row.userId != userId) row,
      SessionRsvp(userId: userId, answer: answer),
    ];
    if (answer == SessionAnswer.rsvpIn &&
        next.where((row) => row.answer == SessionAnswer.rsvpIn).length > 8) {
      throw const RepositoryFailure(
        'This session is full.',
        code: 'session_full',
      );
    }
    _replace(
      current,
      SquadSession(
        id: current.id,
        squadId: current.squadId,
        creatorId: current.creatorId,
        game: current.game,
        startsAt: current.startsAt,
        duration: current.duration,
        note: current.note,
        cancelledAt: current.cancelledAt,
        rsvps: next,
      ),
    );
  }

  @override
  Stream<void> watch({required String squadId}) => _changes.stream;

  SquadSession _find(String sessionId) {
    if (!enabled) throw const SessionNotEnabled();
    for (final session in sessions) {
      if (session.id == sessionId) return session;
    }
    throw const RepositoryFailure('That session is gone.');
  }

  SquadSession _editable(String sessionId) {
    final session = _find(sessionId);
    if (userId != session.creatorId && userId != ownerId) {
      throw const RepositoryFailure(
        'Only the person who scheduled it, or the owner, can change it.',
      );
    }
    return session;
  }

  void _replace(SquadSession current, SquadSession next) {
    final index = sessions.indexOf(current);
    sessions[index] = next;
    _changes.add(null);
  }

  String? _note(String? note) {
    final text = note?.trim() ?? '';
    if (text.isEmpty) return null;
    return text;
  }
}
