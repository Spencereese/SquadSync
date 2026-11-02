import 'dart:async';

import 'package:squadsync/core/repository_failure.dart';
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
  Future<void> deleteMember({required String squadId, required String userId}) {
    return _guard(
      () => _client
          .from('sq8_squad_members')
          .delete()
          .eq('squad_id', squadId)
          .eq('user_id', userId),
    );
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
        .subscribe();
    controller.onCancel = () {
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
    try {
      await action();
    } on PostgrestException catch (error) {
      throw mapPostgrest(error);
    }
  }
}
