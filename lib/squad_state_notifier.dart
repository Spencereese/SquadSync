import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'managers/game_manager.dart';
import 'managers/squad_manager.dart';
import 'managers/peacock_manager.dart';
import 'managers/user_manager.dart';
import 'managers/achievement_manager.dart';
import 'managers/notification_manager.dart';
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
import 'utils.dart'; // For triggerHapticFeedback

/// Typedef for backward compatibility during Riverpod migration
typedef SquadState = LegacySquadState;

/// Legacy SquadState class for backward compatibility
class LegacySquadState extends ChangeNotifier {
  // Basic properties for compatibility
  String displayName = 'Unknown User';
  String? selectedSquadId;
  Map<String, List<String?>> gameSquadSpots = {};
  Map<String, String> statuses = {};
  List<Map<String, dynamic>> scheduledTimes = [];
  List<Map<String, dynamic>> availableGames = [];

  // Managers for compatibility
  dynamic dataManager;
  dynamic persistenceManager;
  dynamic uiManager;
  dynamic persistenceService;
  Map<String, dynamic>? currentGame;
  String? profileImage;
  List<String> squadMembers = [];
  Map<String, String?> memberProfileImages = {};
  List<String> userSquadIds = [];

  List<String> get getFilteredMembers => [];

  Map<String, Map<String, dynamic>> userSquads = {};
  List<Map<String, dynamic>> gameHistory = [];
  Map<String, int> complaints = {};
  Map<String, Map<String, bool>> userBlocks = {};
  Map<String, Map<String, int>> dailyRatings = {};

  Map<String, Map<String, int>> allTimeRatings = {};
  dynamic userManager;
  List<String> get getBlockedUsers => [];
  bool isInitialized = false;
  List<String?> get squadSpots => [];

  Map<String, int> currentStreaks = {};
  Map<String, Map<String, dynamic>?> peacockTimers = {};
  List<String> peacockQueue = [];
  Set<String> preferredPeacockGames = {};
  List<Map<String, dynamic>?> spotTimers = [];
  dynamic context;
  dynamic recordWin;
  Map<String, dynamic>? currentSquad;
  dynamic recordLoss;

  // State data
  SquadStateData get squadStateData =>
      const SquadStateData(displayName: 'Unknown User');

  // Methods for compatibility
  Stream<List<Map<String, dynamic>>> getActivePeacockAlerts(String gameName) {
    return Stream.value([]);
  }

  bool isBanned(String userName) {
    return false;
  }

  String getDisplayNameForUid(String uid) {
    return 'Unknown User';
  }

  int getBanCount(String userName) {
    return 0;
  }

  Future<void> addBan(String userName, String reason) async {
    // Stub implementation
  }

  Future<void> blockUser(String userName) async {
    // Stub implementation
  }

  Future<void> leaveChatGroup(String groupId) async {
    // Stub implementation
  }

  Future<void> joinChatGroup(String groupId) async {
    throw UnimplementedError('joinChatGroup not implemented');
  }

  Future<void> joinSquad(String squadId) async {
    // Stub implementation
  }

  bool isPlayingSolo(String gameName) {
    return false;
  }

  Future<void> updateFirestoreAsync() async {
    // Stub implementation
  }

  Future<void> callSpotForGame(String gameName, int spotIndex) async {
    // Stub implementation
  }

  Future<void> lockCalledSpot(String gameName, int spotIndex) async {
    // Stub implementation
  }

  String? getPlayerGame(String uid) {
    return null;
  }

  Map<String, dynamic> getMemberRatings(String uid) {
    return {};
  }

  Future<void> unblockUser(String userName) async {
    // Stub implementation
  }

  Future<void> updateFirestore() async {
    // Stub implementation
  }

  Future<void> updateTypingStatus(String chatGroupId, bool isTyping) async {
    // Stub implementation
  }

  Future<void> updateTiltEnabled(bool enabled) async {
    // Stub implementation
  }

  Future<void> updateProfileImage(String imageUrl) async {
    // Stub implementation
  }

  Future<void> updateDisplayName(String name) async {
    // Stub implementation
  }

  Future<void> updatePreferredMode(String gameName, String mode) async {
    // Stub implementation
  }

  Future<void> initialize() async {
    // Stub implementation
  }

  Future<void> addGame(String gameName) async {
    // Stub implementation
  }

  Future<void> submitComplaint(String userName, String reason) async {
    // Stub implementation
  }

  Future<void> deleteGame(String gameName) async {
    // Stub implementation
  }

  Future<void> editGame(String oldGameName, String newGameName) async {
    // Stub implementation
  }

  List<Map<String, dynamic>> getVisibleLobbies() {
    return [];
  }

  Future<void> joinLobby(String lobbyId) async {
    // Stub implementation
  }

  bool canRateMember(String uid) {
    return false;
  }

  Future<void> submitRatings(String uid, Map<String, int> ratings) async {
    // Stub implementation
  }

  Future<void> clearAllSpots(String gameName) async {
    // Stub implementation
  }

  Future<void> resetTimers(String gameName) async {
    // Stub implementation
  }

  Future<void> assignSpot(String gameName, int spotIndex, String uid) async {
    // Implementation moved to SquadStateNotifier
  }

  String getSpotTimerDisplay(String gameName, int spotIndex) {
    return '';
  }

  Future<void> stopSoloGame(String gameName) async {
    // Stub implementation
  }

  String? getUidForDisplayName(String displayName) {
    return null;
  }

  Future<void> removeSpot(String gameName, int spotIndex) async {
    // Stub implementation
  }

  Future<void> addToPeacock(String gameName) async {
    // Stub implementation
  }

  String? getPlayerPreferredGame(String uid) {
    return null;
  }

  Future<void> addPreferredPeacockGame(String gameName) async {
    // Stub implementation
  }

  Future<void> removePreferredPeacockGame(String gameName) async {
    // Stub implementation
  }

  Future<void> claimSpot(String gameName, int spotIndex) async {
    // Stub implementation
  }

  Future<void> lockSpot(String gameName, int spotIndex) async {
    // Stub implementation
  }

  Future<void> removeFromPeacock(String gameName) async {
    // Stub implementation
  }

  // This provides minimal backward compatibility
}

/// State class for SquadStateNotifier
class SquadStateData {
  final bool isInitialized;
  final bool isInitialDataLoaded;
  final String? profileImage;
  final String displayName;
  final Map<String, String?> memberProfileImages;

  // Game-specific data
  final Map<String, List<String?>> gameSquadSpots;
  final Map<String, List<Map<String, dynamic>?>> gameSpotTimers;
  final Map<String, Map<String, String>> gameStatuses;
  final Map<String, String> globalStatuses;

  // Squad data
  final List<String> squadMemberUids;
  final Map<String, String> memberDisplayNames;
  final List<String> userSquadIds;
  final String? selectedSquadId;
  final Map<String, Map<String, dynamic>> userSquads;
  final Map<String, dynamic>? currentSquadData;

  // UI state
  final Map<String, bool> typing;
  final bool tiltEnabled;
  final bool hasNewSquadSpot;
  final bool hasUnreadMessages;

  // Game data
  final List<Map<String, dynamic>> gameHistory;
  final Map<String, String?> preferredModes;
  final Map<String, Map<String, bool>> userBlocks;
  final Map<String, Map<String, int>> dailyBanVotes;
  final Map<String, List<Map<String, dynamic>>> bans;
  final List<Map<String, dynamic>> availableGames;
  final Map<String, List<Map<String, dynamic>>> gameLobbies;
  final Set<String> preferredPeacockGames;
  final Set<String> mutedGames;
  final Set<String> hiddenGames;
  final Map<String, Map<String, dynamic>?> peacockTimers;
  final List<String> peacockQueue;
  final List<Map<String, dynamic>> scheduledTimes;
  final bool hasNewAvailability;

  // Current game
  final Map<String, dynamic>? currentGame;

  // Timer states with AsyncValue for optimized updates
  final AsyncValue<Map<String, Duration>> spotTimerStates;
  final AsyncValue<Map<String, Duration>> peacockTimerStates;

  const SquadStateData({
    this.isInitialized = false,
    this.isInitialDataLoaded = false,
    this.profileImage,
    required this.displayName,
    this.memberProfileImages = const {},
    this.gameSquadSpots = const {},
    this.gameSpotTimers = const {},
    this.gameStatuses = const {},
    this.globalStatuses = const {},
    this.squadMemberUids = const [],
    this.memberDisplayNames = const {},
    this.userSquadIds = const [],
    this.selectedSquadId,
    this.userSquads = const {},
    this.currentSquadData,
    this.typing = const {},
    this.tiltEnabled = false,
    this.hasNewSquadSpot = false,
    this.hasUnreadMessages = false,
    this.gameHistory = const [],
    this.preferredModes = const {},
    this.userBlocks = const {},
    this.dailyBanVotes = const {},
    this.bans = const {},
    this.availableGames = const [],
    this.gameLobbies = const {},
    this.preferredPeacockGames = const {},
    this.mutedGames = const {},
    this.hiddenGames = const {},
    this.peacockTimers = const {},
    this.peacockQueue = const [],
    this.scheduledTimes = const [],
    this.hasNewAvailability = false,
    this.currentGame,
    this.spotTimerStates = const AsyncValue.loading(),
    this.peacockTimerStates = const AsyncValue.loading(),
  });

  SquadStateData copyWith({
    bool? isInitialized,
    bool? isInitialDataLoaded,
    String? profileImage,
    String? displayName,
    Map<String, String?>? memberProfileImages,
    Map<String, List<String?>>? gameSquadSpots,
    Map<String, List<Map<String, dynamic>?>>? gameSpotTimers,
    Map<String, Map<String, String>>? gameStatuses,
    Map<String, String>? globalStatuses,
    List<String>? squadMemberUids,
    Map<String, String>? memberDisplayNames,
    List<String>? userSquadIds,
    String? selectedSquadId,
    Map<String, Map<String, dynamic>>? userSquads,
    Map<String, dynamic>? currentSquadData,
    Map<String, bool>? typing,
    bool? tiltEnabled,
    bool? hasNewSquadSpot,
    bool? hasUnreadMessages,
    List<Map<String, dynamic>>? gameHistory,
    Map<String, String?>? preferredModes,
    Map<String, Map<String, bool>>? userBlocks,
    Map<String, Map<String, int>>? dailyBanVotes,
    Map<String, List<Map<String, dynamic>>>? bans,
    List<Map<String, dynamic>>? availableGames,
    Map<String, List<Map<String, dynamic>>>? gameLobbies,
    Set<String>? preferredPeacockGames,
    Set<String>? mutedGames,
    Set<String>? hiddenGames,
    Map<String, Map<String, dynamic>?>? peacockTimers,
    List<String>? peacockQueue,
    List<Map<String, dynamic>>? scheduledTimes,
    bool? hasNewAvailability,
    Map<String, dynamic>? currentGame,
    AsyncValue<Map<String, Duration>>? spotTimerStates,
    AsyncValue<Map<String, Duration>>? peacockTimerStates,
  }) {
    return SquadStateData(
      isInitialized: isInitialized ?? this.isInitialized,
      isInitialDataLoaded: isInitialDataLoaded ?? this.isInitialDataLoaded,
      profileImage: profileImage ?? this.profileImage,
      displayName: displayName ?? this.displayName,
      memberProfileImages: memberProfileImages ?? this.memberProfileImages,
      gameSquadSpots: gameSquadSpots ?? this.gameSquadSpots,
      gameSpotTimers: gameSpotTimers ?? this.gameSpotTimers,
      gameStatuses: gameStatuses ?? this.gameStatuses,
      globalStatuses: globalStatuses ?? this.globalStatuses,
      squadMemberUids: squadMemberUids ?? this.squadMemberUids,
      memberDisplayNames: memberDisplayNames ?? this.memberDisplayNames,
      userSquadIds: userSquadIds ?? this.userSquadIds,
      selectedSquadId: selectedSquadId ?? this.selectedSquadId,
      userSquads: userSquads ?? this.userSquads,
      currentSquadData: currentSquadData ?? this.currentSquadData,
      typing: typing ?? this.typing,
      tiltEnabled: tiltEnabled ?? this.tiltEnabled,
      hasNewSquadSpot: hasNewSquadSpot ?? this.hasNewSquadSpot,
      hasUnreadMessages: hasUnreadMessages ?? this.hasUnreadMessages,
      gameHistory: gameHistory ?? this.gameHistory,
      preferredModes: preferredModes ?? this.preferredModes,
      userBlocks: userBlocks ?? this.userBlocks,
      dailyBanVotes: dailyBanVotes ?? this.dailyBanVotes,
      bans: bans ?? this.bans,
      availableGames: availableGames ?? this.availableGames,
      gameLobbies: gameLobbies ?? this.gameLobbies,
      preferredPeacockGames:
          preferredPeacockGames ?? this.preferredPeacockGames,
      mutedGames: mutedGames ?? this.mutedGames,
      hiddenGames: hiddenGames ?? this.hiddenGames,
      peacockTimers: peacockTimers ?? this.peacockTimers,
      peacockQueue: peacockQueue ?? this.peacockQueue,
      scheduledTimes: scheduledTimes ?? this.scheduledTimes,
      hasNewAvailability: hasNewAvailability ?? this.hasNewAvailability,
      currentGame: currentGame ?? this.currentGame,
      spotTimerStates: spotTimerStates ?? this.spotTimerStates,
      peacockTimerStates: peacockTimerStates ?? this.peacockTimerStates,
    );
  }
}

/// Riverpod StateNotifier for SquadState management
class SquadStateNotifier extends StateNotifier<SquadStateData> {
  // Manager dependencies
  final GameManager gameManager;
  final SquadManager squadManager;
  final PeacockManager peacockManager;
  final UserManager userManager;
  final AchievementManager achievementManager;
  final NotificationManager notificationManager;
  final AvailabilityManager availabilityManager;
  final SquadDataManager dataManager;
  final SquadUIManager uiManager;
  final SquadPersistenceManager persistenceManager;
  final StateInitializer stateInitializer;
  final TimerState timerState;
  final SquadPersistenceService persistenceService;
  final NotificationCoordinator notificationCoordinator;
  final LobbyService lobbyService;
  final PeacockService peacockService;
  final AchievementService achievementService;
  final SquadMembershipService squadMembershipService;
  final SpotManagementService spotManagementService;
  final ChatService chatService;
  final AuthService authService;
  final AudioService audioService;
  final CacheService cacheService;
  final FirestoreService firestoreService;
  final MediaService mediaService;
  final ReactionService reactionService;
  final PollService pollService;
  final TimerServiceNotifier timerService;
  final AiService aiService;
  final IgdbAuthService igdbAuthService;
  final MessageService messageService;

  // Subscriptions and timers
  StreamSubscription<DocumentSnapshot>? _squadSubscription;
  Timer? _timer;
  BuildContext? context;

  // Timer throttling and optimization
  Timer? _throttledTimerUpdate;
  final Duration _throttleDuration =
      const Duration(seconds: 5); // Update every 5 seconds for non-critical UI

  SquadStateNotifier({
    required this.gameManager,
    required this.squadManager,
    required this.peacockManager,
    required this.userManager,
    required this.achievementManager,
    required this.notificationManager,
    required this.availabilityManager,
    required this.dataManager,
    required this.uiManager,
    required this.persistenceManager,
    required this.stateInitializer,
    required this.timerState,
    required this.persistenceService,
    required this.notificationCoordinator,
    required this.lobbyService,
    required this.peacockService,
    required this.achievementService,
    required this.squadMembershipService,
    required this.spotManagementService,
    required this.chatService,
    required this.authService,
    required this.audioService,
    required this.cacheService,
    required this.firestoreService,
    required this.mediaService,
    required this.reactionService,
    required this.pollService,
    required this.timerService,
    required this.aiService,
    required this.igdbAuthService,
    required this.messageService,
  }) : super(const SquadStateData(displayName: 'Unknown User'));

  // Computed properties for backward compatibility
  List<String?> get squadSpots {
    return cacheService.getOrCompute('squadSpots', () {
      final gameName = state.currentGame?['name'] ?? '';
      final rawSpots = state.gameSquadSpots[gameName] ?? [];
      return rawSpots
          .map((uid) => uid != null ? getDisplayNameForUid(uid) : null)
          .toList();
    });
  }

  List<Map<String, dynamic>?> get spotTimers {
    final gameName = state.currentGame?['name'] ?? '';
    if (!state.gameSpotTimers.containsKey(gameName)) {
      final maxSpots = state.currentGame?['maxSpots'] ?? 4;
      final updatedTimers =
          Map<String, List<Map<String, dynamic>?>>.from(state.gameSpotTimers);
      updatedTimers[gameName] = List.filled(maxSpots, null);
      state = state.copyWith(gameSpotTimers: updatedTimers);
    }
    return state.gameSpotTimers[gameName] ?? [];
  }

  Map<String, String> get statuses {
    final rawStatuses = squadManager.getStatuses(
        state.currentGame?['name'] ?? '',
        state.globalStatuses,
        state.gameStatuses);
    return rawStatuses;
  }

  List<String> get squadMembers {
    return cacheService.getOrCompute('squadMembers', () {
      return state.squadMemberUids
          .map((uid) => getDisplayNameForUid(uid))
          .toList();
    });
  }

  bool get isCreator =>
      state.selectedSquadId != null &&
      FirebaseAuth.instance.currentUser?.uid ==
          state.currentSquadData?['creatorUid'];

  // Helper methods
  String getDisplayNameForUid(String uid) {
    // Handle calling UIDs (format: uid_calling)
    if (uid.contains('_calling')) {
      final actualUid = uid.split('_calling')[0];
      // Check if this is the current user
      if (actualUid == FirebaseAuth.instance.currentUser?.uid) {
        return state.displayName;
      }
      if (state.memberDisplayNames.containsKey(actualUid)) {
        return state.memberDisplayNames[actualUid]!;
      }
    }

    // Check if this is the current user
    if (uid == FirebaseAuth.instance.currentUser?.uid) {
      return state.displayName;
    }

    if (state.memberDisplayNames.containsKey(uid)) {
      return state.memberDisplayNames[uid]!;
    }
    // Return a user-friendly fallback instead of showing UID
    return 'Unknown User';
  }

  String? getUidForDisplayName(String displayName) {
    return state.memberDisplayNames.entries
            .firstWhere((entry) => entry.value == displayName,
                orElse: () => MapEntry('', ''))
            .key
            .isEmpty
        ? null
        : state.memberDisplayNames.entries
            .firstWhere((entry) => entry.value == displayName)
            .key;
  }

  // Initialization method
  Future<void> initialize(BuildContext ctx) async {
    if (state.isInitialized) {
      return;
    }

    context = ctx;
    await stateInitializer.initializeUserState();
    stateInitializer.initializeData();

    // Initialize services
    await audioService.initialize();
    cacheService.setDefaultMaxAge(
        'squadSpots', const Duration(milliseconds: 100));
    cacheService.setDefaultMaxAge(
        'squadMembers', const Duration(milliseconds: 100));

    // Check if user is already authenticated
    final currentUser = authService.currentUser;
    if (currentUser != null) {
      // Load display name using AuthService
      final displayName = await authService.loadDisplayName() ?? 'User';
      final profileImage = await authService.loadProfileImage();

      // Cache the current user's display name
      final updatedDisplayNames =
          Map<String, String>.from(state.memberDisplayNames);
      updatedDisplayNames[currentUser.uid] = displayName;

      await stateInitializer.loadUserSquads(currentUser.uid);
      stateInitializer.listenToSquadChanges();

      state = state.copyWith(
        displayName: displayName,
        profileImage: profileImage,
        memberDisplayNames: updatedDisplayNames,
        isInitialDataLoaded: true,
      );
    }

    // Initialize auth service without callback - auth state is handled by AuthWrapper
    authService.initialize(onAuthStateChanged: (_) {
      // Auth state changes are handled by the AuthWrapper StreamBuilder
      // This callback is kept for compatibility but doesn't trigger state changes
    });

    // Start Firestore sync for squad data
    persistenceService.syncWithFirestore();

    // Initialize optimized timer system instead of old timerState
    _initializeTimerSystem();

    // Schedule daily ban vote reset
    _scheduleDailyReset();

    // Mark as initialized after setting up listeners
    state = state.copyWith(isInitialized: true);
  }

  /// Initialize optimized timer system with throttling and AsyncValue
  void _initializeTimerSystem() {
    // Initialize timer states as loading
    state = state.copyWith(
      spotTimerStates: const AsyncValue.loading(),
      peacockTimerStates: const AsyncValue.loading(),
    );

    // Start throttled timer updates (every 5 seconds for non-critical UI)
    _startThrottledTimerUpdates();

    // Listen to Firebase Cloud Functions for server-side timer updates
    _listenToCloudFunctionUpdates();

    // Load initial timer data from cache/offline storage
    _loadCachedTimerData();
  }

  /// Start throttled timer updates to prevent spam rebuilds
  void _startThrottledTimerUpdates() {
    // Cancel any existing throttled updates
    _throttledTimerUpdate?.cancel();

    // Start periodic updates every 5 seconds
    _throttledTimerUpdate = Timer.periodic(_throttleDuration, (_) {
      _updateTimerStatesThrottled();
    });
  }

  /// Update timer states with throttling (non-critical UI updates)
  void _updateTimerStatesThrottled() {
    if (!mounted) return;

    final currentGameName = state.currentGame?['name'] ?? '';
    final spotTimers = _calculateSpotTimerStates(currentGameName);
    final peacockTimers = _calculatePeacockTimerStates();

    // Only update if there are actual changes to prevent unnecessary rebuilds
    final hasSpotChanges = !_areTimerStatesEqual(
        state.spotTimerStates.valueOrNull ?? {}, spotTimers);
    final hasPeacockChanges = !_areTimerStatesEqual(
        state.peacockTimerStates.valueOrNull ?? {}, peacockTimers);

    if (hasSpotChanges || hasPeacockChanges) {
      state = state.copyWith(
        spotTimerStates: AsyncValue.data(spotTimers),
        peacockTimerStates: AsyncValue.data(peacockTimers),
      );
    }
  }

  /// Calculate current spot timer states for a game
  Map<String, Duration> _calculateSpotTimerStates(String gameName) {
    final timers = <String, Duration>{};
    final gameTimers = state.gameSpotTimers[gameName] ?? [];

    for (int i = 0; i < gameTimers.length; i++) {
      final timer = gameTimers[i];
      if (timer != null &&
          timer['startTime'] != null &&
          timer['duration'] != null) {
        final durationMs = (timer['duration'] as num) * 1000;
        final elapsedMs =
            DateTime.now().millisecondsSinceEpoch - (timer['startTime'] as num);
        final remainingMs = durationMs - elapsedMs;
        final remaining = Duration(milliseconds: remainingMs.toInt());
        if (remaining > Duration.zero) {
          timers['spot_${gameName}_$i'] = remaining;
        }
      }
    }
    return timers;
  }

  /// Calculate current peacock timer states
  Map<String, Duration> _calculatePeacockTimerStates() {
    final timers = <String, Duration>{};

    state.peacockTimers.forEach((player, timer) {
      if (timer != null &&
          timer['startTime'] != null &&
          timer['duration'] != null) {
        final durationMs = (timer['duration'] as num) * 1000;
        final elapsedMs =
            DateTime.now().millisecondsSinceEpoch - (timer['startTime'] as num);
        final remainingMs = durationMs - elapsedMs;
        final remaining = Duration(milliseconds: remainingMs.toInt());
        if (remaining > Duration.zero) {
          timers['peacock_$player'] = remaining;
        }
      }
    });
    return timers;
  }

  /// Check if timer states are equal to prevent unnecessary updates
  bool _areTimerStatesEqual(Map<String, Duration> a, Map<String, Duration> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) ||
          (a[key]! - b[key]!).abs() > const Duration(seconds: 1)) {
        return false;
      }
    }
    return true;
  }

  /// Listen to Firebase Cloud Functions for server-side timer updates
  void _listenToCloudFunctionUpdates() {
    // Listen to Firestore for timer updates from Cloud Functions
    final squadId = state.selectedSquadId;
    if (squadId != null) {
      FirebaseFirestore.instance
          .collection('squads')
          .doc(squadId)
          .snapshots()
          .listen((doc) {
        if (doc.exists) {
          final data = doc.data()!;
          _handleCloudFunctionTimerUpdate(data);
        }
      });
    }
  }

  /// Handle timer updates from Cloud Functions (immediate notifications)
  void _handleCloudFunctionTimerUpdate(Map<String, dynamic> data) {
    final gameName = state.currentGame?['name'] ?? '';
    bool hasExpiredTimers = false;

    // Check for expired spot timers
    final updatedSpotTimers =
        Map<String, List<Map<String, dynamic>?>>.from(state.gameSpotTimers);
    if (data['gameSpotTimers'] != null) {
      final cloudSpotTimers =
          Map<String, List<Map<String, dynamic>?>>.from(data['gameSpotTimers']);
      if (cloudSpotTimers[gameName] != null) {
        final currentTimers =
            List<Map<String, dynamic>?>.from(updatedSpotTimers[gameName] ?? []);
        final cloudTimers = cloudSpotTimers[gameName]!;

        for (int i = 0;
            i < cloudTimers.length && i < currentTimers.length;
            i++) {
          if (currentTimers[i] != null && cloudTimers[i] == null) {
            // Timer expired - spot freed
            hasExpiredTimers = true;
            _handleSpotExpiration(gameName, i);
          }
        }
        updatedSpotTimers[gameName] = cloudTimers;
      }
    }

    // Check for expired peacock timers
    final updatedPeacockTimers =
        Map<String, Map<String, dynamic>?>.from(state.peacockTimers);
    if (data['peacockTimers'] != null) {
      final cloudPeacockTimers =
          Map<String, Map<String, dynamic>?>.from(data['peacockTimers']);
      state.peacockTimers.forEach((player, timer) {
        if (timer != null && cloudPeacockTimers[player] == null) {
          // Peacock timer expired
          hasExpiredTimers = true;
          _handlePeacockExpiration(player);
        }
      });
      updatedPeacockTimers.clear();
      updatedPeacockTimers.addAll(cloudPeacockTimers);
    }

    // Update state with cloud data
    state = state.copyWith(
      gameSpotTimers: updatedSpotTimers,
      peacockTimers: updatedPeacockTimers,
    );

    // Trigger immediate UI update for expirations
    if (hasExpiredTimers) {
      _updateTimerStatesImmediate();
    }
  }

  /// Handle spot timer expiration
  void _handleSpotExpiration(String gameName, int spotIndex) {
    // Trigger haptic feedback
    triggerHapticFeedback();

    // Notify user via NotificationManager
    notificationManager.showSmartNotification(
      title: 'Spot Freed',
      body: 'A spot in $gameName has become available!',
      channelId: 'timer_channel',
    );

    // Update UI state
    uiManager.setNewSquadSpot(true, gameName);
  }

  /// Handle peacock timer expiration
  void _handlePeacockExpiration(String player) {
    // Trigger haptic feedback
    triggerHapticFeedback();

    // Clean up peacock queue
    final updatedQueue = List<String>.from(state.peacockQueue);
    updatedQueue.remove(player);

    state = state.copyWith(peacockQueue: updatedQueue);

    // Notify user
    notificationManager.showSmartNotification(
      title: 'Peacock Available',
      body: '$player is no longer strutting!',
      channelId: 'timer_channel',
    );
  }

  /// Immediate timer state update (for expirations)
  void _updateTimerStatesImmediate() {
    final currentGameName = state.currentGame?['name'] ?? '';
    final spotTimers = _calculateSpotTimerStates(currentGameName);
    final peacockTimers = _calculatePeacockTimerStates();

    state = state.copyWith(
      spotTimerStates: AsyncValue.data(spotTimers),
      peacockTimerStates: AsyncValue.data(peacockTimers),
    );
  }

  /// Load cached timer data for offline support
  Future<void> _loadCachedTimerData() async {
    try {
      // Load from SharedPreferences or SQLite
      // This would integrate with existing caching logic
      final prefs = await SharedPreferences.getInstance();

      // Load cached timer states if available
      final cachedSpotTimers = prefs.getString('cached_spot_timers');
      final cachedPeacockTimers = prefs.getString('cached_peacock_timers');

      if (cachedSpotTimers != null || cachedPeacockTimers != null) {
        // Parse and set cached data
        state = state.copyWith(
          spotTimerStates: cachedSpotTimers != null
              ? AsyncValue.data(_parseTimerMap(cachedSpotTimers))
              : const AsyncValue.loading(),
          peacockTimerStates: cachedPeacockTimers != null
              ? AsyncValue.data(_parseTimerMap(cachedPeacockTimers))
              : const AsyncValue.loading(),
        );
      }
    } catch (e) {
      // Error loading cached data - continue with loading state
    }
  }

  /// Parse timer map from JSON string
  Map<String, Duration> _parseTimerMap(String json) {
    // Implementation for parsing cached timer data
    return {};
  }

  /// Start a spot timer with optimized state management
  Future<void> startSpotTimer(
      String gameName, int spotIndex, Duration duration) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;

    // Update gameSpotTimers
    final updatedTimers =
        Map<String, List<Map<String, dynamic>?>>.from(state.gameSpotTimers);
    if (!updatedTimers.containsKey(gameName)) {
      updatedTimers[gameName] = [];
    }
    while (updatedTimers[gameName]!.length <= spotIndex) {
      updatedTimers[gameName]!.add(null);
    }
    updatedTimers[gameName]![spotIndex] = {
      'startTime': startTime,
      'duration': duration.inSeconds,
    };

    state = state.copyWith(gameSpotTimers: updatedTimers);

    // Trigger haptic feedback for timer start
    triggerHapticFeedback();

    // Update Firestore
    try {
      await firestoreService.updateFirestore(
          displayNameCache: dataManager.memberDisplayNames);
    } catch (e) {
      if (context != null) {
        showSnackBar(context!, 'Failed to update spot timer: $e');
      }
    }

    // Immediate UI update
    _updateTimerStatesImmediate();
  }

  /// Start a peacock timer with optimized state management
  Future<void> startPeacockTimer(String player, Duration duration) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;

    // Update peacockTimers
    final updatedTimers =
        Map<String, Map<String, dynamic>?>.from(state.peacockTimers);
    updatedTimers[player] = {
      'startTime': startTime,
      'duration': duration.inSeconds,
      'mode': 'Quads',
    };

    // Update status
    final updatedStatuses = Map<String, String>.from(state.globalStatuses);
    updatedStatuses[player] = 'Strutting';

    state = state.copyWith(
      peacockTimers: updatedTimers,
      globalStatuses: updatedStatuses,
    );

    // Trigger haptic feedback
    triggerHapticFeedback();

    // Update Firestore
    try {
      await firestoreService.updateFirestore(
          displayNameCache: dataManager.memberDisplayNames);
    } catch (e) {
      if (context != null) {
        showSnackBar(context!, 'Failed to update peacock timer: $e');
      }
    }

    // Immediate UI update
    _updateTimerStatesImmediate();
  }

  /// Upload media for squad chat
  Future<String?> uploadSquadMedia(String filePath, String fileName) async {
    try {
      final downloadUrl = await mediaService.uploadMediaWithSignedUrl(
          File(filePath), fileName, onProgress: (progress) {
        // Handle progress if needed
      });
      return downloadUrl;
    } catch (e) {
      if (context != null) {
        showSnackBar(context!, 'Failed to upload media: $e');
      }
      return null;
    }
  }

  void _scheduleDailyReset() {
    // Implementation for daily reset scheduling
    // This would be similar to the original implementation
  }

  // Delegate methods to managers
  Future<String> createSquad(String name) async {
    return await squadManager.createSquad(name);
  }

  Future<bool> joinSquad(String code) async {
    return await squadManager.joinSquad(code);
  }

  Future<void> leaveSquad() async {
    await squadMembershipService.leaveSquad(
      state.selectedSquadId,
      state.userSquadIds,
      state.userSquads,
      () => state = state.copyWith(), // This will trigger a state update
    );
  }

  Stream<List<Map<String, dynamic>>> getActivePeacockAlerts(String gameName) {
    return peacockService.getActivePeacockAlerts(gameName);
  }

  // Add more delegated methods as needed...

  void clearNotifications(int tabIndex) {
    notificationCoordinator.clearNotificationsForTab(tabIndex);
  }

  // Update methods for profile settings
  void updateTiltEnabled(bool value) {
    state = state.copyWith(tiltEnabled: value);
  }

  void updateProfileImage(String? url) {
    state = state.copyWith(profileImage: url);
  }

  void updateDisplayName(String? name) {
    state = state.copyWith(displayName: name);
  }

  void setCurrentGame(Map<String, dynamic>? game) {
    state = state.copyWith(currentGame: game);
  }

  // Reset method for sign out
  void reset() {
    state = const SquadStateData(displayName: 'Unknown User');
  }

  // Call spot for game
  void callSpotForGame(int spot, String gameName) {
    final currentSpots =
        List<String?>.from(state.gameSquadSpots[gameName] ?? []);
    while (currentSpots.length <= spot) {
      currentSpots.add(null);
    }
    currentSpots[spot] = FirebaseAuth.instance.currentUser!.uid;
    state = state.copyWith(
      gameSquadSpots: {...state.gameSquadSpots, gameName: currentSpots},
      globalStatuses: {...state.globalStatuses, state.displayName: 'Ready'},
    );
  }

  // Load squad data from Firestore
  Future<void> loadSquadData(String squadId) async {
    try {
      final squadDoc = await FirebaseFirestore.instance
          .collection('squads')
          .doc(squadId)
          .get();
      if (squadDoc.exists) {
        final data = squadDoc.data()!;
        state = state.copyWith(
          selectedSquadId: squadId,
          currentSquadData: data,
          gameSquadSpots:
              Map<String, List<String?>>.from(data['gameSquadSpots'] ?? {}),
          gameSpotTimers: Map<String, List<Map<String, dynamic>?>>.from(
              data['gameSpotTimers'] ?? {}),
          gameStatuses:
              Map<String, Map<String, String>>.from(data['gameStatuses'] ?? {}),
          globalStatuses:
              Map<String, String>.from(data['globalStatuses'] ?? {}),
          currentGame: data['currentGame'],
          tiltEnabled: data['tiltEnabled'] ?? false,
          profileImage: data['profileImage'],
          displayName: data['displayName'],
        );
      }
    } catch (e) {
      // Error loading squad data - could add logging here
      rethrow;
    }
  }

  // Update spot timers
  void updateSpotTimers(String gameName, List<Map<String, dynamic>?> timers) {
    try {
      state = state.copyWith(
        gameSpotTimers: {...state.gameSpotTimers, gameName: timers},
      );
    } catch (e) {
      // Error updating spot timers - could add logging here
      rethrow;
    }
  }

  Future<void> assignSpot(String gameName, int spotIndex, String uid) async {
    final updatedSpots = Map<String, List<String?>>.from(state.gameSquadSpots);
    if (!updatedSpots.containsKey(gameName)) {
      final maxSpots = state.currentGame?['maxSpots'] ?? 4;
      updatedSpots[gameName] = List.filled(maxSpots, null);
    }
    updatedSpots[gameName]![spotIndex] = uid;
    state = state.copyWith(gameSquadSpots: updatedSpots);
  }

  Future<void> removeSpot(String gameName, int spotIndex) async {
    final updatedSpots = Map<String, List<String?>>.from(state.gameSquadSpots);
    if (updatedSpots.containsKey(gameName) &&
        spotIndex < updatedSpots[gameName]!.length) {
      updatedSpots[gameName]![spotIndex] = null;
      state = state.copyWith(gameSquadSpots: updatedSpots);
    }
  }

  Future<void> claimSpot(String gameName, int spotIndex) async {
    final currentUser = authService.currentUser;
    if (currentUser != null) {
      await assignSpot(gameName, spotIndex, currentUser.uid);
    }
  }

  Future<void> lockSpot(String gameName, int spotIndex) async {
    // For now, just assign to a special value or handle differently
    // This might need more implementation based on requirements
  }

  @override
  void dispose() {
    _timer?.cancel();
    _throttledTimerUpdate?.cancel();
    _squadSubscription?.cancel();
    timerState.dispose();
    persistenceService.dispose();
    audioService.dispose();
    authService.dispose();
    super.dispose();
  }
}
