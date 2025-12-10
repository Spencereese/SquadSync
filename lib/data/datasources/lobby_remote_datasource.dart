import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/services/supabase_service.dart';
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

  // Timer processing (calls Cloud Functions)
  Future<void> processExpiredTimers();

  // Real-time streams
  Stream<Lobby> getLobbyStream(String lobbyId);
  Stream<List<Lobby>> getUserLobbiesStream(String userId);

  // Analytics
  Future<void> trackLobbyEvent(String event, Map<String, dynamic> data);
}

class LobbyRemoteDataSourceImpl implements LobbyRemoteDataSource {
  final AuthServiceSupabase _authService = AuthServiceSupabase();
  final SupabaseClient _supabase = SupabaseService.client;

  @override
  Future<Lobby> createLobby(Lobby lobby) async {
    final json = squad.toJson();

    // Convert to snake_case for Supabase
    final data = {
      'id': json['id'],
      'name': json['name'],
      'member_uids': json['memberUids'],
      'game_name': json['gameName'],
      'max_spots': json['maxSpots'],
      'created_by': json['createdBy'],
      'created_at': json['createdAt'],
      'squad_spots': json['spots'],
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
    return squad;
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

  // Helper to convert from snake_case to camelCase for Squad entity
  Map<String, dynamic> _toEntityJson(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'name': data['name'],
      'memberUids': data['member_uids'] ?? [],
      'gameName': data['game_name'] ?? '',
      'maxSpots': data['max_spots'] ?? 8,
      'createdBy': data['created_by'] ?? '',
      'createdAt': data['created_at'],
      'spots': data['squad_spots'] ?? [],
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
    final response =
        await _supabase.from('lobbies').select().eq('id', lobbyId).maybeSingle();

    if (response == null) return null;
    return Squad.fromJson(_toEntityJson(response));
  }

  @override
  Future<Lobby?> getLobbyByInviteCode(String inviteCode) async {
    final response = await _supabase
        .from('lobbies')
        .select()
        .eq('invite_code', inviteCode)
        .maybeSingle();

    if (response == null) return null;
    return Squad.fromJson(_toEntityJson(response));
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
        .map((data) => Squad.fromJson(_toEntityJson(data)))
        .toList();
  }

  @override
  Future<void> updateLobby(Lobby lobby) async {
    final json = squad.toJson();

    // Convert to snake_case for Supabase
    final data = {
      'name': json['name'],
      'member_uids': json['memberUids'],
      'game_name': json['gameName'],
      'max_spots': json['maxSpots'],
      'created_by': json['createdBy'],
      'squad_spots': json['spots'],
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

    await _supabase.from('lobbies').update(data).eq('id', squad.id);
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

    // Log the kick event
    await _supabase.from('squad_events').insert({
      'squad_id': lobbyId,
      'type': 'member_kicked',
      'member_id': memberId,
      'kicked_by': kickedBy,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> assignSpot(String lobbyId, int spotIndex, String? userId) async {
    // Fetch current squad
    final squadData = await _supabase
        .from('lobbies')
        .select('squad_spots')
        .eq('id', lobbyId)
        .single();

    final spots = List<String?>.from(squadData['squad_spots'] ?? []);

    // Ensure the spots array is large enough
    while (spots.length <= spotIndex) {
      spots.add(null);
    }
    spots[spotIndex] = userId;

    await _supabase
        .from('lobbies')
        .update({'squad_spots': spots}).eq('id', lobbyId);
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
          if (data.isEmpty) throw Exception('Squad not found');
          return Squad.fromJson(_toEntityJson(data.first));
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
          .map((data) => Squad.fromJson(_toEntityJson(data)))
          .toList();
    });
  }

  @override
  Future<void> trackLobbyEvent(String event, Map<String, dynamic> data) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    await _supabase.from('analytics').insert({
      'user_id': userId,
      'event': event,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
