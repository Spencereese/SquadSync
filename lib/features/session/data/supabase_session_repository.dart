import 'dart:async';

import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/session/data/session_repository.dart';
import 'package:squadsync/features/session/domain/squad_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSessionRepository implements SessionRepository {
  SupabaseSessionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SessionBoard> load({required String squadId}) async {
    try {
      final rows = await _client
          .from('sq8_sessions')
          .select(
            'id, squad_id, creator_id, game, starts_at, duration_minutes, note, cancelled_at',
          )
          .eq('squad_id', squadId)
          .isFilter('cancelled_at', null)
          .order('starts_at');
      if (rows.isEmpty) return const SessionBoard(enabled: true);
      final ids = [for (final row in rows) row['id'] as String];
      final rsvps = await _client
          .from('sq8_session_rsvps')
          .select('session_id, user_id, response')
          .inFilter('session_id', ids);
      return SessionBoard(
        enabled: true,
        sessions: [
          for (final row in rows)
            _session(row, [
              for (final rsvp in rsvps)
                if (rsvp['session_id'] == row['id']) rsvp,
            ]),
        ],
      );
    } on PostgrestException catch (error) {
      if (_missing(error)) return SessionBoard.notEnabled;
      throw RepositoryFailure(error.message);
    }
  }

  @override
  Future<SquadSession> create({
    required String squadId,
    required String game,
    required DateTime startsAt,
    Duration? duration,
    String? note,
  }) async {
    final me = _client.auth.currentUser?.id;
    try {
      final row = await _client
          .from('sq8_sessions')
          .insert({
            'squad_id': squadId,
            'creator_id': me,
            'game': game.trim(),
            'starts_at': startsAt.toUtc().toIso8601String(),
            if (duration != null) 'duration_minutes': duration.inMinutes,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          })
          .select(
            'id, squad_id, creator_id, game, starts_at, duration_minutes, note, cancelled_at',
          )
          .single();
      return _session(row, const []);
    } on PostgrestException catch (error) {
      if (_missing(error)) throw const SessionNotEnabled();
      throw RepositoryFailure(error.message);
    }
  }

  @override
  Future<void> update({
    required String sessionId,
    required String game,
    required DateTime startsAt,
    Duration? duration,
    String? note,
  }) async {
    try {
      await _client
          .from('sq8_sessions')
          .update({
            'game': game.trim(),
            'starts_at': startsAt.toUtc().toIso8601String(),
            'duration_minutes': duration?.inMinutes,
            'note': note == null || note.trim().isEmpty ? null : note.trim(),
          })
          .eq('id', sessionId);
    } on PostgrestException catch (error) {
      _fail(error);
    }
  }

  @override
  Future<void> cancel({required String sessionId}) async {
    try {
      await _client
          .from('sq8_sessions')
          .update({'cancelled_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', sessionId);
    } on PostgrestException catch (error) {
      _fail(error);
    }
  }

  @override
  Future<void> rsvp({
    required String sessionId,
    required SessionAnswer answer,
  }) async {
    final me = _client.auth.currentUser?.id;
    try {
      await _client.from('sq8_session_rsvps').upsert({
        'session_id': sessionId,
        'user_id': me,
        'response': switch (answer) {
          SessionAnswer.rsvpIn => 'in',
          SessionAnswer.maybe => 'maybe',
          SessionAnswer.out => 'out',
        },
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'session_id,user_id');
    } on PostgrestException catch (error) {
      if (error.message.contains('session_full')) {
        throw const RepositoryFailure(
          'This session is full.',
          code: 'session_full',
        );
      }
      _fail(error);
    }
  }

  @override
  Stream<void> watch({required String squadId}) {
    final channel = _client.channel('sq8-sessions-$squadId');
    final controller = StreamController<void>.broadcast();
    void emit() {
      if (!controller.isClosed) controller.add(null);
    }

    for (final event in [
      PostgresChangeEvent.insert,
      PostgresChangeEvent.update,
    ]) {
      channel.onPostgresChanges(
        event: event,
        schema: 'public',
        table: 'sq8_sessions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'squad_id',
          value: squadId,
        ),
        callback: (_) => emit(),
      );
    }
    for (final event in PostgresChangeEvent.values) {
      if (event == PostgresChangeEvent.all) continue;
      channel.onPostgresChanges(
        event: event,
        schema: 'public',
        table: 'sq8_session_rsvps',
        callback: (_) => emit(),
      );
    }
    channel.subscribe();
    controller.onCancel = () {
      unawaited(_client.removeChannel(channel));
    };
    return controller.stream;
  }

  Never _fail(PostgrestException error) {
    if (_missing(error)) throw const SessionNotEnabled();
    throw RepositoryFailure(error.message);
  }

  bool _missing(PostgrestException error) {
    return error.code == '42P01' || error.code == 'PGRST205';
  }

  SquadSession _session(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> rsvps,
  ) {
    final minutes = row['duration_minutes'];
    return SquadSession(
      id: row['id'] as String,
      squadId: row['squad_id'] as String,
      creatorId: row['creator_id'] as String,
      game: row['game'] as String,
      startsAt: DateTime.parse(row['starts_at'] as String),
      duration: minutes is int ? Duration(minutes: minutes) : null,
      note: row['note'] as String?,
      cancelledAt: row['cancelled_at'] == null
          ? null
          : DateTime.parse(row['cancelled_at'] as String),
      rsvps: [
        for (final rsvp in rsvps)
          SessionRsvp(
            userId: rsvp['user_id'] as String,
            answer: switch (rsvp['response']) {
              'in' => SessionAnswer.rsvpIn,
              'maybe' => SessionAnswer.maybe,
              _ => SessionAnswer.out,
            },
          ),
      ],
    );
  }
}
