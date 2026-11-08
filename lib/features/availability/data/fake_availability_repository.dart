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

  final List<StoredCheckIn> _rows;

  List<StoredCheckIn> get rows => List.unmodifiable(_rows);

  @override
  Future<List<StoredCheckIn>> load({required String squadId}) async {
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
