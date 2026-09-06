import 'package:flutter/foundation.dart';
import 'package:squad_sync/data/lobby_stats_codec.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/services/session_rating_machine.dart';
import 'package:squad_sync/services/supabase_service.dart';
import 'package:squad_sync/services/jwt_validator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service_supabase.dart';

abstract class LobbyRemoteDataSource {
  Future<Lobby> createLobby(Lobby lobby);
  Future<Lobby?> getLobby(String lobbyId);
  Future<Lobby?> getLobbyByInviteCode(String inviteCode);
  Future<List<Lobby>> getUserLobbies(String userId);
  Future<void> updateLobby(Lobby lobby);
  Future<void> deleteLobby(String lobbyId);

  // Membership operations
  Future<void> joinLobby(String lobbyId, String userId);
  Future<void> leaveLobby(String lobbyId, String userId);
  Future<void> kickMember(String lobbyId, String memberId, String kickedBy);

  // Spot management
  Future<void> assignSpot(String lobbyId, int spotIndex, String? userId);
  Future<void> startSpotTimer(String lobbyId, int spotIndex, Duration duration);
  Future<void> cancelSpotTimer(String lobbyId, int spotIndex);

  // Status and activity
  Future<void> updateMemberStatus(String lobbyId, String userId, String status);
  Future<void> updateLastActivity(String lobbyId);

  // Timer processing (calls Cloud Functions)
  Future<void> processExpiredTimers();

  // Real-time streams
  Stream<Lobby> getLobbyStream(String lobbyId);
  Stream<List<Lobby>> getUserLobbiesStream(String userId);
  Stream<List<Lobby>> getPublicLobbiesStream({
    bool? isActive,
    String? gameFocus,
    int limit,
    String orderBy,
    bool ascending,
  });

  // Analytics
  Future<void> trackLobbyEvent(String event, Map<String, dynamic> data);

  // Invite management
  Future<void> createInvite(Map<String, dynamic> inviteData);

  // Peacock management
  Future<void> createPeacock(Map<String, dynamic> peacockData);
  Future<void> updateUserPeacock(
      String userId, Map<String, dynamic> peacockStatus);

  // Match history
  Future<void> recordMatchResult({
    required String lobbyId,
    required String gameName,
    required String result,
    required List<String> playerUids,
    required String createdBy,
    String? notes,
  });
  Future<Map<String, dynamic>> getLobbyStats(String lobbyId);
  Future<List<Map<String, dynamic>>> getMatchHistory(String lobbyId);
}

class LobbyRemoteDataSourceImpl
    with JwtValidationMixin
    implements LobbyRemoteDataSource {
  /// Prefer an injected [supabase] (Riverpod / tests). The no-arg path uses
  /// [SupabaseService.maybeClient] and throws a clear [StateError] when
  /// uninitialized — never [Supabase.instance] assert in a harness.
  ///
  /// [matchHistoryClient] is the table I/O target (defaults to [supabase]).
  /// Tests inject a recording fake here so create/update never need the
  /// Postgrest fluent types.
  LobbyRemoteDataSourceImpl({
    SupabaseClient? supabase,
    AuthServiceSupabase? authService,
    dynamic matchHistoryClient,
  })  : _supabase = supabase ?? _clientOrThrow(),
        _authService = authService ?? AuthServiceSupabase(),
        _matchHistoryClient = matchHistoryClient;

  final AuthServiceSupabase _authService;
  final SupabaseClient _supabase;
  final dynamic _matchHistoryClient;

  dynamic get _historyClient => _matchHistoryClient ?? _supabase;

  static SupabaseClient _clientOrThrow() {
    final client = SupabaseService.maybeClient;
    if (client == null) {
      throw StateError(
        'LobbyRemoteDataSourceImpl requires an injected SupabaseClient '
        '(or initialized SupabaseService). Override in unit tests — '
        'do not construct against Supabase.instance.',
      );
    }
    return client;
  }

  @override
  Future<Lobby> createLobby(Lobby lobby) async {
    // Validate JWT before creating lobby
    validateJwt();
    final authenticatedUserId = getAuthenticatedUserId();

    // Ensure creator matches authenticated user
    if (lobby.createdBy != authenticatedUserId) {
      throw UnauthorizedException('Cannot create lobby for another user');
    }

    final json = lobby.toJson();

    // Convert to snake_case for Supabase
    final data = <String, dynamic>{
      'id': json['id'],
      'name': json['name'],
      'member_uids': json['memberUids'],
      'game_focus': json['gameName'],
      'max_spots': json['maxSpots'],
      'created_by': json['createdBy'],
      'created_at': json['createdAt'],
      'spot_timers': json['spotTimers'] != null
          ? _convertSpotTimersToMap(json['spotTimers'])
          : {},
      'viewers': json['viewers'],
      'statuses': json['statuses'],
      'is_active': json['isActive'],
      'description': json['description'],
      'settings': json['settings'],
    };

    final chatGroupId = lobby.chatGroupId?.trim();
    if (chatGroupId != null && chatGroupId.isNotEmpty) {
      data['chat_group_id'] = chatGroupId;
    }

    await _insertLobbyRow(data);
    return lobby;
  }

  /// Write [chat_group_id] when the column exists. Retry without it on
  /// Postgres 42703 (undefined_column) so create still succeeds.
  Future<void> _insertLobbyRow(Map<String, dynamic> data) async {
    try {
      await _supabase.from('lobbies').insert(data);
    } catch (e) {
      if (data.containsKey('chat_group_id') && _isUndefinedColumn42703(e)) {
        debugPrint(
            '⚠️ lobbies.chat_group_id missing (42703); inserting without bind');
        final retry = Map<String, dynamic>.from(data)..remove('chat_group_id');
        await _supabase.from('lobbies').insert(retry);
        return;
      }
      rethrow;
    }
  }

  bool _isUndefinedColumn42703(Object error) {
    if (error is PostgrestException && error.code == '42703') return true;
    final text = error.toString();
    return text.contains('42703') || text.contains('undefined_column');
  }

  // Helper to convert spotTimers list to map for Supabase
  Map<String, dynamic> _convertSpotTimersToMap(List<dynamic> spotTimers) {
    final map = <String, dynamic>{};
    for (var i = 0; i < spotTimers.length; i++) {
      if (spotTimers[i] != null) {
        map[i.toString()] = spotTimers[i];
      }
    }
    return map;
  }

  // Helper to convert map back to list for entity
  List<Map<String, dynamic>?> _convertSpotTimersToList(
      Map<String, dynamic>? timersMap, int maxSpots) {
    final list = List<Map<String, dynamic>?>.filled(maxSpots, null);
    if (timersMap != null) {
      timersMap.forEach((key, value) {
        final index = int.tryParse(key);
        if (index != null && index < maxSpots) {
          list[index] = value as Map<String, dynamic>?;
        }
      });
    }
    return list;
  }

  // Helper to convert from snake_case to camelCase for Lobby entity
  Map<String, dynamic> _toEntityJson(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'name': data['name'],
      'memberUids': data['member_uids'] ?? [],
      'gameName': data['game_focus'] ?? '',
      'maxSpots': data['max_spots'] ?? 8,
      'createdBy': data['created_by'] ?? '',
      'createdAt': data['created_at'],
      'spots': data['lobby_spots'] ?? [],
      'spotTimers': _convertSpotTimersToList(
        data['spot_timers'],
        data['max_spots'] ?? 8,
      ),
      'viewers': data['viewers'] ?? [],
      'statuses': data['statuses'] ?? {},
      'isActive': data['is_active'] ?? true,
      'description': data['description'],
      'settings': data['settings'],
      'chatGroupId':
          (data['chat_group_id'] ?? data['chatGroupId'])?.toString(),
    };
  }

  @override
  Future<Lobby?> getLobby(String lobbyId) async {
    final response = await _supabase
        .from('lobbies')
        .select()
        .eq('id', lobbyId)
        .maybeSingle();

    if (response == null) return null;
    return Lobby.fromJson(_toEntityJson(response));
  }

  @override
  Future<Lobby?> getLobbyByInviteCode(String inviteCode) async {
    final response = await _supabase
        .from('lobbies')
        .select()
        .eq('invite_code', inviteCode)
        .maybeSingle();

    if (response == null) return null;
    return Lobby.fromJson(_toEntityJson(response));
  }

  @override
  Future<List<Lobby>> getUserLobbies(String userId) async {
    // Note: Supabase doesn't have arrayContains, need to use contains operator
    // The @> operator checks if the left JSONB/array contains the right value
    final response = await _supabase
        .from('lobbies')
        .select()
        .contains('member_uids', [userId]);

    return (response as List<dynamic>)
        .map((data) => Lobby.fromJson(_toEntityJson(data)))
        .toList();
  }

  @override
  Future<void> updateLobby(Lobby lobby) async {
    final json = lobby.toJson();

    // Convert to snake_case for Supabase
    final data = {
      'name': json['name'],
      'member_uids': json['memberUids'],
      'game_focus': json['gameName'],
      'max_spots': json['maxSpots'],
      'created_by': json['createdBy'],
      'spot_timers': json['spotTimers'] != null
          ? _convertSpotTimersToMap(json['spotTimers'])
          : {},
      'viewers': json['viewers'],
      'statuses': json['statuses'],
      'is_active': json['isActive'],
      'description': json['description'],
      'settings': json['settings'],
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _supabase.from('lobbies').update(data).eq('id', lobby.id);
  }

  @override
  Future<void> deleteLobby(String lobbyId) async {
    await _supabase.from('lobbies').delete().eq('id', lobbyId);
  }

  @override
  Future<void> joinLobby(String lobbyId, String userId) async {
    // Fetch current squad
    final squadData = await _supabase
        .from('lobbies')
        .select('member_uids')
        .eq('id', lobbyId)
        .single();

    final memberUids = List<String>.from(squadData['member_uids'] ?? []);
    if (!memberUids.contains(userId)) {
      memberUids.add(userId);
    }

    await _supabase
        .from('lobbies')
        .update({'member_uids': memberUids}).eq('id', lobbyId);
  }

  @override
  Future<void> leaveLobby(String lobbyId, String userId) async {
    // Fetch current squad
    final squadData = await _supabase
        .from('lobbies')
        .select('member_uids')
        .eq('id', lobbyId)
        .single();

    final memberUids = List<String>.from(squadData['member_uids'] ?? []);
    memberUids.remove(userId);

    await _supabase
        .from('lobbies')
        .update({'member_uids': memberUids}).eq('id', lobbyId);
  }

  @override
  Future<void> kickMember(
      String lobbyId, String memberId, String kickedBy) async {
    // Remove from squad
    final squadData = await _supabase
        .from('lobbies')
        .select('member_uids')
        .eq('id', lobbyId)
        .single();

    final memberUids = List<String>.from(squadData['member_uids'] ?? []);
    memberUids.remove(memberId);

    await _supabase
        .from('lobbies')
        .update({'member_uids': memberUids}).eq('id', lobbyId);
  }

  @override
  Future<void> assignSpot(String lobbyId, int spotIndex, String? userId) async {
    // Fetch current squad
    final squadData = await _supabase
        .from('lobbies')
        .select('lobby_spots')
        .eq('id', lobbyId)
        .single();

    final spots = List<String?>.from(squadData['lobby_spots'] ?? []);

    // Ensure the spots array is large enough
    while (spots.length <= spotIndex) {
      spots.add(null);
    }
    spots[spotIndex] = userId;

    await _supabase
        .from('lobbies')
        .update({'lobby_spots': spots}).eq('id', lobbyId);
  }

  @override
  Future<void> startSpotTimer(
      String lobbyId, int spotIndex, Duration duration) async {
    // Fetch current squad timers
    final squadData = await _supabase
        .from('lobbies')
        .select('spot_timers')
        .eq('id', lobbyId)
        .single();

    final spotTimers =
        Map<String, dynamic>.from(squadData['spot_timers'] ?? {});

    spotTimers[spotIndex.toString()] = {
      'start_time': DateTime.now().toIso8601String(),
      'duration': duration.inSeconds,
      'spot_index': spotIndex,
    };

    await _supabase
        .from('lobbies')
        .update({'spot_timers': spotTimers}).eq('id', lobbyId);

    // Note: Server-side timer processing would be implemented with Supabase Edge Functions
  }

  @override
  Future<void> cancelSpotTimer(String lobbyId, int spotIndex) async {
    // Fetch current squad timers
    final squadData = await _supabase
        .from('lobbies')
        .select('spot_timers')
        .eq('id', lobbyId)
        .single();

    final spotTimers =
        Map<String, dynamic>.from(squadData['spot_timers'] ?? {});
    spotTimers.remove(spotIndex.toString());

    await _supabase
        .from('lobbies')
        .update({'spot_timers': spotTimers}).eq('id', lobbyId);
  }

  @override
  Future<void> updateMemberStatus(
      String lobbyId, String userId, String status) async {
    // Fetch current statuses
    final lobbyData = await _supabase
        .from('lobbies')
        .select('statuses')
        .eq('id', lobbyId)
        .single();

    final statuses = Map<String, dynamic>.from(lobbyData['statuses'] ?? {});
    statuses[userId] = status;

    await _supabase.from('lobbies').update({
      'statuses': statuses,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', lobbyId);
  }

  @override
  Future<void> updateLastActivity(String lobbyId) async {
    await _supabase.from('lobbies').update({
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', lobbyId);
  }

  @override
  Future<void> processExpiredTimers() async {
    // Server assigns via process_expired_timers. Client display only.
    // RPC / edge sketch may be unapplied (Spencer YES). Never throw.
    try {
      await _supabase.rpc('process_expired_timers');
      return;
    } catch (e) {
      debugPrint('process_expired_timers RPC unavailable: $e');
    }
    try {
      await _supabase.functions.invoke('process-timers');
    } catch (e) {
      debugPrint('process-timers edge sketch unavailable: $e');
    }
  }

  @override
  Stream<Lobby> getLobbyStream(String lobbyId) {
    return _supabase
        .from('lobbies')
        .stream(primaryKey: ['id'])
        .eq('id', lobbyId)
        .handleError((error) {
          // Handle RealtimeSubscribeException gracefully
          if (error is RealtimeSubscribeException) {
            debugPrint(
                '❌ getLobbyStream RealtimeSubscribeException: ${error.status}');
            if (error.status == RealtimeSubscribeStatus.channelError ||
                error.status == RealtimeSubscribeStatus.timedOut) {
              debugPrint('❌ Channel error/timeout - triggering cleanup');
              // Async cleanup without blocking stream
              SupabaseService.cleanupOldChannels();
            }
          }
          // Re-throw to allow listener to handle
          throw error;
        })
        .map((data) {
          if (data.isEmpty) throw Exception('Lobby not found');
          return Lobby.fromJson(_toEntityJson(data.first));
        });
  }

  @override
  Stream<List<Lobby>> getUserLobbiesStream(String userId) {
    // Note: Supabase real-time streams don't support array contains filters
    // We need to filter on the Dart side
    return _supabase.from('lobbies').stream(primaryKey: ['id']).map((dataList) {
      return dataList
          .where((data) {
            final memberUids = List<String>.from(data['member_uids'] ?? []);
            return memberUids.contains(userId);
          })
          .map((data) => Lobby.fromJson(_toEntityJson(data)))
          .toList();
    });
  }

  @override
  Stream<List<Lobby>> getPublicLobbiesStream({
    bool? isActive,
    String? gameFocus,
    int limit = 50,
    String orderBy = 'created_at',
    bool ascending = false,
  }) {
    var query = _supabase
        .from('lobbies')
        .stream(primaryKey: ['id'])
        .eq('is_public', true)
        .order(orderBy, ascending: ascending)
        .limit(limit);

    // Add timeout and error handling with retry logic
    return query.timeout(
      const Duration(seconds: 15),
      onTimeout: (sink) {
        debugPrint('⚠️ Public lobbies stream timeout - returning empty list');
        sink.add([]); // Emit empty list on timeout
      },
    ).handleError((error, stackTrace) {
      debugPrint('⚠️ Public lobbies stream error: $error');

      // Handle specific error types gracefully
      if (error.toString().contains('HandshakeException') ||
          error.toString().contains('SocketException') ||
          error.toString().contains('RealtimeSubscribeException')) {
        debugPrint('⚠️ Connection issue detected, returning empty stream');
        return <List<dynamic>>[];
      }

      // Re-throw other errors
      throw error;
    }).map((dataList) {
      var filteredData = dataList;

      // Apply isActive filter if specified
      if (isActive != null) {
        filteredData = filteredData
            .where((data) => (data['is_active'] as bool? ?? true) == isActive)
            .toList();
      }

      // Apply gameFocus filter if specified
      if (gameFocus != null) {
        filteredData = filteredData
            .where((data) => data['game_focus'] == gameFocus)
            .toList();
      }

      return filteredData
          .map((data) => Lobby.fromJson(_toEntityJson(data)))
          .toList();
    });
  }

  @override
  Future<void> trackLobbyEvent(String event, Map<String, dynamic> data) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    // TODO: Create analytics table in Supabase or use external analytics service
    // await _supabase.from('analytics').insert({
    //   'user_id': userId,
    //   'event': event,
    //   'data': data,
    //   'timestamp': DateTime.now().toIso8601String(),
    // });
    throw UnimplementedError('analytics table does not exist in schema');
  }

  @override
  Future<void> createInvite(Map<String, dynamic> inviteData) async {
    validateJwt();
    final authenticatedUserId = getAuthenticatedUserId();

    // Ensure creator matches authenticated user
    if (inviteData['created_by'] != authenticatedUserId) {
      throw UnauthorizedException('Cannot create invite for another user');
    }

    try {
      await _supabase.from('invites').upsert(inviteData);
    } catch (e) {
      throw Exception('Failed to create invite: $e');
    }
  }

  @override
  Future<void> createPeacock(Map<String, dynamic> peacockData) async {
    validateJwt();
    final authenticatedUserId = getAuthenticatedUserId();

    // Ensure user_id matches authenticated user
    if (peacockData['user_id'] != authenticatedUserId) {
      throw UnauthorizedException(
          'Cannot create peacock entry for another user');
    }

    try {
      await _supabase.from('peacocks').insert(peacockData);
    } catch (e) {
      throw Exception('Failed to create peacock entry: $e');
    }
  }

  @override
  Future<void> updateUserPeacock(
      String userId, Map<String, dynamic> peacockStatus) async {
    validateJwt();
    final authenticatedUserId = getAuthenticatedUserId();

    // Ensure userId matches authenticated user
    if (userId != authenticatedUserId) {
      throw UnauthorizedException(
          'Cannot update peacock status for another user');
    }

    try {
      await _supabase
          .from('users')
          .update({'peacock': peacockStatus}).eq('uid', userId);
    } catch (e) {
      throw Exception('Failed to update user peacock status: $e');
    }
  }

  @override
  Future<void> recordMatchResult({
    required String lobbyId,
    required String gameName,
    required String result,
    required List<String> playerUids,
    required String createdBy,
    String? notes,
  }) async {
    final authenticatedUserId = _supabase.auth.currentUser?.id;
    if (authenticatedUserId == null) {
      throw UnauthorizedException('Authentication required');
    }
    if (createdBy != authenticatedUserId) {
      throw UnauthorizedException('Cannot record match for another user');
    }

    try {
      final existing = await findRecentMatchHistory(
        lobbyId: lobbyId,
        createdBy: createdBy,
      );
      final write = planMatchHistoryWrite(
        lobbyId: lobbyId,
        gameName: gameName,
        result: result,
        playerUids: playerUids,
        createdBy: createdBy,
        notes: notes,
        existingRow: existing,
      );
      await applyMatchHistoryWrite(_historyClient, write);
    } catch (e) {
      if (e is UnauthorizedException) rethrow;
      throw Exception('Failed to record match result: $e');
    }
  }

  /// Latest `match_history` row for this lobby + creator inside the
  /// 10-minute UPDATE window. Null when none — caller inserts.
  Future<Map<String, dynamic>?> findRecentMatchHistory({
    required String lobbyId,
    required String createdBy,
    DateTime? now,
  }) {
    return findRecentMatchHistoryOn(
      _historyClient,
      lobbyId: lobbyId,
      createdBy: createdBy,
      now: now,
    );
  }

  @override
  Future<Map<String, dynamic>> getLobbyStats(String lobbyId) async {
    validateJwt();

    try {
      final response = await _supabase
          .rpc('get_lobby_stats', params: {'p_lobby_id': lobbyId});
      debugPrint(
        'StatsDashboard: KEY rpc get_lobby_stats lobby=$lobbyId '
        'type=${response.runtimeType} value=$response',
      );

      final coerced = coerceLobbyStatsResponse(response);
      if (coerced.isNotEmpty) return coerced;

      if (response == null || (response is List && response.isEmpty)) {
        return {
          'total_matches': 0,
          'wins': 0,
          'losses': 0,
          'draws': 0,
          'win_rate': 0.0,
        };
      }

      throw Exception(
        'Unexpected get_lobby_stats shape (${response.runtimeType}): $response',
      );
    } catch (e) {
      throw Exception('Failed to fetch lobby stats: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMatchHistory(String lobbyId) async {
    validateJwt();

    try {
      final response = await _supabase
          .from('match_history')
          .select()
          .eq('lobby_id', lobbyId)
          .order('created_at', ascending: false)
          .limit(100);

      final rows = [
        for (final row in response) Map<String, dynamic>.from(row as Map),
      ];
      debugPrint(
        'StatsDashboard: KEY rpc match_history lobby=$lobbyId rows=${rows.length}',
      );
      return rows;
    } catch (e) {
      throw Exception('Failed to fetch match history: $e');
    }
  }
}

/// First row from a Postgrest select (list or single map). Null if empty.
Map<String, dynamic>? firstMatchHistoryRow(dynamic response) {
  if (response is List) {
    if (response.isEmpty) return null;
    final first = response.first;
    if (first is Map) return Map<String, dynamic>.from(first);
    return null;
  }
  if (response is Map) return Map<String, dynamic>.from(response);
  return null;
}

/// Insert or update `match_history` from a planned write.
///
/// [client] is [SupabaseClient] in production. Tests pass a recording fake;
/// the chain is invoked dynamically so unit harnesses do not need the
/// Postgrest fluent types.
Future<void> applyMatchHistoryWrite(
  dynamic client,
  SessionRatingWrite write,
) async {
  if (write.isUpdate) {
    await client
        .from(kMatchHistoryTable)
        .update(write.payload)
        .eq('id', write.matchId);
    return;
  }
  await client.from(kMatchHistoryTable).insert(write.payload);
}

/// Latest in-window `match_history` row for [lobbyId] + [createdBy].
Future<Map<String, dynamic>?> findRecentMatchHistoryOn(
  dynamic client, {
  required String lobbyId,
  required String createdBy,
  DateTime? now,
}) async {
  final cutoff = (now ?? DateTime.now())
      .toUtc()
      .subtract(kMatchHistoryUpdateWindow)
      .toIso8601String();
  final response = await client
      .from(kMatchHistoryTable)
      .select()
      .eq('lobby_id', lobbyId)
      .eq('created_by', createdBy)
      .gte('created_at', cutoff)
      .order('created_at', ascending: false)
      .limit(1);
  return firstMatchHistoryRow(response);
}
