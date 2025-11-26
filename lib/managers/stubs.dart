// Stub implementations for removed manager classes
// TODO: Migrate code using these to use the new Riverpod notifiers instead

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AchievementManager extends ChangeNotifier {
  // Stub implementation
}

class AvailabilityManager extends ChangeNotifier {
  // Stub implementation
  Future<List<Map<String, dynamic>>> suggestLobbies(
      [List<Map<String, dynamic>>? pinnedGames]) async {
    // Stub implementation - return empty list
    return [];
  }
}

class FirestoreManager extends ChangeNotifier {
  // Stub implementation
  Future<void> addScheduleEvent(dynamic event) async {
    // Stub implementation
  }

  Future<void> voteForScheduleEvent(dynamic eventId) async {
    // Stub implementation
  }

  Future<List<Map<String, dynamic>>> getUserScheduleEvents(
      [String? playerUid]) async {
    // Stub implementation - return empty list
    return [];
  }

  Future<void> deleteScheduleEvent(dynamic eventId) async {
    // Stub implementation
  }

  Future<void> sendInvite(dynamic invite) async {
    // Stub implementation
  }
}

class GameManager extends ChangeNotifier {
  // Stub implementation
  List<Map<String, dynamic>> get availableGames => [];

  Future<List<Map<String, dynamic>>> fetchGamesFromIGDB(String query) async {
    // Stub implementation - return empty list
    return [];
  }

  bool get isOffline => false;

  List<Map<String, dynamic>> get games => [];

  bool isGameHidden(String gameName) {
    // Stub implementation - never hidden
    return false;
  }

  Map<String, dynamic>? get currentGame => null;

  void selectGame(Map<String, dynamic> game) {
    // Stub implementation
  }
}

class NotificationManager extends ChangeNotifier {
  // Stub implementation
  void showNotification({String? title, String? body, String? message}) {
    // Stub implementation
  }

  Future<void> scheduleNotification(
      {String? title, String? body, DateTime? scheduledTime}) async {
    // Stub implementation
  }

  static Future<void> initialize() async {
    // Stub implementation
  }

  Stream<int> getUnreadNotificationCount() {
    // Stub implementation - return stream of 0
    return Stream.value(0);
  }

  Future<void> updateFCMToken([String? token]) async {
    // Stub implementation
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getFilteredNotificationsStream({Set<String>? mutedGames}) {
    // Stub implementation - return empty stream
    return Stream.value([]);
  }

  Future<void> archiveNotification([String? notificationId]) async {
    // Stub implementation
  }

  Future<void> markAsRead([String? notificationId]) async {
    // Stub implementation
  }

  void showSmartNotification(
      {String? title, String? body, String? channelId, String? payload}) {
    // Stub implementation
  }
}

class PeacockManager extends ChangeNotifier {
  // Stub implementation
}

class ReviewManager extends ChangeNotifier {
  // Stub implementation
}

class SquadDataManager extends ChangeNotifier {
  // Stub implementation
}

class SquadManager extends ChangeNotifier {
  // Stub implementation
  Future<void> addViewer(String lobbyId, String userId) async {
    // Stub implementation
  }

  Future<void> leaveLobby(String lobbyId, String userId) async {
    // Stub implementation
  }

  Future<void> removeViewer(String lobbyId, String userId) async {
    // Stub implementation
  }

  Stream<QuerySnapshot<Object?>> getActiveLobbiesStream() {
    // Stub implementation - return empty stream
    return Stream<QuerySnapshot<Object?>>.empty();
  }

  Future<void> joinLobby(String peacockId, String userId) async {
    // Stub implementation
  }

  Future<void> closeLobby(String peacockId) async {
    // Stub implementation
  }

  Future<void> claimPeacockSpot(
      String peacockId, String userId, String gameName) async {
    // Stub implementation
  }

  Future<void> lockPeacockSpot(
      String peacockId, String userId, String gameName) async {
    // Stub implementation
  }

  Future<List<Map<String, dynamic>>> getSquadAlerts(String squadId) async {
    // Stub implementation
    return [];
  }

  Future<void> sendGameAlert(String squadId, String userId, String message,
      {String? specificGame, List<String>? pinnedGames}) async {
    // Stub implementation
  }

  Future<void> clearGameAlerts(String squadId, String userId) async {
    // Stub implementation
  }
}

class SquadPersistenceManager extends ChangeNotifier {
  // Stub implementation
}

class SquadUIManager extends ChangeNotifier {
  // Stub implementation
}

class SyncManager extends ChangeNotifier {
  SyncManager({required this.sqliteHelper});
  final dynamic sqliteHelper; // SQLiteHelper type not available

  // Stub implementation
  Future<void> deltaSync(String chatGroupId) async {
    // Stub implementation
  }
}

class UserManager extends ChangeNotifier {
  // Stub implementation
}
