import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/data/datasources/lobby_remote_datasource.dart';
import 'package:squad_sync/services/jwt_validator.dart';
import 'package:squad_sync/services/session_rating_machine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final ratedAt = DateTime.utc(2026, 9, 5, 18);
  final notes = notesForSessionRating(
    reduceSessionRating(
      current: SessionRatingState.unrated,
      event: SessionRatingEvent.rate,
      vibes: 5,
      comms: 4,
      gunny: 3,
      wingman: 2,
      comment: 'clutch',
      result: 'win',
      raterUid: 'u1',
      ratedAt: ratedAt,
    ),
  );

  test('no-arg LobbyRemoteDataSourceImpl fails clearly without a client', () {
    expect(
      () => LobbyRemoteDataSourceImpl(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('injected SupabaseClient'),
        ),
      ),
    );
  });

  test('constructs against a fake client without Supabase.instance', () {
    final ds = LobbyRemoteDataSourceImpl(
      supabase: AuthOnlySupabaseClient(userId: 'u1'),
    );
    expect(ds, isA<LobbyRemoteDataSourceImpl>());
  });

  test('recordMatchResult create inserts when no recent row', () async {
    final client = RecordingMatchHistoryClient();
    final ds = LobbyRemoteDataSourceImpl(
      supabase: AuthOnlySupabaseClient(userId: 'u1'),
      matchHistoryClient: client,
    );

    await ds.recordMatchResult(
      lobbyId: 'lobby-1',
      gameName: 'Warzone',
      result: 'win',
      playerUids: const ['u1', 'u2'],
      createdBy: 'u1',
      notes: notes,
    );

    expect(client.op, 'insert');
    expect(client.table, kMatchHistoryTable);
    expect(client.inserts, hasLength(1));
    expect(client.updates, isEmpty);
    expect(client.inserts.single['lobby_id'], 'lobby-1');
    expect(client.inserts.single['created_by'], 'u1');
    expect(client.inserts.single['result'], 'win');
    expect(
      decodeSessionRatingFromNotes(client.inserts.single['notes'])?.vibes,
      5,
    );
    expect(
      decodeSessionRatingFromNotes(client.inserts.single['notes'])?.comment,
      'clutch',
    );
  });

  test('recordMatchResult update patches a recent row', () async {
    final client = RecordingMatchHistoryClient(
      selectRows: [
        {
          'id': 'm-existing',
          'lobby_id': 'lobby-1',
          'created_by': 'u1',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'notes': 'plain',
        },
      ],
    );
    final ds = LobbyRemoteDataSourceImpl(
      supabase: AuthOnlySupabaseClient(userId: 'u1'),
      matchHistoryClient: client,
    );

    await ds.recordMatchResult(
      lobbyId: 'lobby-1',
      gameName: 'Warzone',
      result: 'loss',
      playerUids: const ['u1'],
      createdBy: 'u1',
      notes: notes,
    );

    expect(client.op, 'update');
    expect(client.table, kMatchHistoryTable);
    expect(client.inserts, isEmpty);
    expect(client.updates, hasLength(1));
    expect(client.filters['id'], 'm-existing');
    expect(client.updates.single['result'], 'loss');
    expect(
      decodeSessionRatingFromNotes(client.updates.single['notes'])?.gunny,
      3,
    );
    expect(
      decodeSessionRatingFromNotes(client.updates.single['notes'])?.wingman,
      2,
    );
  });

  test('recordMatchResult rejects a missing session', () async {
    final ds = LobbyRemoteDataSourceImpl(
      supabase: AuthOnlySupabaseClient(),
    );
    expect(
      () => ds.recordMatchResult(
        lobbyId: 'lobby-1',
        gameName: 'Warzone',
        result: 'win',
        playerUids: const ['u1'],
        createdBy: 'u1',
      ),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('applyMatchHistoryWrite create vs update hit mocked client', () async {
    final createClient = RecordingMatchHistoryClient();
    await applyMatchHistoryWrite(
      createClient,
      SessionRatingWrite.create({
        'lobby_id': 'lobby-1',
        'notes': notes,
      }),
    );
    expect(createClient.op, 'insert');
    expect(createClient.inserts.single['lobby_id'], 'lobby-1');

    final updateClient = RecordingMatchHistoryClient();
    await applyMatchHistoryWrite(
      updateClient,
      const SessionRatingWrite.update(
        matchId: 'm1',
        payload: {'result': 'win'},
      ),
    );
    expect(updateClient.op, 'update');
    expect(updateClient.filters['id'], 'm1');
    expect(updateClient.updates.single['result'], 'win');
  });
}

class _FakeUser extends Fake implements User {
  _FakeUser(this.id);

  @override
  final String id;
}

class _FakeGoTrueClient extends Fake implements GoTrueClient {
  _FakeGoTrueClient({String? userId})
      : currentUser = userId == null ? null : _FakeUser(userId);

  @override
  final User? currentUser;
}

/// Auth-only [SupabaseClient] (ConstitutionManager DI). Table I/O uses
/// [RecordingMatchHistoryClient] so `from()` is not the Postgrest stub.
class AuthOnlySupabaseClient extends Fake implements SupabaseClient {
  AuthOnlySupabaseClient({String? userId})
      : auth = _FakeGoTrueClient(userId: userId);

  @override
  final GoTrueClient auth;
}

/// Recording table client for match_history create/update.
class RecordingMatchHistoryClient {
  RecordingMatchHistoryClient({this.selectRows = const []});

  List<Map<String, dynamic>> selectRows;
  final inserts = <Map<String, dynamic>>[];
  final updates = <Map<String, dynamic>>[];
  final filters = <String, Object>{};
  String? table;
  String? op;

  RecordingQuery from(String table) {
    this.table = table;
    return RecordingQuery(this);
  }
}

class RecordingQuery implements Future<dynamic> {
  RecordingQuery(this.client);

  final RecordingMatchHistoryClient client;

  dynamic get _value => client.op == 'select' ? client.selectRows : null;

  RecordingQuery insert(Object values, {bool defaultToNull = true}) {
    client.op = 'insert';
    client.inserts.add(Map<String, dynamic>.from(values as Map));
    return this;
  }

  RecordingQuery update(Map values) {
    client.op = 'update';
    client.updates.add(Map<String, dynamic>.from(values));
    return this;
  }

  RecordingQuery select([String columns = '*']) {
    client.op = 'select';
    return this;
  }

  RecordingQuery eq(String column, Object value) {
    client.filters[column] = value;
    return this;
  }

  RecordingQuery gte(String column, Object value) {
    client.filters['gte:$column'] = value;
    return this;
  }

  RecordingQuery order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    return this;
  }

  RecordingQuery limit(int count, {String? referencedTable}) {
    return this;
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(dynamic value) onValue, {
    Function? onError,
  }) {
    return Future<dynamic>.value(_value).then(onValue, onError: onError);
  }

  @override
  Future<dynamic> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) {
    return Future<dynamic>.value(_value);
  }

  @override
  Future<dynamic> whenComplete(FutureOr<void> Function() action) {
    return Future<dynamic>.sync(() async {
      await action();
      return _value;
    });
  }

  @override
  Future<dynamic> timeout(
    Duration timeLimit, {
    FutureOr<dynamic> Function()? onTimeout,
  }) {
    return Future<dynamic>.value(_value);
  }

  @override
  Stream<dynamic> asStream() => Stream<dynamic>.value(_value);
}
