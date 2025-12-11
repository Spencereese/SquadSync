import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/lobby.dart';

final currentLobbyIdProvider = StateProvider<String?>((ref) => null);

final currentLobbyProvider =
    AsyncNotifierProvider<CurrentLobbyNotifier, Lobby?>(
        () => CurrentLobbyNotifier());

/// CurrentLobbyNotifier - Realtime Lobby Tracking
/// Tracks active lobby with Supabase Realtime subscriptions
/// Monitors lobby changes: spots, timers, statuses, member updates
class CurrentLobbyNotifier extends AsyncNotifier<Lobby?> {
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

  /// Convert Supabase lobby data to Lobby model
  Lobby _lobbyFromSupabase(Map<String, dynamic> data) {
    return Lobby(
      id: data['id'] as String,
      name: data['name'] as String? ?? 'Unnamed Lobby',
      memberUids: (data['member_uids'] as List<dynamic>?)?.cast<String>() ?? [],
      gameName: data['game_focus'] as String,
      maxSpots: data['max_spots'] as int,
      createdBy: data['creator_uid'] as String? ?? '',
      createdAt: _parseTimestamp(data['created_at']) ?? DateTime.now(),
      spots: (data['spots'] as List<dynamic>?)?.cast<String?>() ??
          List.filled(data['max_spots'] as int? ?? 8, null),
      spotTimers: (data['spot_timers'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>?)
              .toList() ??
          List.filled(data['max_spots'] as int? ?? 8, null),
      viewers: (data['viewers'] as List<dynamic>?)?.cast<String>() ?? [],
      statuses: Map<String, String>.from(
          data['statuses'] as Map<String, dynamic>? ?? {}),
      isActive: data['is_active'] as bool? ?? true,
      description: data['description'] as String?,
      settings: data['settings'] as Map<String, dynamic>?,
    );
  }

  @override
  FutureOr<Lobby?> build() async {
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
          await _supabase.from('lobbies').select().eq('id', lobbyId).single();

      final lobby = _lobbyFromSupabase(response);
      state = AsyncData(lobby);

      // Listen to realtime changes for this lobby
      _subscription = _supabase
          .from('lobbies')
          .stream(primaryKey: ['id'])
          .eq('id', lobbyId)
          .listen((data) {
            if (data.isEmpty) {
              state = const AsyncData(null);
              return;
            }
            final updatedLobby = _lobbyFromSupabase(data.first);
            state = AsyncData(updatedLobby);
          });

      return lobby;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<void> claimSpot(int spotIndex) async {
    final lobby = state.value;
    if (lobby == null) return;

    final uid = AuthServiceSupabase().currentUser!.id;
    final currentClaim =
        spotIndex < lobby.spots.length ? lobby.spots[spotIndex] : null;

    // Can only claim if spot is null or already claimed by this user
    if (currentClaim != null && currentClaim != uid) return;

    // Check if within maxSpots
    if (spotIndex >= lobby.maxSpots) return;

    // Update spots
    final updatedSpots = List<String?>.from(lobby.spots);
    // Ensure list is large enough
    while (updatedSpots.length <= spotIndex) {
      updatedSpots.add(null);
    }
    updatedSpots[spotIndex] = uid;

    await _supabase.from('lobbies').update({
      'spots': updatedSpots,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', lobby.id);
  }

  Future<void> unclaimSpot(int spotIndex) async {
    final lobby = state.value;
    if (lobby == null) return;

    final uid = AuthServiceSupabase().currentUser!.id;
    final currentClaim =
        spotIndex < lobby.spots.length ? lobby.spots[spotIndex] : null;

    // Can only unclaim own spot
    if (currentClaim != uid) return;

    final updatedSpots = List<String?>.from(lobby.spots);
    updatedSpots[spotIndex] = null;

    await _supabase.from('lobbies').update({
      'spots': updatedSpots,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', lobby.id);
  }

  Future<void> updateStatus(String status) async {
    final lobby = state.value;
    if (lobby == null) return;

    final uid = AuthServiceSupabase().currentUser!.id;

    final updatedStatuses = Map<String, String>.from(lobby.statuses);
    updatedStatuses[uid] = status;

    await _supabase.from('lobbies').update({
      'statuses': updatedStatuses,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', lobby.id);
  }

  Future<void> updateLastActivity() async {
    final lobby = state.value;
    if (lobby == null) return;

    await _supabase.from('lobbies').update({
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', lobby.id);
  }

  Future<void> leaveLobby() async {
    final lobby = state.value;
    if (lobby == null) return;

    final uid = AuthServiceSupabase().currentUser!.id;

    // Remove from memberUids
    final updatedMembers =
        lobby.memberUids.where((member) => member != uid).toList();

    // Clear spots claimed by this user
    final updatedSpots = List<String?>.from(lobby.spots);
    for (int i = 0; i < updatedSpots.length; i++) {
      if (updatedSpots[i] == uid) {
        updatedSpots[i] = null;
      }
    }

    // Clear status
    final updatedStatuses = Map<String, String>.from(lobby.statuses);
    updatedStatuses.remove(uid);

    await _supabase.from('lobbies').update({
      'member_uids': updatedMembers,
      'spots': updatedSpots,
      'statuses': updatedStatuses,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', lobby.id);

    // Clear current lobby
    ref.read(currentLobbyIdProvider.notifier).state = null;
  }
}
