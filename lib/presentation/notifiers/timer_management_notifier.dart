import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:squad_sync/domain/repositories/lobby_repository.dart';
import 'package:squad_sync/core/injection.dart';

import '../../services/peacock_assignment_machine.dart';
import '../../services/timer_service.dart';

part 'timer_management_notifier.freezed.dart';

/// State for timer management
@freezed
class TimerManagementState with _$TimerManagementState {
  const factory TimerManagementState({
    required Map<String, Duration> spotTimerStates,
    required Map<String, Duration> peacockTimerStates,
    required Map<String, List<Map<String, dynamic>?>> gameSpotTimers,
    required Map<String, Map<String, dynamic>?> peacockTimers,
    required bool isProcessing,
  }) = _TimerManagementState;

  factory TimerManagementState.initial() => const TimerManagementState(
        spotTimerStates: {},
        peacockTimerStates: {},
        gameSpotTimers: {},
        peacockTimers: {},
        isProcessing: false,
      );
}

/// Manages spot timers and peacock timers for lobbies
/// Handles timer orchestration, persistence, and expiration processing
class TimerManagementNotifier
    extends AutoDisposeAsyncNotifier<TimerManagementState> {
  late final LobbyRepository _repository;
  late final TimerServiceNotifier _timerService;

  StreamSubscription? _spotTimerSubscription;
  StreamSubscription? _peacockTimerSubscription;

  @override
  Future<TimerManagementState> build() async {
    try {
      _repository = ref.read(lobbyRepositoryProvider);
      _timerService = ref.watch(timerServiceProvider.notifier);

      ref.onDispose(() {
        _spotTimerSubscription?.cancel();
        _peacockTimerSubscription?.cancel();
      });

      return TimerManagementState.initial();
    } catch (e) {
      debugPrint('Error initializing TimerManagementNotifier: $e');
      return TimerManagementState.initial();
    }
  }

  /// Subscribe to real-time timer state updates for a lobby
  void subscribeToLobbyTimers(String lobbyId) {
    _spotTimerSubscription?.cancel();
    _spotTimerSubscription =
        _repository.getSpotTimerStates(lobbyId).listen((timerStates) {
      final currentState = state.valueOrNull;
      if (currentState == null) return;

      state = AsyncData(currentState.copyWith(spotTimerStates: timerStates));
    });
  }

  /// Subscribe to peacock timer updates
  void subscribeToPeacockTimers() {
    _peacockTimerSubscription?.cancel();
    _peacockTimerSubscription =
        _repository.getPeacockTimerStates().listen((timerStates) {
      final currentState = state.valueOrNull;
      if (currentState == null) return;

      state = AsyncData(currentState.copyWith(peacockTimerStates: timerStates));
    });
  }

  /// Start a timer for a spot claim
  Future<void> startSpotTimer(
    String lobbyId,
    String gameName,
    int spotIndex,
    String userId,
    Duration duration,
  ) async {
    try {
      final timerKey = 'spot_${gameName}_$userId';

      // Start timer in TimerService
      await _timerService.startSpotTimer(gameName, userId, duration);

      // Update repository
      await _repository.startSpotTimer(lobbyId, spotIndex, duration);

      debugPrint('✅ Started spot timer: $timerKey for ${duration.inMinutes}m');
    } catch (e) {
      debugPrint('❌ Error starting spot timer: $e');
      rethrow;
    }
  }

  /// Stop a timer for a spot
  Future<void> stopSpotTimer(
    String gameName,
    String userId,
  ) async {
    try {
      final timerKey = 'spot_${gameName}_$userId';
      await _timerService.stopTimer(timerKey);

      debugPrint('✅ Stopped spot timer: $timerKey');
    } catch (e) {
      debugPrint('❌ Error stopping spot timer: $e');
      rethrow;
    }
  }

  /// Cancel a spot timer via repository
  Future<void> cancelSpotTimer(String lobbyId, int spotIndex) async {
    try {
      await _repository.cancelSpotTimer(lobbyId, spotIndex);
      debugPrint('✅ Cancelled spot timer at index $spotIndex');
    } catch (e) {
      debugPrint('❌ Error cancelling spot timer: $e');
      rethrow;
    }
  }

  /// Process expired timers (hybrid client-server approach)
  /// Server-side: Supabase pg_cron runs every 30 seconds
  /// Client-side: Can trigger on-demand for immediate checks
  Future<void> processExpiredTimers() async {
    final currentState = state.valueOrNull;
    if (currentState?.isProcessing ?? false) return;

    try {
      state = AsyncData((state.valueOrNull ?? TimerManagementState.initial())
          .copyWith(isProcessing: true));

      await _repository.processExpiredTimers();

      debugPrint('✅ Processed expired timers');

      state = AsyncData((state.valueOrNull ?? TimerManagementState.initial())
          .copyWith(isProcessing: false));
    } catch (e) {
      debugPrint('❌ Error processing expired timers: $e');
      state = AsyncData((state.valueOrNull ?? TimerManagementState.initial())
          .copyWith(isProcessing: false));
    }
  }

  /// Reset all timers for a specific game
  Future<void> resetTimersForGame(
      String gameName, Map<String, List<String?>> gameLobbySpots) async {
    try {
      final spots = gameLobbySpots[gameName] ?? [];
      for (int i = 0; i < spots.length; i++) {
        final spotUid = spots[i];
        if (spotUid != null) {
          final timerKey =
              'spot_${gameName}_${spotUid.replaceAll('_calling', '')}';
          await _timerService.stopTimer(timerKey);
        }
      }

      debugPrint('✅ Reset all timers for game: $gameName');
    } catch (e) {
      debugPrint('❌ Error resetting timers: $e');
      rethrow;
    }
  }

  /// Get remaining time for a spot timer
  Duration? getSpotTimerRemaining(String gameName, String userId) {
    final currentState = state.valueOrNull;
    if (currentState == null) return null;

    final timerKey = 'spot_${gameName}_$userId';
    return currentState.spotTimerStates[timerKey];
  }

  /// Get remaining time for a peacock timer
  Duration? getPeacockTimerRemaining(String userId) {
    final currentState = state.valueOrNull;
    if (currentState == null) return null;

    return currentState.peacockTimerStates[userId];
  }

  /// Check if a timer is active for a user
  bool hasActiveTimer(String gameName, String userId) {
    final remaining = getSpotTimerRemaining(gameName, userId);
    return remaining != null && remaining.inSeconds > 0;
  }

  /// Get all active timers for a game
  Map<String, Duration> getActiveTimersForGame(String gameName) {
    final currentState = state.valueOrNull;
    if (currentState == null) return {};

    final prefix = 'spot_${gameName}_';
    return Map.fromEntries(
      currentState.spotTimerStates.entries.where(
        (entry) => entry.key.startsWith(prefix) && entry.value.inSeconds > 0,
      ),
    );
  }

  /// Update timer state from external source (e.g., real-time updates)
  void updateTimerStates({
    Map<String, Duration>? spotTimers,
    Map<String, Duration>? peacockTimers,
  }) {
    final currentState = state.valueOrNull ?? TimerManagementState.initial();

    state = AsyncData(currentState.copyWith(
      spotTimerStates: spotTimers ?? currentState.spotTimerStates,
      peacockTimerStates: peacockTimers ?? currentState.peacockTimerStates,
    ));
  }

  /// Sync timer data with SQLite local storage
  Future<void> syncTimerData(
      Map<String, List<Map<String, dynamic>?>> gameSpotTimers) async {
    try {
      final currentState = state.valueOrNull ?? TimerManagementState.initial();

      state = AsyncData(currentState.copyWith(
        gameSpotTimers: gameSpotTimers,
      ));

      debugPrint('✅ Synced timer data with local storage');
    } catch (e) {
      debugPrint('❌ Error syncing timer data: $e');
    }
  }

  /// Clean up expired peacock timers
  Future<void> cleanupExpiredPeacockTimers() async {
    try {
      final timers = state.valueOrNull?.peacockTimerStates ?? {};
      final tracker = PeacockAssignmentTracker.instance;
      for (final entry in timers.entries) {
        if (entry.value.inSeconds <= 0) {
          tracker.expire(entry.key);
        }
      }
      await _repository.processPeacockQueue();
      debugPrint('✅ Cleaned up expired peacock timers');
    } catch (e) {
      debugPrint('❌ Error cleaning up peacock timers: $e');
    }
  }
}

// Backward compatibility alias (riverpod generates 'timerManagementProvider')
final timerManagementNotifierProvider = AutoDisposeAsyncNotifierProvider<
    TimerManagementNotifier, TimerManagementState>(
  TimerManagementNotifier.new,
);

/// Convenience provider to get timer remaining for a spot
final spotTimerRemainingProvider =
    Provider.family<Duration?, (String gameName, String userId)>((ref, params) {
  final timerState = ref.watch(timerManagementNotifierProvider);
  return timerState.maybeWhen(
    data: (state) {
      final timerKey = 'spot_${params.$1}_${params.$2}';
      return state.spotTimerStates[timerKey];
    },
    orElse: () => null,
  );
});

/// Convenience provider to check if user has active timer
final hasActiveTimerProvider =
    Provider.family<bool, (String gameName, String userId)>((ref, params) {
  final remaining = ref.watch(spotTimerRemainingProvider(params));
  return remaining != null && remaining.inSeconds > 0;
});
