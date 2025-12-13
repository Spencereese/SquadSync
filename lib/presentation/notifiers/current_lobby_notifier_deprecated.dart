// ============================================================================
// DEPRECATED: This file has been merged into lobby_notifier.dart
// Date: December 12, 2024
//
// CurrentLobbyNotifier functionality is now part of the unified LobbyNotifier
// which combines:
// - Spots, timers, and peacock queue (from lobby_notifier.dart)
// - Current lobby tracking (from current_lobby_notifier.dart - THIS FILE)
// - User lobby memberships (from user_squads concept)
//
// Migration:
// - Use lobbyNotifierProvider instead of currentLobbyProvider
// - Access current lobby via: ref.watch(lobbyNotifierProvider).value?.currentLobby
// - Use compatibility providers: currentLobbyProvider and currentLobbyIdProvider
//   (defined in lobby_notifier.dart)
//
// This file is kept for reference only. Remove after confirming all migrations.
// ============================================================================

import 'dart:async';

import '../../services/auth_service_supabase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/lobby.dart';
import '../../domain/repositories/lobby_repository.dart';
import '../../core/injection.dart';

final currentLobbyIdProvider = StateProvider<String?>((ref) => null);

final currentLobbyProvider =
    AsyncNotifierProvider<CurrentLobbyNotifier, Lobby?>(
        () => CurrentLobbyNotifier());

/// CurrentLobbyNotifier - Realtime Lobby Tracking
/// Tracks active lobby with repository real-time streams
/// Monitors lobby changes: spots, timers, statuses, member updates
class CurrentLobbyNotifier extends AsyncNotifier<Lobby?> {
  StreamSubscription<Lobby?>? _subscription;
  late final LobbyRepository _repository;

  @override
  FutureOr<Lobby?> build() async {
    _repository = ref.read(lobbyRepositoryProvider);
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
      final lobby = await _repository.getLobby(lobbyId);
      state = AsyncData(lobby);

      // Listen to realtime changes for this lobby
      _subscription = _repository.getLobbyStream(lobbyId).listen(
        (updatedLobby) {
          state = AsyncData(updatedLobby);
        },
        onError: (error, stackTrace) {
          state = AsyncError(error, stackTrace);
        },
      );

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

    // Use repository to assign spot
    await _repository.assignSpot(lobby.id, spotIndex, uid);
  }

  Future<void> unclaimSpot(int spotIndex) async {
    final lobby = state.value;
    if (lobby == null) return;

    final uid = AuthServiceSupabase().currentUser!.id;
    final currentClaim =
        spotIndex < lobby.spots.length ? lobby.spots[spotIndex] : null;

    // Can only unclaim own spot
    if (currentClaim != uid) return;

    // Use repository to clear spot
    await _repository.assignSpot(lobby.id, spotIndex, null);
  }

  Future<void> updateStatus(String status) async {
    final lobby = state.value;
    if (lobby == null) return;

    final uid = AuthServiceSupabase().currentUser!.id;

    // Use repository to update member status
    await _repository.updateMemberStatus(lobby.id, uid, status);
  }

  Future<void> updateLastActivity() async {
    final lobby = state.value;
    if (lobby == null) return;

    // Use repository to update last activity timestamp
    // Note: This will be implemented once LobbyRepository has updateLastActivity method
    await _repository.trackLobbyEvent('activity_update', {
      'lobbyId': lobby.id,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> leaveLobby() async {
    final lobby = state.value;
    if (lobby == null) return;

    final uid = AuthServiceSupabase().currentUser!.id;

    // Use repository to leave lobby
    await _repository.leaveLobby(lobby.id, uid);

    // Clear current lobby
    ref.read(currentLobbyIdProvider.notifier).state = null;
  }
}
