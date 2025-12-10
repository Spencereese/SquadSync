import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/public_squad.dart';

final currentLobbyIdProvider = StateProvider<String?>((ref) => null);

final currentLobbyProvider =
    AsyncNotifierProvider<CurrentLobbyNotifier, PublicSquad?>(
        () => CurrentLobbyNotifier());

/// CurrentSquadNotifier - Supabase Migration
/// Replaces Firebase Firestore with Supabase PostgreSQL + Realtime
/// Uses PublicSquad model for public squad discovery features
class CurrentLobbyNotifier extends AsyncNotifier<PublicSquad?> {
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  final SupabaseClient _supabase = SupabaseService.client;

  /// Safely parse timestamp from Supabase data (handles ISO8601 strings)
  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    if (value is DateTime) return value;
    return null;
  }

  /// Convert Supabase squad data to PublicSquad model
  PublicSquad _squadFromSupabase(Map<String, dynamic> data) {
    // Parse peacock timers
    final peacockTimersData =
        data['peacock_timers'] as Map<String, dynamic>? ?? {};
    final peacockTimers = peacockTimersData.map((key, value) {
      final timerData = value as Map<String, dynamic>? ?? {};
      final endTime = _parseTimestamp(timerData['endTime']) ?? DateTime.now();
      final isActive = timerData['isActive'] as bool? ?? false;

      return MapEntry(
        key,
        PeacockTimer(
          endTime: endTime,
          isActive: isActive,
        ),
      );
    });

    return PublicSquad(
      id: data['id'] as String,
      name: data['name'] as String? ?? 'Unnamed Squad',
      primaryGameId: data['primary_game_id'] as String?,
      primaryGameName: data['primary_game_name'] as String?,
      maxSpots: data['max_spots'] as int?,
      creatorUid: data['creator_uid'] as String? ?? '',
      createdAt: _parseTimestamp(data['created_at']) ?? DateTime.now(),
      isPublic: data['is_public'] as bool? ?? false,
      inviteCode: data['invite_code'] as String?,
      memberUids: (data['member_uids'] as List<dynamic>?)?.cast<String>() ?? [],
      lastActivity: _parseTimestamp(data['last_activity']) ?? DateTime.now(),
      spotClaims: Map<String, String?>.from(
          data['spot_claims'] as Map<String, dynamic>? ?? {}),
      peacockTimers: peacockTimers,
      userStatuses: Map<String, String>.from(
          data['user_statuses'] as Map<String, dynamic>? ?? {}),
      tags: (data['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      lookingForMore: data['looking_for_more'] as bool? ?? false,
      description: data['description'] as String? ?? '',
      bumpTimestamp: data['bump_timestamp'] != null
          ? _parseTimestamp(data['bump_timestamp'])
          : null,
    );
  }

  @override
  FutureOr<PublicSquad?> build() async {
    final lobbyId = ref.watch(currentLobbyIdProvider);
    _subscription?.cancel();
    _subscription = null;

    if (lobbyId == null) {
      return null;
    }

    ref.onDispose(() {
      _subscription?.cancel();
    });

    try {
      // Set loading state
      state = const AsyncLoading();

      // Fetch initial data
      final response =
          await _supabase.from('squads').select().eq('id', lobbyId).single();

      final squad = _squadFromSupabase(response);
      state = AsyncData(squad);

      // Listen to realtime changes
      _subscription = _supabase
          .from('squads')
          .stream(primaryKey: ['id'])
          .eq('id', lobbyId)
          .listen((data) {
            if (data.isEmpty) {
              state = const AsyncData(null);
              return;
            }
            final updatedSquad = _squadFromSupabase(data.first);
            state = AsyncData(updatedSquad);
          });

      return squad;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<void> claimSpot(String spotNumber) async {
    final squad = state.value;
    if (squad == null) return;

    final uid = AuthServiceSupabase().currentUser!.id;
    final currentClaim = squad.spotClaims[spotNumber];

    // Can only claim if spot is null or already claimed by this user
    if (currentClaim != null && currentClaim != uid) return;

    // Check if within maxSpots
    if (squad.maxSpots != null &&
        (int.tryParse(spotNumber) == null ||
            int.parse(spotNumber) > squad.maxSpots!)) {
      return;
    }

    // Update spot claims
    final updatedSpotClaims = Map<String, String?>.from(squad.spotClaims);
    updatedSpotClaims[spotNumber] = uid;

    await _supabase.from('squads').update({
      'spot_claims': updatedSpotClaims,
      'last_activity': DateTime.now().toIso8601String(),
    }).eq('id', squad.id);

    // Bump squad if it's public
    await _bumpSquadIfPublic();
  }

  Future<void> unclaimSpot(String spotNumber) async {
    final squad = state.value;
    if (squad == null) return;

    final uid = AuthServiceSupabase().currentUser!.id;
    final currentClaim = squad.spotClaims[spotNumber];

    // Can only unclaim own spot
    if (currentClaim != uid) return;

    final updatedSpotClaims = Map<String, String?>.from(squad.spotClaims);
    updatedSpotClaims[spotNumber] = null;

    await _supabase.from('squads').update({
      'spot_claims': updatedSpotClaims,
      'last_activity': DateTime.now().toIso8601String(),
    }).eq('id', squad.id);
  }

  Future<void> startPeacockTimer(String uid, Duration duration) async {
    final squad = state.value;
    if (squad == null) return;

    final endTime = DateTime.now().add(duration);
    final timerData = {
      'endTime': endTime.toIso8601String(),
      'isActive': true,
    };

    final updatedTimers = Map<String, dynamic>.from(squad.peacockTimers.map(
      (key, value) => MapEntry(key, {
        'endTime': value.endTime.toIso8601String(),
        'isActive': value.isActive,
      }),
    ));
    updatedTimers[uid] = timerData;

    await _supabase.from('squads').update({
      'peacock_timers': updatedTimers,
      'last_activity': DateTime.now().toIso8601String(),
    }).eq('id', squad.id);
  }

  Future<void> cancelPeacockTimer(String uid) async {
    final squad = state.value;
    if (squad == null) return;

    final updatedTimers = Map<String, dynamic>.from(squad.peacockTimers.map(
      (key, value) => MapEntry(key, {
        'endTime': value.endTime.toIso8601String(),
        'isActive': value.isActive,
      }),
    ));
    updatedTimers.remove(uid);

    await _supabase.from('squads').update({
      'peacock_timers': updatedTimers,
      'last_activity': DateTime.now().toIso8601String(),
    }).eq('id', squad.id);
  }

  Future<void> setStatus(String uid, String status) async {
    final squad = state.value;
    if (squad == null) return;

    final updatedStatuses = Map<String, String>.from(squad.userStatuses);
    updatedStatuses[uid] = status;

    await _supabase.from('squads').update({
      'user_statuses': updatedStatuses,
      'last_activity': DateTime.now().toIso8601String(),
    }).eq('id', squad.id);
  }

  Future<void> updateLastActivity() async {
    final squad = state.value;
    if (squad == null) return;

    await _supabase.from('squads').update({
      'last_activity': DateTime.now().toIso8601String(),
    }).eq('id', squad.id);
  }

  Future<void> updatePrimaryGame({
    required String? gameId,
    required String? gameName,
    required int? maxSpots,
  }) async {
    final lobbyId = ref.read(currentLobbyIdProvider);
    if (lobbyId == null) return;

    await _supabase.from('squads').update({
      'primary_game_id': gameId,
      'primary_game_name': gameName,
      'max_spots': maxSpots,
    }).eq('id', lobbyId);
  }

  Future<void> bumpSquad() async {
    final lobbyId = state.valueOrNull?.id;
    if (lobbyId == null) return;

    final squadData = await _supabase
        .from('squads')
        .select('bump_timestamp')
        .eq('id', lobbyId)
        .single();

    final lastBump = _parseTimestamp(squadData['bump_timestamp']);

    if (lastBump != null &&
        DateTime.now().difference(lastBump) < const Duration(hours: 1)) {
      throw Exception("Can only bump once per hour");
    }

    await _supabase.from('squads').update({
      'bump_timestamp': DateTime.now().toIso8601String(),
    }).eq('id', lobbyId);
  }

  Future<void> _bumpSquadIfPublic() async {
    final squad = state.value;
    if (squad == null || !squad.isPublic) return;

    try {
      final squadData = await _supabase
          .from('squads')
          .select('bump_timestamp')
          .eq('id', squad.id)
          .single();

      final lastBump = _parseTimestamp(squadData['bump_timestamp']);

      // 5-minute cooldown for activity-based bumping
      if (lastBump != null &&
          DateTime.now().difference(lastBump) < const Duration(minutes: 5)) {
        return; // Too soon, skip bump
      }

      await _supabase.from('squads').update({
        'bump_timestamp': DateTime.now().toIso8601String(),
      }).eq('id', squad.id);
    } catch (e) {
      // Ignore bump errors to not interrupt main flow
    }
  }

  Future<void> leaveSquad() async {
    final squad = state.value;
    if (squad == null) return;

    final uid = AuthServiceSupabase().currentUser!.id;

    // Remove from memberUids
    final updatedMembers =
        squad.memberUids.where((member) => member != uid).toList();

    // Clear spots claimed by this user
    final updatedSpotClaims = Map<String, String?>.from(squad.spotClaims);
    updatedSpotClaims.removeWhere((spot, claimUid) => claimUid == uid);

    // Clear peacock timer
    final updatedTimers = Map<String, dynamic>.from(squad.peacockTimers.map(
      (key, value) => MapEntry(key, {
        'endTime': value.endTime.toIso8601String(),
        'isActive': value.isActive,
      }),
    ));
    updatedTimers.remove(uid);

    // Clear status
    final updatedStatuses = Map<String, String>.from(squad.userStatuses);
    updatedStatuses.remove(uid);

    await _supabase.from('squads').update({
      'member_uids': updatedMembers,
      'spot_claims': updatedSpotClaims,
      'peacock_timers': updatedTimers,
      'user_statuses': updatedStatuses,
      'last_activity': DateTime.now().toIso8601String(),
    }).eq('id', squad.id);

    // Clear current squad
    ref.read(currentLobbyIdProvider.notifier).state = null;
  }
}
