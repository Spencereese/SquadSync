// Stub implementations for removed manager classes
// Converted to Riverpod StateNotifier pattern

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod/riverpod.dart';

// Simple state classes for managers
class AchievementManagerState {}

class AvailabilityManagerState {}

class FirestoreManagerState {}

class GameManagerState {
  final List<Map<String, dynamic>> availableGames;
  final List<Map<String, dynamic>> games;
  final Map<String, dynamic>? currentGame;
  final bool isOffline;

  const GameManagerState({
    this.availableGames = const [],
    this.games = const [],
    this.currentGame,
    this.isOffline = false,
  });

  GameManagerState copyWith({
    List<Map<String, dynamic>>? availableGames,
    List<Map<String, dynamic>>? games,
    Map<String, dynamic>? Function()? currentGame,
    bool? isOffline,
  }) {
    return GameManagerState(
      availableGames: availableGames ?? this.availableGames,
      games: games ?? this.games,
      currentGame: currentGame != null ? currentGame() : this.currentGame,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class NotificationManagerState {}

class PeacockManagerState {}

class ReviewManagerState {}

class SquadDataManagerState {}

class SquadManagerState {}

class SquadPersistenceManagerState {}

class SquadUIManagerState {}

class SyncManagerState {}

class UserManagerState {}

// StateNotifier implementations
class AchievementManager extends StateNotifier<AchievementManagerState> {
  AchievementManager() : super(AchievementManagerState());
}

class AvailabilityManager extends StateNotifier<AvailabilityManagerState> {
  AvailabilityManager() : super(AvailabilityManagerState());

  Future<List<Map<String, dynamic>>> suggestLobbies(
      [List<Map<String, dynamic>>? pinnedGames]) async {
    return [];
  }
}

class FirestoreManager extends StateNotifier<FirestoreManagerState> {
  FirestoreManager() : super(FirestoreManagerState());

  Future<void> addScheduleEvent(dynamic event) async {}

  Future<void> voteForScheduleEvent(dynamic eventId) async {}

  Future<List<Map<String, dynamic>>> getUserScheduleEvents(
      [String? playerUid]) async {
    return [];
  }

  Future<void> deleteScheduleEvent(dynamic eventId) async {}

  Future<void> sendInvite(dynamic invite) async {}
}

class GameManager extends StateNotifier<GameManagerState> {
  GameManager() : super(const GameManagerState());

  List<Map<String, dynamic>> get availableGames => state.availableGames;

  Future<List<Map<String, dynamic>>> fetchGamesFromIGDB(String query) async {
    return [];
  }

  bool get isOffline => state.isOffline;

  List<Map<String, dynamic>> get games => state.games;

  bool isGameHidden(String gameName) {
    return false;
  }

  Map<String, dynamic>? get currentGame => state.currentGame;

  void selectGame(Map<String, dynamic> game) {
    state = state.copyWith(currentGame: () => game);
  }
}

class NotificationManager extends StateNotifier<NotificationManagerState> {
  NotificationManager() : super(NotificationManagerState());

  void showNotification({String? title, String? body, String? message}) {}

  Future<void> scheduleNotification(
      {String? title, String? body, DateTime? scheduledTime}) async {}

  static Future<void> initialize() async {}

  Stream<int> getUnreadNotificationCount() {
    return Stream.value(0);
  }

  Future<void> updateFCMToken([String? token]) async {}

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getFilteredNotificationsStream({Set<String>? mutedGames}) {
    return Stream.value([]);
  }

  Future<void> archiveNotification([String? notificationId]) async {}

  Future<void> markAsRead([String? notificationId]) async {}

  void showSmartNotification(
      {String? title, String? body, String? channelId, String? payload}) {}
}

class PeacockManager extends StateNotifier<PeacockManagerState> {
  PeacockManager() : super(PeacockManagerState());
}

class ReviewManager extends StateNotifier<ReviewManagerState> {
  ReviewManager() : super(ReviewManagerState());
}

class SquadDataManager extends StateNotifier<SquadDataManagerState> {
  SquadDataManager() : super(SquadDataManagerState());
}

class SquadManager extends StateNotifier<SquadManagerState> {
  SquadManager() : super(SquadManagerState());

  Future<void> addViewer(String lobbyId, String userId) async {}

  Future<void> leaveLobby(String lobbyId, String userId) async {}

  Future<void> removeViewer(String lobbyId, String userId) async {}

  Stream<QuerySnapshot<Object?>> getActiveLobbiesStream() {
    return Stream<QuerySnapshot<Object?>>.empty();
  }

  Future<void> joinLobby(String peacockId, String userId) async {}

  Future<void> closeLobby(String peacockId) async {}

  Future<void> claimPeacockSpot(
      String peacockId, String userId, String gameName) async {}

  Future<void> lockPeacockSpot(
      String peacockId, String userId, String gameName) async {}

  Future<List<Map<String, dynamic>>> getSquadAlerts(String squadId) async {
    return [];
  }

  Future<void> sendGameAlert(String squadId, String userId, String message,
      {String? specificGame, List<String>? pinnedGames}) async {}

  Future<void> clearGameAlerts(String squadId, String userId) async {}
}

class SquadPersistenceManager
    extends StateNotifier<SquadPersistenceManagerState> {
  SquadPersistenceManager() : super(SquadPersistenceManagerState());
}

class SquadUIManager extends StateNotifier<SquadUIManagerState> {
  SquadUIManager() : super(SquadUIManagerState());
}

class SyncManager extends StateNotifier<SyncManagerState> {
  SyncManager({required this.sqliteHelper}) : super(SyncManagerState());
  final dynamic sqliteHelper;

  Future<void> deltaSync(String chatGroupId) async {}
}

class UserManager extends StateNotifier<UserManagerState> {
  UserManager() : super(UserManagerState());
}

// Riverpod providers for each manager
final achievementManagerProvider =
    StateNotifierProvider<AchievementManager, AchievementManagerState>((ref) {
  return AchievementManager();
});

final availabilityManagerProvider =
    StateNotifierProvider<AvailabilityManager, AvailabilityManagerState>((ref) {
  return AvailabilityManager();
});

final firestoreManagerProvider =
    StateNotifierProvider<FirestoreManager, FirestoreManagerState>((ref) {
  return FirestoreManager();
});

final gameManagerProvider =
    StateNotifierProvider<GameManager, GameManagerState>((ref) {
  return GameManager();
});

final notificationManagerProvider =
    StateNotifierProvider<NotificationManager, NotificationManagerState>((ref) {
  return NotificationManager();
});

final peacockManagerProvider =
    StateNotifierProvider<PeacockManager, PeacockManagerState>((ref) {
  return PeacockManager();
});

final reviewManagerProvider =
    StateNotifierProvider<ReviewManager, ReviewManagerState>((ref) {
  return ReviewManager();
});

final squadDataManagerProvider =
    StateNotifierProvider<SquadDataManager, SquadDataManagerState>((ref) {
  return SquadDataManager();
});

final squadManagerProvider =
    StateNotifierProvider<SquadManager, SquadManagerState>((ref) {
  return SquadManager();
});

final squadPersistenceManagerProvider = StateNotifierProvider<
    SquadPersistenceManager, SquadPersistenceManagerState>((ref) {
  return SquadPersistenceManager();
});

final squadUIManagerProvider =
    StateNotifierProvider<SquadUIManager, SquadUIManagerState>((ref) {
  return SquadUIManager();
});

final userManagerProvider =
    StateNotifierProvider<UserManager, UserManagerState>((ref) {
  return UserManager();
});
