import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'managers/user_manager.dart';
import 'managers/availability_manager.dart';
import 'managers/squad_manager.dart';
import 'managers/timer_state.dart';
import 'managers/squad_data_manager.dart';
import 'services/timer_service.dart';
import 'managers/squad_ui_manager.dart';
import 'managers/squad_persistence_manager.dart';
import 'managers/game_manager.dart';
import 'managers/peacock_manager.dart';
import 'managers/achievement_manager.dart';
import 'managers/notification_manager.dart';
import 'chat/chat_state.dart';
import 'chat/sqlite_helper.dart';
import 'services/firestore_service.dart';
import 'managers/state_initializer.dart';
import 'managers/squad_persistence_service.dart';
import 'managers/notification_coordinator.dart';
import 'managers/lobby_service.dart';
import 'managers/peacock_service.dart';
import 'managers/achievement_service.dart';
import 'managers/squad_membership_service.dart';
import 'managers/spot_management_service.dart';
import 'chat/chat_service.dart';
import 'services/grok_service.dart';
import 'services/reaction_service.dart';
import 'services/voice_service.dart';
import 'services/app_flow_manager.dart';
import 'services/services.dart';
import 'app_theme.dart';
import 'squad_state_notifier.dart';

// LEGACY PROVIDERS - TODO: Remove after full Riverpod migration
// These ChangeNotifierProvider instances are kept for backward compatibility
// during partial migration. New code should use Riverpod StateNotifierProvider
// and generated providers for better performance and tree-shaking.

// Provider for Theme
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeData>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeData> {
  ThemeNotifier() : super(AppTheme.darkTheme);

  bool get isDarkTheme => state == AppTheme.darkTheme;

  void toggleTheme(bool isDark) {
    state = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
  }
}

// LEGACY PROVIDERS - Keep for backward compatibility during migration
// TODO: Gradually replace with Riverpod StateNotifierProvider and generated providers

// Provider for UserManager
final userManagerProvider = ChangeNotifierProvider<UserManager>((ref) {
  return UserManager();
});

// Provider for AvailabilityManager
final availabilityManagerProvider =
    ChangeNotifierProvider<AvailabilityManager>((ref) {
  return AvailabilityManager();
});

// Provider for SquadManager
final squadManagerProvider = ChangeNotifierProvider<SquadManager>((ref) {
  final analytics = ref.read(appFlowManagerProvider);
  return SquadManager(analytics: analytics);
});

// Provider for GameManager
final gameManagerProvider = Provider<GameManager>((ref) {
  return GameManager();
});

// Provider for Legacy SquadState
final squadStateProvider = ChangeNotifierProvider<SquadState>((ref) {
  return SquadState();
});

// Provider for ChatState
final chatStateProvider = ChangeNotifierProvider<ChatState>((ref) {
  return ChatState();
});

// Provider for Discovery
final discoveryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userManager = ref.read(userManagerProvider);
  return userManager.fetchPublicGroups();
});

// Provider for TimerState
final timerStateProvider =
    StateNotifierProvider<TimerState, Map<String, Duration>>((ref) {
  // Assuming we have providers for the managers, but for now, create instances
  final dataManager = SquadDataManager();
  final uiManager = SquadUIManager();
  final persistenceManager = SquadPersistenceManager();
  final timerService = ref.watch(timerServiceProvider);
  return TimerState(
    dataManager: dataManager,
    uiManager: uiManager,
    persistenceManager: persistenceManager,
    timerService: timerService,
  );
});

// Provider for ChatService
final chatServiceProvider = Provider((ref) => ChatService());

// Provider for ReactionService
final reactionServiceProvider = Provider((ref) => ReactionService());

// Provider for GrokService
final grokServiceProvider = Provider<GrokService>((ref) => GrokService());

// Provider for AppFlowManager
final appFlowManagerProvider = Provider<AppFlowManager>((ref) {
  return AppFlowManager(FirebaseAnalytics.instance);
});

// User properties provider for efficient selects
final userPropertiesProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value({});

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data() ?? {});
});

// Current user ID provider
final currentUserIdProvider = StreamProvider<String?>((ref) {
  return FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
});

// Voice room provider is defined in voice_service.dart

// Provider for SquadStateNotifier
final squadStateNotifierProvider =
    StateNotifierProvider<SquadStateNotifier, SquadStateData>((ref) {
  // Create all the manager dependencies
  final gameManager = GameManager();
  final squadManager = ref.read(squadManagerProvider);
  final peacockManager = PeacockManager();
  final userManager = ref.read(userManagerProvider);
  final achievementManager = AchievementManager(SquadDataManager());
  final notificationManager = NotificationManager();
  final availabilityManager = ref.read(availabilityManagerProvider);
  final dataManager = SquadDataManager();
  final uiManager = SquadUIManager();
  final persistenceManager = SquadPersistenceManager();
  final stateInitializer = StateInitializer(
    dataManager: dataManager,
    persistenceManager: persistenceManager,
  );
  final timerState = ref.read(timerStateProvider.notifier);
  final firestoreService = FirestoreService();
  final cacheService = CacheService();
  final persistenceService = SquadPersistenceService(
    dataManager: dataManager,
    uiManager: uiManager,
    persistenceManager: persistenceManager,
    firestoreService: firestoreService,
    cacheService: cacheService,
  );
  final notificationCoordinator = NotificationCoordinator(
    notificationManager: notificationManager,
    uiManager: uiManager,
    availabilityManager: availabilityManager,
  );
  final lobbyService = LobbyService(
    dataManager: dataManager,
    persistenceService: persistenceService,
  );
  final peacockService = PeacockService();
  final achievementService = AchievementService(achievementManager);
  final squadMembershipService =
      SquadMembershipService(squadManager, stateInitializer);
  final spotManagementService = SpotManagementService(
    dataManager: dataManager,
    persistenceManager: persistenceManager,
    uiManager: uiManager,
    cacheService: cacheService,
    getSquadSpots: () => [], // Will be updated when state is available
    getGameSquadSpots: () => {},
    getGameSpotTimers: () => {},
    getSpotTimers: () => [],
    getPeacockTimers: () => {},
    getPeacockQueue: () => [],
    getGlobalStatuses: () => {},
    getCurrentGame: () => null,
    getDisplayName: () => null,
    getUidForDisplayName: (name) => null,
  );
  final chatService = ref.read(chatServiceProvider);
  final authService = AuthService();
  final audioService = AudioService();

  return SquadStateNotifier(
    gameManager: gameManager,
    squadManager: squadManager,
    peacockManager: peacockManager,
    userManager: userManager,
    achievementManager: achievementManager,
    notificationManager: notificationManager,
    availabilityManager: availabilityManager,
    dataManager: dataManager,
    uiManager: uiManager,
    persistenceManager: persistenceManager,
    stateInitializer: stateInitializer,
    timerState: timerState,
    persistenceService: persistenceService,
    notificationCoordinator: notificationCoordinator,
    lobbyService: lobbyService,
    peacockService: peacockService,
    achievementService: achievementService,
    squadMembershipService: squadMembershipService,
    spotManagementService: spotManagementService,
    chatService: chatService,
    authService: authService,
    audioService: audioService,
    cacheService: cacheService,
  );
});

// Search State for Group Discovery
class SearchState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> results;

  const SearchState({
    this.isLoading = false,
    this.error,
    this.results = const [],
  });

  SearchState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? results,
  }) {
    return SearchState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      results: results ?? this.results,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier() : super(const SearchState());

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading, error: null);
  }

  void setError(String error) {
    state = state.copyWith(isLoading: false, error: error);
  }

  void setResults(List<Map<String, dynamic>> results) {
    state = state.copyWith(isLoading: false, error: null, results: results);
  }
}

final searchNotifierProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier();
});

// Additional providers for services
final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());
final notificationManagerProvider =
    ChangeNotifierProvider<NotificationManager>((ref) => NotificationManager());
final sqliteHelperProvider = Provider<SQLiteHelper>((ref) => SQLiteHelper());

// Provider for VoiceRoom
final voiceRoomProvider =
    StateNotifierProvider.family<VoiceRoomNotifier, VoiceRoomState, String>(
        (ref, roomId) {
  return VoiceRoomNotifier(
      roomId, 'Voice Room $roomId'); // Default name, can be updated
});
