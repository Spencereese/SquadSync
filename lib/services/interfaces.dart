import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

/// Interfaces for better testability and dependency injection

/// Interface for authentication service
abstract class IAuthService {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  void initialize({required Function(User?) onAuthStateChanged});
  Future<String?> loadDisplayName();
  Future<String?> loadProfileImage();
  Future<void> saveDisplayName(String displayName);
  Future<void> saveProfileImage(String? imageUrl);
  void dispose();
}

/// Interface for audio service
abstract class IAudioService {
  Future<void> initialize();
  Future<void> playVictorySound();
  Future<void> playAchievementSound(int streak);
  void dispose();
}

/// Interface for cache service
abstract class ICacheService {
  T getOrCompute<T>(String key, T Function() compute);
  void invalidate(String key);
  void invalidateAll();
  void setDefaultMaxAge(String key, Duration maxAge);
}

/// Interface for Firestore service
abstract class IFirestoreService {
  void registerField<T>(FirestoreFieldSerializer<T> serializer);
  void markFieldChanged(String fieldName);
  Future<void> updateFirestore({
    required Map<String, String> displayNameCache,
    bool force = false,
  });
  Future<Map<String, dynamic>?> loadFirestore(
      String collection, String document);

  // Voice room methods
  Stream<Map<String, dynamic>?> getVoiceRoomStream(String roomId);
  Future<void> updateVoiceRoom(String roomId, Map<String, dynamic> data);
  Future<void> updateVoiceParticipant(String roomId, String uid, Map<String, dynamic> data);
}

/// Interface for game manager
abstract class IGameManager {
  List<Map<String, dynamic>> get availableGames;
  Map<String, List<Map<String, dynamic>>> get gameLobbies;
  Set<String> get preferredPeacockGames;
  Set<String> get mutedGames;
  Set<String> get hiddenGames;
  Map<String, dynamic>? get currentGame;

  set availableGames(List<Map<String, dynamic>> value);
  set gameLobbies(Map<String, List<Map<String, dynamic>>> value);
  set preferredPeacockGames(Set<String> value);
  set mutedGames(Set<String> value);
  set hiddenGames(Set<String> value);
  set currentGame(Map<String, dynamic>? value);

  void togglePreferredPeacockGame(String gameName);
  void toggleMutedGame(String gameName);
  void toggleHiddenGame(String gameName);
}

/// Interface for squad manager
abstract class ISquadManager {
  Future<String> createSquad(String name);
  Future<bool> joinSquad(String code);
  Future<void> leaveSquad(String squadId);
  Future<Map<String, dynamic>?> getSquadData(String squadId);
  Future<void> updateSquadData(String squadId, Map<String, dynamic> data);
}

/// Interface for peacock manager
abstract class IPeacockManager {
  List<String> get peacockQueue;
  Map<String, Map<String, dynamic>?> get peacockTimers;

  set peacockQueue(List<String> value);
  set peacockTimers(Map<String, Map<String, dynamic>?> value);

  void startPeacockTimer(BuildContext context);
  void cancelPeacockTimer();
  void addToPeacockQueue(String player);
  void removeFromPeacockQueue(String player);
  void clearPeacockQueue();
}

/// Interface for user manager
abstract class IUserManager {
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> getUserProfile(String uid);
  Future<void> blockUser(String blockerUid, String blockedUid);
  Future<void> unblockUser(String blockerUid, String blockedUid);
  Future<Map<String, bool>> getBlockedUsers(String uid);
}

/// Interface for achievement manager
abstract class IAchievementManager {
  Map<String, int> get currentStreaks;
  Map<String, int> get highestStreaks;
  Map<String, Set<String>> get achievements;
  Map<String, Map<String, List<int>>> get dailyRatings;
  Map<String, Map<String, List<int>>> get allTimeRatings;
  Map<String, int> get complaints;

  set currentStreaks(Map<String, int> value);
  set highestStreaks(Map<String, int> value);
  set achievements(Map<String, Set<String>> value);
  set dailyRatings(Map<String, Map<String, List<int>>> value);
  set allTimeRatings(Map<String, Map<String, List<int>>> value);
  set complaints(Map<String, int> value);

  void updateStreak(String uid, int streak);
  void addAchievement(String uid, String achievement);
  void addComplaint(String uid);
  void addRating(String uid, String raterUid, int rating);
}

/// Interface for notification manager
abstract class INotificationManager {
  Future<void> showNotification(String title, String message);
  Future<void> scheduleNotification(
      String title, String message, DateTime time);
  Future<void> cancelNotification(int id);
}

/// Interface for Firestore manager
abstract class IFirestoreManager {
  Future<void> updateDocument(
      String collection, String document, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> getDocument(String collection, String document);
  Stream<DocumentSnapshot> listenToDocument(String collection, String document);
}

/// Interface for availability manager
abstract class IAvailabilityManager {
  List<Map<String, dynamic>> get scheduledTimes;
  bool get hasNewAvailability;

  set scheduledTimes(List<Map<String, dynamic>> value);

  void addScheduledTime(Map<String, dynamic> timeSlot);
  void removeScheduledTime(String id);
  void markAvailabilityAsSeen();
}

/// Interface for squad data manager
abstract class ISquadDataManager {
  // Data properties
  Map<String, List<String?>> get gameSquadSpots;
  Map<String, List<Map<String, dynamic>?>> get gameSpotTimers;
  Map<String, Map<String, String>> get gameStatuses;
  Map<String, String> get globalStatuses;
  List<String> get squadMemberUids;
  Map<String, String> get memberDisplayNames;
  List<String> get squadMembers;
  Map<String, String?> get memberProfileImages;
  Map<String, String?> get preferredModes;
  Map<String, Map<String, bool>> get userBlocks;
  Map<String, Map<String, int>> get dailyBanVotes;
  List<Map<String, dynamic>> get gameHistory;
  Map<String, String> get currentStreaks;
  Map<String, String> get highestStreaks;
  Map<String, Set<String>> get achievements;
  Map<String, Map<String, List<int>>> get dailyRatings;
  Map<String, Map<String, List<int>>> get allTimeRatings;
  Map<String, int> get complaints;
  Map<String, List<Map<String, dynamic>>> get bans;
  Map<String, Map<String, dynamic>?> get peacockTimers;
  List<String> get peacockQueue;
  List<String> get userSquadIds;
  String? get selectedSquadId;
  Map<String, Map<String, dynamic>> get userSquads;
  Map<String, dynamic>? get currentSquad;
  List<String> get filteredMembers;
  List<String> get blockedUsers;

  // Data operations
  List<String?> get squadSpots;
  List<Map<String, dynamic>?> get spotTimers;
  Map<String, String> get statuses;
  String getDisplayNameForUid(String uid);
  String? getUidForDisplayName(String displayName);
  Future<void> loadMemberDisplayNames();
  void invalidateCache();

  // Data update methods (for internal use)
  void setSquadMemberUids(List<String> uids);
  void setSelectedSquadId(String? squadId);
  void setCurrentSquadData(Map<String, dynamic>? data);
  void addUserSquad(String squadId, Map<String, dynamic> squadData);
  void removeUserSquad(String squadId);
  void updateGameSquadSpots(String gameName, List<String?> spots);
  void updateGameSpotTimers(
      String gameName, List<Map<String, dynamic>?> timers);
  void updateGameStatuses(String gameName, Map<String, String> statuses);
  void updateGlobalStatuses(Map<String, String> statuses);
}

/// Interface for squad UI manager
abstract class ISquadUIManager {
  // UI state properties
  bool get tiltEnabled;
  bool get hasNewAvailability;
  bool get hasNewSquadSpot;
  bool get hasUnreadMessages;
  Map<String, bool> get typing;
  DocumentSnapshot? get replyingTo;
  String? get profileImage;
  bool get isCreator;

  // UI state operations
  void updateTiltEnabled(bool value);
  void setNewAvailability(bool value);
  void setNewSquadSpot(bool value, [String? gameName]);
  void setReplyingTo(DocumentSnapshot? message);
  void setTyping(String userId, bool isTyping);
}

/// Interface for squad persistence manager
abstract class ISquadPersistenceManager {
  // Persistence state
  bool get isInitialized;
  bool get isInitialDataLoaded;
  Map<String, dynamic>? get currentGame;

  // Persistence operations
  Future<void> initialize(BuildContext context);
  void dispose();
  Future<void> leaveSquad();
  void selectSquad(String squadId);
  Future<void> updateFirestoreAsync({bool force = false});
  void updateFirestore({bool force = false});
  void markFieldChanged(String field);
}
