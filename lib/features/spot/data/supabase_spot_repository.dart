import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/spot/data/spot_repository.dart';
import 'package:squadsync/features/spot/domain/spot_call.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live spot calls. The database owns the five-minute window and the lock.
class SupabaseSpotRepository implements SpotRepository {
  SupabaseSpotRepository(this._client);

  final SupabaseClient _client;

  Never _map(PostgrestException error) {
    final message = error.message;
    if (error.code == '42P01' || error.code == 'PGRST205') {
      throw const SpotNotEnabled();
    }
    if (message.contains('spot_full')) {
      throw const RepositoryFailure('This spot is full.');
    }
    if (message.contains('spot_join_closed')) {
      throw const RepositoryFailure('The join window is closed.');
    }
    if (message.contains('spot_locked')) {
      throw const RepositoryFailure('This spot is locked.');
    }
    if (message.contains('spot_already_open')) {
      throw const RepositoryFailure('A spot is already open.');
    }
    if (message.contains('spot_not_caller')) {
      throw const RepositoryFailure('Only the caller or the owner can lock.');
    }
    throw RepositoryFailure(message);
  }

  @override
  Future<SpotCall?> load({required String squadId}) async {
    try {
      final rows = await _client
          .from('sq8_spot_calls')
          .select(
            'id, squad_id, caller_id, game, starts_at, called_at, join_until, locked_at, locked_by',
          )
          .eq('squad_id', squadId)
          .isFilter('closed_at', null)
          .limit(1);
      if (rows.isEmpty) return null;
      final row = rows.first;
      final id = row['id'] as String;
      final rsvpRows = await _client
          .from('sq8_spot_rsvps')
          .select('user_id, response, starter')
          .eq('call_id', id);
      return _call(row, rsvpRows);
    } on PostgrestException catch (error) {
      _map(error);
    }
  }

  @override
  Future<SpotCall> callSpot({
    required String squadId,
    required String game,
    required DateTime startsAt,
  }) async {
    try {
      await _client.rpc<dynamic>(
        'sq8_call_spot',
        params: {
          'squad': squadId,
          'game': game,
          'starts_at': startsAt.toUtc().toIso8601String(),
        },
      );
      final call = await load(squadId: squadId);
      if (call == null) {
        throw const RepositoryFailure('The spot was not saved.');
      }
      return call;
    } on PostgrestException catch (error) {
      _map(error);
    }
  }

  @override
  Future<void> rsvp({
    required String callId,
    required SpotAnswer answer,
  }) async {
    try {
      await _client.rpc<dynamic>(
        'sq8_rsvp_spot',
        params: {
          'call_id': callId,
          'response': answer == SpotAnswer.rsvpIn ? 'in' : 'out',
        },
      );
    } on PostgrestException catch (error) {
      _map(error);
    }
  }

  @override
  Future<void> lock({required String callId}) async {
    try {
      await _client.rpc<dynamic>('sq8_lock_spot', params: {'call_id': callId});
    } on PostgrestException catch (error) {
      _map(error);
    }
  }

  SpotCall _call(Map<String, dynamic> row, List<Map<String, dynamic>> rsvps) {
    return SpotCall(
      id: row['id'] as String,
      squadId: row['squad_id'] as String,
      callerId: row['caller_id'] as String,
      game: row['game'] as String,
      startsAt: DateTime.parse(row['starts_at'] as String),
      calledAt: DateTime.parse(row['called_at'] as String),
      joinUntil: DateTime.parse(row['join_until'] as String),
      lockedAt: row['locked_at'] == null
          ? null
          : DateTime.parse(row['locked_at'] as String),
      lockedBy: row['locked_by'] as String?,
      rsvps: [
        for (final rsvp in rsvps)
          SpotRsvp(
            userId: rsvp['user_id'] as String,
            response: rsvp['response'] == 'in'
                ? SpotAnswer.rsvpIn
                : SpotAnswer.rsvpOut,
            starter: rsvp['starter'] == true,
          ),
      ],
    );
  }
}
