import 'dart:async';

import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/spot/data/spot_repository.dart';
import 'package:squadsync/features/spot/domain/spot_call.dart';

/// In-memory spot call. The join window is five minutes from [clock].
/// A locked call blocks the next one until [spotLockMax] has passed.
class FakeSpotRepository implements SpotRepository {
  FakeSpotRepository({
    required this.clock,
    this.userId = 'spencer',
    this.ownerId = 'spencer',
  });

  final SquadClock clock;
  String userId;
  String ownerId;
  SpotCall? call;
  final Set<String> starters = {};
  final StreamController<SpotChange> _changes =
      StreamController<SpotChange>.broadcast();

  /// Test seam for a realtime insert, update, or delete. Does not change [call].
  void deliver(SpotChange change) {
    if (_changes.isClosed) return;
    _changes.add(change);
  }

  Never _refuse(String code, {String action = 'save'}) {
    throw RepositoryFailure(spotErrorMessage(code, action: action), code: code);
  }

  SpotCall? _live(String squadId) {
    final current = call;
    if (current == null || current.squadId != squadId) return null;
    return current;
  }

  bool _blocksNextCall(SpotCall current, DateTime now) {
    final lockedAt = current.lockedAt;
    if (lockedAt != null) {
      return now.difference(lockedAt.toUtc()) < spotLockMax;
    }
    return now.isBefore(current.joinUntil);
  }

  @override
  Future<SpotCall?> load({required String squadId}) async {
    return _live(squadId);
  }

  @override
  Future<SpotCall> callSpot({
    required String squadId,
    required String game,
    required DateTime startsAt,
  }) async {
    final label = game.trim();
    if (label.isEmpty) _refuse('spot_game_blank');
    final now = clock.now().toUtc();
    final current = _live(squadId);
    if (current != null && _blocksNextCall(current, now)) {
      _refuse('spot_already_open');
    }
    final rows = <SpotRsvp>[
      for (final id in starters)
        SpotRsvp(userId: id, response: SpotAnswer.rsvpIn, starter: true),
      if (!starters.contains(userId))
        SpotRsvp(userId: userId, response: SpotAnswer.rsvpIn, starter: false),
    ];
    call = SpotCall(
      id: 'spot-${now.microsecondsSinceEpoch}',
      squadId: squadId,
      callerId: userId,
      game: label,
      startsAt: startsAt,
      calledAt: now,
      joinUntil: now.add(const Duration(minutes: 5)),
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
    if (current == null || current.id != callId) _refuse('spot_missing');
    final now = clock.now().toUtc();
    if (current.lockedAt != null) _refuse('spot_locked');
    final mine = current.starter(userId);
    if (answer == SpotAnswer.rsvpIn &&
        !now.isBefore(current.joinUntil) &&
        !mine) {
      _refuse('spot_join_closed');
    }
    final next = [
      for (final row in current.rsvps)
        if (row.userId != userId) row,
      SpotRsvp(userId: userId, response: answer, starter: mine),
    ];
    if (answer == SpotAnswer.rsvpIn &&
        next.where((row) => row.response == SpotAnswer.rsvpIn).length > 8) {
      _refuse('spot_full');
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
    final current = _require(callId);
    if (userId != current.callerId && userId != ownerId) {
      _refuse('spot_not_caller', action: 'lock');
    }
    final now = clock.now().toUtc();
    call = SpotCall(
      id: current.id,
      squadId: current.squadId,
      callerId: current.callerId,
      game: current.game,
      startsAt: current.startsAt,
      calledAt: current.calledAt,
      joinUntil: current.joinUntil,
      lockedAt: current.lockedAt ?? now,
      lockedBy: current.lockedBy ?? userId,
      rsvps: current.rsvps,
    );
  }

  @override
  Future<void> end({required String callId}) async {
    final current = _require(callId);
    if (userId != current.callerId && userId != ownerId) {
      _refuse('spot_not_caller', action: 'end');
    }
    if (current.lockedAt == null) _refuse('spot_not_locked', action: 'end');
    call = null;
  }

  @override
  Future<void> cancel({required String callId}) async {
    final current = _require(callId);
    if (userId != current.callerId) {
      _refuse('spot_not_caller', action: 'cancel');
    }
    if (current.lockedAt != null) _refuse('spot_locked', action: 'cancel');
    call = null;
  }

  @override
  Stream<SpotChange> watch({required String squadId}) {
    return _changes.stream;
  }

  SpotCall _require(String callId) {
    final current = call;
    if (current == null || current.id != callId) _refuse('spot_missing');
    return current;
  }
}
