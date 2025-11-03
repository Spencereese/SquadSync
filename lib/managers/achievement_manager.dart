import 'package:flutter/material.dart';
import 'squad_data_manager.dart';

/// Manages achievements, ratings, complaints, and bans
class AchievementManager with ChangeNotifier {
  final SquadDataManager _dataManager;

  // Local copies for UI state management
  Map<String, int> _currentStreaks = {};
  Map<String, int> _highestStreaks = {};
  Map<String, Set<String>> _achievements = {};
  Map<String, Map<String, List<int>>> _dailyRatings = {};
  Map<String, Map<String, List<int>>> _allTimeRatings = {};
  Map<String, int> _complaints = {};
  Map<String, List<Map<String, dynamic>>> _bans = {};

  AchievementManager(this._dataManager) {
    // Initialize with data from SquadDataManager
    _currentStreaks = Map.from(_dataManager.currentStreaks);
    _highestStreaks = Map.from(_dataManager.highestStreaks);
    _achievements = Map.from(_dataManager.achievements);
    _dailyRatings = Map.from(_dataManager.dailyRatings);
    _allTimeRatings = Map.from(_dataManager.allTimeRatings);
    _complaints = Map.from(_dataManager.complaints);
    _bans = Map.from(_dataManager.bans);
  }

  Map<String, int> get currentStreaks => _currentStreaks;
  Map<String, int> get highestStreaks => _highestStreaks;
  Map<String, Set<String>> get achievements => _achievements;
  Map<String, Map<String, List<int>>> get dailyRatings => _dailyRatings;
  Map<String, Map<String, List<int>>> get allTimeRatings => _allTimeRatings;
  Map<String, int> get complaints => _complaints;
  Map<String, List<Map<String, dynamic>>> get bans => _bans;

  // Setters for delegated properties
  set currentStreaks(Map<String, int> value) {
    _currentStreaks = value;
    notifyListeners();
  }

  set highestStreaks(Map<String, int> value) {
    _highestStreaks = value;
    notifyListeners();
  }

  set achievements(Map<String, Set<String>> value) {
    _achievements = value;
    notifyListeners();
  }

  set dailyRatings(Map<String, Map<String, List<int>>> value) {
    _dailyRatings = value;
    notifyListeners();
  }

  set allTimeRatings(Map<String, Map<String, List<int>>> value) {
    _allTimeRatings = value;
    notifyListeners();
  }

  set complaints(Map<String, int> value) {
    _complaints = value;
    notifyListeners();
  }

  set bans(Map<String, List<Map<String, dynamic>>> value) {
    _bans = value;
    notifyListeners();
  }

  Future<void> submitComplaint({
    required String submittedBy,
    required String targetMember,
    required String reason,
    required String category,
    required List<String> squadMembers,
  }) async {
    await _dataManager.submitComplaint(
      submittedBy: submittedBy,
      targetMember: targetMember,
      reason: reason,
      category: category,
    );
    // Update local state
    _complaints[targetMember] = (_complaints[targetMember] ?? 0) + 1;
    notifyListeners();
  }

  Future<void> submitRatings({
    required String submittedBy,
    required String targetMember,
    required Map<String, int?> ratings,
    required List<String> squadMembers,
    required List<Map<String, dynamic>> gameHistory,
  }) async {
    await _dataManager.submitRatings(
      submittedBy: submittedBy,
      targetMember: targetMember,
      ratings: ratings,
    );
    // Update local state - simplified version
    ratings.forEach((category, rating) {
      if (rating != null && rating >= 0 && rating <= 5) {
        _dailyRatings[targetMember] ??= {};
        _dailyRatings[targetMember]![category] ??= [];
        _dailyRatings[targetMember]![category]!.add(rating);

        _allTimeRatings[targetMember] ??= {};
        _allTimeRatings[targetMember]![category] ??= [];
        _allTimeRatings[targetMember]![category]!.add(rating);
      }
    });
    notifyListeners();
  }

  void addBan(String player, String voter) {
    bans[player] ??= [];
    bans[player]!.add({
      'voter': voter,
      'timestamp': DateTime.now(),
    });
    notifyListeners();
  }

  int getBanCount(String player) => bans[player]?.length ?? 0;

  bool isBanned(String player) => getBanCount(player) >= 5;

  int getBanDuration(String player) {
    final banCount = getBanCount(player);
    if (banCount == 0) return 0;
    if (banCount == 1) return 5; // 5 minutes
    if (banCount == 2) return 15; // 15 minutes
    if (banCount == 3) return 30; // 30 minutes
    if (banCount == 4) return 60; // 1 hour
    return 120; // 2 hours for 5+ bans
  }

  Future<void> recordWin({
    required List<String?> squadSpots,
    required Map<String, String> statuses,
    required List<Map<String, dynamic>> gameHistory,
  }) async {
    List<String> walkingPlayers = squadSpots
        .where((spot) => spot != null && statuses[spot] == 'Walking')
        .cast<String>()
        .toList();

    Map<String, int> updatedStreaks = {};
    for (var player in walkingPlayers) {
      int oldStreak = _currentStreaks[player] ?? 0;
      updatedStreaks[player] = oldStreak + 1;
      await _checkAchievements(player, updatedStreaks[player]!);
    }

    _currentStreaks.addAll(updatedStreaks);
    gameHistory.add({
      'result': 'Win',
      'players': walkingPlayers,
      'timestamp': DateTime.now().toIso8601String(),
      'ratings': {}, // Fresh ratings map for this game
    });

    notifyListeners();
  }

  void recordLoss({
    required List<String?> squadSpots,
    required List<Map<String, dynamic>?> spotTimers,
    required Map<String, int> currentStreaks,
    required List<Map<String, dynamic>> gameHistory,
  }) {
    List<String> walkingPlayers = squadSpots
        .where((spot) =>
            spot != null && spotTimers[squadSpots.indexOf(spot)] == null)
        .cast<String>()
        .toList();
    for (var player in walkingPlayers) {
      _currentStreaks[player] = 0;
    }
    gameHistory.add({
      'result': 'Loss',
      'players': walkingPlayers,
      'timestamp': DateTime.now().toIso8601String(),
      'ratings': {}, // Fresh ratings map for this game
    });
    notifyListeners();
  }

  Future<void> _checkAchievements(String player, int streak) async {
    _achievements[player] ??= {};
    bool added = false;
    if (streak >= 10) {
      _achievements[player]!.add('Chicken');
      added = true;
    }
    if (streak >= 4 && !added) {
      _achievements[player]!.add('Duck');
      added = true;
    }
    if (streak >= 3 && !added) {
      _achievements[player]!.add('Turkey');
    }
  }
}
