import 'dart:async';
import 'package:flutter/material.dart';
import '../managers/squad_data_manager.dart';
import '../managers/squad_ui_manager.dart';
import '../managers/squad_persistence_manager.dart';

/// Service responsible for all timer-related operations in the squad system.
///
/// This service handles:
/// - Spot timer management and formatting
/// - Timer expiration checking and spot locking
/// - Server timer synchronization
/// - Peacock timer operations
/// - Timer display formatting
class TimerState with ChangeNotifier {
  final SquadDataManager dataManager;
  final SquadUIManager uiManager;
  final SquadPersistenceManager persistenceManager;

  Timer? _timer;
  final DateTime _lastFirestoreUpdate = DateTime.now();

  TimerState({
    required this.dataManager,
    required this.uiManager,
    required this.persistenceManager,
  });

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
  void initialize() {
    // Start periodic timer checking
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkAndLockExpiredSpots();
      _checkForServerTimerUpdates();
    });
  }

  /// Dispose of the timer service
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Format seconds into MM:SS format
  String _formatTimer(int? seconds) {
    if (seconds == null) return '00:00';
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Get display string for a spot timer
  String getSpotTimerDisplay(int index, String gameName) {
    if (!gameSpotTimers.containsKey(gameName) ||
        gameSpotTimers[gameName]![index] == null) {
      return '00:00';
    }

    final timer = gameSpotTimers[gameName]![index]!;
    int startTime = timer['startTime'] as int;
    int duration = timer['duration'] as int;

    if (duration == -1) {
      // Counting up (player is in game)
      int elapsed =
          ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000).floor();
      return _formatTimer(elapsed);
    } else {
      // Counting down
      int remaining = duration -
          ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000).floor();
      return _formatTimer(remaining > 0 ? remaining : 0);
    }
  }

  /// Check if there are any active timers
  bool hasActiveTimers(String gameName) {
    if (!gameSpotTimers.containsKey(gameName)) return false;

    for (final timer in gameSpotTimers[gameName]!) {
      if (timer != null) return true;
    }
    return false;
  }

  /// Check for server timer updates periodically
  void _checkForServerTimerUpdates() {
    // Periodically refresh timer data from Firestore to sync with server-side updates
    // This ensures the UI reflects server-side timer changes even when app was closed
    final now = DateTime.now();
    if (now.difference(_lastFirestoreUpdate).inSeconds >= 30) {
      // Check every 30 seconds
      // Force a refresh from Firestore to get latest timer state
      // This will be called by the parent SquadState
    }
  }

  /// Check and lock expired spots
  void _checkAndLockExpiredSpots() {
    final gameName = dataManager.currentGame?['name'] ?? '';
    if (gameSpotTimers.containsKey(gameName)) {
      for (int i = 0; i < gameSpotTimers[gameName]!.length; i++) {
        final timer = gameSpotTimers[gameName]![i];
        if (timer != null) {
          final startTime = timer['startTime'] as int;
          final duration = timer['duration'] as int;
          final elapsed =
              (DateTime.now().millisecondsSinceEpoch - startTime) / 1000;
          final remaining = duration - elapsed.floor();

          if (duration > 0 && remaining <= 0) {
            // Check if this is a calling timer
            final isCalling = timer['calling'] == true;

            if (isCalling) {
              // All calling spots - remove them if not manually locked (expired)
              removeSpot(i, gameName);
            } else {
              // Regular timer expired, free the spot
              removeSpot(i, gameName);
            }
          }
        }
      }
    }
    // Always notify listeners to update timer displays every second
    notifyListeners();
  }

  /// Remove a spot (free it up)
  void removeSpot(int index, String gameName) {
    if (gameSpotTimers.containsKey(gameName) &&
        index < gameSpotTimers[gameName]!.length) {
      gameSpotTimers[gameName]![index] = null;
      persistenceManager.markFieldChanged('spotTimers');
      notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
  }

  /// Lock a called spot
  void lockCalledSpot(String gameName, int index, String displayName,
      String userUid, VoidCallback updateFirestore) {
    dataManager.lockCalledSpot(gameName, index, displayName, userUid);
    persistenceManager.markFieldChanged('squadSpots');
    persistenceManager.markFieldChanged('spotTimers');
    persistenceManager.markFieldChanged('globalStatuses');
    updateFirestore();
    notifyListeners();
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
      } else {
        peacockQueue.add(player);
        statuses[player] = 'Waiting';
        persistenceManager.markFieldChanged('peacockQueue');
      }
      persistenceManager.markFieldChanged('statuses');
      updateFirestore();
      notifyListeners();
    }
  }

  /// Remove player from peacock
  void removeFromPeacock(String player, VoidCallback updateFirestore) {
    if (peacockTimers.containsKey(player)) {
      peacockTimers.remove(player);
      persistenceManager.markFieldChanged('peacockTimers');
      updateFirestore();
      notifyListeners();
    } else if (peacockQueue.contains(player)) {
      peacockQueue.remove(player);
      persistenceManager.markFieldChanged('peacockQueue');
      updateFirestore();
      notifyListeners();
    }
  }
}
