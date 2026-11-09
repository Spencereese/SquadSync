import 'dart:async';

import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/squad/data/roster_channel.dart';
import 'package:squadsync/core/sq8_database.dart';
import 'package:squadsync/core/sq8_rows.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps a PostgREST error onto the exceptions the repositories already catch.
Exception mapPostgrest(PostgrestException error) {
  if (error.code == '23505') return const Sq8DuplicateRow();
  if (error.message.contains('sq8_squad_full')) return const Sq8SquadFull();
  if (error.message.contains('sq8_owner_protected')) {
    return const Sq8OwnerProtected();
  }
  return RepositoryFailure(error.message);
}

class SupabaseSq8Database implements Sq8Database {
  SupabaseSq8Database(this._client);

  final SupabaseClient _client;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Future<Sq8Member?> myProfile() async {
    final me = _requireUser();
    final row = await _client
        .from('sq8_profiles')
        .select('id, display_name, default_game')
        .eq('id', me)
        .maybeSingle();
    if (row == null) return null;
    return memberFromRow({
      'user_id': row['id'],
      'sq8_profiles': {
        'display_name': row['display_name'],
        'default_game': row['default_game'],
      },
    });
  }

  @override
  Future<void> insertMyProfile({
    required String displayName,
    required String defaultGame,
  }) async {
    final me = _requireUser();
    try {
      await _client.from('sq8_profiles').insert({
        'id': me,
        'display_name': displayName,
        'default_game': defaultGame,
      });
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        throw const RepositoryFailure(
          'The server cannot create your profile yet. Nothing was saved.',
        );
      }
      throw mapPostgrest(error);
    }
  }

  @override
  Future<void> updateMyProfile({
    required String displayName,
    required String defaultGame,
  }) {
    final me = _requireUser();
    return _guard(
      () => _client
          .from('sq8_profiles')
          .update({'display_name': displayName, 'default_game': defaultGame})
          .eq('id', me),
    );
  }

  @override
  Future<String> createSquad() async {
    final me = _requireUser();
    final Map<String, dynamic> row;
    try {
      row = await _client
          .from('sq8_squads')
          .insert({'owner_id': me})
          .select('id')
          .single();
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        final existing = await mySquadId();
        if (existing != null) return existing;
        throw const Sq8DuplicateRow();
      }
      // The insert can seat the owner and still hide the returned row
      // until the owner select policy exists. Open that squad if it is there.
      if (error.code == 'PGRST116' || error.code == '42501') {
        final existing = await mySquadId();
        if (existing != null) return existing;
        throw const RepositoryFailure(
          'The squad was not opened. Nothing is on screen until the server returns it.',
        );
      }
      throw mapPostgrest(error);
    }
    final id = row['id'];
    if (id is! String || id.isEmpty) {
      throw const RepositoryFailure('squad was not created');
    }
    return id;
  }

  @override
  Future<String?> mySquadId() async {
    final me = _requireUser();
    final row = await _client
        .from('sq8_squad_members')
        .select('squad_id')
        .eq('user_id', me)
        .maybeSingle();
    final id = row?['squad_id'];
    if (id is! String || id.isEmpty) return null;
    return id;
  }

  @override
  Future<String> ownerId(String squadId) async {
    final row = await _client
        .from('sq8_squads')
        .select('owner_id')
        .eq('id', squadId)
        .single();
    final id = row['owner_id'];
    if (id is! String || id.isEmpty) {
      throw const RepositoryFailure('squad is missing an owner');
    }
    return id;
  }

  @override
  Future<List<Sq8Member>> membersOf(String squadId) async {
    final rows = await _client
        .from('sq8_squad_members')
        .select('user_id, sq8_profiles(display_name, default_game)')
        .eq('squad_id', squadId);
    return [for (final row in rows) memberFromRow(row)];
  }

  @override
  Future<void> insertMember({required String squadId, required String userId}) {
    return _guard(
      () => _client.from('sq8_squad_members').insert({
        'squad_id': squadId,
        'user_id': userId,
      }),
    );
  }

  @override
  Future<bool> deleteMember({
    required String squadId,
    required String userId,
  }) async {
    final rows = await _guardValue(
      () => _client
          .from('sq8_squad_members')
          .delete()
          .eq('squad_id', squadId)
          .eq('user_id', userId)
          .select('user_id'),
    );
    return rows.isNotEmpty;
  }

  @override
  Future<List<Sq8Message>> newestMessages(
    String squadId, {
    required int limit,
  }) async {
    final rows = await _client
        .from('sq8_messages')
        .select()
        .eq('squad_id', squadId)
        .order('sent_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);
    return [for (final row in rows) messageFromRow(row)];
  }

  @override
  Future<List<Sq8Message>> olderMessages(
    String squadId, {
    required DateTime before,
    required String beforeId,
    required int limit,
  }) async {
    final rows = await _client
        .from('sq8_messages')
        .select()
        .eq('squad_id', squadId)
        .or(olderThanFilter(before, beforeId))
        .order('sent_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);
    return [for (final row in rows) messageFromRow(row)];
  }

  @override
  Future<void> insertMessage(Sq8Message message) {
    return _guard(
      () => _client.from('sq8_messages').insert({
        'id': message.id,
        'squad_id': message.squadId,
        'sender_id': message.senderId,
        'body': message.body,
        'sent_at': message.sentAt.toUtc().toIso8601String(),
      }),
    );
  }

  @override
  Stream<Sq8Message> watchInserts(String squadId) {
    final channel = _client.channel('sq8-messages-$squadId');
    final controller = StreamController<Sq8Message>.broadcast();
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sq8_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'squad_id',
            value: squadId,
          ),
          callback: (payload) {
            if (controller.isClosed) return;
            controller.add(messageFromRow(payload.newRecord));
          },
        )
        .subscribe((status, error) {
          if (controller.isClosed) return;
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            controller.addError(
              RepositoryFailure(error?.toString() ?? 'live updates stopped'),
            );
          }
        });
    controller.onCancel = () {
      unawaited(_client.removeChannel(channel));
    };
    return controller.stream;
  }

  @override
  Stream<void> watchRoster({String? squadId, required String userId}) {
    final topic = rosterTopic(squadId: squadId, userId: userId);
    final channel = _client.channel(topic);
    final controller = StreamController<void>.broadcast();
    var disposed = false;

    void emit(PostgresChangePayload _) {
      if (disposed || controller.isClosed) return;
      controller.add(null);
    }

    if (squadId == null || squadId.isEmpty) {
      for (final event in [
        PostgresChangeEvent.insert,
        PostgresChangeEvent.delete,
      ]) {
        channel.onPostgresChanges(
          event: event,
          schema: 'public',
          table: 'sq8_squad_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: emit,
        );
      }
    } else {
      for (final event in PostgresChangeEvent.values) {
        if (event == PostgresChangeEvent.all) continue;
        channel.onPostgresChanges(
          event: event,
          schema: 'public',
          table: 'sq8_squad_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'squad_id',
            value: squadId,
          ),
          callback: emit,
        );
      }
      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'sq8_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'squad_id',
          value: squadId,
        ),
        callback: emit,
      );
    }

    // subscribe() can be called once per channel. Error, timeout, and a
    // dropped socket are rejoined by the realtime client. Token refresh
    // drops this channel and opens a new one.
    channel.subscribe();
    controller.onCancel = () {
      disposed = true;
      unawaited(_client.removeChannel(channel));
    };
    return controller.stream;
  }

  @override
  Future<Sq8Cursor?> readCursor(String squadId) async {
    final me = _requireUser();
    final row = await _client
        .from('sq8_chat_read_state')
        .select('last_read_at, last_read_id')
        .eq('user_id', me)
        .eq('squad_id', squadId)
        .maybeSingle();
    if (row == null) return null;
    return cursorFromRow(row);
  }

  @override
  Future<int> unreadCount(String squadId, Sq8Cursor? cursor) {
    final me = _requireUser();
    var query = _client
        .from('sq8_messages')
        .count()
        .eq('squad_id', squadId)
        .neq('sender_id', me);
    if (cursor != null) {
      query = query.or(newerThanFilter(cursor.lastReadAt, cursor.lastReadId));
    }
    return query;
  }

  @override
  Future<void> upsertCursor({
    required String squadId,
    required DateTime lastReadAt,
    String? lastReadId,
  }) {
    final me = _requireUser();
    return _guard(
      () => _client.from('sq8_chat_read_state').upsert({
        'user_id': me,
        'squad_id': squadId,
        'last_read_at': lastReadAt.toUtc().toIso8601String(),
        'last_read_id': lastReadId,
      }, onConflict: 'user_id,squad_id'),
    );
  }

  String _requireUser() {
    final id = userId;
    if (id == null || id.isEmpty) {
      throw const RepositoryFailure('not signed in');
    }
    return id;
  }

  Future<void> _guard(Future<dynamic> Function() action) async {
    await _guardValue(action);
  }

  Future<T> _guardValue<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      throw mapPostgrest(error);
    }
  }
}
