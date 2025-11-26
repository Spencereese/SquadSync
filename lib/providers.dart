import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat/chat_service.dart';
import 'services/firestore_service_refactored.dart' as refactored;
import 'chat/chat_state.dart';
import 'chat/sqlite_helper.dart';
import 'services/agora_config.dart';
import 'services/app_flow_manager.dart';
import 'services/services.dart';
import 'app_theme.dart';
import 'managers/stubs.dart';

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

// Provider for ChatState (still needed for some legacy code)
final chatStateProvider = ChangeNotifierProvider<ChatState>((ref) {
  return ChatState();
});

// Provider for AvailabilityManager
final availabilityManagerProvider =
    ChangeNotifierProvider<AvailabilityManager>((ref) {
  return AvailabilityManager();
});

// Provider for SquadManager
final squadManagerProvider = ChangeNotifierProvider<SquadManager>((ref) {
  return SquadManager();
});

// Provider for GameManager
final gameManagerProvider = Provider<GameManager>((ref) {
  return GameManager();
});

// Provider for ChatService
final chatServiceProvider = Provider((ref) {
  final syncManager = ref.watch(syncManagerProvider);
  return ChatService(syncManager);
});

// Provider for SyncManager
final syncManagerProvider = Provider<SyncManager>((ref) {
  final sqliteHelper = ref.watch(sqliteHelperProvider);
  return SyncManager(sqliteHelper: sqliteHelper);
});

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
final sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

// Agora config provider
final agoraConfigProvider = Provider((ref) => AgoraConfig());

// Voice service provider
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final notificationManager = ref.watch(notificationManagerProvider);
  final appFlowManager = ref.watch(appFlowManagerProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);
  final sqliteHelper = ref.watch(sqliteHelperProvider);
  return VoiceService(
    notificationManager: notificationManager,
    appFlowManager: appFlowManager,
    firestoreService: firestoreService,
    sqliteHelper: sqliteHelper,
  );
});

// Provider for VoiceRoom
final voiceRoomProvider = StateNotifierProvider.family<VoiceRoomNotifier,
    AsyncValue<VoiceRoomState>, String>((ref, roomId) {
  final voiceService = ref.watch(voiceServiceProvider);
  final notificationManager = ref.watch(notificationManagerProvider);
  final appFlowManager = ref.watch(appFlowManagerProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);
  final sqliteHelper = ref.watch(sqliteHelperProvider);
  return VoiceRoomNotifier(
    roomId: roomId,
    roomName: 'Voice Room $roomId',
    voiceService: voiceService,
    notificationManager: notificationManager,
    appFlowManager: appFlowManager,
    firestoreService: firestoreService,
    sqliteHelper: sqliteHelper,
  );
});

// Additional service providers for backward compatibility
final firestoreManagerProvider =
    ChangeNotifierProvider<FirestoreManager>((ref) => FirestoreManager());

// Provider for popular games (placeholder for now)
final popularGamesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // TODO: Implement actual popular games fetching
  return [];
});

// Refactored Firestore Service Providers
final firestoreServiceRefactoredProvider =
    Provider<refactored.FirestoreService>((ref) {
  final firestore = FirebaseFirestore.instance;
  final sqliteHelper = ref.watch(sqliteHelperProvider);
  final grokService = ref.watch(grokServiceProvider);
  final notificationManager = ref.watch(notificationManagerProvider);

  return refactored.FirestoreService(
    firestore: firestore,
    sqliteHelper: sqliteHelper,
    grokService: grokService,
    notificationManager: notificationManager,
  );
});

// Suggested Groups Notifier Provider
final suggestedGroupsNotifierProvider = StateNotifierProvider<
    refactored.SuggestedGroupsNotifier, refactored.FirestoreState>((ref) {
  final firestoreService = ref.watch(firestoreServiceRefactoredProvider);
  return refactored.SuggestedGroupsNotifier(firestoreService);
});
