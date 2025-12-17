import 'package:squad_sync/domain/entities/lobby.dart';
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
}

class LobbyRemoteDataSourceImpl
    with JwtValidationMixin
    implements LobbyRemoteDataSource {
  final AuthServiceSupabase _authService = AuthServiceSupabase();
  final SupabaseClient _supabase = SupabaseService.client;

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
    final data = {
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

    await _supabase.from('lobbies').insert(data);
    return lobby;
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
    // This would call a Supabase Edge Function to process expired timers server-side
    // For now, we'll handle this locally in the repository implementation
    // TODO: Implement Edge Function for timer processing
  }

  @override
  Stream<Lobby> getLobbyStream(String lobbyId) {
    return _supabase
        .from('lobbies')
        .stream(primaryKey: ['id'])
        .eq('id', lobbyId)
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

    return query.map((dataList) {
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
    validateJwt();
    final authenticatedUserId = getAuthenticatedUserId();

    // Ensure createdBy matches authenticated user
    if (createdBy != authenticatedUserId) {
      throw UnauthorizedException('Cannot record match for another user');
    }

    try {
      await _supabase.from('match_history').insert({
        'lobby_id': lobbyId,
        'game_name': gameName,
        'result': result,
        'player_uids': playerUids,
        'created_by': createdBy,
        'notes': notes,
      });
    } catch (e) {
      throw Exception('Failed to record match result: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getLobbyStats(String lobbyId) async {
    validateJwt();

    try {
      final response = await _supabase
          .rpc('get_lobby_stats', params: {'p_lobby_id': lobbyId});

      if (response is List && response.isNotEmpty) {
        return response.first as Map<String, dynamic>;
      }

      return {
        'total_matches': 0,
        'wins': 0,
        'losses': 0,
        'draws': 0,
        'win_rate': 0.0,
      };
    } catch (e) {
      throw Exception('Failed to fetch lobby stats: $e');
    }
  }
}
