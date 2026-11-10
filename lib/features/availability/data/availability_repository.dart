import 'package:squadsync/features/availability/domain/check_in.dart';

/// The signed-in person's check-ins for one squad.
/// A missing table is [AvailabilityNotEnabled], not an empty board and not a demo.
abstract class AvailabilityRepository {
  Future<List<StoredCheckIn>> load({required String squadId});

  /// Inserts or replaces only the signed-in person's row.
  /// Throws [RepositoryFailure] without writing when the save is refused.
  Future<StoredCheckIn> save({
    required String squadId,
    required CheckInDraft draft,
  });

  /// Removes only the signed-in person's row. They are then not checked in,
  /// which is different from marking unavailable.
  Future<void> clear({required String squadId});

  /// Fires when a check-in row in [squadId] changes.
  /// An empty stream is fine. Resume and pull-to-refresh do not need it.
  Stream<void> watch({required String squadId});
}

/// The live project has no check-in table yet. Do not invent rows.
class AvailabilityNotEnabled implements Exception {
  const AvailabilityNotEnabled();
}
