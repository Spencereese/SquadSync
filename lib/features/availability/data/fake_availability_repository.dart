import 'dart:async';

import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/availability/data/availability_repository.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';

/// In-memory check-ins for one squad. [userId] is the signed-in person.
/// Changing [userId] is an account change: saves write the new id only.
class FakeAvailabilityRepository implements AvailabilityRepository {
  FakeAvailabilityRepository({
    required this.clock,
    this.userId = 'spencer',
    this.failLoad = false,
    this.failSave = false,
    this.notEnabled = false,
    List<StoredCheckIn>? seed,
  }) : _rows = [for (final row in seed ?? const <StoredCheckIn>[]) row];

  final SquadClock clock;
  String userId;
  bool failLoad;
  bool failSave;
  bool notEnabled;

  /// Completes before a load returns. Tests hold the first frame on this.
  Future<void>? holdLoads;

  /// How many times [load] has been asked. A delete for another squad
  /// must not increment this.
  int loadCount = 0;

  final List<StoredCheckIn> _rows;
  final _changes = StreamController<CheckInChange>.broadcast();

  /// Test seam for a realtime insert or update. Does not add a row.
  void notify() {
    if (!_changes.isClosed) _changes.add(const CheckInChange());
  }

  /// An unfiltered delete, the way realtime delivers one. Does not drop a row.
  void notifyDeleted(String userId) {
    if (!_changes.isClosed) {
      _changes.add(CheckInChange(deletedUserId: userId));
    }
  }

  /// Removes a stored row without telling listeners.
  void drop(String userId) {
    _rows.removeWhere((row) => row.userId == userId);
  }

  List<StoredCheckIn> get rows => List.unmodifiable(_rows);

  @override
  Future<List<StoredCheckIn>> load({required String squadId}) async {
    loadCount += 1;
    final hold = holdLoads;
    if (hold != null) await hold;
    if (notEnabled) throw const AvailabilityNotEnabled();
    if (failLoad) {
      throw const RepositoryFailure('Could not load check-ins.');
    }
    return [
      for (final row in _rows)
        if (row.squadId == squadId) row,
    ];
  }

  @override
  Future<StoredCheckIn> save({
    required String squadId,
    required CheckInDraft draft,
  }) async {
    if (notEnabled) throw const AvailabilityNotEnabled();
    if (failSave) {
      throw const RepositoryFailure(
        'Could not save your check-in. Nothing was saved.',
      );
    }
    final stamped = _stamp(squadId, draft);
    _rows.removeWhere((row) => row.userId == userId);
    _rows.add(stamped);
    return stamped;
  }

  @override
  Future<void> clear({required String squadId}) async {
    if (notEnabled) throw const AvailabilityNotEnabled();
    if (failSave) {
      throw const RepositoryFailure(
        'Could not clear your check-in. Nothing was changed.',
      );
    }
    _rows.removeWhere((row) => row.userId == userId && row.squadId == squadId);
  }

  @override
  Stream<CheckInChange> watch({required String squadId}) => _changes.stream;

  /// A row another phone stored. Does not notify until [notify].
  void store(StoredCheckIn row) {
    _rows.removeWhere((stored) => stored.userId == row.userId);
    _rows.add(row);
  }

  StoredCheckIn _stamp(String squadId, CheckInDraft draft) {
    final checkedAt = clock.now().toUtc();
    switch (draft.kind) {
      case CheckInKind.availableNow:
        return StoredCheckIn(
          userId: userId,
          squadId: squadId,
          kind: CheckInKind.availableNow,
          checkedAt: checkedAt,
          until: checkedAt.add(availableNowWindow),
        );
      case CheckInKind.unavailable:
        return StoredCheckIn(
          userId: userId,
          squadId: squadId,
          kind: CheckInKind.unavailable,
          checkedAt: checkedAt,
        );
      case CheckInKind.availableLater:
        final until = draft.until?.toUtc();
        if (until == null) {
          throw const RepositoryFailure(
            'Pick a time at least a minute from now. Nothing was saved.',
          );
        }
        final problem = rejectLater(checkedAt, until);
        if (problem != null) throw RepositoryFailure(problem);
        return StoredCheckIn(
          userId: userId,
          squadId: squadId,
          kind: CheckInKind.availableLater,
          checkedAt: checkedAt,
          until: until,
        );
    }
  }
}
