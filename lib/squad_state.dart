import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/ai_service.dart';
import 'managers/game_manager.dart';
import 'managers/squad_manager.dart';
import 'managers/peacock_manager.dart';
import 'managers/user_manager.dart';
import 'managers/achievement_manager.dart';
import 'managers/notification_manager.dart';
import 'managers/firestore_manager.dart';
import 'managers/availability_manager.dart';
import 'managers/squad_data_manager.dart';
import 'managers/squad_ui_manager.dart';
import 'managers/squad_persistence_manager.dart';
import 'managers/state_initializer.dart';
import 'managers/timer_state.dart';
import 'managers/squad_persistence_service.dart';
import 'managers/notification_coordinator.dart';
import 'managers/lobby_service.dart';
import 'managers/peacock_service.dart';
import 'managers/achievement_service.dart';
import 'managers/squad_membership_service.dart';
import 'managers/spot_management_service.dart';
import 'chat/chat_service.dart';
import 'services/services.dart';

/// Central state management coordinator for the SquadSync application.
///
/// This class serves as the main state coordinator that delegates operations
/// to specialized manager classes while maintaining a unified interface for
/// the UI layer. It handles initialization, synchronization, and coordination
/// between different aspects of squad management including games, users,
/// achievements, and real-time updates.
///
/// Key responsibilities:
/// - Initialize and coordinate all manager classes
/// - Handle Firebase authentication and data synchronization
/// - Provide unified access to squad data across different games
/// - Manage real-time updates and state persistence
/// - Coordinate between UI components and business logic managers
///
/// The class follows a delegation pattern where complex business logic
/// is handled by specialized managers (AchievementManager, UserManager, etc.)
/// while SquadState focuses on coordination and state management.
class SquadState with ChangeNotifier {
  // Persistence properties
  bool get isInitialized => persistenceManager.isInitialized;
  bool get isInitialDataLoaded => persistenceManager.isInitialDataLoaded;
  String? get profileImage => persistenceManager.profileImage;
  String? get displayName => persistenceManager.displayName;
  Map<String, String?> get memberProfileImages =>
      persistenceManager.memberProfileImages;

  // Game-specific squad spots: Map<gameName, List<String?>>
  Map<String, List<String?>> get gameSquadSpots => dataManager.gameSquadSpots;
  // Game-specific spot timers: Map<gameName, List<Map<String, dynamic>?>>
  Map<String, List<Map<String, dynamic>?>> get gameSpotTimers =>
      dataManager.gameSpotTimers;
  // Game-specific statuses: Map<gameName, Map<String, String>>
  Map<String, Map<String, String>> get gameStatuses => dataManager.gameStatuses;
  // Global statuses that persist across games (Walking, Strutting, etc.)
  Map<String, String> get globalStatuses => dataManager.globalStatuses;

  void _invalidateCache() {
    cacheService.invalidateAll();
  }

  // Legacy properties for backward compatibility (computed from current game)
  List<String?> get squadSpots {
    return cacheService.getOrCompute('squadSpots', () {
      final gameName = currentGame?['name'] ?? '';
      final rawSpots = gameSquadSpots[gameName] ?? [];
      return rawSpots
          .map((uid) => uid != null ? getDisplayNameForUid(uid) : null)
          .toList();
    });
  }

  List<Map<String, dynamic>?> get spotTimers {
    final gameName = currentGame?['name'] ?? '';
    if (!gameSpotTimers.containsKey(gameName)) {
      final maxSpots = currentGame?['maxSpots'] ?? 4;
      gameSpotTimers[gameName] = List.filled(maxSpots, null);
    }
    return gameSpotTimers[gameName] ?? [];
  }

  Map<String, String> get statuses {
    final rawStatuses = squadManager.getStatuses(
        currentGame?['name'] ?? '', globalStatuses, gameStatuses);
    // globalStatuses already has display names as keys, so no conversion needed
    return rawStatuses;
  }

  // New: Store member UIDs and provide display names dynamically
  List<String> get squadMemberUids => dataManager.squadMemberUids;
  Map<String, String> get _memberDisplayNames => dataManager.memberDisplayNames;

  // Legacy: Keep for backward compatibility, but now computed from UIDs
  List<String> get squadMembers {
    return cacheService.getOrCompute('squadMembers', () {
      return squadMemberUids.map((uid) => getDisplayNameForUid(uid)).toList();
    });
  }

  // Get display name for a UID, with caching
  String getDisplayNameForUid(String uid) {
    // Handle calling UIDs (format: uid_calling)
    if (uid.contains('_calling')) {
      final actualUid = uid.split('_calling')[0];
      // Check if this is the current user
      if (actualUid == FirebaseAuth.instance.currentUser?.uid &&
          displayName != null) {
        return displayName!;
      }
      if (_memberDisplayNames.containsKey(actualUid)) {
        return _memberDisplayNames[actualUid]!;
      }
    }

    // Check if this is the current user
    if (uid == FirebaseAuth.instance.currentUser?.uid && displayName != null) {
      return displayName!;
    }

    if (_memberDisplayNames.containsKey(uid)) {
      return _memberDisplayNames[uid]!;
    }
    // Return a user-friendly fallback instead of showing UID
    return 'User';
  }

  // Get UID for a display name (reverse lookup)
  String? getUidForDisplayName(String displayName) {
    return _memberDisplayNames.entries
            .firstWhere((entry) => entry.value == displayName,
                orElse: () => MapEntry('', ''))
            .key
            .isEmpty
        ? null
        : _memberDisplayNames.entries
            .firstWhere((entry) => entry.value == displayName)
            .key;
  }

  // Keep properties that are still needed directly in SquadState
  Map<String, bool> get typing => uiManager.typing;
  set typing(Map<String, bool> value) => uiManager.typing = value;
  bool get tiltEnabled => uiManager.tiltEnabled;
  set tiltEnabled(bool value) => uiManager.tiltEnabled = value;
  bool get hasNewSquadSpot => uiManager.hasNewSquadSpot;
  set hasNewSquadSpot(bool value) => uiManager.hasNewSquadSpot = value;
  bool get hasUnreadMessages => uiManager.hasUnreadMessages;
  set hasUnreadMessages(bool value) => uiManager.hasUnreadMessages = value;

  // New: Multiple squad tracking
  List<String> get userSquadIds => dataManager.userSquadIds;
  String? get selectedSquadId => dataManager.selectedSquadId;
  Map<String, Map<String, dynamic>> get userSquads => dataManager.userSquads;
  bool get isCreator =>
      selectedSquadId != null &&
      FirebaseAuth.instance.currentUser?.uid == currentSquadData?['creatorUid'];

  Map<String, dynamic>? get currentSquadData => dataManager.currentSquadData;
  StreamSubscription<DocumentSnapshot>? _squadSubscription;

  // Delegated data properties from dataManager
  List<Map<String, dynamic>> get gameHistory => dataManager.gameHistory;
  set gameHistory(List<Map<String, dynamic>> value) =>
      dataManager.gameHistory = value;
  Map<String, String?> get preferredModes => dataManager.preferredModes;
  set preferredModes(Map<String, String?> value) =>
      dataManager.preferredModes = value;
  Map<String, Map<String, bool>> get userBlocks => dataManager.userBlocks;
  set userBlocks(Map<String, Map<String, bool>> value) =>
      dataManager.userBlocks = value;
  Map<String, Map<String, int>> get dailyBanVotes => dataManager.dailyBanVotes;
  set dailyBanVotes(Map<String, Map<String, int>> value) =>
      dataManager.dailyBanVotes = value;
  Map<String, List<Map<String, dynamic>>> get bans => dataManager.bans;
  set bans(Map<String, List<Map<String, dynamic>>> value) =>
      dataManager.bans = value;
  List<Map<String, dynamic>> get availableGames => dataManager.availableGames;
  Map<String, List<Map<String, dynamic>>> get gameLobbies =>
      dataManager.gameLobbies;
  Set<String> get preferredPeacockGames => dataManager.preferredPeacockGames;
  Set<String> get mutedGames => dataManager.mutedGames;
  Set<String> get hiddenGames => dataManager.hiddenGames;
  Map<String, Map<String, dynamic>?> get peacockTimers =>
      dataManager.peacockTimers;
  List<String> get peacockQueue => dataManager.peacockQueue;
  List<Map<String, dynamic>> get scheduledTimes => dataManager.scheduledTimes;
  bool get hasNewAvailability => availabilityManager.hasNewAvailability;

  // Get active peacock alerts for a specific game
  Stream<List<Map<String, dynamic>>> getActivePeacockAlerts(String gameName) {
    return peacockService.getActivePeacockAlerts(gameName);
  }

  // Chat-related properties
  DocumentSnapshot? _replyingTo;
  DocumentSnapshot? get replyingTo => _replyingTo;

  // Current squad data getter
  Map<String, dynamic>? get currentSquad => dataManager.currentSquadData;

  // Filtered members getter excluding blocked users
  List<String> get getFilteredMembers {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final blocks = userBlocks[uid] ?? {};
    return squadMembers
        .where((member) => !blocks.containsKey(member) || !blocks[member]!)
        .toList();
  }

  // Get list of blocked users for current user
  List<String> get getBlockedUsers {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final blocks = userBlocks[uid] ?? {};
    return blocks.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _timer;

  BuildContext? context;

  // Manager instances for decomposed functionality
  final GameManager gameManager = GameManager();
  late final SquadManager squadManager = SquadManager();
  late final PeacockManager peacockManager = PeacockManager();
  final UserManager userManager = UserManager();
  late final AchievementManager achievementManager =
      AchievementManager(dataManager);
  final NotificationManager notificationManager = NotificationManager();
  final FirestoreManager firestoreManager = FirestoreManager();
  final AvailabilityManager availabilityManager = AvailabilityManager();
  final ChatService chatService = ChatService();

  // New managers
  final SquadDataManager dataManager = SquadDataManager();
  final SquadUIManager uiManager = SquadUIManager();
  final SquadPersistenceManager persistenceManager = SquadPersistenceManager();
  late final TimerState timerState;
  late final SquadPersistenceService persistenceService;

  // Services
  final AuthService authService = AuthService();
  final AudioService audioService = AudioService();
  final CacheService cacheService = CacheService();
  final FirestoreService firestoreService = FirestoreService();

  // State initializer for complex initialization logic
  late final StateInitializer stateInitializer;

  // Notification coordinator for managing all notification logic
  late final NotificationCoordinator notificationCoordinator;

  // Lobby service for managing lobby and game operations
  late final LobbyService lobbyService;

  // Peacock service for handling peacock-related queries
  late final PeacockService peacockService;

  // Achievement service for handling ratings and complaints
  late final AchievementService achievementService;

  // Squad membership service for handling squad joining/leaving operations
  late final SquadMembershipService squadMembershipService;

  // Spot management service for handling spot claiming, assignment, and removal
  late final SpotManagementService spotManagementService;

  SquadState() {
    timerState = TimerState(
      dataManager: dataManager,
      uiManager: uiManager,
      persistenceManager: persistenceManager,
    );
    // Listen to TimerState changes and propagate them
    timerState.addListener(notifyListeners);
    persistenceService = SquadPersistenceService(
      dataManager: dataManager,
      uiManager: uiManager,
      persistenceManager: persistenceManager,
      firestoreService: firestoreService,
      cacheService: cacheService,
    );

    // Initialize state initializer with callback for state changes
    stateInitializer = StateInitializer(
      dataManager: dataManager,
      persistenceManager: persistenceManager,
      onStateChanged: notifyListeners,
    );

    // Initialize notification coordinator
    notificationCoordinator = NotificationCoordinator(
      notificationManager: notificationManager,
      uiManager: uiManager,
      availabilityManager: availabilityManager,
    );

    // Initialize lobby service
    lobbyService = LobbyService(
      dataManager: dataManager,
      persistenceService: persistenceService,
    );

    // Initialize peacock service
    peacockService = PeacockService();

    // Initialize achievement service
    achievementService = AchievementService(achievementManager);

    // Initialize squad membership service
    squadMembershipService =
        SquadMembershipService(squadManager, stateInitializer);

    // Initialize spot management service
    spotManagementService = SpotManagementService(
      dataManager: dataManager,
      persistenceManager: persistenceManager,
      uiManager: uiManager,
      cacheService: cacheService,
      getSquadSpots: () => squadSpots,
      getGameSquadSpots: () => gameSquadSpots,
      getGameSpotTimers: () => gameSpotTimers,
      getSpotTimers: () => spotTimers,
      getPeacockTimers: () => peacockTimers,
      getPeacockQueue: () => peacockQueue,
      getGlobalStatuses: () => globalStatuses,
      getCurrentGame: () => currentGame,
      getDisplayName: () => displayName,
      getUidForDisplayName: getUidForDisplayName,
    );
  }

  // Ensure currentGame is always valid
  Map<String, dynamic>? get currentGame {
    // Return the stored currentGame if it exists, regardless of availableGames
    if (dataManager.currentGame != null) {
      return dataManager.currentGame;
    }
    // Return first available game as fallback
    return availableGames.isNotEmpty ? availableGames.first : null;
  }

  // Private setter for internal use
  set currentGame(Map<String, dynamic>? value) {
    dataManager.currentGame = value;
    // Ensure squadSpots array is properly sized for the new game
    if (value != null) {
      final gameName = value['name'] ?? '';
      final maxSpots = value['maxSpots'] ?? 4;
      if (!dataManager.gameSquadSpots.containsKey(gameName)) {
        dataManager.gameSquadSpots[gameName] =
            List<String?>.filled(maxSpots, null);
      } else if (dataManager.gameSquadSpots[gameName]!.length != maxSpots) {
        // Resize the array if maxSpots changed
        final currentSpots = dataManager.gameSquadSpots[gameName]!;
        dataManager.gameSquadSpots[gameName] =
            List<String?>.filled(maxSpots, null);
        // Copy existing spots (up to the new maxSpots)
        for (int i = 0; i < currentSpots.length && i < maxSpots; i++) {
          dataManager.gameSquadSpots[gameName]![i] = currentSpots[i];
        }
      }
    }
    notifyListeners();
  }

  // Getters for delegated properties
  Map<String, int> get currentStreaks => dataManager.currentStreaks;
  Map<String, int> get highestStreaks => dataManager.highestStreaks;
  Map<String, int> get complaints => dataManager.complaints;
  Map<String, Set<String>> get achievements => dataManager.achievements;
  Map<String, Map<String, List<int>>> get dailyRatings =>
      dataManager.dailyRatings;
  Map<String, Map<String, List<int>>> get allTimeRatings =>
      dataManager.allTimeRatings;

  // Setters for delegated properties
  set currentStreaks(Map<String, int> value) {
    dataManager.currentStreaks = value;
  }

  set highestStreaks(Map<String, int> value) {
    dataManager.highestStreaks = value;
  }

  set complaints(Map<String, int> value) {
    dataManager.complaints = value;
  }

  set achievements(Map<String, Set<String>> value) {
    dataManager.achievements = value;
  }

  set dailyRatings(Map<String, Map<String, List<int>>> value) {
    dataManager.dailyRatings = value;
  }

  set allTimeRatings(Map<String, Map<String, List<int>>> value) {
    dataManager.allTimeRatings = value;
  }

  set selectedSquadId(String? value) {
    dataManager.selectedSquadId = value;
    notifyListeners();
  }

  set userSquadIds(List<String> value) {
    dataManager.userSquadIds = value;
  }

  set userSquads(Map<String, Map<String, dynamic>> value) {
    dataManager.userSquads = value;
  }

  set currentSquadData(Map<String, dynamic>? value) {
    dataManager.currentSquadData = value;
  }

  set peacockQueue(List<String> value) {
    peacockManager.peacockQueue = value;
  }

  set peacockTimers(Map<String, Map<String, dynamic>?> value) {
    peacockManager.peacockTimers = value;
  }

  set availableGames(List<Map<String, dynamic>> value) {
    dataManager.availableGames = value;
    gameManager.availableGames = value;
  }

  set preferredPeacockGames(Set<String> value) {
    gameManager.preferredPeacockGames = value;
  }

  set mutedGames(Set<String> value) {
    gameManager.mutedGames = value;
  }

  set hiddenGames(Set<String> value) {
    gameManager.hiddenGames = value;
  }

  /// Initializes the SquadState and all dependent managers and services.
  ///
  /// This method performs the complete initialization sequence for the application:
  /// 1. Sets up the build context for UI operations
  /// 2. Initializes local state and data structures
  /// 3. Configures caching with appropriate timeouts
  /// 4. Sets up Firebase authentication state change handling
  /// 5. Loads user profile and squad data
  /// 6. Initializes real-time listeners for squad changes
  ///
  /// [ctx] The build context used for UI operations and provider access
  ///
  /// This method is idempotent - calling it multiple times will only
  /// perform initialization once.
  Future<void> initialize(BuildContext ctx) async {
    if (persistenceManager.isInitialized) {
      debugPrint('SquadState already initialized, skipping');
      return;
    }

    context = ctx;
    await stateInitializer.initializeUserState();
    stateInitializer.initializeData();
    // Removed _syncWithFirestore() call from here - will be called after auth

    // Initialize services
    await audioService.initialize();
    cacheService.setDefaultMaxAge(
        'squadSpots', const Duration(milliseconds: 100));
    cacheService.setDefaultMaxAge(
        'squadMembers', const Duration(milliseconds: 100));

    // Initialize auth service
    authService.initialize(onAuthStateChanged: (user) async {
      if (user != null) {
        // Start Firestore sync only after authentication
        persistenceService.syncWithFirestore();

        // Load display name using AuthService
        persistenceManager.displayName =
            await authService.loadDisplayName() ?? 'User';
        persistenceManager.profileImage = await authService.loadProfileImage();

        // Cache the current user's display name
        dataManager.memberDisplayNames[user.uid] =
            persistenceManager.displayName!;
        await stateInitializer.loadUserSquads(user.uid);
        stateInitializer.listenToSquadChanges();
        persistenceManager.isInitialDataLoaded =
            true; // Mark initial data loading as complete
        notifyListeners();
      } else {
        // User signed out - stop Firestore sync
        _squadSubscription?.cancel();
        _squadSubscription = null;

        persistenceManager.displayName = null;
        persistenceManager.profileImage = null;
        userSquadIds.clear();
        selectedSquadId = null;
        currentSquadData = null;
        dataManager.squadMemberUids = [];
        _invalidateCache();
        persistenceManager.isInitialDataLoaded =
            true; // Mark initial data loading as complete
        notifyListeners();
      }
    });

    // Initialize timer service
    timerState.initialize();

    // Schedule daily ban vote reset
    _scheduleDailyReset();

    // Mark as initialized after setting up listeners
    persistenceManager.isInitialized = true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _squadSubscription?.cancel();
    timerState.removeListener(notifyListeners);
    timerState.dispose();
    persistenceService.dispose();
    audioService.dispose();
    authService.dispose();
    super.dispose();
  }

  // Reset method for sign out - clears all state and allows re-initialization
  void reset() {
    // Cancel all subscriptions and timers
    _timer?.cancel();
    _timer = null;
    _squadSubscription?.cancel();
    _squadSubscription = null;

    // Reset initialization flag to allow re-initialization
    persistenceManager.isInitialized = false;

    // Clear all dataManager properties
    dataManager.squadMemberUids.clear();
    dataManager.memberDisplayNames.clear();
    dataManager.gameSquadSpots.clear();
    dataManager.gameSpotTimers.clear();
    dataManager.gameStatuses.clear();
    dataManager.globalStatuses.clear();
    dataManager.gameHistory.clear();
    dataManager.preferredModes.clear();
    dataManager.userBlocks.clear();
    dataManager.dailyBanVotes.clear();
    dataManager.userSquadIds.clear();
    dataManager.selectedSquadId = null;
    dataManager.userSquads.clear();
    dataManager.currentSquadData = null;
    dataManager.availableGames.clear();
    dataManager.gameLobbies.clear();
    dataManager.preferredPeacockGames.clear();
    dataManager.mutedGames.clear();
    dataManager.hiddenGames.clear();
    dataManager.currentStreaks.clear();
    dataManager.highestStreaks.clear();
    dataManager.achievements.clear();
    dataManager.dailyRatings.clear();
    dataManager.allTimeRatings.clear();
    dataManager.complaints.clear();
    dataManager.bans.clear();
    dataManager.scheduledTimes.clear();
    dataManager.peacockTimers.clear();
    dataManager.peacockQueue.clear();

    // Clear cache
    _invalidateCache();

    // Reset services
    audioService.dispose();
    authService.dispose();

    // Clear context reference
    context = null;

    notifyListeners();
  }

  // New: Create/join wrappers
  Future<String> createSquad(String name) async {
    final squadId = await squadManager.createSquad(name);
    userSquadIds.add(squadId);
    selectedSquadId = squadId; // Select the new squad
    stateInitializer.loadSquadData(squadId);
    notifyListeners();
    return squadId;
  }

  Future<bool> joinSquad(String code) async {
    final success = await squadManager.joinSquad(code);
    if (success) {
      // Find the squad ID from the code
      final query = await _firestore
          .collection('squads')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final squadId = query.docs.first.id;
        if (!userSquadIds.contains(squadId)) {
          userSquadIds.add(squadId);
        }
        selectedSquadId = squadId; // Select the joined squad
        stateInitializer.loadSquadData(squadId);
        notifyListeners();
      }
    }
    return success;
  }

  /// Join a chat group using an invite code
  Future<bool> joinChatGroup(String code) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    try {
      // First, try to find the invite in the chat_groups collection
      // We need to search through all chat_groups/*/invites/* documents
      final invitesQuery = await _firestore
          .collectionGroup('invites')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (invitesQuery.docs.isEmpty) {
        throw Exception('Invalid invite code');
      }

      final inviteDoc = invitesQuery.docs.first;
      final inviteData = inviteDoc.data();

      // Check if invite is expired
      final expiresAt = inviteData['expiresAt'];
      if (expiresAt != null) {
        final expiryDate = DateTime.parse(expiresAt);
        if (DateTime.now().isAfter(expiryDate)) {
          throw Exception('Invite code has expired');
        }
      }

      // Check usage limit
      final maxUses = inviteData['maxUses'] ?? 50;
      final currentUses = inviteData['uses'] ?? 0;
      if (currentUses >= maxUses) {
        throw Exception('Invite code has reached its usage limit');
      }

      // Get the group ID from the document path
      // Path format: chat_groups/{groupId}/invites/{code}
      final pathSegments = inviteDoc.reference.path.split('/');
      if (pathSegments.length < 4 || pathSegments[0] != 'chat_groups') {
        throw Exception('Invalid invite document path');
      }
      final groupId = pathSegments[1];

      // Get the group data to check membership
      final groupDoc =
          await _firestore.collection('chat_groups').doc(groupId).get();

      if (!groupDoc.exists) {
        throw Exception('Group no longer exists');
      }

      final groupData = groupDoc.data()!;
      final members = List<String>.from(groupData['members'] ?? []);

      // Check if user is already a member
      if (members.contains(currentUser.uid)) {
        return true; // Already a member
      }

      // Add user to the group
      await _firestore.collection('chat_groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([currentUser.uid]),
        'memberCount': FieldValue.increment(1),
      });

      // Create a reference document in user's chat_groups subcollection
      final userGroupRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('chat_groups')
          .doc(groupId);

      // Copy relevant group data to user's subcollection
      await userGroupRef.set({
        'name': groupData['name'] ?? 'Unnamed Group',
        'description': groupData['description'] ?? '',
        'imageUrl': groupData['imageUrl'],
        'isPublic': groupData['isPublic'] ?? false,
        'memberCount': groupData['memberCount'] ?? 1,
        'createdBy': groupData['createdBy'],
        'createdAt': groupData['createdAt'],
        'lastMessage': null,
        'lastMessageTime': null,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Update invite usage count
      await inviteDoc.reference.update({
        'uses': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      debugPrint('Error joining chat group: $e');
      rethrow; // Re-throw to let caller handle the error
    }
  }

  Future<void> leaveSquad() async {
    await squadMembershipService.leaveSquad(
      selectedSquadId,
      userSquadIds,
      userSquads,
      () {
        selectedSquadId = userSquadIds.isNotEmpty ? userSquadIds.first : null;
        currentSquadData = null;
        _squadSubscription?.cancel();
        notifyListeners();
      },
    );
  }

  /// Leave a chat group
  Future<void> leaveChatGroup(String groupId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    try {
      // First, check if this is a public group in the main chat_groups collection
      final groupDoc =
          await _firestore.collection('chat_groups').doc(groupId).get();

      if (groupDoc.exists) {
        // This is a public group - remove user from it
        final groupData = groupDoc.data()!;
        final members = List<String>.from(groupData['members'] ?? []);

        // Check if user is actually a member
        if (!members.contains(currentUser.uid)) {
          return; // Already not a member
        }

        // Remove user from the group
        await _firestore.collection('chat_groups').doc(groupId).update({
          'members': FieldValue.arrayRemove([currentUser.uid]),
          'memberCount': FieldValue.increment(-1),
        });
      } else {
        // This might be a user-specific group or the group no longer exists
        // Check if it exists in user's subcollection
        final userGroupDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('chat_groups')
            .doc(groupId)
            .get();

        if (!userGroupDoc.exists) {
          throw Exception('Group not found');
        }

        // For user-specific groups, we might want to delete them entirely
        // since they are owned by the user. But for now, let's just remove
        // the reference from user's subcollection
      }

      // Always remove the group from user's chat_groups subcollection
      // This ensures the group disappears from their UI
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('chat_groups')
          .doc(groupId)
          .delete();

      notifyListeners();
    } catch (e) {
      debugPrint('Error leaving chat group: $e');
      rethrow; // Re-throw to let caller handle the error
    }
  }

  // Public: Select a squad
  void selectSquad(String squadId) {
    debugPrint('DEBUG SquadState.selectSquad: called with squadId=$squadId');
    debugPrint('DEBUG SquadState.selectSquad: userSquadIds=$userSquadIds');
    debugPrint(
        'DEBUG SquadState.selectSquad: userSquads keys=${userSquads.keys}');
    squadMembershipService.selectSquad(
      squadId,
      userSquadIds,
      userSquads,
      () {
        selectedSquadId = squadId;
        // Load squad data from userSquads if available, otherwise it will be loaded when accessed
        currentSquadData = userSquads[squadId];
        notifyListeners();
        debugPrint(
            'DEBUG SquadState.selectSquad: completed, selectedSquadId=$selectedSquadId');
      },
    );
  }

  // Get squad data by ID
  Map<String, dynamic>? getSquadById(String squadId) {
    return userSquads[squadId];
  }

  void _markFieldChanged(String field) {
    firestoreService.markFieldChanged(field);
  }

  Future<void> updateFirestoreAsync({bool force = false}) async {
    await persistenceManager.updateFirestoreAsync(
      memberDisplayNames: _memberDisplayNames,
      force: force,
    );
  }

  void updateFirestore({bool force = false}) {
    persistenceService.updateFirestore(force: force);
  }

  Future<void> submitComplaint({
    required String targetMember,
    required String reason,
    required String category,
    required String submittedBy,
  }) async {
    await achievementService.submitComplaint(
      submittedBy: submittedBy,
      targetMember: targetMember,
      reason: reason,
      category: category,
      squadMembers: squadMembers,
    );
    notifyListeners();
  }

  Future<void> submitRatings({
    required String targetMember,
    required Map<String, int?> ratings,
    required String submittedBy,
  }) async {
    // Check if user is banned
    if (isBanned(submittedBy)) {
      throw Exception('You are currently banned and cannot submit ratings');
    }
    await achievementService.submitRatings(
      submittedBy: submittedBy,
      targetMember: targetMember,
      ratings: ratings,
      squadMembers: squadMembers,
      gameHistory: gameHistory,
    );
    notifyListeners();
  }

  // Add this method to SquadState
  Future<bool> hasRatedMember(String targetMember, String submittedBy) async {
    return achievementService.hasRatedMember(
        targetMember, submittedBy, gameHistory);
  }

  // Existing canRateMember (ensure public)
  Future<bool> canRateMember(String targetMember, String submittedBy) async {
    return achievementService.canRateMember(
        targetMember, submittedBy, gameHistory);
  }

  /// Gets average rating for a member in a category
  double getAverageRating(String member, String category,
      {bool daily = false}) {
    final memberRatings = daily ? dailyRatings[member] : allTimeRatings[member];
    if (memberRatings == null) return 0.0;
    final ratings = memberRatings[category];
    if (ratings == null || ratings.isEmpty) return 0.0;
    return ratings.reduce((a, b) => a + b) / ratings.length;
  }

  /// Gets all ratings for a member as a map for display
  Map<String, double> getMemberRatings(String member, {bool daily = false}) {
    return {
      'Vibes': getAverageRating(member, 'Vibes', daily: daily),
      'Comms': getAverageRating(member, 'Comms', daily: daily),
      'Gunny': getAverageRating(member, 'Gunny', daily: daily),
      'Wingman': getAverageRating(member, 'Wingman', daily: daily),
    };
  }

  // New methods for tilt and notifications
  void updateTiltEnabled(bool value) {
    tiltEnabled = value;
    notifyListeners();
  }

  void setNewAvailability(bool value) {
    availabilityManager.setNewAvailability(value);
  }

  void setNewSquadSpot(bool value, [String? gameName]) {
    notificationCoordinator.notifyNewSquadSpot(
      gameName: gameName,
      isGameMuted: gameName != null ? isGameMuted(gameName) : false,
      isGameHidden: gameName != null ? isGameHidden(gameName) : false,
    );
    notifyListeners();
  }

  void setUnreadMessages(bool value) {
    hasUnreadMessages = value;
    notifyListeners();
  }

  void clearNotifications(int tabIndex) {
    notificationCoordinator.clearNotificationsForTab(tabIndex);
    notifyListeners();
  }

  void setReplyingTo(DocumentSnapshot? message) {
    _replyingTo = message;
    notifyListeners();
  }

  void clearReplyingTo() {
    _replyingTo = null;
    notifyListeners();
  }

  Future<void> sendReply(String messageId, String text) async {
    final squadId = selectedSquadId;
    if (squadId == null || _replyingTo == null) return;

    await chatService.sendReply(messageId, text, squadId);
    clearReplyingTo();
  }

  Future<void> deleteMessage(String messageId) async {
    final squadId = selectedSquadId;
    if (squadId == null) return;

    await chatService.deleteMessage(messageId, squadId,
        chatType: ChatType.squad);
  }

  void updatePreferredMode(String user, String? mode) {
    preferredModes[user] = mode;
    _markFieldChanged('preferredModes');
    updateFirestore(force: true);
    notifyListeners();
  }

  Future<void> blockUser(String user) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await userManager.blockUser(uid, user);
    notifyListeners();
  }

  Future<void> unblockUser(String user) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await userManager.unblockUser(uid, user);
    notifyListeners();
  }

  Future<void> removePinnedGame(String gameName) async {
    await userManager.removePinnedGame(gameName);
    notifyListeners();
  }

  void updateProfileImage(String url) {
    persistenceManager.profileImage = url;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _firestore
          .collection('users')
          .doc(user.uid)
          .set({'profileImage': url}, SetOptions(merge: true));
    }
    notifyListeners();
  }

  void updateDisplayName(String name) async {
    persistenceManager.displayName = name;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({'displayName': name}, SetOptions(merge: true));
    }
    // Also save to SharedPreferences for persistence
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yourName', name);
    notifyListeners();
  }

  Future<void> removeFromPeacock(String player) async {
    await peacockManager.removeFromPeacock(player);
    notifyListeners();
  }

  void claimSpot(int index) {
    final userName = displayName;
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userName != null && userUid != null) {
      // Check if user is currently banned
      if (isBanned(userName)) {
        ScaffoldMessenger.of(context!).showSnackBar(
          const SnackBar(
              content: Text('You are currently banned and cannot claim spots')),
        );
        return;
      }
      dataManager.claimSpot(index, userName, userUid);
      dataManager.globalStatuses[userName] = 'Calling'; // Changed from 'Ready'
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
      _markFieldChanged('statuses');
      uiManager.setNewSquadSpot(true, currentGame?['name'] ?? '');
      updateFirestoreAsync(force: true);
      notifyListeners();
    }
  }

  void claimSpotForGame(int index, String gameName, {int? maxSpots}) {
    final userName = displayName;
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userName != null && userUid != null) {
      dataManager.callSpotForGame(index, userName, userUid, gameName,
          maxSpots: maxSpots);
      persistenceManager.markFieldChanged('squadSpots');
      persistenceManager.markFieldChanged('spotTimers');
      persistenceManager.markFieldChanged('globalStatuses');
      _markFieldChanged('statuses');
      uiManager.setNewSquadSpot(true, gameName);
      updateFirestoreAsync(force: true);
      notifyListeners();
    }
  }

  void callSpotForGame(int index, String gameName, {int? maxSpots}) {
    debugPrint(
        'callSpotForGame called: index=$index, gameName=$gameName, maxSpots=$maxSpots');
    final userName = displayName;
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userName != null && userUid != null) {
      debugPrint(
          'Calling dataManager.callSpotForGame with userName=$userName, userUid=$userUid');
      dataManager.callSpotForGame(index, userName, userUid, gameName,
          maxSpots: maxSpots);
      persistenceManager.markFieldChanged('squadSpots');
      persistenceManager.markFieldChanged('spotTimers');
      persistenceManager.markFieldChanged('globalStatuses');
      _markFieldChanged('statuses');
      uiManager.setNewSquadSpot(true, gameName);
      debugPrint('About to call updateFirestoreAsync');
      updateFirestoreAsync(force: true).then((_) {
        debugPrint('updateFirestoreAsync completed successfully');
      }).catchError((error) {
        debugPrint('updateFirestoreAsync failed: $error');
      });
      notifyListeners();
      debugPrint('callSpotForGame completed');
    } else {
      debugPrint(
          'callSpotForGame failed: userName=$userName, userUid=$userUid');
    }
  }

  void lockCalledSpot(String gameName, int index) {
    debugPrint('lockCalledSpot called: gameName=$gameName, index=$index');
    final userName = displayName;
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userName != null && userUid != null) {
      debugPrint(
          'Calling dataManager.lockCalledSpot with userName=$userName, userUid=$userUid');
      dataManager.lockCalledSpot(gameName, index, userName, userUid);
      persistenceManager.markFieldChanged('squadSpots');
      persistenceManager.markFieldChanged('spotTimers');
      persistenceManager.markFieldChanged('globalStatuses');
      _markFieldChanged('statuses');
      debugPrint('About to call updateFirestoreAsync for lock');
      updateFirestoreAsync(force: true).then((_) {
        debugPrint('updateFirestoreAsync completed successfully for lock');
      }).catchError((error) {
        debugPrint('updateFirestoreAsync failed for lock: $error');
      });
      notifyListeners();
      debugPrint('lockCalledSpot completed');
    } else {
      debugPrint('lockCalledSpot failed: userName=$userName, userUid=$userUid');
    }
  }

  void startPeacockTimer(BuildContext dialogContext) {
    final userName = displayName;
    if (userName != null &&
        userName != 'User' &&
        squadSpots.contains(userName)) {
      // If user is already in a spot, remove them from it first
      final gameName = currentGame?['name'] ?? '';
      int spotIndex = squadSpots.indexOf(userName);
      if (spotIndex != -1 && gameSquadSpots.containsKey(gameName)) {
        gameSquadSpots[gameName]![spotIndex] = null;
        gameSpotTimers[gameName]![spotIndex] = null;
        _markFieldChanged('squadSpots');
        _markFieldChanged('spotTimers');
        _markFieldChanged('globalStatuses');
        _markFieldChanged('statuses');
        cacheService.invalidate('squadSpots');
        setNewSquadSpot(true, gameName); // Trigger squad spot notification
      }
    }
    // Delegate to peacock manager
    peacockManager.startPeacockTimer(dialogContext);
  }

  void updateTypingStatus(String user, bool isTyping) {
    if (typing[user] != isTyping) {
      typing[user] = isTyping;
      _markFieldChanged('typing');
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  String? getTypingUser() {
    return typing.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .firstOrNull;
  }

  void assignSpot(int index, String player) {
    final playerUid = getUidForDisplayName(player);
    final gameName = currentGame?['name'] ?? '';

    if (playerUid != null) {
      // Initialize game data structures if needed
      if (!gameSquadSpots.containsKey(gameName)) {
        final maxSpots = currentGame?['maxSpots'] ?? 4;
        gameSquadSpots[gameName] = List.filled(maxSpots, null);
        gameSpotTimers[gameName] = List.filled(maxSpots, null);
      }

      gameSquadSpots[gameName]![index] = playerUid;
      gameSpotTimers[gameName]![index] = {
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'duration': 300,
      };
      globalStatuses[player] =
          'Ready'; // Set global status to Ready during timer
      if (peacockTimers.containsKey(player)) {
        peacockTimers.remove(player);
        _markFieldChanged('peacockTimers');
      } else if (peacockQueue.contains(player)) {
        peacockQueue.remove(player);
        _markFieldChanged('peacockQueue');
      }
      _markFieldChanged('squadSpots');
      _markFieldChanged('spotTimers');
      _markFieldChanged('globalStatuses');
      _markFieldChanged('statuses');
      cacheService.invalidate('squadSpots');
      setNewSquadSpot(true, gameName); // Trigger squad spot notification
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  void removeSpot(int index) {
    debugPrint('removeSpot called: index=$index');
    final gameName = currentGame?['name'] ?? '';
    debugPrint('removeSpot: gameName=$gameName');
    if (gameSquadSpots.containsKey(gameName) &&
        index < gameSquadSpots[gameName]!.length) {
      final playerUid = gameSquadSpots[gameName]![index];
      debugPrint('removeSpot: playerUid=$playerUid');
      if (playerUid != null) {
        final player = getDisplayNameForUid(playerUid);
        debugPrint('removeSpot: player=$player');
        gameSquadSpots[gameName]![index] = null;
        gameSpotTimers[gameName]![index] = null;
        if (peacockTimers.containsKey(player)) {
          globalStatuses[player] = 'Strutting';
        } else if (peacockQueue.contains(player)) {
          globalStatuses[player] = 'Waiting';
        } else {
          globalStatuses[player] = 'Offline';
        }
        _markFieldChanged('globalStatuses');
        _markFieldChanged('statuses');
        _markFieldChanged('squadSpots');
        _markFieldChanged('spotTimers');
        cacheService.invalidate('squadSpots');
        debugPrint('About to call updateFirestore for removeSpot');
        updateFirestore(force: true);
        notifyListeners();
        debugPrint('removeSpot completed successfully');
      } else {
        debugPrint('removeSpot: playerUid was null, no action taken');
      }
    } else {
      debugPrint(
          'removeSpot: conditions not met - gameSquadSpots.containsKey(gameName)=${gameSquadSpots.containsKey(gameName)}, index < gameSquadSpots[gameName]!.length=${index < gameSquadSpots[gameName]!.length}');
    }
  }

  void lockSpot(int index) {
    final gameName = currentGame?['name'] ?? '';
    if (gameSpotTimers.containsKey(gameName) &&
        index < gameSpotTimers[gameName]!.length) {
      // Set timer to track when player went in game (counting up)
      gameSpotTimers[gameName]![index] = {
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'duration': -1, // Special value to indicate counting up
      };
      final playerUid = gameSquadSpots[gameName]?[index];
      if (playerUid != null) {
        final player = getDisplayNameForUid(playerUid);
        globalStatuses[player] = 'in game';
        _markFieldChanged('globalStatuses');
        _markFieldChanged('statuses');
        _markFieldChanged('spotTimers');
        updateFirestore(force: true);
        notifyListeners();
      }
    }
  }

  Future<void> recordWin() async {
    await achievementManager.recordWin(
      squadSpots: squadSpots,
      statuses: statuses,
      gameHistory: gameHistory,
    );
    await audioService.playVictorySound();
    notificationCoordinator.notifySquadWin(squadSpots, statuses);
    _markFieldChanged('currentStreaks');
    _markFieldChanged('gameHistory');
    _markFieldChanged('achievements');
    updateFirestore(force: true);
    notifyListeners();
  }

  void recordLoss() {
    achievementManager.recordLoss(
      squadSpots: squadSpots,
      spotTimers: spotTimers,
      currentStreaks: currentStreaks,
      gameHistory: gameHistory,
    );
    _markFieldChanged('currentStreaks');
    _markFieldChanged('gameHistory');
    updateFirestore(force: true);
    notifyListeners();
  }

  void clearAllSpots() {
    final currentGameName = dataManager.currentGame?['name'] ?? 'Warzone';
    final maxSpots = dataManager.currentGame?['maxSpots'] ?? 4;
    dataManager.gameSquadSpots[currentGameName] = List.filled(maxSpots, null);
    dataManager.gameSpotTimers[currentGameName] = List.filled(maxSpots, null);
    dataManager.peacockTimers.clear();
    dataManager.peacockQueue.clear();
    for (var member in squadMembers) {
      if (gameStatuses[currentGameName]?[member] == 'Strutting' ||
          gameStatuses[currentGameName]?[member] == 'Walking') {
        gameStatuses[currentGameName]?[member] = 'Ready';
      } else {
        gameStatuses[currentGameName]?[member] = 'Offline';
      }
    }
    _markFieldChanged('squadSpots');
    _markFieldChanged('spotTimers');
    _markFieldChanged('peacockTimers');
    _markFieldChanged('peacockQueue');
    _markFieldChanged('statuses');
    updateFirestore(force: true);
    notifyListeners();
  }

  void resetTimers() {
    for (int i = 0; i < spotTimers.length; i++) {
      if (spotTimers[i] != null && squadSpots[i] != null) {
        spotTimers[i] = {
          'startTime': DateTime.now().millisecondsSinceEpoch,
          'duration': 300,
        };
      }
    }
    peacockTimers.forEach((player, timer) {
      if (timer != null) {
        timer['startTime'] = DateTime.now().millisecondsSinceEpoch;
        timer['duration'] = 3600;
      }
    });
    _markFieldChanged('spotTimers');
    _markFieldChanged('peacockTimers');
    notifyListeners();
  }

  void reupPeacock() {
    peacockManager.reupPeacock();
  }

  void claimPeacockDialog() {
    peacockManager.claimPeacockDialog();
  }

  void managePeacock() {
    peacockManager.managePeacock();
  }

  void addBan(String player, String voter) {
    // Initialize daily ban votes if not exists
    if (!dailyBanVotes.containsKey(player)) {
      dailyBanVotes[player] = {};
    }
    // Add vote (will overwrite if already voted today)
    dailyBanVotes[player]![voter] = DateTime.now().millisecondsSinceEpoch;
    _markFieldChanged('dailyBanVotes');
    notifyListeners();
  }

  void _resetDailyBanVotes() {
    dailyBanVotes.clear();
    _markFieldChanged('dailyBanVotes');
    notifyListeners();
  }

  // Reset ban votes daily at midnight
  void _scheduleDailyReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = tomorrow.difference(now);

    Future.delayed(timeUntilMidnight, () {
      _resetDailyBanVotes();
      // Schedule next reset
      _scheduleDailyReset();
    });
  }

  int getBanVoteCount(String player) {
    // Count explicit votes (excluding self-votes)
    int explicitVotes = 0;
    final playerVotes = dailyBanVotes[player];
    if (playerVotes != null) {
      // Only count votes from other players
      explicitVotes = playerVotes.keys.where((voter) => voter != player).length;
    }

    // Add votes from blocked users (mutual blocking counts as vote for each other)
    for (final member in squadMembers) {
      if (member != player && // Exclude self
          isUserBlockedBy(player, member) &&
          isUserBlockedBy(member, player)) {
        // Mutual block - each counts as a vote for the other
        explicitVotes += 1;
      }
    }

    return explicitVotes;
  }

  bool isBanned(String player) {
    final totalEligibleVoters =
        squadMembers.length - 1; // Exclude the player themselves
    final voteCount = getBanVoteCount(player);
    // Banned if more than half the other squad members vote for ban
    return totalEligibleVoters > 0 && voteCount > (totalEligibleVoters / 2);
  }

  int getBanDuration(String player) {
    final totalEligibleVoters =
        squadMembers.length - 1; // Exclude the player themselves
    final voteCount = getBanVoteCount(player);

    if (voteCount >= totalEligibleVoters) {
      // All other users voted - 48 hour ban
      return 48 * 3600 * 1000;
    } else if (voteCount > (totalEligibleVoters / 2)) {
      // More than half voted - 24 hour ban
      return 24 * 3600 * 1000;
    }
    return 0;
  }

  int getBanCount(String player) {
    return bans[player]?.length ?? 0;
  }

  // Check if user A is blocked by user B
  bool isUserBlockedBy(String targetUser, String blocker) {
    final blockerUid = getUidForDisplayName(blocker);
    return userBlocks[blockerUid]?[targetUser] ?? false;
  }

  // Get the game name where a player has claimed a spot
  String? getPlayerGame(String player) {
    // First check if player is in claimed spots
    for (final gameName in gameSquadSpots.keys) {
      if (gameSquadSpots[gameName]?.contains(player) ?? false) {
        return gameName;
      }
    }

    // Then check if player is playing solo
    final status = globalStatuses[player];
    if (status != null && status.contains('(Solo)')) {
      // Extract game name from "Playing: GameName (Solo)"
      final match = RegExp(r'Playing: (.+) \(Solo\)').firstMatch(status);
      if (match != null) {
        return match.group(1);
      }
    } else if (status == 'Playing Solo') {
      return 'Solo';
    }

    return null;
  }

  bool updateSpotTimers() {
    // Server-side timers are now handled by Cloud Functions
    // This method only cleans up any locally detected expired timers as fallback
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

  bool updatePeacockTimers() {
    return peacockManager.updatePeacockTimers();
  }

  String getPeacockTimerDisplay(String player) {
    return peacockManager.getPeacockTimerDisplay(player);
  }

  String getSpotTimerDisplay(int index) {
    final gameName = currentGame?['name'] ?? '';
    return timerState.getSpotTimerDisplay(index, gameName);
  }

  void addToPeacock(String player) {
    final spotIndex = squadSpots.indexOf(player);
    if (spotIndex != -1) {
      squadSpots[spotIndex] = null;
      spotTimers[spotIndex] = null;
      statuses[player] = 'Offline';
      _markFieldChanged('squadSpots');
      _markFieldChanged('spotTimers');
      _markFieldChanged('statuses');
    }

    if (!peacockTimers.containsKey(player) && !peacockQueue.contains(player)) {
      if (peacockTimers.length < 4) {
        peacockTimers[player] = {
          'startTime': DateTime.now().millisecondsSinceEpoch,
          'duration': 3600,
          'mode': 'Quads'
        };
        statuses[player] = 'Strutting';
        _markFieldChanged('peacockTimers');
      } else {
        peacockQueue.add(player);
        statuses[player] = 'Waiting';
        _markFieldChanged('peacockQueue');
      }
      _markFieldChanged('statuses');
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  // Game selection and lobbies methods
  void selectGame(Map<String, dynamic> game) {
    dataManager.currentGame = game;
    // Reset spots to match new game size
    int newSize = game['maxSpots'] ?? 4;
    final gameName = game['name'];
    if (!dataManager.gameSquadSpots.containsKey(gameName) ||
        gameSquadSpots[gameName]!.length != newSize) {
      gameSquadSpots[gameName] = List.filled(newSize, null);
      gameSpotTimers[gameName] = List.filled(newSize, null);
      _markFieldChanged('squadSpots');
      _markFieldChanged('spotTimers');
    }
    updateFirestore(force: true);
    notifyListeners();
  }

  List<Map<String, dynamic>> getVisibleLobbies(String gameName) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final userBlocksMap = this.userBlocks[uid] ?? {};
    // Convert Map<String, bool> to Set<String> for blocked users
    final userBlocks = {
      uid: userBlocksMap.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toSet()
    };
    return lobbyService.getVisibleLobbies(gameName, userBlocks);
  }

  void joinLobby(String lobbyId, String playerName) {
    lobbyService.joinLobby(lobbyId, playerName);
  }

  void addGame(Map<String, dynamic> game) {
    lobbyService.addGame(availableGames, game);
    notifyListeners();
  }

  void editGame(int index, Map<String, dynamic> updatedGame) {
    lobbyService.editGame(availableGames, index, updatedGame);
    notifyListeners();
  }

  void deleteGame(int index) {
    if (lobbyService.deleteGame(availableGames, index, currentGame?['name'])) {
      notifyListeners();
    }
  }

  Map<String, dynamic>? getPlayerLobby(String playerName) {
    return lobbyService.getPlayerLobby(playerName);
  }

  bool hasBlockedPlayersInLobby(
      Map<String, dynamic> lobby, String currentUserId) {
    return lobbyService.hasBlockedPlayersInLobby(lobby, currentUserId);
  }

  String? getPlayerPreferredGame(String playerName) {
    // This could be stored in user preferences or derived from history
    // For now, return null - can be extended later
    return null;
  }

  void addPreferredPeacockGame(String gameName) {
    preferredPeacockGames.add(gameName);
    updateFirestore(force: true);
    notifyListeners();
  }

  void removePreferredPeacockGame(String gameName) {
    preferredPeacockGames.remove(gameName);
    updateFirestore(force: true);
    notifyListeners();
  }

  void muteGame(String gameName) {
    mutedGames.add(gameName);
    _markFieldChanged('mutedGames');
    updateFirestore(force: true);
    notifyListeners();
  }

  void unmuteGame(String gameName) {
    mutedGames.remove(gameName);
    _markFieldChanged('mutedGames');
    updateFirestore(force: true);
    notifyListeners();
  }

  void hideGame(String gameName) {
    hiddenGames.add(gameName);
    muteGame(gameName); // Hidden games are muted
    _markFieldChanged('hiddenGames');
    updateFirestore(force: true);
    notifyListeners();
  }

  void unhideGame(String gameName) {
    hiddenGames.remove(gameName);
    unmuteGame(gameName); // Unhide also unmutes
    _markFieldChanged('hiddenGames');
    updateFirestore(force: true);
    notifyListeners();
  }

  bool isGameHidden(String gameName) {
    return hiddenGames.contains(gameName);
  }

  void startSoloGame([String? gameName]) {
    final userName = displayName;
    if (userName != null && userName != 'User') {
      // Set global status to indicate solo play
      if (gameName != null) {
        globalStatuses[userName] = 'Playing: $gameName (Solo)';
      } else {
        globalStatuses[userName] = 'Playing Solo';
      }
      _markFieldChanged('globalStatuses');
      _markFieldChanged('statuses');
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  void stopSoloGame() {
    final userName = displayName;
    if (userName != null) {
      // Remove solo status, go back to offline
      globalStatuses.remove(userName);
      _markFieldChanged('globalStatuses');
      _markFieldChanged('statuses');
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  bool isPlayingSolo(String playerName) {
    final status = globalStatuses[playerName];
    return status != null &&
        (status.contains('(Solo)') || status == 'Playing Solo');
  }

  bool isGameMuted(String gameName) {
    return mutedGames.contains(gameName);
  }

  // Get active alerts for chat list
  Future<List<Map<String, dynamic>>> getActiveAlerts() async {
    return persistenceService.getActiveAlerts();
  }
}
