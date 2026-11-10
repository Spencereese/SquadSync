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

  /// Fires when a check-in row changes.
  /// An empty stream is fine. Resume and pull-to-refresh do not need it.
  /// A delete cannot be filtered by squad: the payload has the primary key
  /// only. [CheckInChange.deletedUserId] is that key, and the listener
  /// reloads only when [reloadAfterCheckInDelete] says the id is local.
  Stream<CheckInChange> watch({required String squadId});
}

/// A check-in insert, update, or delete.
class CheckInChange {
  const CheckInChange({this.deletedUserId});

  /// Null for an insert or update in this squad.
  /// Set for a delete, which is delivered without a squad filter.
  final String? deletedUserId;
}

/// Realtime DELETE rows do not include squad_id, so the subscription is
/// unfiltered and this decides whether to reload. A missing id reloads,
/// because the event cannot be matched. An id this squad is not showing
/// does not.
bool reloadAfterCheckInDelete({
  required Iterable<String> knownUserIds,
  required String? deletedUserId,
}) {
  final id = deletedUserId?.trim() ?? '';
  if (id.isEmpty) return true;
  return knownUserIds.contains(id);
}

/// The live project has no check-in table yet. Do not invent rows.
class AvailabilityNotEnabled implements Exception {
  const AvailabilityNotEnabled();
}
