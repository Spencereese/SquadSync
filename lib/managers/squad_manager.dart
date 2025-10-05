import 'package:flutter/material.dart';

/// Manages squad spots, assignments, and timers
class SquadManager with ChangeNotifier {
  // Game-specific squad spots: Map<gameName, List<String?>>
  Map<String, List<String?>> gameSquadSpots = {};
  // Game-specific spot timers: Map<gameName, List<Map<String, dynamic>?>>
  Map<String, List<Map<String, dynamic>?>> gameSpotTimers = {};

  List<String?> get squadSpots {
    final gameName = currentGame?['name'] ?? '';
    if (!gameSquadSpots.containsKey(gameName)) {
      final maxSpots = currentGame?['maxSpots'] ?? 4;
      gameSquadSpots[gameName] = List.filled(maxSpots, null);
      gameSpotTimers[gameName] = List.filled(maxSpots, null);
    }
    return gameSquadSpots[gameName] ?? [];
  }

  List<Map<String, dynamic>?> get spotTimers {
    final gameName = currentGame?['name'] ?? '';
    if (!gameSpotTimers.containsKey(gameName)) {
      final maxSpots = currentGame?['maxSpots'] ?? 4;
      gameSpotTimers[gameName] = List.filled(maxSpots, null);
    }
    return gameSpotTimers[gameName] ?? [];
  }

  Map<String, dynamic>? currentGame;

  List<String?> getSquadSpots(String gameName) {
    if (!gameSquadSpots.containsKey(gameName)) {
      final maxSpots = currentGame?['maxSpots'] ?? 4;
      gameSquadSpots[gameName] = List.filled(maxSpots, null);
      gameSpotTimers[gameName] = List.filled(maxSpots, null);
    }
    return gameSquadSpots[gameName] ?? [];
  }

  List<Map<String, dynamic>?> getSpotTimers(String gameName) {
    if (!gameSpotTimers.containsKey(gameName)) {
      final maxSpots = currentGame?['maxSpots'] ?? 4;
      gameSpotTimers[gameName] = List.filled(maxSpots, null);
    }
    return gameSpotTimers[gameName] ?? [];
  }

  Map<String, String> getStatuses(
      String gameName, Map<String, String> globalStatuses) {
    // Merge global statuses with game-specific statuses
    final mergedStatuses = Map<String, String>.from(globalStatuses);
    // Global statuses take precedence over game-specific statuses
    return mergedStatuses;
  }

  void claimSpot(int index) {
    if (index >= 0 && index < squadSpots.length) {
      // Implementation from original SquadState
      notifyListeners();
    }
  }

  void assignSpot(int index, String player) {
    final gameName = currentGame?['name'] ?? '';
    if (gameSquadSpots.containsKey(gameName) &&
        index >= 0 &&
        index < gameSquadSpots[gameName]!.length) {
      gameSquadSpots[gameName]![index] = player;
      notifyListeners();
    }
  }

  void removeSpot(int index) {
    final gameName = currentGame?['name'] ?? '';
    if (gameSquadSpots.containsKey(gameName) &&
        index >= 0 &&
        index < gameSquadSpots[gameName]!.length) {
      gameSquadSpots[gameName]![index] = null;
      notifyListeners();
    }
  }

  void lockSpot(int index) {
    // Implementation from original SquadState
    notifyListeners();
  }

  void clearAllSpots() {
    final gameName = currentGame?['name'] ?? '';
    if (gameSquadSpots.containsKey(gameName)) {
      gameSquadSpots[gameName] =
          List.filled(gameSquadSpots[gameName]!.length, null);
      notifyListeners();
    }
  }

  void resetTimers() {
    final gameName = currentGame?['name'] ?? '';
    if (gameSpotTimers.containsKey(gameName)) {
      gameSpotTimers[gameName] =
          List.filled(gameSpotTimers[gameName]!.length, null);
      notifyListeners();
    }
  }

  void updateSpotTimers() {
    // Implementation from original SquadState
    notifyListeners();
  }

  String getSpotTimerDisplay(int index) {
    final gameName = currentGame?['name'] ?? '';
    if (gameSpotTimers.containsKey(gameName) &&
        index >= 0 &&
        index < gameSpotTimers[gameName]!.length) {
      final timerData = gameSpotTimers[gameName]![index];
      if (timerData != null && timerData['seconds'] != null) {
        return _formatTimer(timerData['seconds']);
      }
    }
    return '00:00';
  }

  String _formatTimer(int? seconds) {
    if (seconds == null || seconds <= 0) return '00:00';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
