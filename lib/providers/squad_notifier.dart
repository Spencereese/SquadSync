import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import '../managers/achievement_manager.dart';
import '../managers/squad_data_manager.dart';
import '../services/services.dart';
import 'service_providers.dart';
import '../utils.dart';

part 'squad_notifier.freezed.dart';
part 'squad_notifier.g.dart';

// Typedefs for family providers

@freezed
class SquadState with _$SquadState {
  const factory SquadState({
    required Map<String, List<String?>> gameSquadSpots,
    required Map<String, List<Map<String, dynamic>?>> gameSpotTimers,
    required Map<String, Map<String, String>> gameStatuses,
    required Map<String, String> globalStatuses,
    required List<String> squadMemberUids,
    required Map<String, String> memberDisplayNames,
    required List<String> userSquadIds,
    required String? selectedSquadId,
    required Map<String, Map<String, dynamic>> userSquads,
    required Map<String, dynamic>? currentSquadData,
    required Map<String, Map<String, dynamic>?> peacockTimers,
    required List<String> peacockQueue,
    required List<Map<String, dynamic>> scheduledTimes,
    required Set<String> preferredPeacockGames,
    required Map<String, dynamic>? currentGame,
    required bool isInitialized,
    required bool isInitialDataLoaded,
    String? errorMessage,
  }) = _SquadState;

  factory SquadState.initial() => const SquadState(
        gameSquadSpots: {},
        gameSpotTimers: {},
        gameStatuses: {},
        globalStatuses: {},
        squadMemberUids: [],
        memberDisplayNames: {},
        userSquadIds: [],
        selectedSquadId: null,
        userSquads: {},
        currentSquadData: null,
        peacockTimers: {},
        peacockQueue: [],
        scheduledTimes: [],
        preferredPeacockGames: {},
        currentGame: null,
        isInitialized: false,
        isInitialDataLoaded: false,
        errorMessage: null,
      );
}

class _StubDataManager extends SquadDataManager {
  _StubDataManager() {
    // Initialize empty data
  }
}

@riverpod
class SquadNotifier extends _$SquadNotifier {
  late final AchievementManager _achievementManager;
  late final MediaService _mediaService;
  late final AuthService _authService;

  // Timer management - now delegated to TimerServiceNotifier
  TimerServiceNotifier get _timerService => ref.read(timerServiceProvider.notifier);

  @override
  Future<SquadState> build() async {
    _achievementManager = AchievementManager(_StubDataManager());
    _mediaService = ref.read(mediaServiceProvider);
    _authService = ref.read(authServiceProvider);

    // Initialize state
    await _initializeSquadData();

    // Set up real-time listeners
    _setupFirestoreListeners();

    return SquadState.initial().copyWith(
      isInitialized: true,
      isInitialDataLoaded: true,
    );
  }

  Future<void> _initializeSquadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load user's squads directly from Firestore
      final firestore = FirebaseFirestore.instance;
      final userSquadsDoc =
          await firestore.collection('users').doc(user.uid).get();
      final userData = userSquadsDoc.data() ?? {};
      final squadIds = List<String>.from(userData['squadIds'] ?? []);

      // Load current squad if selected from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final selectedSquadId = prefs.getString('selectedSquadId');

      Map<String, dynamic>? currentSquadData;
      if (selectedSquadId != null) {
        final squadDoc =
            await firestore.collection('squads').doc(selectedSquadId).get();
        currentSquadData = squadDoc.data();
      }

      // Load game-specific data
      final gameSquadSpots = await _loadGameSquadSpots();
      final gameSpotTimers = await _loadGameSpotTimers();
      final gameStatuses = await _loadGameStatuses();

      final newState = state.value!.copyWith(
        userSquadIds: squadIds,
        selectedSquadId: selectedSquadId,
        currentSquadData: currentSquadData,
        gameSquadSpots: gameSquadSpots,
        gameSpotTimers: gameSpotTimers,
        gameStatuses: gameStatuses,
      );
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<Map<String, List<String?>>> _loadGameSquadSpots() async {
    // Implementation to load spots from persistence
    return {};
  }

  Future<Map<String, List<Map<String, dynamic>?>>> _loadGameSpotTimers() async {
    // Implementation to load timers from persistence
    return {};
  }

  Future<Map<String, Map<String, String>>> _loadGameStatuses() async {
    // Implementation to load statuses from persistence
    return {};
  }

  void _setupFirestoreListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen to squad changes
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        final newState = state.value!.copyWith(
          selectedSquadId: data['selectedSquadId'],
        );
        state = AsyncValue.data(newState);
      }
    });
  }

  // Squad management methods
  Future<void> createSquad(String name) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firestore = FirebaseFirestore.instance;
      final squadRef = firestore.collection('squads').doc();
      final squadId = squadRef.id;

      // Create squad document
      await squadRef.set({
        'name': name,
        'createdBy': user.uid,
        'members': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update user's squad list
      await firestore.collection('users').doc(user.uid).update({
        'squadIds': FieldValue.arrayUnion([squadId]),
      });

      await selectSquad(squadId);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> joinSquad(String code) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firestore = FirebaseFirestore.instance;
      final squadQuery = await firestore
          .collection('squads')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();

      if (squadQuery.docs.isEmpty) {
        throw Exception('Invalid invite code');
      }

      final squadId = squadQuery.docs.first.id;

      // Add user to squad
      await firestore.collection('squads').doc(squadId).update({
        'members': FieldValue.arrayUnion([user.uid]),
      });

      // Update user's squad list
      await firestore.collection('users').doc(user.uid).update({
        'squadIds': FieldValue.arrayUnion([squadId]),
      });

      await selectSquad(squadId);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> leaveSquad() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || state.value?.selectedSquadId == null) return;

      final firestore = FirebaseFirestore.instance;
      final squadId = state.value!.selectedSquadId!;

      // Remove user from squad
      await firestore.collection('squads').doc(squadId).update({
        'members': FieldValue.arrayRemove([user.uid]),
      });

      // Update user's squad list
      await firestore.collection('users').doc(user.uid).update({
        'squadIds': FieldValue.arrayRemove([squadId]),
      });

      final newState = state.value!.copyWith(
        selectedSquadId: null,
        currentSquadData: null,
      );
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> uploadSquadMediaWithFeedback(
      BuildContext context, String filePath) async {
    try {
      final file = File(filePath);
      final fileName = file.path.split('/').last;
      final isVideo = fileName.toLowerCase().endsWith('.mp4') ||
          fileName.toLowerCase().endsWith('.mov') ||
          fileName.toLowerCase().endsWith('.avi');

      final mediaUrl = await _mediaService.uploadMedia(file, fileName, isVideo);

      // Update squad data with media URL
      if (state.value?.selectedSquadId != null) {
        final firestore = FirebaseFirestore.instance;
        await firestore
            .collection('squads')
            .doc(state.value!.selectedSquadId!)
            .update({
          'mediaUrls': FieldValue.arrayUnion([mediaUrl]),
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Squad media uploaded successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload squad media: $e')),
        );
      }
    }
  }

  Future<void> signOutWithFeedback(BuildContext context) async {
    try {
      await _authService.signOut();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign out: $e')),
        );
      }
    }
  }

  Future<void> selectSquad(String squadId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final squadDoc = await firestore.collection('squads').doc(squadId).get();

      if (!squadDoc.exists) {
        throw Exception('Squad not found');
      }

      final squadData = squadDoc.data()!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedSquadId', squadId);

      final newState = state.value!.copyWith(
        selectedSquadId: squadId,
        currentSquadData: squadData,
      );
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Media upload method using MediaService
  Future<String?> uploadSquadMedia(File file, String fileName) async {
    try {
      final mediaUrl = await _mediaService.uploadMediaWithSignedUrl(
        file,
        fileName,
        onProgress: (progress) {
          // Could emit progress state if needed
        },
        onError: (error) {
          throw Exception(error);
        },
      );
      return mediaUrl;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return null;
    }
  }

  // Spot management methods
  Future<void> claimSpot(String gameName, int spotIndex) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update local state
      final currentSpots =
          Map<String, List<String?>>.from(state.value!.gameSquadSpots);
      if (!currentSpots.containsKey(gameName)) {
        final maxSpots = state.value!.currentGame?['maxSpots'] ?? 4;
        currentSpots[gameName] = List.filled(maxSpots, null);
      }
      currentSpots[gameName]![spotIndex] = user.uid;

      final newState = state.value!.copyWith(gameSquadSpots: currentSpots);
      state = AsyncValue.data(newState);

      // Start timer using TimerServiceNotifier
      await _timerService.startSpotTimer(gameName, user.uid, const Duration(minutes: 5));

      // Update gameSpotTimers state for UI
      await _updateSpotTimerState(gameName, spotIndex, user.uid);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> assignSpot(String gameName, int spotIndex, String uid) async {
    try {
      // Update local state
      final currentSpots =
          Map<String, List<String?>>.from(state.value!.gameSquadSpots);
      if (!currentSpots.containsKey(gameName)) {
        final maxSpots = state.value!.currentGame?['maxSpots'] ?? 4;
        currentSpots[gameName] = List.filled(maxSpots, null);
      }
      currentSpots[gameName]![spotIndex] = uid;

      final newState = state.value!.copyWith(gameSquadSpots: currentSpots);
      state = AsyncValue.data(newState);

      // Start timer using TimerServiceNotifier
      await _timerService.startSpotTimer(gameName, uid, const Duration(minutes: 5));

      // Update gameSpotTimers state for UI
      await _updateSpotTimerState(gameName, spotIndex, uid);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> removeSpot(String gameName, int spotIndex) async {
    try {
      // Get the UID before removing from state
      final uid = state.value!.gameSquadSpots[gameName]?[spotIndex];

      // Update local state
      final currentSpots =
          Map<String, List<String?>>.from(state.value!.gameSquadSpots);
      if (currentSpots.containsKey(gameName) &&
          spotIndex < currentSpots[gameName]!.length) {
        currentSpots[gameName]![spotIndex] = null;
        final newState = state.value!.copyWith(gameSquadSpots: currentSpots);
        state = AsyncValue.data(newState);
      }

      // Stop timer if UID exists
      if (uid != null) {
        await _timerService.stopTimer('spot_${gameName}_$uid');
        await _clearSpotTimerState(gameName, spotIndex);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> lockSpot(String gameName, int spotIndex) async {
    try {
      // For now, just mark as locked - this might need more implementation
      // Update local state to indicate spot is locked
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Timer state management helpers
  Future<void> _updateSpotTimerState(String gameName, int spotIndex, String uid) async {
    final remaining = _timerService.getRemainingTime('spot_${gameName}_$uid');
    final currentTimers = Map<String, List<Map<String, dynamic>?>>.from(
        state.value!.gameSpotTimers);
    currentTimers[gameName] ??= List.filled(4, null);
    currentTimers[gameName]![spotIndex] = {
      'startTime': DateTime.now().subtract(const Duration(minutes: 5) - remaining),
      'duration': const Duration(minutes: 5),
      'remaining': remaining.inSeconds,
      'isExpired': false,
      'isExpiring': remaining.inMinutes < 1,
      'uid': uid,
    };

    final newState = state.value!.copyWith(gameSpotTimers: currentTimers);
    state = AsyncValue.data(newState);
  }

  Future<void> _clearSpotTimerState(String gameName, int spotIndex) async {
    final currentTimers = Map<String, List<Map<String, dynamic>?>>.from(
        state.value!.gameSpotTimers);
    if (currentTimers[gameName] != null) {
      currentTimers[gameName]![spotIndex] = null;
    }

    final newState = state.value!.copyWith(gameSpotTimers: currentTimers);
    state = AsyncValue.data(newState);
  }

  Future<void> _updatePeacockTimerState(String uid, String gameName) async {
    final remaining = _timerService.getRemainingTime('peacock_$uid');
    final currentPeacockTimers =
        Map<String, Map<String, dynamic>?>.from(state.value!.peacockTimers);
    currentPeacockTimers[uid] = {
      'startTime': DateTime.now().subtract(const Duration(minutes: 10) - remaining),
      'duration': const Duration(minutes: 10),
      'remaining': remaining.inSeconds,
      'gameName': gameName,
    };

    final newState = state.value!.copyWith(peacockTimers: currentPeacockTimers);
    state = AsyncValue.data(newState);
  }

  Future<void> _clearPeacockTimerState(String uid) async {
    final currentPeacockTimers =
        Map<String, Map<String, dynamic>?>.from(state.value!.peacockTimers);
    currentPeacockTimers.remove(uid);

    final newState = state.value!.copyWith(peacockTimers: currentPeacockTimers);
    state = AsyncValue.data(newState);
  }

  Future<void> clearAllSpots(String gameName) async {
    try {
      // Stop all timers for this game
      final spots = state.value!.gameSquadSpots[gameName] ?? [];
      for (int i = 0; i < spots.length; i++) {
        final uid = spots[i];
        if (uid != null) {
          await _timerService.stopTimer('spot_${gameName}_$uid');
        }
      }

      // Update local state
      final currentSpots =
          Map<String, List<String?>>.from(state.value!.gameSquadSpots);
      final maxSpots = state.value!.currentGame?['maxSpots'] ?? 4;
      currentSpots[gameName] = List.filled(maxSpots, null);

      final currentTimers = Map<String, List<Map<String, dynamic>?>>.from(
          state.value!.gameSpotTimers);
      currentTimers[gameName] = List.filled(maxSpots, null);

      final newState = state.value!.copyWith(
        gameSquadSpots: currentSpots,
        gameSpotTimers: currentTimers,
      );
      state = AsyncValue.data(newState);

      // Invalidate the provider to trigger a rebuild
      ref.invalidateSelf();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> resetTimers(String gameName) async {
    try {
      // Stop all timers for this game
      final spots = state.value!.gameSquadSpots[gameName] ?? [];
      for (int i = 0; i < spots.length; i++) {
        final uid = spots[i];
        if (uid != null) {
          await _timerService.stopTimer('spot_${gameName}_$uid');
        }
      }

      // Update local state
      final currentTimers = Map<String, List<Map<String, dynamic>?>>.from(
          state.value!.gameSpotTimers);
      currentTimers[gameName] = List.filled(4, null);

      final newState = state.value!.copyWith(gameSpotTimers: currentTimers);
      state = AsyncValue.data(newState);

      // Invalidate the provider to trigger a rebuild
      ref.invalidateSelf();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Peacock queue methods
  Future<void> addToPeacock(String gameName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update local state
      final currentQueue = List<String>.from(state.value!.peacockQueue);
      if (!currentQueue.contains(user.uid)) {
        currentQueue.add(user.uid);
      }

      final newState = state.value!.copyWith(peacockQueue: currentQueue);
      state = AsyncValue.data(newState);

      // Start peacock timer using TimerServiceNotifier
      await _timerService.startPeacockTimer(user.uid, const Duration(minutes: 10));

      // Update peacock timers state for UI
      await _updatePeacockTimerState(user.uid, gameName);

      // Haptic feedback for joining peacock
      triggerHapticFeedback();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> removeFromPeacock(String gameName, [String? userId]) async {
    try {
      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Update local state
      final currentQueue = List<String>.from(state.value!.peacockQueue);
      currentQueue.remove(uid);

      final newState = state.value!.copyWith(peacockQueue: currentQueue);
      state = AsyncValue.data(newState);

      // Stop peacock timer
      await _timerService.stopTimer('peacock_$uid');

      // Clear peacock timer state
      await _clearPeacockTimerState(uid);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> addPreferredPeacockGame(String gameName) async {
    final currentPreferred =
        Set<String>.from(state.value!.preferredPeacockGames);
    currentPreferred.add(gameName);

    final newState =
        state.value!.copyWith(preferredPeacockGames: currentPreferred);
    state = AsyncValue.data(newState);
  }

  Future<void> removePreferredPeacockGame(String gameName) async {
    final currentPreferred =
        Set<String>.from(state.value!.preferredPeacockGames);
    currentPreferred.remove(gameName);

    final newState =
        state.value!.copyWith(preferredPeacockGames: currentPreferred);
    state = AsyncValue.data(newState);
  }

  // Game-specific data methods
  void setCurrentGame(Map<String, dynamic>? game) {
    final newState = state.value!.copyWith(currentGame: game);
    state = AsyncValue.data(newState);
  }

  // UID-based user methods
  String getDisplayNameForUid(String uid) {
    return state.value!.memberDisplayNames[uid] ?? 'Unknown User';
  }

  String? getUidForDisplayName(String displayName) {
    return state.value!.memberDisplayNames.entries
        .firstWhere((entry) => entry.value == displayName,
            orElse: () => MapEntry('', ''))
        .key;
  }

  // Computed properties
  List<String?> get squadSpots {
    final gameName = state.value!.currentGame?['name'] ?? '';
    return state.value!.gameSquadSpots[gameName] ?? [];
  }

  Map<String, String> get statuses {
    final gameName = state.value!.currentGame?['name'] ?? '';
    return state.value!.gameStatuses[gameName] ?? {};
  }

  List<String> get squadMembers {
    return state.value!.squadMemberUids
        .map((uid) => getDisplayNameForUid(uid))
        .toList();
  }

  bool get isCreator {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || state.value!.currentSquadData == null) return false;
    return state.value!.currentSquadData!['creatorId'] == user.uid;
  }

  // Stream for peacock alerts
  Stream<List<Map<String, dynamic>>> getActivePeacockAlerts(String gameName) {
    return Stream.value([]); // Placeholder - implement based on requirements
  }

  // Achievement methods
  Future<void> recordWin(List<Map<String, dynamic>> gameHistory) async {
    final gameName = state.value!.currentGame?['name'] ?? '';
    final squadSpots = state.value!.gameSquadSpots[gameName] ?? [];
    final statuses = state.value!.gameStatuses[gameName] ?? {};

    await _achievementManager.recordWin(
      squadSpots: squadSpots,
      statuses: statuses,
      gameHistory: gameHistory,
    );
  }

  Future<void> recordLoss(List<Map<String, dynamic>> gameHistory) async {
    final gameName = state.value!.currentGame?['name'] ?? '';
    final squadSpots = state.value!.gameSquadSpots[gameName] ?? [];
    final spotTimers = state.value!.gameSpotTimers[gameName] ?? [];
    final currentStreaks = _achievementManager.currentStreaks;

    _achievementManager.recordLoss(
      squadSpots: squadSpots,
      spotTimers: spotTimers,
      currentStreaks: currentStreaks,
      gameHistory: gameHistory,
    );
  }

  // Rating methods
  Future<void> submitRatings(String uid, Map<String, int> ratings) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final squadMembers = state.value!.squadMemberUids;
    final gameHistory = state.value!.currentSquadData?['gameHistory'] ?? [];

    await _achievementManager.submitRatings(
      submittedBy: user.uid,
      targetMember: uid,
      ratings: ratings,
      squadMembers: squadMembers,
      gameHistory: List<Map<String, dynamic>>.from(gameHistory),
    );
  }

  bool canRateMember(String uid) {
    // Simple implementation - can rate if they're in the current squad
    return state.value!.squadMemberUids.contains(uid);
  }

  // Missing methods from Step 1 - clear all spots and timers for all games
  Future<void> clearAllSpotsForAllGames() async {
    try {
      final newState = state.value!.copyWith(
        gameSquadSpots: {},
        gameSpotTimers: {},
      );
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> resetAllTimers() async {
    try {
      final newState = state.value!.copyWith(
        gameSpotTimers: {},
      );
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

// Family providers for game-specific data
@riverpod
List<String?> squadSpots(Ref ref, String gameName) {
  return ref.watch(squadNotifierProvider.select(
    (state) => state.value?.gameSquadSpots[gameName] ?? [],
  ));
}

@riverpod
List<Map<String, dynamic>?> spotTimers(Ref ref, String gameName) {
  return ref.watch(squadNotifierProvider.select(
    (state) => state.value?.gameSpotTimers[gameName] ?? [],
  ));
}

@riverpod
Map<String, String> gameStatuses(Ref ref, String gameName) {
  return ref.watch(squadNotifierProvider.select(
    (state) => state.value?.gameStatuses[gameName] ?? {},
  ));
}

// Family providers for timer states with AsyncValue
@riverpod
AsyncValue<Map<String, dynamic>> spotTimerState(Ref ref, String gameName, int spotIndex) {
  final timerService = ref.watch(timerServiceProvider.notifier);
  final spots = ref.watch(squadNotifierProvider.select(
    (state) => state.value?.gameSquadSpots[gameName] ?? [],
  ));

  if (spotIndex >= spots.length || spots[spotIndex] == null) {
    return const AsyncValue.data({});
  }

  final uid = spots[spotIndex]!;
  final timerKey = 'spot_${gameName}_$uid';

  try {
    final remaining = timerService.getRemainingTime(timerKey);
    final isExpired = remaining.inSeconds <= 0;
    final isExpiring = remaining.inMinutes < 1 && remaining.inSeconds > 0;

    return AsyncValue.data({
      'remaining': remaining.inSeconds,
      'isExpired': isExpired,
      'isExpiring': isExpiring,
      'uid': uid,
      'gameName': gameName,
      'spotIndex': spotIndex,
    });
  } catch (e) {
    return AsyncValue.error(e, StackTrace.current);
  }
}

@riverpod
AsyncValue<Map<String, dynamic>> peacockTimerState(Ref ref, String userId) {
  final timerService = ref.watch(timerServiceProvider.notifier);
  final timerKey = 'peacock_$userId';

  try {
    final remaining = timerService.getRemainingTime(timerKey);
    final isExpired = remaining.inSeconds <= 0;
    final isExpiring = remaining.inMinutes < 1 && remaining.inSeconds > 0;

    return AsyncValue.data({
      'remaining': remaining.inSeconds,
      'isExpired': isExpired,
      'isExpiring': isExpiring,
      'userId': userId,
      'type': 'peacock',
    });
  } catch (e) {
    return AsyncValue.error(e, StackTrace.current);
  }
}

// Stream providers for real-time timer updates with debouncing
@riverpod
Stream<Duration> spotTimerStream(Ref ref, String gameName, int spotIndex) {
  final timerService = ref.watch(timerServiceProvider.notifier);
  final spots = ref.watch(squadNotifierProvider.select(
    (state) => state.value?.gameSquadSpots[gameName] ?? [],
  ));

  if (spotIndex >= spots.length || spots[spotIndex] == null) {
    return Stream.value(Duration.zero);
  }

  final uid = spots[spotIndex]!;
  final timerKey = 'spot_${gameName}_$uid';

  return timerService.observeTimer(timerKey);
}

@riverpod
Stream<Duration> peacockTimerStream(Ref ref, String userId) {
  final timerService = ref.watch(timerServiceProvider.notifier);
  final timerKey = 'peacock_$userId';

  return timerService.observeTimer(timerKey);
}
