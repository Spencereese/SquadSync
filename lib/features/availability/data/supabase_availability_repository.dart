import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/availability/data/availability_repository.dart';
import 'package:squadsync/features/availability/data/check_in_row.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live check-ins. The database stamps the time and the "available now"
/// window. This class does not fall back to demo rows when the table is missing.
class SupabaseAvailabilityRepository implements AvailabilityRepository {
  SupabaseAvailabilityRepository(this._client);

  final SupabaseClient _client;

  String _requireUser() {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw const RepositoryFailure('not signed in');
    }
    return id;
  }

  @override
  Future<List<StoredCheckIn>> load({required String squadId}) async {
    _requireUser();
    try {
      final rows = await _client
          .from('sq8_check_ins')
          .select('user_id, squad_id, kind, checked_at, until_at')
          .eq('squad_id', squadId);
      return [for (final row in rows) checkInFromRow(row)];
    } on PostgrestException catch (error) {
      throw mapCheckInReadError(error);
    }
  }

  @override
  Future<StoredCheckIn> save({
    required String squadId,
    required CheckInDraft draft,
  }) async {
    final me = _requireUser();
    if (draft.kind == CheckInKind.availableLater && draft.until == null) {
      throw const RepositoryFailure(
        'Pick a time at least a minute from now. Nothing was saved.',
      );
    }
    final payload = <String, dynamic>{
      'user_id': me,
      'squad_id': squadId,
      'kind': checkInKindKey(draft.kind),
      'until_at': draft.kind == CheckInKind.availableLater
          ? draft.until!.toUtc().toIso8601String()
          : null,
    };
    try {
      final row = await _client
          .from('sq8_check_ins')
          .upsert(payload, onConflict: 'user_id')
          .select('user_id, squad_id, kind, checked_at, until_at')
          .single();
      return checkInFromRow(row);
    } on PostgrestException catch (error) {
      throw mapCheckInWriteError(error);
    }
  }

  @override
  Future<void> clear({required String squadId}) async {
    final me = _requireUser();
    try {
      await _client
          .from('sq8_check_ins')
          .delete()
          .eq('user_id', me)
          .eq('squad_id', squadId);
    } on PostgrestException catch (error) {
      throw mapCheckInWriteError(error);
    }
  }
}
