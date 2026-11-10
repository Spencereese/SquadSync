import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/spot/data/spot_repository.dart';
import 'package:squadsync/features/spot/domain/spot_call.dart';

/// In-memory spot call. The join window is five minutes from [clock].
class FakeSpotRepository implements SpotRepository {
  FakeSpotRepository({required this.clock, this.userId = 'spencer'});

  final SquadClock clock;
  String userId;
  SpotCall? call;
  final Set<String> starters = {};

  @override
  Future<SpotCall?> load({required String squadId}) async {
    final current = call;
    if (current == null || current.squadId != squadId) return null;
    return current;
  }

  @override
  Future<SpotCall> callSpot({
    required String squadId,
    required String game,
    required DateTime startsAt,
  }) async {
    final label = game.trim();
    if (label.isEmpty) {
      throw const RepositoryFailure('Type a game. Nothing was called.');
    }
    final now = clock.now().toUtc();
    final current = call;
    if (current != null &&
        current.squadId == squadId &&
        current.lockedAt == null &&
        now.isBefore(current.joinUntil)) {
      throw const RepositoryFailure('A spot is already open.');
    }
    final created = SpotCall(
      id: 'spot-${now.millisecondsSinceEpoch}',
      squadId: squadId,
      callerId: userId,
      game: label,
      startsAt: startsAt,
      calledAt: now,
      joinUntil: now.add(const Duration(minutes: 5)),
      rsvps: const [],
    );
    final rows = <SpotRsvp>[
      for (final id in starters)
        SpotRsvp(userId: id, response: SpotAnswer.rsvpIn, starter: true),
      if (!starters.contains(userId))
        SpotRsvp(userId: userId, response: SpotAnswer.rsvpIn, starter: false),
    ];
    call = SpotCall(
      id: created.id,
      squadId: squadId,
      callerId: userId,
      game: label,
      startsAt: startsAt,
      calledAt: now,
      joinUntil: created.joinUntil,
      rsvps: rows,
    );
    return call!;
  }

  @override
  Future<void> rsvp({
    required String callId,
    required SpotAnswer answer,
  }) async {
    final current = call;
    if (current == null || current.id != callId) {
      throw const RepositoryFailure('That spot is gone.');
    }
    final now = clock.now().toUtc();
    if (current.lockedAt != null) {
      throw const RepositoryFailure('This spot is locked.');
    }
    final mine = current.starter(userId);
    if (answer == SpotAnswer.rsvpIn &&
        !now.isBefore(current.joinUntil) &&
        !mine) {
      throw const RepositoryFailure('The join window is closed.');
    }
    final next = [
      for (final row in current.rsvps)
        if (row.userId != userId) row,
      SpotRsvp(userId: userId, response: answer, starter: mine),
    ];
    if (answer == SpotAnswer.rsvpIn &&
        next.where((row) => row.response == SpotAnswer.rsvpIn).length > 8) {
      throw const RepositoryFailure('This spot is full.');
    }
    call = SpotCall(
      id: current.id,
      squadId: current.squadId,
      callerId: current.callerId,
      game: current.game,
      startsAt: current.startsAt,
      calledAt: current.calledAt,
      joinUntil: current.joinUntil,
      lockedAt: current.lockedAt,
      lockedBy: current.lockedBy,
      rsvps: next,
    );
  }

  @override
  Future<void> lock({required String callId}) async {
    final current = call;
    if (current == null || current.id != callId) {
      throw const RepositoryFailure('That spot is gone.');
    }
    call = SpotCall(
      id: current.id,
      squadId: current.squadId,
      callerId: current.callerId,
      game: current.game,
      startsAt: current.startsAt,
      calledAt: current.calledAt,
      joinUntil: current.joinUntil,
      lockedAt: clock.now().toUtc(),
      lockedBy: userId,
      rsvps: current.rsvps,
    );
  }
}
