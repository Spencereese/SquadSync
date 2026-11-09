import 'dart:convert';

import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/invite/data/invite_repository.dart';
import 'package:squadsync/features/invite/domain/invite_code.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseInviteRepository implements InviteRepository {
  SupabaseInviteRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SquadInvite?> current() async {
    try {
      final row = await _client
          .from('sq8_invites')
          .select('code, expires_at, squad_id')
          .isFilter('revoked_at', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return _invite(row);
    } on PostgrestException catch (error) {
      if (_missing(error)) throw const InvitesNotEnabled();
      throw const RepositoryFailure('Could not load the invite.');
    }
  }

  @override
  Future<SquadInvite> createOrRotate() async {
    final body = await _rpc('sq8_create_invite');
    if (body['ok'] != true) {
      throw RepositoryFailure(
        joinErrorMessage(_error(body) ?? JoinError.invalid),
      );
    }
    return _fromRpc(body);
  }

  @override
  Future<JoinDecision> join(String code) async {
    final body = await _rpc('sq8_join_with_code', {'code': code});
    if (body['ok'] == true) {
      final squadId = body['squad_id'];
      if (squadId is! String || squadId.isEmpty) {
        return const JoinDecision.failed(JoinError.invalid);
      }
      return JoinDecision.joined(squadId);
    }
    final error = _error(body);
    if (error == null) return const JoinDecision.failed(JoinError.invalid);
    return JoinDecision.failed(error);
  }

  Future<Map<String, dynamic>> _rpc(
    String name, [
    Map<String, dynamic>? params,
  ]) async {
    try {
      final raw = params == null
          ? await _client.rpc<dynamic>(name)
          : await _client.rpc<dynamic>(name, params: params);
      return _json(raw);
    } on PostgrestException catch (error) {
      if (_missing(error)) throw const InvitesNotEnabled();
      throw const RepositoryFailure('Could not use invites.');
    }
  }

  SquadInvite _fromRpc(Map<String, dynamic> body) {
    final code = body['code'];
    final squadId = body['squad_id'];
    final expires = body['expires_at'];
    if (code is! String || squadId is! String || expires is! String) {
      throw const RepositoryFailure('The invite was not created.');
    }
    return SquadInvite(
      code: code,
      squadId: squadId,
      expiresAt: DateTime.parse(expires).toUtc(),
    );
  }

  SquadInvite _invite(Map<String, dynamic> row) {
    final code = row['code'];
    final squadId = row['squad_id'];
    final expires = row['expires_at'];
    if (code is! String || squadId is! String || expires is! String) {
      throw const RepositoryFailure('The invite could not be read.');
    }
    return SquadInvite(
      code: code,
      squadId: squadId,
      expiresAt: DateTime.parse(expires).toUtc(),
    );
  }

  JoinError? _error(Map<String, dynamic> body) {
    final code = body['error'];
    if (code is! String) return null;
    return joinErrorFromCode(code);
  }

  Map<String, dynamic> _json(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry('$key', value));
    }
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    }
    throw const RepositoryFailure('Could not use invites.');
  }

  bool _missing(PostgrestException error) {
    return error.code == 'PGRST202' ||
        error.code == 'PGRST205' ||
        error.code == '42883' ||
        error.code == '42P01';
  }
}
