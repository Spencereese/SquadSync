import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../managers/squad_data_manager.dart';
import '../managers/squad_ui_manager.dart';
import '../managers/squad_persistence_manager.dart';
import '../services/timer_service.dart';

/// Service responsible for all timer-related operations in the squad system.
///
/// This service handles:
/// - Spot timer management and formatting
/// - Timer expiration checking and spot locking
/// - Server timer synchronization
/// - Peacock timer operations
/// - Timer display formatting
class TimerState extends StateNotifier<Map<String, Duration>> {
  final SquadDataManager dataManager;
  final SquadUIManager uiManager;
  final SquadPersistenceManager persistenceManager;
  final TimerService _timerService;

  Timer? _debounceTimer;
  SharedPreferences? _prefs;

  // Cache for display strings with 1-second validity
  final Map<String, String> _displayCache = {};
  final Map<String, DateTime> _cacheTimes = {};

  TimerState({
    required this.dataManager,
    required this.uiManager,
    required this.persistenceManager,
    TimerService? timerService,
  })  : _timerService = timerService ?? TimerService(),
        super({}) {
    _initializeCache();
  }

  // Timer properties delegation
  Map<String, List<Map<String, dynamic>?>> get gameSpotTimers =>
      dataManager.gameSpotTimers;
  Map<String, Map<String, dynamic>?> get peacockTimers =>
      dataManager.peacockTimers;
  List<String> get peacockQueue => dataManager.peacockQueue;

  // Legacy properties for backward compatibility
  List<Map<String, dynamic>?> get spotTimers {
    final gameName = dataManager.currentGame?['name'] ?? '';
    if (!gameSpotTimers.containsKey(gameName)) {
      final maxSpots = dataManager.currentGame?['maxSpots'] ?? 4;
      gameSpotTimers[gameName] = List.filled(maxSpots, null);
    }
    return gameSpotTimers[gameName] ?? [];
  }

  /// Initialize the timer service
  void initialize() async {
    await _initializeCache();
    // No longer need periodic timer, TimerService handles it
  }

  Future<void> _initializeCache() async {
    _prefs = await SharedPreferences.getInstance();
    // Load cached timers and spots
    _loadFromCache();
  }

  void _loadFromCache() {
    if (_prefs == null) return;
    // Load cached data if needed
    // For example, load last known timer states
  }

  /// Dispose of the timer service
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Format duration into MM:SS format
  String _formatDuration(Duration duration) {
    int seconds = duration.inSeconds;
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Get display string for a spot timer
  String getSpotTimerDisplay(int index, String gameName) {
    final key = 'spot_${gameName}_${index}';
    final cacheKey = key;

    // Check cache
    if (_displayCache.containsKey(cacheKey) &&
        _cacheTimes.containsKey(cacheKey) &&
        DateTime.now().difference(_cacheTimes[cacheKey]!).inSeconds < 1) {
      return _displayCache[cacheKey]!;
    }

    // Use state for remaining time
    final remaining = state[key];
    if (remaining == null) {
      return '00:00';
    }

    final display = _formatDuration(remaining);
    _displayCache[cacheKey] = display;
    _cacheTimes[cacheKey] = DateTime.now();
    return display;
  }

  /// Check if there are any active timers
  bool hasActiveTimers(String gameName) {
    if (!gameSpotTimers.containsKey(gameName)) return false;

    for (final timer in gameSpotTimers[gameName]!) {
      if (timer != null) return true;
    }
    return false;
  }

  /// Update spot timer using TimerService
  void updateSpotTimer(String gameName, int spotIndex, Duration duration) {
    final key = 'spot_${gameName}_${spotIndex}';
    _timerService.startTimer(key, duration, () {
      removeSpot(spotIndex, gameName);
    });
    // Listen to the stream and update state
    _timerService.observeTimer(key).listen((remaining) {
      state = {...state, key: remaining};
    });
  }

  /// Update peacock timer using TimerService
  void updatePeacockTimer(String player, Duration duration) {
    final key = 'peacock_$player';
    _timerService.startTimer(key, duration, () {
      removeFromPeacock(player, () {});
    });
    // Listen to the stream and update state
    _timerService.observeTimer(key).listen((remaining) {
      state = {...state, key: remaining};
    });
  }

  /// Remove a spot (free it up)
  void removeSpot(int index, String gameName) {
    if (gameSpotTimers.containsKey(gameName) &&
        index < gameSpotTimers[gameName]!.length) {
      gameSpotTimers[gameName]![index] = null;
      persistenceManager.markFieldChanged('spotTimers');
    }
  }

  /// Claim a spot in the current game
  void claimSpot(int index, String displayName, String userUid, String gameName,
      VoidCallback updateFirestore) {
    dataManager.claimSpot(index, displayName, userUid);
    dataManager.globalStatuses[displayName] = 'Calling';

    // Remove from peacock if present
    if (dataManager.peacockTimers.containsKey(displayName)) {
      dataManager.peacockTimers.remove(displayName);
      persistenceManager.markFieldChanged('peacockTimers');
    } else if (dataManager.peacockQueue.contains(displayName)) {
      dataManager.peacockQueue.remove(displayName);
      persistenceManager.markFieldChanged('peacockQueue');
    }

    persistenceManager.markFieldChanged('squadSpots');
    persistenceManager.markFieldChanged('spotTimers');
    persistenceManager.markFieldChanged('globalStatuses');

    uiManager.setNewSquadSpot(true, gameName);
    updateFirestore();
  }

  /// Call a spot for a specific game
  void callSpotForGame(int index, String displayName, String userUid,
      String gameName, int? maxSpots, VoidCallback updateFirestore) {
    dataManager.callSpotForGame(index, displayName, userUid, gameName,
        maxSpots: maxSpots);
    persistenceManager.markFieldChanged('squadSpots');
    persistenceManager.markFieldChanged('spotTimers');
    persistenceManager.markFieldChanged('globalStatuses');
    uiManager.setNewSquadSpot(true, gameName);
    updateFirestore();

    // Start timer using TimerService
    final timer = gameSpotTimers[gameName]?[index];
    if (timer != null) {
      final duration = timer['duration'] as int;
      updateSpotTimer(gameName, index, Duration(seconds: duration));
    }
  }

  /// Lock a called spot
  void lockCalledSpot(String gameName, int index, String displayName,
      String userUid, VoidCallback updateFirestore) {
    dataManager.lockCalledSpot(gameName, index, displayName, userUid);
    persistenceManager.markFieldChanged('squadSpots');
    persistenceManager.markFieldChanged('spotTimers');
    persistenceManager.markFieldChanged('globalStatuses');
    updateFirestore();

    // Stop timer
    final key = 'spot_${gameName}_${index}';
    _timerService.stopTimer(key);
    state = {...state}..remove(key);
  }

  /// Add player to peacock queue
  void addToPeacock(String player, String gameName,
      Map<String, String> statuses, VoidCallback updateFirestore) {
    // Remove from current spots if present
    final spotIndex = dataManager.gameSquadSpots[gameName]?.indexOf(player);
    if (spotIndex != null && spotIndex != -1) {
      dataManager.gameSquadSpots[gameName]![spotIndex] = null;
      if (gameSpotTimers.containsKey(gameName) &&
          spotIndex < gameSpotTimers[gameName]!.length) {
        gameSpotTimers[gameName]![spotIndex] = null;
      }
      statuses[player] = 'Offline';
      persistenceManager.markFieldChanged('squadSpots');
      persistenceManager.markFieldChanged('spotTimers');
    }

    if (!peacockTimers.containsKey(player) && !peacockQueue.contains(player)) {
      if (peacockTimers.length < 4) {
        peacockTimers[player] = {
          'startTime': DateTime.now().millisecondsSinceEpoch,
          'duration': 3600,
          'mode': 'Quads'
        };
        statuses[player] = 'Strutting';
        persistenceManager.markFieldChanged('peacockTimers');

        // Start peacock timer
        updatePeacockTimer(player, const Duration(seconds: 3600));
      } else {
        peacockQueue.add(player);
        statuses[player] = 'Waiting';
        persistenceManager.markFieldChanged('peacockQueue');
      }
      persistenceManager.markFieldChanged('statuses');
      updateFirestore();
    }
  }

  /// Remove player from peacock
  void removeFromPeacock(String player, VoidCallback updateFirestore) {
    if (peacockTimers.containsKey(player)) {
      peacockTimers.remove(player);
      persistenceManager.markFieldChanged('peacockTimers');
      updateFirestore();

      // Stop peacock timer
      final key = 'peacock_$player';
      _timerService.stopTimer(key);
      state = {...state}..remove(key);
    } else if (peacockQueue.contains(player)) {
      peacockQueue.remove(player);
      persistenceManager.markFieldChanged('peacockQueue');
      updateFirestore();
    }
  }
}
