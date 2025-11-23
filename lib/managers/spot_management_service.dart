import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../managers/squad_data_manager.dart';
import '../managers/squad_persistence_manager.dart';
import '../managers/squad_ui_manager.dart';
import '../services/cache_service.dart';

/// Service responsible for managing squad spot operations including claiming,
/// assigning, removing, and locking spots across different games.
class SpotManagementService {
  final SquadDataManager dataManager;
  final SquadPersistenceManager persistenceManager;
  final SquadUIManager uiManager;
  final CacheService cacheService;

  // Data structure accessors (provided by parent)
  final List<String?> Function() getSquadSpots;
  final Map<String, List<String?>> Function() getGameSquadSpots;
  final Map<String, List<Map<String, dynamic>?>> Function() getGameSpotTimers;
  final List<Map<String, dynamic>?> Function() getSpotTimers;
  final Map<String, Map<String, dynamic>?> Function() getPeacockTimers;
  final List<String> Function() getPeacockQueue;
  final Map<String, String> Function() getGlobalStatuses;
  final Map<String, dynamic>? Function() getCurrentGame;
  final String? Function() getDisplayName;
  final String? Function(String) getUidForDisplayName;

  SpotManagementService({
    required this.dataManager,
    required this.persistenceManager,
    required this.uiManager,
    required this.cacheService,
    required this.getSquadSpots,
    required this.getGameSquadSpots,
    required this.getGameSpotTimers,
    required this.getSpotTimers,
    required this.getPeacockTimers,
    required this.getPeacockQueue,
    required this.getGlobalStatuses,
    required this.getCurrentGame,
    required this.getDisplayName,
    required this.getUidForDisplayName,
  });

  /// Claims a spot in the current game for the current user
  void claimSpot(int index) {
    final userName = getDisplayName();
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userName != null && userUid != null) {
      dataManager.claimSpot(index, userName, userUid);
      dataManager.globalStatuses[userName] = 'Calling';
      if (dataManager.peacockTimers.containsKey(userName)) {
        dataManager.peacockTimers.remove(userName);
        persistenceManager.markFieldChanged('peacockTimers');
      } else if (dataManager.peacockQueue.contains(userName)) {
        dataManager.peacockQueue.remove(userName);
        persistenceManager.markFieldChanged('peacockQueue');
      }
      persistenceManager.markFieldChanged('squadSpots');
      persistenceManager.markFieldChanged('spotTimers');
      persistenceManager.markFieldChanged('globalStatuses');
      uiManager.setNewSquadSpot(true, getCurrentGame()?['name'] ?? '');
    }
  }

  /// Claims a spot for a specific game
  void claimSpotForGame(int index, String gameName, {int? maxSpots}) {
    final userName = getDisplayName();
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userName != null && userUid != null) {
      dataManager.callSpotForGame(index, userName, userUid, gameName,
          maxSpots: maxSpots);
      persistenceManager.markFieldChanged('squadSpots');
      persistenceManager.markFieldChanged('spotTimers');
      persistenceManager.markFieldChanged('globalStatuses');
      uiManager.setNewSquadSpot(true, gameName);
    }
  }

  /// Calls a spot for a specific game (similar to claim but with different status)
  void callSpotForGame(int index, String gameName, {int? maxSpots}) {
    debugPrint(
        'callSpotForGame called: index=$index, gameName=$gameName, maxSpots=$maxSpots');
    final userName = getDisplayName();
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userName != null && userUid != null) {
      debugPrint(
          'Calling dataManager.callSpotForGame with userName=$userName, userUid=$userUid');
      dataManager.callSpotForGame(index, userName, userUid, gameName,
          maxSpots: maxSpots);
      persistenceManager.markFieldChanged('squadSpots');
      persistenceManager.markFieldChanged('spotTimers');
      persistenceManager.markFieldChanged('globalStatuses');
      uiManager.setNewSquadSpot(true, gameName);
      debugPrint('About to call updateFirestoreAsync');
      debugPrint('callSpotForGame completed');
    } else {
      debugPrint(
          'callSpotForGame failed: userName=$userName, userUid=$userUid');
    }
  }

  /// Locks a called spot for a specific game
  void lockCalledSpot(String gameName, int index) {
    debugPrint('lockCalledSpot called: gameName=$gameName, index=$index');
    final userName = getDisplayName();
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userName != null && userUid != null) {
      debugPrint(
          'Calling dataManager.lockCalledSpot with userName=$userName, userUid=$userUid');
      dataManager.lockCalledSpot(gameName, index, userName, userUid);
      persistenceManager.markFieldChanged('squadSpots');
      persistenceManager.markFieldChanged('spotTimers');
      persistenceManager.markFieldChanged('globalStatuses');
      debugPrint('About to call updateFirestoreAsync for lock');
      debugPrint('lockCalledSpot completed');
    } else {
      debugPrint('lockCalledSpot failed: userName=$userName, userUid=$userUid');
    }
  }

  /// Assigns a spot to a specific player
  void assignSpot(int index, String player) {
    final playerUid = getUidForDisplayName(player);
    final gameName = getCurrentGame()?['name'] ?? '';

    if (playerUid != null) {
      // Initialize game data structures if needed
      final gameSquadSpots = getGameSquadSpots();
      final gameSpotTimers = getGameSpotTimers();
      if (!gameSquadSpots.containsKey(gameName)) {
        final maxSpots = getCurrentGame()?['maxSpots'] ?? 4;
        gameSquadSpots[gameName] = List.of(List.filled(maxSpots, null));
        gameSpotTimers[gameName] = List.of(List.filled(maxSpots, null));
      }

      gameSquadSpots[gameName]![index] = playerUid;
      gameSpotTimers[gameName]![index] = {
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'duration': 300,
      };
      dataManager.globalStatuses[player] = 'Ready';
      final peacockTimers = getPeacockTimers();
      final peacockQueue = getPeacockQueue();
      if (peacockTimers.containsKey(player)) {
        peacockTimers.remove(player);
        persistenceManager.markFieldChanged('peacockTimers');
      } else if (peacockQueue.contains(player)) {
        peacockQueue.remove(player);
        persistenceManager.markFieldChanged('peacockQueue');
      }
      cacheService.invalidate('squadSpots');
      uiManager.setNewSquadSpot(true, gameName);
      // Note: updateFirestore is handled by parent
    }
  }

  /// Removes a player from a spot
  void removeSpot(int index) {
    debugPrint('removeSpot called: index=$index');
    final gameName = getCurrentGame()?['name'] ?? '';
    debugPrint('removeSpot: gameName=$gameName');
    final gameSquadSpots = getGameSquadSpots();
    final gameSpotTimers = getGameSpotTimers();
    final globalStatuses = getGlobalStatuses();
    if (gameSquadSpots.containsKey(gameName) &&
        index < gameSquadSpots[gameName]!.length) {
      final playerUid = gameSquadSpots[gameName]![index];
      debugPrint('removeSpot: playerUid=$playerUid');
      if (playerUid != null) {
        final player = getUidForDisplayName(playerUid) ?? 'Unknown';
        debugPrint('removeSpot: player=$player');
        gameSquadSpots[gameName]![index] = null;
        gameSpotTimers[gameName]![index] = null;
        final peacockTimers = getPeacockTimers();
        if (peacockTimers.containsKey(player)) {
          globalStatuses[player] = 'Strutting';
        } else if (getPeacockQueue().contains(player)) {
          globalStatuses[player] = 'Waiting';
        } else {
          globalStatuses[player] = 'Offline';
        }
        cacheService.invalidate('squadSpots');
        debugPrint('About to call updateFirestore for removeSpot');
        // Note: updateFirestore is handled by parent
        debugPrint('removeSpot completed successfully');
      } else {
        debugPrint('removeSpot: playerUid was null, no action taken');
      }
    } else {
      debugPrint(
          'removeSpot: conditions not met - gameSquadSpots.containsKey(gameName)=${gameSquadSpots.containsKey(gameName)}, index < gameSquadSpots[gameName]!.length=${index < gameSquadSpots[gameName]!.length}');
    }
  }

  /// Locks a spot (sets it to in-game status)
  void lockSpot(int index) {
    final gameName = getCurrentGame()?['name'] ?? '';
    final gameSpotTimers = getGameSpotTimers();
    final globalStatuses = getGlobalStatuses();
    if (gameSpotTimers.containsKey(gameName) &&
        index < gameSpotTimers[gameName]!.length) {
      gameSpotTimers[gameName]![index] = {
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'duration': -1, // Special value to indicate counting up
      };
      final gameSquadSpots = getGameSquadSpots();
      final playerUid = gameSquadSpots[gameName]?[index];
      if (playerUid != null) {
        final player = getUidForDisplayName(playerUid) ?? 'Unknown';
        globalStatuses[player] = 'in game';
        // Note: updateFirestore is handled by parent
      }
    }
  }

  /// Clears all spots for the current game
  void clearAllSpots() {
    final currentGameName = dataManager.currentGame?['name'] ?? 'Warzone';
    final maxSpots = dataManager.currentGame?['maxSpots'] ?? 4;
    dataManager.gameSquadSpots[currentGameName] =
        List.of(List.filled(maxSpots, null));
    dataManager.gameSpotTimers[currentGameName] =
        List.of(List.filled(maxSpots, null));
    dataManager.peacockTimers.clear();
    dataManager.peacockQueue.clear();
    final squadMembers = dataManager.squadMembers;
    final gameStatuses = dataManager.gameStatuses;
    for (var member in squadMembers) {
      if (gameStatuses[currentGameName]?[member] == 'Strutting' ||
          gameStatuses[currentGameName]?[member] == 'Walking') {
        gameStatuses[currentGameName]?[member] = 'Ready';
      } else {
        gameStatuses[currentGameName]?[member] = 'Offline';
      }
    }
    // Note: updateFirestore is handled by parent
  }

  /// Resets all timers for spots and peacock
  void resetTimers() {
    final gameName = getCurrentGame()?['name'] ?? '';
    final gameSpotTimers = dataManager.gameSpotTimers;
    final gameSquadSpots = dataManager.gameSquadSpots;
    final peacockTimers = getPeacockTimers();

    if (gameSpotTimers.containsKey(gameName) &&
        gameSquadSpots.containsKey(gameName)) {
      final timers = gameSpotTimers[gameName]!;
      final spots = gameSquadSpots[gameName]!;
      for (int i = 0; i < timers.length && i < spots.length; i++) {
        if (timers[i] != null && spots[i] != null) {
          timers[i] = {
            'startTime': DateTime.now().millisecondsSinceEpoch,
            'duration': 300,
          };
        }
      }
    }

    peacockTimers.forEach((player, timer) {
      if (timer != null) {
        timer['startTime'] = DateTime.now().millisecondsSinceEpoch;
        timer['duration'] = 3600;
      }
    });
    persistenceManager.markFieldChanged('spotTimers');
    persistenceManager.markFieldChanged('peacockTimers');
  }

  /// Updates spot timers and cleans up expired ones
  bool updateSpotTimers() {
    // Server-side timers are now handled by Cloud Functions
    // This method only cleans up any locally detected expired timers as fallback
    final spotTimers = getSpotTimers();
    bool changed = false;
    for (int i = 0; i < spotTimers.length; i++) {
      if (spotTimers[i] != null) {
        int startTime = spotTimers[i]!['startTime'] as int;
        int duration = spotTimers[i]!['duration'] as int;
        int elapsed =
            ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000)
                .floor();
        int remaining = duration - elapsed;
        if (remaining <= 0) {
          // Timer expired - clean up locally (server should have done this already)
          removeSpot(i);
          changed = true;
        }
      }
    }
    // Don't update Firestore here - server handles timer expiration
    return changed;
  }
}
