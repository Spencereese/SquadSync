import 'package:flutter/material.dart';

/// Manages achievements, ratings, complaints, and bans
class AchievementManager with ChangeNotifier {
  Map<String, int> _currentStreaks = {};
  Map<String, int> _highestStreaks = {};
  Map<String, Set<String>> _achievements = {};
  Map<String, Map<String, List<int>>> _dailyRatings = {};
  Map<String, Map<String, List<int>>> _allTimeRatings = {};
  Map<String, int> _complaints = {};
  Map<String, List<Map<String, dynamic>>> _bans = {};

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
  }) async {
    // Delegate to SquadState for actual implementation
    // This manager focuses on tracking complaint counts and achievements
    complaints[targetMember] = (complaints[targetMember] ?? 0) + 1;
    notifyListeners();
  }

  Future<void> submitRatings({
    required String submittedBy,
    required Map<String, int> ratings,
  }) async {
    // Implementation from original SquadState
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

  Future<void> recordWin() async {
    // Implementation from original SquadState
    notifyListeners();
  }

  void recordLoss() {
    // Implementation from original SquadState
    notifyListeners();
  }
}
