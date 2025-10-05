import 'package:flutter/material.dart';

/// Manages peacock queue, timers, and related functionality
class PeacockManager with ChangeNotifier {
  List<String> _peacockQueue = [];
  Map<String, Map<String, dynamic>?> _peacockTimers = {};

  List<String> get peacockQueue => _peacockQueue;
  Map<String, Map<String, dynamic>?> get peacockTimers => _peacockTimers;

  set peacockQueue(List<String> value) {
    _peacockQueue = value;
    notifyListeners();
  }

  set peacockTimers(Map<String, Map<String, dynamic>?> value) {
    _peacockTimers = value;
    notifyListeners();
  }

  List<String> squadMembers = [
    "Alex",
    "Spencer",
    "Landon",
    "Drew",
    "John",
    "Dalton",
    "Levi",
    "Daniel"
  ];

  void addToPeacock(String player) {
    if (!_peacockQueue.contains(player)) {
      _peacockQueue.add(player);
      notifyListeners();
    }
  }

  Future<void> removeFromPeacock(String player) async {
    _peacockQueue.remove(player);
    notifyListeners();
  }

  void startPeacockTimer(BuildContext dialogContext) {
    // Implementation from original SquadState
    notifyListeners();
  }

  void reupPeacock() {
    // Implementation from original SquadState
    notifyListeners();
  }

  void claimPeacockDialog() {
    // Implementation from original SquadState
    notifyListeners();
  }

  void managePeacock() {
    // Implementation from original SquadState
    notifyListeners();
  }

  void updatePeacockTimers() {
    // Implementation from original SquadState
    notifyListeners();
  }

  String getPeacockTimerDisplay(String player) {
    final timerData = peacockTimers[player];
    if (timerData != null && timerData['seconds'] != null) {
      return _formatTimer(timerData['seconds']);
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
