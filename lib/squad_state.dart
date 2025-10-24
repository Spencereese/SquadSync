import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
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
import 'services/services.dart';

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
    return cacheService.getOrCompute('statuses', () {
      final rawStatuses =
          squadManager.getStatuses(currentGame?['name'] ?? '', globalStatuses);
      // Convert UID keys to display name keys
      return Map.fromEntries(
        rawStatuses.entries.map((entry) => MapEntry(
              getDisplayNameForUid(entry.key),
              entry.value,
            )),
      );
    });
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
      if (_memberDisplayNames.containsKey(actualUid)) {
        return _memberDisplayNames[actualUid]!;
      }
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

  // Load display names for all squad members
  Future<void> _loadMemberDisplayNames() async {
    if (squadMemberUids.isEmpty) return;

    // Load display names in parallel for better performance
    final futures = squadMemberUids
        .where((uid) => !dataManager.memberDisplayNames.containsKey(uid))
        .map((uid) async {
      try {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        final displayName = userDoc.data()?['displayName'] ?? 'User';
        dataManager.memberDisplayNames[uid] = displayName;
      } catch (e) {
        // If we can't load the display name, use a fallback
        dataManager.memberDisplayNames[uid] = 'User';
      }
    });

    await Future.wait(futures);
    notifyListeners();
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
    return _firestore
        .collection('users')
        .where('peacock.game', isEqualTo: gameName)
        .where('peacock.timer',
            isGreaterThan: DateTime.now().millisecondsSinceEpoch)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            final peacock = data['peacock'] as Map<String, dynamic>?;
            if (peacock != null) {
              return {
                'userId': doc.id,
                'displayName': data['displayName'] ?? 'User',
                'game': peacock['game'],
                'spots': peacock['spots'] ?? 4,
                'timer': peacock['timer'],
                'circle': peacock['circle'],
              };
            }
            return null;
          })
          .where((alert) => alert != null)
          .cast<Map<String, dynamic>>()
          .toList();
    });
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
  final Set<String> _changedFields = {};
  final DateTime _lastFirestoreUpdate = DateTime.now();
  Timer? _timer;

  BuildContext? context;

  // Manager instances for decomposed functionality
  final GameManager gameManager = GameManager();
  late final SquadManager squadManager = SquadManager();
  late final PeacockManager peacockManager = PeacockManager();
  final UserManager userManager = UserManager();
  final AchievementManager achievementManager = AchievementManager();
  final NotificationManager notificationManager = NotificationManager();
  final FirestoreManager firestoreManager = FirestoreManager();
  final AvailabilityManager availabilityManager = AvailabilityManager();

  // New managers
  final SquadDataManager dataManager = SquadDataManager();
  final SquadUIManager uiManager = SquadUIManager();
  final SquadPersistenceManager persistenceManager = SquadPersistenceManager();

  // Services
  final AuthService authService = AuthService();
  final AudioService audioService = AudioService();
  final CacheService cacheService = CacheService();
  final FirestoreService firestoreService = FirestoreService();

  SquadState();

  // Ensure currentGame is always valid
  Map<String, dynamic>? get currentGame {
    if (dataManager.currentGame != null &&
        availableGames.any((game) =>
            game['name'] == dataManager.currentGame!['name'] &&
            game['maxSpots'] == dataManager.currentGame!['maxSpots'])) {
      return dataManager.currentGame;
    }
    // Return first available game if currentGame is invalid
    return availableGames.isNotEmpty ? availableGames.first : null;
  }

  // Private setter for internal use
  set currentGame(Map<String, dynamic>? value) {
    dataManager.currentGame = value;
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

  Future<void> initialize(BuildContext ctx) async {
    if (persistenceManager.isInitialized) {
      debugPrint('SquadState already initialized, skipping');
      return;
    }

    context = ctx;
    await _initState();
    _initializeData();
    // Removed _syncWithFirestore() call from here - will be called after auth

    // Initialize services
    await audioService.initialize();
    cacheService.setDefaultMaxAge(
        'squadSpots', const Duration(milliseconds: 100));
    cacheService.setDefaultMaxAge(
        'statuses', const Duration(milliseconds: 100));
    cacheService.setDefaultMaxAge(
        'squadMembers', const Duration(milliseconds: 100));

    // Initialize auth service
    authService.initialize(onAuthStateChanged: (user) async {
      if (user != null) {
        // Start Firestore sync only after authentication
        _syncWithFirestore();

        // Load display name using AuthService
        persistenceManager.displayName =
            await authService.loadDisplayName() ?? 'User';
        persistenceManager.profileImage = await authService.loadProfileImage();

        // Cache the current user's display name
        dataManager.memberDisplayNames[user.uid] =
            persistenceManager.displayName!;
        await _loadUserSquads(user.uid);
        _listenToSquadChanges();
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

    // Initialize timer
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Only update UI if context is still valid (app is active)
      // Timer logic is now handled server-side by Cloud Functions
      if (context != null) {
        // Check for expired timers and auto-lock spots
        _checkAndLockExpiredSpots();
        // Check for server-side timer updates by refreshing from Firestore periodically
        _checkForServerTimerUpdates();
        _checkPreferredModes();
        // Notify listeners to update timer displays
        notifyListeners();
      }
    });

    // Schedule daily ban vote reset
    _scheduleDailyReset();

    // Mark as initialized after setting up listeners
    persistenceManager.isInitialized = true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _squadSubscription?.cancel();
    audioService.dispose();
    authService.dispose();
    super.dispose();
  }

  // New: Create/join wrappers
  Future<String> createSquad(String name) async {
    final squadId = await squadManager.createSquad(name);
    userSquadIds.add(squadId);
    selectedSquadId = squadId; // Select the new squad
    _loadSquadData(squadId);
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
        _loadSquadData(squadId);
        notifyListeners();
      }
    }
    return success;
  }

  Future<void> leaveSquad() async {
    if (selectedSquadId != null) {
      await squadManager.leaveSquad(selectedSquadId!);
      userSquadIds.remove(selectedSquadId);
      selectedSquadId = userSquadIds.isNotEmpty ? userSquadIds.first : null;
      currentSquadData = null;
      _squadSubscription?.cancel();
      notifyListeners();
    }
  }

  Future<void> _initState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // First try to load from SharedPreferences (most reliable)
      final prefs = await SharedPreferences.getInstance();
      final prefsName = prefs.getString('yourName');

      // Then try to load from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final displayNameFromDoc = userDoc.data()?['displayName'];

      // Prefer SharedPreferences if it has a valid name, otherwise use Firestore
      if (prefsName != null &&
          prefsName.trim().isNotEmpty &&
          prefsName != 'User') {
        persistenceManager.displayName = prefsName.trim();
      } else if (displayNameFromDoc != null &&
          displayNameFromDoc.trim().isNotEmpty) {
        persistenceManager.displayName = displayNameFromDoc.trim();
        // Sync back to SharedPreferences
        await prefs.setString('yourName', persistenceManager.displayName!);
      } else {
        persistenceManager.displayName = 'User';
      }

      persistenceManager.profileImage = userDoc.data()?['profileImage'];

      notifyListeners();
    }
  }

  // New: Load existing squads
  Future<void> _loadUserSquads(String uid) async {
    final query = await _firestore
        .collection('squads')
        .where('members', arrayContains: uid)
        .get();
    userSquadIds = query.docs.map((doc) => doc.id).toList();
    userSquads = {for (var doc in query.docs) doc.id: doc.data()};
    if (userSquadIds.isNotEmpty) {
      selectedSquadId = userSquadIds.first; // Select first squad
      currentSquadData = userSquads[selectedSquadId];
      // Update squad members from the squad document
      dataManager.squadMemberUids =
          List<String>.from(currentSquadData?['members'] ?? []);
      _invalidateCache(); // Clear cached display names
      // Load display names for squad members
      await _loadMemberDisplayNames();
    } else {
      // No squads yet
      selectedSquadId = null;
      currentSquadData = null;
      dataManager.squadMemberUids = [];
      _invalidateCache();
    }
  }

  // New: Listen to squad doc for real-time updates
  void _listenToSquadChanges() {
    if (selectedSquadId == null) return;
    _squadSubscription?.cancel(); // Cancel previous
    _squadSubscription = _firestore
        .collection('squads')
        .doc(selectedSquadId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        currentSquadData = doc.data();
        // Update squad members from the squad document
        dataManager.squadMemberUids =
            List<String>.from(currentSquadData?['members'] ?? []);
        _invalidateCache(); // Clear cached display names
        // Load display names for squad members
        _loadMemberDisplayNames();
        // Update derived properties (e.g., spots from subcollection)
        _syncSpotsFromSquad();
        notifyListeners();
      }
    });
  }

  // Helper: Load squad data and start listening
  void _loadSquadData(String squadId) {
    selectedSquadId = squadId;
    _listenToSquadChanges();
  }

  // Public: Select a squad
  void selectSquad(String squadId) {
    if (userSquadIds.contains(squadId) && userSquads.containsKey(squadId)) {
      selectedSquadId = squadId;
      currentSquadData = userSquads[squadId];
      _loadSquadData(squadId);
      notifyListeners();
    }
  }

  // Get squad data by ID
  Map<String, dynamic>? getSquadById(String squadId) {
    return userSquads[squadId];
  }

  // New: Sync spots from squad subcollection
  Future<void> _syncSpotsFromSquad() async {
    if (selectedSquadId == null) return;
    final spotsSnapshot = await _firestore
        .collection('squads')
        .doc(selectedSquadId)
        .collection('spots')
        .get();
    // Update SquadState's gameSquadSpots for current game
    final gameName = currentGame?['name'] ?? '';
    gameSquadSpots[gameName] = List<String?>.filled(8, null);
    for (var doc in spotsSnapshot.docs) {
      final index = int.tryParse(doc.id);
      if (index != null && index < 8) {
        gameSquadSpots[gameName]![index] = doc.data()['uid'];
      }
    }

    // Auto-assign creator to first spot if no spots are assigned yet
    if (spotsSnapshot.docs.isEmpty &&
        currentSquadData?['creatorUid'] ==
            FirebaseAuth.instance.currentUser?.uid) {
      final userName = displayName;
      if (userName != null && currentGame != null) {
        callSpotForGame(0, gameName);
      }
    }
  }

  void _initializeData() {
    for (var player in squadMembers) {
      // Only set default values if not already set
      if (!statuses.containsKey(player)) {
        statuses[player] = 'Offline';
      }
      if (!currentStreaks.containsKey(player)) {
        currentStreaks[player] = 0;
      }
      if (!highestStreaks.containsKey(player)) {
        highestStreaks[player] = 0;
      }
      if (!complaints.containsKey(player)) {
        complaints[player] = 0;
      }
      if (!achievements.containsKey(player)) {
        achievements[player] = {};
      }
      if (!dailyRatings.containsKey(player)) {
        dailyRatings[player] = {
          "Vibes": [],
          "Comms": [],
          "Gunny": [],
          "Wingman": []
        };
      }
      if (!allTimeRatings.containsKey(player)) {
        allTimeRatings[player] = {
          "Vibes": [],
          "Comms": [],
          "Gunny": [],
          "Wingman": []
        };
      }
      if (!peacockTimers.containsKey(player)) {
        peacockTimers[player] = null;
      }
      if (!typing.containsKey(player)) {
        typing[player] = false;
      }
      if (!memberProfileImages.containsKey(player)) {
        memberProfileImages[player] = null;
      }
      if (!preferredModes.containsKey(player)) {
        preferredModes[player] = null;
      }
    }
    globalStatuses["Alex"] = "Walking";
    globalStatuses["Spencer"] = "Walking";

    // Set default game to Warzone if not already set
    if (dataManager.currentGame == null) {
      dataManager.currentGame = {
        'name': 'Warzone',
        'maxSpots': 4,
        'description': 'Call of Duty: Warzone - Battle Royale',
        'logo': 'assets/images/placeholder.png'
      };
      // Initialize default game spots
      final gameName = dataManager.currentGame!['name'];
      if (!dataManager.gameSquadSpots.containsKey(gameName)) {
        dataManager.gameSquadSpots[gameName] =
            List.filled(dataManager.currentGame!['maxSpots'], null);
        dataManager.gameSpotTimers[gameName] =
            List.filled(dataManager.currentGame!['maxSpots'], null);
      }
    }
  }

  void _syncWithFirestore() {
    _firestore.collection('squad').doc('state').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data()!;
        debugPrint("Raw Firestore data: ${data.toString()}");

        // Handle game-specific data or migrate legacy data
        if (data['gameSquadSpots'] != null) {
          // New game-specific structure - skip spot data as it's now squad-specific
          // gameSquadSpots = (data['gameSquadSpots'] as Map<String, dynamic>).map(
          //     (gameName, spots) =>
          //         MapEntry(gameName, List<String?>.from(spots ?? [])));
          // gameSpotTimers = (data['gameSpotTimers'] as Map<String, dynamic>).map(
          //     (gameName, timers) => MapEntry(
          //         gameName,
          //         (timers as List)
          //             .map((timer) => timer != null
          //                 ? Map<String, dynamic>.from(timer)
          //                 : null)
          //             .toList()));
          // gameStatuses = (data['gameStatuses'] as Map<String, dynamic>).map(
          //     (gameName, statusMap) => MapEntry(
          //         gameName, Map<String, String>.from(statusMap ?? {})));
          dataManager.globalStatuses = Map<String, String>.fromEntries(
              (data['globalStatuses'] as Map<String, dynamic>? ?? {})
                  .entries
                  .where((entry) => entry.key.isNotEmpty && entry.value != null)
                  .map((entry) => MapEntry(entry.key, entry.value as String)));
        } else {
          // Migrate legacy data to current game - skip spot data as it's now squad-specific
          // gameSquadSpots[currentGameName] = List<String?>.from(data['squadSpots'] ?? []);

          // Dynamic spotTimers based on current game - skip as squad-specific
          // var rawSpotTimers = data['spotTimers'] ?? [];
          // int maxSpots = _currentGame?['maxSpots'] ?? 4;
          // gameSpotTimers[currentGameName] = List.filled(maxSpots, null);
          // if (rawSpotTimers is List) {
          //   for (int i = 0; i < rawSpotTimers.length && i < maxSpots; i++) {
          //     final timer = rawSpotTimers[i];
          //     if (timer != null && timer is Map<String, dynamic>) {
          //       gameSpotTimers[currentGameName]![i] = Map<String, dynamic>.from(timer);
          //     }
          //   }
          // }

          // gameStatuses[currentGameName] = Map<String, String>.from(data['statuses'] ?? {});
        }

        // Load global statuses
        dataManager.globalStatuses = Map<String, String>.fromEntries(
            (data['globalStatuses'] as Map<String, dynamic>? ?? {})
                .entries
                .where((entry) => entry.key.isNotEmpty && entry.value != null)
                .map((entry) => MapEntry(entry.key, entry.value as String)));

        dataManager.squadMemberUids = List<String>.from(data['members'] ?? []);
        _invalidateCache();

        // Handle migration: if members contain old hardcoded names instead of UIDs,
        // treat them as display names and map to current user UID for now
        // Firebase UIDs are 28 characters, display names are shorter
        final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserUid != null &&
            squadMemberUids.any((uid) => uid.length < 20)) {
          // This appears to be old data with display names, migrate to current user
          dataManager.squadMemberUids = [currentUserUid];
          dataManager.memberDisplayNames[currentUserUid] =
              persistenceManager.displayName ?? 'User';
        }

        _loadMemberDisplayNames(); // Load display names for all members

        // Ensure all games have status entries for all members
        for (final gameName in gameStatuses.keys) {
          for (var player in squadMembers) {
            if (!gameSquadSpots[gameName]!.contains(player) &&
                !peacockTimers.containsKey(player) &&
                !peacockQueue.contains(player)) {
              gameStatuses[gameName]![player] =
                  gameStatuses[gameName]![player] ?? 'Offline';
            }
          }
        }

        currentStreaks =
            Map<String, int>.from(data['currentStreaks'] ?? currentStreaks);
        highestStreaks =
            Map<String, int>.from(data['highestStreaks'] ?? highestStreaks);
        gameHistory =
            List<Map<String, dynamic>>.from(data['gameHistory'] ?? []);
        complaints = Map<String, int>.from(data['complaints'] ?? complaints);
        achievements =
            (data['achievements'] as Map<dynamic, dynamic>? ?? {}).map(
          (k, v) => MapEntry(
              k.toString(), Set<String>.from(v.map((item) => item.toString()))),
        );
        dailyRatings =
            Map<String, dynamic>.from(data['dailyRatings'] ?? {}).map(
          (k, v) => MapEntry(
            k,
            Map<String, dynamic>.from(v).map(
              (innerKey, innerValue) => MapEntry(
                innerKey,
                (innerValue as List<dynamic>).map((e) => e as int).toList(),
              ),
            ),
          ),
        );
        allTimeRatings =
            Map<String, dynamic>.from(data['allTimeRatings'] ?? {}).map(
          (k, v) => MapEntry(
            k,
            Map<String, dynamic>.from(v).map(
              (innerKey, innerValue) => MapEntry(
                innerKey,
                (innerValue as List<dynamic>).map((e) => e as int).toList(),
              ),
            ),
          ),
        );
        peacockQueue = List<String>.from(data['peacockQueue'] ?? []);
        var rawPeacockTimers = data['peacockTimers'] ?? {};
        peacockTimers = {};
        if (rawPeacockTimers is Map) {
          rawPeacockTimers.forEach((key, value) {
            if (value is Map) {
              peacockTimers[key.toString()] = Map<String, dynamic>.from(value);
            }
          });
        }
        typing = Map<String, bool>.from(data['typing'] ?? typing);
        preferredModes =
            Map<String, String?>.from(data['preferredModes'] ?? preferredModes);
        userBlocks = (data['userBlocks'] as Map<dynamic, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k.toString(), Map<String, bool>.from(v)),
        );
        dailyBanVotes =
            (data['dailyBanVotes'] as Map<dynamic, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k.toString(), Map<String, int>.from(v)),
        );

        // Merge availableGames from Firestore with default games
        var firestoreGames =
            List<Map<String, dynamic>>.from(data['availableGames'] ?? []);
        if (firestoreGames.isNotEmpty) {
          // Use Firestore games but ensure they have required fields
          availableGames = firestoreGames
              .map((game) => {
                    'name': game['name'] ?? 'Unknown Game',
                    'maxSpots': game['maxSpots'] ?? 4,
                    'description': game['description'] ?? 'Custom Game',
                    'logo': game['logo'] ?? 'assets/images/placeholder.png',
                    'coverUrl': game['coverUrl'],
                    'slug': game['slug'],
                  })
              .toList();

          // Asynchronously enrich games with IGDB data in the background
          _enrichGamesWithIgdbData();
        } else {
          // Use default games if no Firestore data
          availableGames = [
            {
              'name': 'Warzone',
              'maxSpots': 4,
              'description': 'Call of Duty: Warzone - Battle Royale',
              'logo': 'assets/images/placeholder.png'
            },
            {
              'name': 'Modern Warfare III',
              'maxSpots': 4,
              'description': 'Call of Duty: Modern Warfare III - Multiplayer',
              'logo': 'assets/images/placeholder.png'
            },
            {
              'name': 'Fortnite',
              'maxSpots': 4,
              'description': 'Fortnite - Battle Royale',
              'logo': 'assets/images/placeholder.png'
            },
            {
              'name': 'Apex Legends',
              'maxSpots': 3,
              'description': 'Apex Legends - Battle Royale',
              'logo': 'assets/images/placeholder.png'
            },
            {
              'name': 'Valorant',
              'maxSpots': 5,
              'description': 'Valorant - Tactical FPS',
              'logo': 'assets/images/placeholder.png'
            },
            {
              'name': 'Overwatch 2',
              'maxSpots': 5,
              'description': 'Overwatch 2 - Hero Shooter',
              'logo': 'assets/images/placeholder.png'
            },
            {
              'name': 'Rocket League',
              'maxSpots': 3,
              'description': 'Rocket League - Sports Action',
              'logo': 'assets/images/placeholder.png'
            },
            {
              'name': 'Minecraft',
              'maxSpots': 4,
              'description': 'Minecraft - Survival/Creative',
              'logo': 'assets/images/placeholder.png'
            },
          ];
        }

        // Now set currentGame and validate it against availableGames
        var firestoreCurrentGame = data['currentGame'];

        // Only use firestore currentGame if it matches an available game
        if (firestoreCurrentGame != null &&
            availableGames.any((game) =>
                game['name'] == firestoreCurrentGame['name'] &&
                game['maxSpots'] == firestoreCurrentGame['maxSpots'])) {
          dataManager.currentGame = firestoreCurrentGame;
        } else {
          // Firestore currentGame is invalid or null, keep existing currentGame or set to first available
          if (dataManager.currentGame == null && availableGames.isNotEmpty) {
            dataManager.currentGame = availableGames.first;
          }
        }

        // Ensure current game has initialized spots
        if (dataManager.currentGame != null) {
          final gameName = dataManager.currentGame!['name'];
          if (!dataManager.gameSquadSpots.containsKey(gameName)) {
            dataManager.gameSquadSpots[gameName] =
                List.filled(dataManager.currentGame!['maxSpots'], null);
            dataManager.gameSpotTimers[gameName] =
                List.filled(dataManager.currentGame!['maxSpots'], null);
          }
        }

        preferredPeacockGames =
            Set<String>.from(data['preferredPeacockGames'] ?? []);
        mutedGames = Set<String>.from(data['mutedGames'] ?? []);
        hiddenGames = Set<String>.from(data['hiddenGames'] ?? []);
        _changedFields.clear();
        notifyListeners();
      } else {
        debugPrint("Firestore snapshot does not exist");
      }
    });

    // Availability sync is now handled by AvailabilityManager
    availabilityManager.syncWithFirestore();

    _firestore.collection('users').snapshots().listen((snapshot) {
      for (var doc in snapshot.docs) {
        String? displayName = doc.data()['displayName'] as String?;
        if (displayName != null && squadMembers.contains(displayName)) {
          memberProfileImages[displayName] =
              doc.data()['profileImage'] as String?;
          preferredModes[displayName] = doc.data()['preferredMode'] as String?;
        }
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && doc.id == user.uid) {
          final docData = doc.data();
          if (docData['displayName'] != null) {
            persistenceManager.displayName = docData['displayName'];
          }
          if (docData['profileImage'] != null) {
            persistenceManager.profileImage = docData['profileImage'];
          }

          // Handle peacock data for current user
          final peacockData = docData['peacock'] as Map<String, dynamic>?;
          if (peacockData != null) {
            final gameName = peacockData['game'] as String?;
            if (gameName != null) {
              // Auto-assign creator to spot 0
              dataManager.gameSquadSpots[gameName] ??= List.filled(4, null);
              dataManager.gameSquadSpots[gameName]![0] = user.uid;
              // Set status to "Looking for squad"
              dataManager.setStatus(user.uid, 'Looking for squad');
            }
          } else {
            // Clear peacock data if no peacock field
            // This handles when peacock expires or is cancelled
            for (final game in dataManager.gameSquadSpots.keys) {
              final spots = dataManager.gameSquadSpots[game];
              if (spots != null && spots.contains(user.uid)) {
                final index = spots.indexOf(user.uid);
                if (index != -1) {
                  spots[index] = null;
                }
              }
            }
          }

          // Save to SharedPreferences for backup
          if (persistenceManager.displayName != null &&
              persistenceManager.displayName != 'User') {
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString('yourName', persistenceManager.displayName!);
            });
          }
        }
      }
      notifyListeners();
    });

    _firestore.collection('chat').snapshots().listen((snapshot) {
      bool hasNew = snapshot.docChanges.any((change) =>
          change.type == DocumentChangeType.added &&
          (change.doc.data()?['read'] ?? true) == false &&
          change.doc.data()?['sender_name'] != null &&
          change.doc.data()?['content'] != null);
      if (hasNew) {
        hasUnreadMessages = true;
        NotificationService.sendNotification(
            'New Message', 'You have an unread message in the chat!');
      }
      notifyListeners();
    });

    // Listen for chat group messages (only for groups user is member of)
    if (selectedSquadId != null) {
      _firestore
          .collection('squads')
          .doc(selectedSquadId)
          .collection('chat_groups')
          .snapshots()
          .listen((groupsSnapshot) async {
        for (var groupDoc in groupsSnapshot.docs) {
          final groupData = groupDoc.data();
          final isPublic = groupData['isPublic'] ?? false;
          final members = List<String>.from(groupData['members'] ?? []);

          // Only listen to groups where user is a member or group is public
          if (isPublic ||
              members.contains(FirebaseAuth.instance.currentUser?.uid)) {
            _firestore
                .collection('squads')
                .doc(selectedSquadId)
                .collection('chat_groups')
                .doc(groupDoc.id)
                .collection('messages')
                .snapshots()
                .listen((messagesSnapshot) {
              bool hasNew = messagesSnapshot.docChanges.any((change) =>
                  change.type == DocumentChangeType.added &&
                  (change.doc.data()?['read'] ?? true) == false &&
                  change.doc.data()?['sender_name'] != null &&
                  change.doc.data()?['content'] != null);
              if (hasNew) {
                hasUnreadMessages = true;
                NotificationService.sendNotification('New Group Message',
                    'You have an unread message in ${groupData['name'] ?? 'a group'}!');
              }
              notifyListeners();
            });
          }
        }
      });
    }

    // Listen to lobbies subcollections for all games
    for (final game in availableGames) {
      final gameName = game['name'] as String;
      _firestore
          .collection('lobbies')
          .doc(gameName)
          .collection('lobbies')
          .snapshots()
          .listen((snapshot) {
        gameLobbies[gameName] = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        notifyListeners();
      });
    }
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
    updateFirestoreAsync(force: force);
  }

  Future<void> submitComplaint({
    required String targetMember,
    required String reason,
    required String category,
    required String submittedBy,
  }) async {
    if (!squadMembers.contains(targetMember)) {
      throw Exception('Invalid member: $targetMember');
    }

    try {
      await _firestore
          .collection('squad')
          .doc('state')
          .collection('complaints')
          .add({
        'targetMember': targetMember,
        'reason': reason,
        'category': category,
        'submittedBy': submittedBy,
        'timestamp': FieldValue.serverTimestamp(),
      });

      complaints[targetMember] = (complaints[targetMember] ?? 0) + 1;
      _markFieldChanged('complaints');
      await updateFirestoreAsync(force: true);

      await NotificationService.sendNotificationToUser(
        recipientDisplayName: targetMember,
        title: 'New Complaint',
        body: 'You received a complaint: $reason ($category).',
      );

      debugPrint('Complaint submitted against $targetMember: $reason');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to submit complaint: $e');
      rethrow;
    }
  }

  Future<void> submitRatings({
    required String targetMember,
    required Map<String, int?> ratings,
    required String submittedBy,
  }) async {
    if (!squadMembers.contains(targetMember)) {
      throw Exception('Invalid member: $targetMember');
    }
    if (targetMember == submittedBy) {
      throw Exception('Cannot rate yourself');
    }

    bool canRate =
        await canRateMember(targetMember, submittedBy); // Updated here
    if (!canRate) {
      throw Exception(
          'You can only rate members you played with (Walking status).');
    }

    try {
      ratings.forEach((category, rating) {
        if (rating != null && rating >= 0 && rating <= 5) {
          dailyRatings[targetMember]![category]!.add(rating);
          allTimeRatings[targetMember]![category]!.add(rating);
        }
      });

      final latestGame = gameHistory.lastWhere(
        (game) =>
            (game['players'] as List).contains(targetMember) &&
            (game['players'] as List).contains(submittedBy),
        orElse: () => {},
      );
      if (latestGame.isNotEmpty) {
        latestGame['ratings'] ??= {};
        (latestGame['ratings'] as Map)[submittedBy] ??= {};
        (latestGame['ratings'] as Map)[submittedBy][targetMember] = ratings;
      }

      _markFieldChanged('dailyRatings');
      _markFieldChanged('allTimeRatings');
      _markFieldChanged('gameHistory');
      await updateFirestoreAsync(force: true);

      final ratedCategories = ratings.entries
          .where((e) => e.value != null)
          .map((e) => '${e.key}: ${e.value}/5')
          .join(', ');
      if (ratedCategories.isNotEmpty) {
        await NotificationService.sendNotificationToUser(
          recipientDisplayName: targetMember,
          title: 'New Rating',
          body: 'You were rated by $submittedBy: $ratedCategories.',
        );
      }

      debugPrint('Ratings submitted for $targetMember: $ratings');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to submit ratings: $e');
      rethrow;
    }
  }

  // Add this method to SquadState
  Future<bool> hasRatedMember(String targetMember, String submittedBy) async {
    final sharedGames = gameHistory
        .where((game) =>
            (game['players'] as List).contains(targetMember) &&
            (game['players'] as List).contains(submittedBy) &&
            (game['result'] == 'Win' || game['result'] == 'Loss'))
        .toList();
    if (sharedGames.isEmpty) return false;
    final latestGame = sharedGames.last;
    final ratings = latestGame['ratings'] as Map? ?? {};
    final submittedRatings = ratings[submittedBy] as Map? ?? {};
    return submittedRatings.containsKey(targetMember);
  }

  // Existing canRateMember (ensure public)
  Future<bool> canRateMember(String targetMember, String submittedBy) async {
    return gameHistory.any((game) =>
        (game['players'] as List).contains(targetMember) &&
        (game['players'] as List).contains(submittedBy) &&
        (game['result'] == 'Win' || game['result'] == 'Loss'));
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
    hasNewSquadSpot = value;
    if (value &&
        (gameName == null ||
            (!isGameMuted(gameName) && !isGameHidden(gameName)))) {
      NotificationService.sendNotification(
          'New Squad Spot', 'A spot has been claimed or opened!');
    }
    notifyListeners();
  }

  void setUnreadMessages(bool value) {
    hasUnreadMessages = value;
    notifyListeners();
  }

  void clearNotifications(int tabIndex) {
    if (tabIndex == 1) availabilityManager.setNewAvailability(false);
    if (tabIndex == 2) hasNewSquadSpot = false;
    if (tabIndex == 3) hasUnreadMessages = false;
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
    if (_replyingTo == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'No user logged in';

      await _firestore.collection('chat').add({
        'text': text,
        'sender': user.displayName ?? persistenceManager.displayName ?? 'User',
        'timestamp': FieldValue.serverTimestamp(),
        'replyTo': messageId,
        'delivered': false,
        'read': false,
      });

      clearReplyingTo();
      debugPrint('Reply sent to message $messageId: $text');
    } catch (e) {
      debugPrint('Failed to send reply: $e');
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final squadId = selectedSquadId;
    if (squadId == null) return;

    try {
      await _firestore
          .collection('squads')
          .doc(squadId)
          .collection('chat')
          .doc(messageId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
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
    if (peacockTimers.containsKey(player)) {
      peacockTimers.remove(player);
      statuses[player] = 'Offline';
      _markFieldChanged('peacockTimers');
      _markFieldChanged('statuses');
    } else if (peacockQueue.contains(player)) {
      peacockQueue.remove(player);
      statuses[player] = 'Offline';
      _markFieldChanged('peacockQueue');
      _markFieldChanged('statuses');
    }
    await updateFirestoreAsync(force: true);
    notifyListeners();
  }

  void claimSpot(int index) {
    final userName = displayName;
    final userUid = getUidForDisplayName(userName ?? '');
    if (userName != null && userUid != null) {
      dataManager.claimSpot(index, userName, userUid);
      dataManager.globalStatuses[userName] =
          'Calling'; // Changed from 'Ready'
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
      // Invalidate cache for statuses
      cacheService.invalidate('statuses');
      updateFirestoreAsync(force: true);
      notifyListeners();
    }
  }

  void claimSpotForGame(int index, String gameName, {int? maxSpots}) {
    final userName = displayName;
    final userUid = getUidForDisplayName(userName ?? '');
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
    final userName = displayName;
    final userUid = getUidForDisplayName(userName ?? '');
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

  void lockCalledSpot(String gameName, int index) {
    final userName = displayName;
    final userUid = getUidForDisplayName(userName ?? '');
    if (userName != null && userUid != null) {
      dataManager.lockCalledSpot(gameName, index, userName, userUid);
      persistenceManager.markFieldChanged('squadSpots');
      persistenceManager.markFieldChanged('spotTimers');
      persistenceManager.markFieldChanged('globalStatuses');
      _markFieldChanged('statuses');
      updateFirestoreAsync(force: true);
      notifyListeners();
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
        setNewSquadSpot(true, gameName); // Trigger squad spot notification
      }
    }
    // Delegate to peacock manager
    peacockManager.startPeacockTimer(dialogContext);
  }

  void _checkPreferredModes() {
    int claimedCount = squadSpots.where((spot) => spot != null).length;
    int availableSpots = 4 - claimedCount;
    if (availableSpots == 0 || peacockQueue.isEmpty) return;

    List<String> potentialPlayers =
        squadSpots.where((spot) => spot != null).cast<String>().toList();
    Map<String, List<String>> modeGroups = {
      'duos': [],
      'trios': [],
      'quads': []
    };

    for (var player in peacockQueue) {
      String? mode = preferredModes[player];
      if (mode != null) {
        modeGroups[mode]?.add(player);
        potentialPlayers.add(player);
      }
    }

    for (var player in List.from(peacockQueue)) {
      String? mode = preferredModes[player];
      if (mode == null) continue;

      int requiredPlayers = mode == 'duos'
          ? 2
          : mode == 'trios'
              ? 3
              : 4;
      int currentPlayers = potentialPlayers.length;

      if (currentPlayers >= requiredPlayers && availableSpots > 0) {
        int spotsToFill =
            (requiredPlayers - claimedCount).clamp(1, availableSpots);
        _fillSpots([player], spotsToFill);
        potentialPlayers.remove(player);
      }
    }
  }

  void _fillSpots(List<String> players, int spotsNeeded) {
    final gameName = currentGame?['name'] ?? '';
    for (var player in players) {
      final playerUid = getUidForDisplayName(player);
      if (playerUid != null) {
        int? freeSpot = squadSpots.indexOf(null);
        if (freeSpot != -1 && gameSquadSpots.containsKey(gameName)) {
          gameSquadSpots[gameName]![freeSpot] = playerUid;
          gameSpotTimers[gameName]![freeSpot] = {
            'startTime': DateTime.now().millisecondsSinceEpoch,
            'duration': 300,
          };
          globalStatuses[player] = 'Ready';
          peacockQueue.remove(player);
          _markFieldChanged('squadSpots');
          _markFieldChanged('spotTimers');
          _markFieldChanged('globalStatuses');
          _markFieldChanged('statuses');
          _markFieldChanged('peacockQueue');
          setNewSquadSpot(true, gameName); // Trigger squad spot notification
        }
      }
    }
    updateFirestore(force: true);
    notifyListeners();
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
      setNewSquadSpot(true, gameName); // Trigger squad spot notification
      updateFirestore(force: true);
      notifyListeners();
    }
  }

  void removeSpot(int index) {
    final gameName = currentGame?['name'] ?? '';
    if (gameSquadSpots.containsKey(gameName) &&
        index < gameSquadSpots[gameName]!.length) {
      final playerUid = gameSquadSpots[gameName]![index];
      if (playerUid != null) {
        final player = getDisplayNameForUid(playerUid);
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
        updateFirestore(force: true);
        notifyListeners();
      }
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
    List<String> walkingPlayers = squadSpots
        .where((spot) => spot != null && statuses[spot] == 'Walking')
        .cast<String>()
        .toList();
    Map<String, int> updatedStreaks = {};
    for (var player in walkingPlayers) {
      int oldStreak = currentStreaks[player] ?? 0;
      updatedStreaks[player] = oldStreak + 1;
      await _checkAchievements(player, updatedStreaks[player]!);
    }
    currentStreaks.addAll(updatedStreaks);
    gameHistory.add({
      'result': 'Win',
      'players': walkingPlayers,
      'timestamp': DateTime.now().toIso8601String(),
      'ratings': {}, // Fresh ratings map for this game
    });
    await audioService.playVictorySound();
    NotificationService.sendNotification(
        'Squad Win!', '${walkingPlayers.join(', ')} won a game!');
    _markFieldChanged('currentStreaks');
    _markFieldChanged('gameHistory');
    _markFieldChanged('achievements');
    updateFirestore(force: true);
    notifyListeners();
  }

  void recordLoss() {
    List<String> walkingPlayers = squadSpots
        .where((spot) =>
            spot != null && spotTimers[squadSpots.indexOf(spot)] == null)
        .cast<String>()
        .toList();
    for (var player in walkingPlayers) {
      currentStreaks[player] = 0;
    }
    gameHistory.add({
      'result': 'Loss',
      'players': walkingPlayers,
      'timestamp': DateTime.now().toIso8601String(),
      'ratings': {}, // Fresh ratings map for this game
    });
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

    if (voteCount > (totalEligibleVoters / 2)) {
      // More than half voted - 24 hour ban
      return 24 * 3600 * 1000;
    } else if (voteCount >= totalEligibleVoters) {
      // All other users voted - 48 hour ban
      return 48 * 3600 * 1000;
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
    if (spotTimers[index] == null) return '00:00';
    int startTime = spotTimers[index]!['startTime'] as int;
    int duration = spotTimers[index]!['duration'] as int;

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

  String _formatTimer(int? seconds) {
    if (seconds == null) return '00:00';
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _checkForServerTimerUpdates() {
    // Periodically refresh timer data from Firestore to sync with server-side updates
    // This ensures the UI reflects server-side timer changes even when app was closed
    final now = DateTime.now();
    if (now.difference(_lastFirestoreUpdate).inSeconds >= 30) {
      // Check every 30 seconds
      // Force a refresh from Firestore to get latest timer state
      updateFirestore(force: true);
    }
  }

  void _checkAndLockExpiredSpots() {
    final gameName = currentGame?['name'] ?? '';
    if (gameSpotTimers.containsKey(gameName)) {
      for (int i = 0; i < gameSpotTimers[gameName]!.length; i++) {
        final timer = gameSpotTimers[gameName]![i];
        if (timer != null) {
          final startTime = timer['startTime'] as int;
          final duration = timer['duration'] as int;
          final elapsed =
              (DateTime.now().millisecondsSinceEpoch - startTime) / 1000;
          final remaining = duration - elapsed.floor();

          if (remaining <= 0) {
            // Check if this is a calling timer
            final isCalling = timer['calling'] == true;

            if (isCalling) {
              // All calling spots - remove them if not manually locked (expired)
              removeSpot(i);
            } else {
              // Regular timer expired, free the spot
              removeSpot(i);
            }
          }
        }
      }
    }
  }

  Future<void> _checkAchievements(String player, int streak) async {
    achievements[player] ??= {};
    bool added = false;
    if (streak >= 10) {
      achievements[player]!.add('Chicken');
      await audioService.playAchievementSound(streak);
      added = true;
    }
    if (streak >= 4 && !added) {
      achievements[player]!.add('Duck');
      await audioService.playAchievementSound(streak);
      added = true;
    }
    if (streak >= 3 && !added) {
      achievements[player]!.add('Turkey');
      await audioService.playAchievementSound(streak);
    }
    _markFieldChanged('achievements');
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
    final userBlocks = this.userBlocks[uid] ?? {};

    return gameLobbies[gameName]?.where((lobby) {
          final players = List<String>.from(lobby['players'] ?? []);
          // Filter out lobbies with blocked players
          return !players.any((player) =>
              userBlocks.containsKey(player) && userBlocks[player]!);
        }).toList() ??
        [];
  }

  void joinLobby(String lobbyId, String playerName) {
    // Find the lobby across all games
    Map<String, dynamic>? targetLobby;
    String? targetGame;

    for (final gameEntry in gameLobbies.entries) {
      final lobby = gameEntry.value.firstWhere(
        (l) => l['id'] == lobbyId,
        orElse: () => <String, dynamic>{},
      );
      if (lobby.isNotEmpty) {
        targetLobby = lobby;
        targetGame = gameEntry.key;
        break;
      }
    }

    if (targetLobby != null && targetGame != null) {
      final players = List<String>.from(targetLobby['players'] ?? []);
      if (!players.contains(playerName)) {
        players.add(playerName);
        targetLobby['players'] = players;

        // Update Firestore
        _firestore
            .collection('lobbies')
            .doc(targetGame)
            .collection('lobbies')
            .doc(lobbyId)
            .update({'players': players});

        notifyListeners();
      }
    }
  }

  void addGame(Map<String, dynamic> game) {
    if (!availableGames.any((g) => g['name'] == game['name'])) {
      availableGames.add(game);
      // Add to Firestore
      _firestore.collection('games').add(game);

      // Set up lobbies listener for the new game
      final gameName = game['name'] as String;
      _firestore
          .collection('lobbies')
          .doc(gameName)
          .collection('lobbies')
          .snapshots()
          .listen((snapshot) {
        gameLobbies[gameName] = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        notifyListeners();
      });

      notifyListeners();
    }
  }

  void editGame(int index, Map<String, dynamic> updatedGame) {
    if (index >= 0 && index < availableGames.length) {
      availableGames[index] = updatedGame;
      // Save to Firestore
      _firestore.collection('games').doc(updatedGame['name']).set(updatedGame);
      notifyListeners();
    }
  }

  void deleteGame(int index) {
    if (index >= 0 && index < availableGames.length) {
      // Don't allow deleting if it's the current game
      if (availableGames[index]['name'] == dataManager.currentGame?['name']) {
        return;
      }
      availableGames.removeAt(index);
      notifyListeners();
    }
  }

  Map<String, dynamic>? getPlayerLobby(String playerName) {
    return dataManager.getPlayerLobby(playerName);
  }

  bool hasBlockedPlayersInLobby(
      Map<String, dynamic> lobby, String currentUserId) {
    return dataManager.hasBlockedPlayersInLobby(lobby, currentUserId);
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
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('circles')
          .where('status', isEqualTo: 'active')
          .get();

      final alerts = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final gameName = data['gameName'] as String?;
        if (gameName != null) {
          // Fetch host name and other details, assuming stored in circles or elsewhere
          final hostName = data['hostName'] ?? 'Unknown';
          final maxSpots = data['maxSpots'] ?? 4;
          final chatGroupId = data['chatGroupId'] ?? '';
          alerts.add({
            'gameName': gameName,
            'hostName': hostName,
            'maxSpots': maxSpots,
            'chatGroupId': chatGroupId,
          });
        }
      }
      return alerts;
    } catch (e) {
      debugPrint('Error fetching active alerts: $e');
      return [];
    }
  }

  /// Asynchronously enrich games with IGDB data
  Future<void> _enrichGamesWithIgdbData() async {
    try {
      final enrichedGames =
          await gameManager.enrichGamesWithIgdbData(availableGames);
      if (enrichedGames.length == availableGames.length) {
        availableGames = enrichedGames;
        notifyListeners();
        // Update Firestore with enriched data
        await _firestore.collection('squads').doc(selectedSquadId).set({
          'availableGames': availableGames,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error enriching games with IGDB data: $e');
    }
  }
}
