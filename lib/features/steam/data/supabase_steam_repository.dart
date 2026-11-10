import 'package:squadsync/features/steam/data/steam_repository.dart';
import 'package:squadsync/features/steam/domain/steam_presence.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls `sq8-steam-presence`. A missing function or secret is not set up.
class SupabaseSteamRepository implements SteamRepository {
  SupabaseSteamRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SteamBoard> presence() async {
    final body = await _invoke({'op': 'presence'});
    if (body == null || body['status'] == 'not_set_up') {
      return SteamBoard.notSetUp;
    }
    final rows = body['members'];
    if (rows is! List) return SteamBoard.notSetUp;
    return SteamBoard(
      setUp: true,
      members: [
        for (final row in rows)
          if (row is Map) _member(row),
      ].whereType<SteamMember>().toList(),
    );
  }

  @override
  Future<SteamLink?> mine() async {
    try {
      final me = _client.auth.currentUser?.id;
      if (me == null) return null;
      final row = await _client
          .from('sq8_steam_links')
          .select('steam_id')
          .eq('user_id', me)
          .maybeSingle();
      final id = row?['steam_id'];
      if (id is! String || id.isEmpty) return null;
      return SteamLink(id);
    } on PostgrestException catch (error) {
      if (_missing(error)) return null;
      rethrow;
    }
  }

  @override
  Future<SteamLinkResult> link(String raw) async {
    final body = await _invoke({'op': 'link', 'steam': raw});
    if (body == null || body['status'] == 'not_set_up') {
      return const SteamLinkResult(message: 'Steam presence not set up yet');
    }
    if (body['status'] == 'linked' && body['steam_id'] is String) {
      return SteamLinkResult(link: SteamLink(body['steam_id'] as String));
    }
    final message = body['message'];
    return SteamLinkResult(
      message: message is String && message.isNotEmpty
          ? message
          : 'That is not a SteamID64 or a vanity URL.',
    );
  }

  @override
  Future<void> unlink() async {
    await _invoke({'op': 'unlink'});
  }

  SteamMember? _member(Map<dynamic, dynamic> row) {
    final userId = row['user_id'];
    final state = row['state'];
    if (userId is! String || state is! String) return null;
    final game = row['game'];
    return SteamMember(
      userId: userId,
      game: game is String ? game : null,
      view: switch (state) {
        'playing' => SteamView.playing,
        'private' => SteamView.privateProfile,
        'not_linked' => SteamView.notLinked,
        _ => SteamView.notInGame,
      },
    );
  }

  Future<Map<String, dynamic>?> _invoke(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(
        'sq8-steam-presence',
        body: body,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return data.map((key, value) => MapEntry('$key', value));
      return null;
    } on FunctionException {
      return {'status': 'not_set_up'};
    }
  }

  bool _missing(PostgrestException error) {
    return error.code == '42P01' || error.code == 'PGRST205';
  }
}
