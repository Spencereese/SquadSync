import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/igdb_service.dart' as igdb_service;
import '../services/igdb_auth_service.dart';
import 'service_providers.dart';
import 'system_notifier.dart';
import '../chat/sqlite_helper.dart';

part 'game_notifier.freezed.dart';
part 'game_notifier.g.dart';

@freezed
class GameState with _$GameState {
  const factory GameState({
    required List<Map<String, dynamic>> availableGames,
    required List<Map<String, dynamic>> gameHistory,
    required Map<String, List<Map<String, dynamic>>> gameLobbies,
    required Map<String, dynamic>? currentGame,
    required Map<String, dynamic>? onboardingFlow,
    required bool isInitialized,
    String? errorMessage,
  }) = _GameState;

  factory GameState.initial() => const GameState(
        availableGames: [],
        gameHistory: [],
        gameLobbies: {},
        currentGame: null,
        onboardingFlow: null,
        isInitialized: false,
        errorMessage: null,
      );
}

@riverpod
class GameNotifier extends _$GameNotifier {
  late final igdb_service.IgdbService _igdbService;
  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;

  @override
  Future<GameState> build({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    IgdbAuthService? igdbAuthService, // Keep for compatibility with generated code
  }) async {
    _firestore = firestore ?? FirebaseFirestore.instance;
    _auth = auth ?? FirebaseAuth.instance;
    _igdbService = igdb_service.IgdbService(
      SQLiteHelper(),
      ref.watch(firestoreServiceProvider),
    );

    // Initialize games and lobbies
    final initialState = await _initializeGames();

    return initialState;
  }

  Future<GameState> _initializeGames() async {
    try {
      // Load available games from Firestore
      final gamesSnapshot =
          await _firestore.collection('games').orderBy('name').get();

      final games = gamesSnapshot.docs.map((doc) => doc.data()).toList();

      // Load visible lobbies from Firestore
      final lobbiesSnapshot = await _firestore
          .collection('lobbies')
          .where('isVisible', isEqualTo: true)
          .get();

      final gameLobbies = <String, List<Map<String, dynamic>>>{};
      for (var doc in lobbiesSnapshot.docs) {
        final data = doc.data();
        final gameName = data['gameName'] as String;
        if (!gameLobbies.containsKey(gameName)) {
          gameLobbies[gameName] = [];
        }
        gameLobbies[gameName]!.add(data);
      }

      return GameState.initial().copyWith(
        availableGames: games,
        gameLobbies: gameLobbies,
        isInitialized: true,
      );
    } catch (e) {
      return GameState.initial().copyWith(
        errorMessage: e.toString(),
        isInitialized: true,
      );
    }
  }

  // Game selection methods
  Future<void> selectGame(Map<String, dynamic> game) async {
    final newState = state.value!.copyWith(currentGame: game);
    state = AsyncValue.data(newState);
  }

  /// Get pinned games with maxSpots from currentGame context
  Future<List<Map<String, dynamic>>> getPinnedGamesWithContext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pinnedGameNames = prefs.getStringList('pinned_games') ?? [];

      if (pinnedGameNames.isEmpty) return [];

      // Get current game context for maxSpots
      final currentGame = state.value!.currentGame;
      final defaultMaxSpots = currentGame?['maxSpots'] ?? 6;

      // Fetch game details for pinned games
      final pinnedGames = <Map<String, dynamic>>[];
      for (final gameName in pinnedGameNames) {
        try {
          final games = await _igdbService.fetchGames(gameName);
          if (games.isNotEmpty) {
            final game = Map<String, dynamic>.from(games.first);
            game['maxSpots'] = defaultMaxSpots; // Apply current game context
            game['isPinned'] = true;
            pinnedGames.add(game);
          }
        } catch (e) {
          debugPrint('Failed to fetch pinned game $gameName: $e');
        }
      }

      return pinnedGames;
    } catch (e) {
      debugPrint('Failed to get pinned games: $e');
      return [];
    }
  }

  Future<void> searchGames(String query) async {
    try {
      // Simple local search in available games
      final allGames = state.value!.availableGames;
      final results = allGames.where((game) {
        final name = game['name'] as String? ?? '';
        return name.toLowerCase().contains(query.toLowerCase());
      }).toList();

      final newState = state.value!.copyWith(availableGames: results);
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> searchGamesIGDB(BuildContext context, String query) async {
    try {
      final games = await _igdbService.fetchGames(query);

      // Update state with search results
      final newState = state.value!.copyWith(availableGames: games);
      state = AsyncValue.data(newState);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${games.length} games')),
        );
      }
    } catch (e) {
      // Use enhanced error handling
      await handleSearchError(context, query, e);
    }
  }

  /// Retry IGDB search with enhanced error handling
  Future<void> retrySearchIGDB(BuildContext context, String query) async {
    try {
      // Clear any cached errors
      final currentState = state.value;
      if (currentState != null) {
        state = AsyncValue.data(currentState.copyWith(errorMessage: null));
      }

      await searchGamesIGDB(context, query);
    } catch (e) {
      // Log retry failure
      await _logSearchError(query, e, isRetry: true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Retry failed. Using cached games.')),
        );
      }
    }
  }

  /// Fallback search using cached or asset games
  Future<void> _fallbackSearch(String query) async {
    try {
      // Try to get cached games first
      final cachedGames = await _igdbService.fetchGames(query);

      if (cachedGames.isNotEmpty) {
        final newState = state.value!.copyWith(availableGames: cachedGames);
        state = AsyncValue.data(newState);
        return;
      }

      // If no cache, try local search in available games
      final allGames = state.value!.availableGames;
      final filteredGames = allGames.where((game) {
        final name = game['name'] as String? ?? '';
        return name.toLowerCase().contains(query.toLowerCase());
      }).toList();

      if (filteredGames.isNotEmpty) {
        final newState = state.value!.copyWith(availableGames: filteredGames);
        state = AsyncValue.data(newState);
      }
    } catch (e) {
      debugPrint('Fallback search failed: $e');
    }
  }

  /// Log search errors to analytics
  Future<void> _logSearchError(String query, dynamic error, {bool isRetry = false}) async {
    try {
      final user = _auth.currentUser;
      final errorData = {
        'query': query,
        'error': error.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'userId': user?.uid,
        'isRetry': isRetry,
        'platform': 'igdb',
      };

      // Log to Firestore for analytics
      await _firestore.collection('search_errors').add(errorData);

      // Note: SystemNotifier logging can be added here if needed
      debugPrint('Search error logged: $errorData');
    } catch (logError) {
      debugPrint('Failed to log search error: $logError');
    }
  }

  // Lobby methods
  Future<void> createLobby(
      String gameName, Map<String, dynamic> settings) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Create lobby in Firestore
      await _firestore.collection('lobbies').add({
        'gameName': gameName,
        'hostId': user.uid,
        'settings': settings,
        'players': [user.uid],
        'isVisible': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _refreshLobbies();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> joinLobby(String lobbyId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Add player to lobby in Firestore
      await _firestore.collection('lobbies').doc(lobbyId).update({
        'players': FieldValue.arrayUnion([user.uid]),
      });

      await _refreshLobbies();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> leaveLobby(String lobbyId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Remove player from lobby in Firestore
      await _firestore.collection('lobbies').doc(lobbyId).update({
        'players': FieldValue.arrayRemove([user.uid]),
      });

      await _refreshLobbies();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> _refreshLobbies() async {
    try {
      // Load visible lobbies from Firestore
      final lobbiesSnapshot = await _firestore
          .collection('lobbies')
          .where('isVisible', isEqualTo: true)
          .get();

      final gameLobbies = <String, List<Map<String, dynamic>>>{};
      for (var doc in lobbiesSnapshot.docs) {
        final data = doc.data();
        final gameName = data['gameName'] as String;
        if (!gameLobbies.containsKey(gameName)) {
          gameLobbies[gameName] = [];
        }
        gameLobbies[gameName]!.add(data);
      }

      final newState = state.value!.copyWith(gameLobbies: gameLobbies);
      state = AsyncValue.data(newState);
    } catch (e) {
      // Handle silently
    }
  }

  // Onboarding methods
  Future<void> completeOnboardingStep(
      String step, Map<String, dynamic> data) async {
    try {
      // Simplified - just update local onboarding flow
      final currentFlow = state.value!.onboardingFlow ?? {};
      final updatedFlow = Map<String, dynamic>.from(currentFlow);
      updatedFlow[step] = data;

      final newState = state.value!.copyWith(onboardingFlow: updatedFlow);
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> pinGame(Map<String, dynamic> game) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pinnedGames = prefs.getStringList('pinned_games') ?? [];
      final gameName = game['name'] as String;

      if (!pinnedGames.contains(gameName)) {
        pinnedGames.add(gameName);
        await prefs.setStringList('pinned_games', pinnedGames);
      }

      // Refresh available games to reflect pinning
      await _initializeGames();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> unpinGame(String gameName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pinnedGames = prefs.getStringList('pinned_games') ?? [];
      pinnedGames.remove(gameName);
      await prefs.setStringList('pinned_games', pinnedGames);

      await _initializeGames();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Game history
  Future<void> addToGameHistory(Map<String, dynamic> gameEntry) async {
    final currentHistory =
        List<Map<String, dynamic>>.from(state.value!.gameHistory);
    currentHistory.insert(0, gameEntry); // Add to beginning

    final newState = state.value!.copyWith(gameHistory: currentHistory);
    state = AsyncValue.data(newState);
  }

  /// Handle AsyncValue error states with automatic recovery
  Future<void> handleSearchError(BuildContext context, String query, dynamic error) async {
    // Log the error
    await _logSearchError(query, error);

    // Try to recover with cached data
    await _fallbackSearch(query);

    // Update onboarding flow if applicable
    await _updateOnboardingFlowOnError(query, error);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search failed, showing cached results. Error: $error'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => retrySearchIGDB(context, query),
          ),
        ),
      );
    }
  }

  /// Update onboarding flow when search errors occur
  Future<void> _updateOnboardingFlowOnError(String query, dynamic error) async {
    final currentFlow = state.value!.onboardingFlow ?? {};
    final searchErrors = currentFlow['searchErrors'] as List<dynamic>? ?? [];

    searchErrors.add({
      'query': query,
      'error': error.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    });

    final updatedFlow = Map<String, dynamic>.from(currentFlow)
      ..['searchErrors'] = searchErrors
      ..['lastErrorTime'] = DateTime.now().toIso8601String();

    final newState = state.value!.copyWith(onboardingFlow: updatedFlow);
    state = AsyncValue.data(newState);
  }

  /// Get games for onboarding flow with error handling
  Future<List<Map<String, dynamic>>> getOnboardingGames() async {
    try {
      // Try to get popular games for onboarding
      final games = await _igdbService.fetchGames('');
      return games.take(5).toList(); // Limit for onboarding
    } catch (e) {
      // Fallback to basic games from Firestore
      try {
        final gamesSnapshot = await _firestore.collection('games').limit(5).get();
        return gamesSnapshot.docs.map((doc) => doc.data()).toList();
      } catch (firestoreError) {
        // Final fallback - return empty list
        debugPrint('Onboarding games failed: $firestoreError');
        return [];
      }
    }
  }

  /// Enhanced game selection with UID-based user tracking
  Future<void> selectGameWithTracking(Map<String, dynamic> game) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Update current game
    await selectGame(game);

    // Track game selection for analytics
    try {
      await _firestore.collection('game_selections').add({
        'userId': user.uid,
        'gameName': game['name'],
        'gameSlug': game['slug'],
        'selectedAt': FieldValue.serverTimestamp(),
        'maxSpots': game['maxSpots'] ?? 6,
      });
    } catch (e) {
      debugPrint('Failed to track game selection: $e');
    }

    // Update onboarding flow
    final currentFlow = state.value!.onboardingFlow ?? {};
    final selectedGames = currentFlow['selectedGames'] as List<dynamic>? ?? [];

    if (!selectedGames.contains(game['name'])) {
      selectedGames.add(game['name']);
      final updatedFlow = Map<String, dynamic>.from(currentFlow)
        ..['selectedGames'] = selectedGames
        ..['lastGameSelection'] = DateTime.now().toIso8601String();

      final newState = state.value!.copyWith(onboardingFlow: updatedFlow);
      state = AsyncValue.data(newState);
    }
  }
}

/// Family provider for query-based game searches
@riverpod
Future<List<Map<String, dynamic>>> gameSearchResults(
  Ref ref,
  String query,
) async {
  final igdbService = ref.watch(igdb_service.igdbServiceProvider);
  return igdbService.fetchGames(query);
}

/// Family provider for game details with caching
@riverpod
Future<Map<String, dynamic>?> gameDetails(
  Ref ref,
  String gameSlug,
) async {
  final igdbService = ref.watch(igdb_service.igdbServiceProvider);

  // For now, return basic game data - could be extended for detailed API calls
  final games = await igdbService.fetchGames(gameSlug);
  return games.isNotEmpty ? games.first : null;
}

/// Family provider for popular games (empty query)
@riverpod
Future<List<Map<String, dynamic>>> popularGames(
  Ref ref,
) async {
  final igdbService = ref.watch(igdb_service.igdbServiceProvider);
  return igdbService.fetchGames(''); // Empty query returns popular games
}

/// Provider for game-scoped data with current game context
@riverpod
Future<Map<String, dynamic>> gameScopedData(
  Ref ref,
  String gameName,
) async {
  // Get game data from IGDB service
  final igdbService = ref.watch(igdb_service.igdbServiceProvider);

  try {
    final games = await igdbService.fetchGames(gameName);
    final gameData = games.isNotEmpty ? games.first : null;

    return {
      'gameName': gameName,
      'maxSpots': gameData?['maxSpots'] ?? 6,
      'currentPlayers': 0, // Would need a separate query for active lobbies
      'isPinned': false, // Would need user preferences integration
      'gameData': gameData,
    };
  } catch (e) {
    return {
      'gameName': gameName,
      'maxSpots': 6,
      'currentPlayers': 0,
      'isPinned': false,
      'error': e.toString(),
    };
  }
}

/// Provider for UID-based user game preferences
@riverpod
Future<Map<String, dynamic>> userGamePreferences(
  Ref ref,
  String userId,
) async {
  final firestore = ref.watch(firestoreServiceProvider);

  try {
    final doc = await firestore.loadFirestore('user_preferences', userId);
    return doc ?? {
      'pinnedGames': [],
      'mutedGames': [],
      'gameHistory': [],
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  } catch (e) {
    return {
      'pinnedGames': [],
      'mutedGames': [],
      'gameHistory': [],
      'lastUpdated': DateTime.now().toIso8601String(),
      'error': e.toString(),
    };
  }
}

/// Provider for game statistics and analytics
@riverpod
Future<Map<String, dynamic>> gameStatistics(
  Ref ref,
  String gameName,
) async {
  final firestore = ref.watch(firestoreServiceProvider);

  try {
    // Get game stats from Firestore
    final statsDoc = await firestore.loadFirestore('game_stats', gameName);
    return statsDoc ?? {
      'gameName': gameName,
      'totalPlayers': 0,
      'activeLobbies': 0,
      'averageRating': 0.0,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  } catch (e) {
    return {
      'gameName': gameName,
      'totalPlayers': 0,
      'activeLobbies': 0,
      'averageRating': 0.0,
      'lastUpdated': DateTime.now().toIso8601String(),
      'error': e.toString(),
    };
  }
}