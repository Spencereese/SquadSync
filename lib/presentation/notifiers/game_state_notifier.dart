import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/domain/repositories/game_repository.dart';
import 'package:squad_sync/core/injection.dart';

import 'discovery_notifier.dart' as discovery;

part 'game_state_notifier.freezed.dart';

/// State for game selection and tracking
@freezed // Disable DiagnosticableTreeMixin - has bugs in Freezed 3.0
class GameSelectionState with _$GameSelectionState {
  const factory GameSelectionState({
    required Map<String, dynamic>? currentGame,
    required String currentGameName,
    required List<Map<String, dynamic>> availableGames,
    required List<Map<String, dynamic>> gameHistory,
    required Map<String, List<Map<String, dynamic>>> gameLobbies,
    required Map<String, String?> preferredModes,
    required Set<String> mutedGames,
    required Set<String> hiddenGames,
    required bool isLoading,
  }) = _GameSelectionState;

  factory GameSelectionState.initial() => const GameSelectionState(
        currentGame: null,
        currentGameName: '',
        availableGames: [],
        gameHistory: [],
        gameLobbies: {},
        preferredModes: {},
        mutedGames: {},
        hiddenGames: {},
        isLoading: false,
      );
}

/// Manages game selection logic, current game tracking, and IGDB integration
/// Coordinates with DiscoveryNotifier for filters/popular games
class GameStateNotifier extends AutoDisposeAsyncNotifier<GameSelectionState> {
  late final GameRepository _repository;

  StreamSubscription? _gameSelectionSubscription;

  @override
  Future<GameSelectionState> build() async {
    try {
      _repository = ref.read(gameRepositoryProvider);

      ref.onDispose(() {
        _gameSelectionSubscription?.cancel();
      });

      // Load initial game data
      return await _loadGameData();
    } catch (e) {
      debugPrint('Error initializing GameStateNotifier: $e');
      return GameSelectionState.initial();
    }
  }

  Future<GameSelectionState> _loadGameData() async {
    try {
      final availableGames = await _repository.getAvailableGames();
      final gameLobbies = await _repository.getGameLobbies();

      return GameSelectionState.initial().copyWith(
        availableGames: availableGames,
        gameLobbies: gameLobbies,
      );
    } catch (e) {
      debugPrint('Error loading game data: $e');
      return GameSelectionState.initial();
    }
  }

  /// Set the current game
  Future<void> setCurrentGame(Map<String, dynamic>? game) async {
    try {
      final currentState = state.valueOrNull ?? GameSelectionState.initial();

      debugPrint(
          'Setting current game: ${game?['name']}, coverUrl: ${game?['coverUrl']}');

      state = AsyncData(currentState.copyWith(
        currentGame: game,
        currentGameName: game?['name'] as String? ?? '',
      ));

      // Add to game history if not null
      if (game != null) {
        await _addToGameHistory(game);
      }
    } catch (e) {
      debugPrint('Error setting current game: $e');
    }
  }

  /// Add a game to history
  Future<void> _addToGameHistory(Map<String, dynamic> game) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    final history = List<Map<String, dynamic>>.from(currentState.gameHistory);

    // Remove if already exists to avoid duplicates
    history.removeWhere((g) => g['name'] == game['name']);

    // Add to front of history
    history.insert(0, {
      ...game,
      'lastPlayedAt': DateTime.now().toIso8601String(),
    });

    // Keep only last 20 games
    if (history.length > 20) {
      history.removeRange(20, history.length);
    }

    state = AsyncData(currentState.copyWith(gameHistory: history));
  }

  /// Clear current game selection
  void clearCurrentGame() {
    final currentState = state.valueOrNull;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(
        currentGame: null,
        currentGameName: '',
      ));
    }
  }

  /// Search for games via IGDB
  Future<List<Game>> searchGames(String query, {int limit = 10}) async {
    if (query.isEmpty) return [];

    try {
      final currentState = state.valueOrNull ?? GameSelectionState.initial();
      state = AsyncData(currentState.copyWith(isLoading: true));

      final games = await _repository.fetchGames(query, limit: limit);

      state = AsyncData((state.valueOrNull ?? GameSelectionState.initial())
          .copyWith(isLoading: false));

      return games;
    } catch (e) {
      debugPrint('Error searching games: $e');
      state = AsyncData((state.valueOrNull ?? GameSelectionState.initial())
          .copyWith(isLoading: false));
      return [];
    }
  }

  /// Get popular games from IGDB
  Future<List<Game>> getPopularGames() async {
    try {
      final currentState = state.valueOrNull ?? GameSelectionState.initial();
      state = AsyncData(currentState.copyWith(isLoading: true));

      final games = await _repository.getPopularGames();

      state = AsyncData((state.valueOrNull ?? GameSelectionState.initial())
          .copyWith(isLoading: false));

      return games;
    } catch (e) {
      debugPrint('Error fetching popular games: $e');
      state = AsyncData((state.valueOrNull ?? GameSelectionState.initial())
          .copyWith(isLoading: false));
      return [];
    }
  }

  /// Get game details from IGDB
  Future<Game?> getGameDetails(int igdbId) async {
    try {
      return await _repository.getGameDetails(igdbId);
    } catch (e) {
      debugPrint('Error fetching game details: $e');
      return null;
    }
  }

  /// Get cached games for offline support
  Future<List<Game>> getCachedGames(String query) async {
    try {
      return await _repository.getCachedGames(query);
    } catch (e) {
      debugPrint('Error getting cached games: $e');
      return [];
    }
  }

  /// Get offline games from local JSON
  Future<List<Game>> getOfflineGames(String query, {int limit = 10}) async {
    try {
      return await _repository.getOfflineGames(query, limit: limit);
    } catch (e) {
      debugPrint('Error getting offline games: $e');
      return [];
    }
  }

  /// Update preferred game mode
  void updatePreferredMode(String gameName, String? mode) {
    final currentState = state.valueOrNull;
    if (currentState != null) {
      final updatedModes =
          Map<String, String?>.from(currentState.preferredModes);
      updatedModes[gameName] = mode;

      state = AsyncData(currentState.copyWith(preferredModes: updatedModes));
    }
  }

  /// Mute a game
  void muteGame(String gameName) {
    final currentState = state.valueOrNull;
    if (currentState != null) {
      final updatedMuted = Set<String>.from(currentState.mutedGames);
      updatedMuted.add(gameName);

      state = AsyncData(currentState.copyWith(mutedGames: updatedMuted));
    }
  }

  /// Unmute a game
  void unmuteGame(String gameName) {
    final currentState = state.valueOrNull;
    if (currentState != null) {
      final updatedMuted = Set<String>.from(currentState.mutedGames);
      updatedMuted.remove(gameName);

      state = AsyncData(currentState.copyWith(mutedGames: updatedMuted));
    }
  }

  /// Hide a game
  void hideGame(String gameName) {
    final currentState = state.valueOrNull;
    if (currentState != null) {
      final updatedHidden = Set<String>.from(currentState.hiddenGames);
      updatedHidden.add(gameName);

      state = AsyncData(currentState.copyWith(hiddenGames: updatedHidden));
    }
  }

  /// Unhide a game
  void unhideGame(String gameName) {
    final currentState = state.valueOrNull;
    if (currentState != null) {
      final updatedHidden = Set<String>.from(currentState.hiddenGames);
      updatedHidden.remove(gameName);

      state = AsyncData(currentState.copyWith(hiddenGames: updatedHidden));
    }
  }

  /// Get available games list
  List<Map<String, dynamic>> get availableGames => state.maybeWhen(
        data: (data) => data.availableGames,
        orElse: () => [],
      );

  /// Get game history
  List<Map<String, dynamic>> get gameHistory => state.maybeWhen(
        data: (data) => data.gameHistory,
        orElse: () => [],
      );

  /// Get current game
  Map<String, dynamic>? get currentGame => state.maybeWhen(
        data: (data) => data.currentGame,
        orElse: () => null,
      );

  /// Get current game name
  String get currentGameName => state.maybeWhen(
        data: (data) => data.currentGameName,
        orElse: () => '',
      );

  /// Check if a game is muted
  bool isGameMuted(String gameName) => state.maybeWhen(
        data: (data) => data.mutedGames.contains(gameName),
        orElse: () => false,
      );

  /// Check if a game is hidden
  bool isGameHidden(String gameName) => state.maybeWhen(
        data: (data) => data.hiddenGames.contains(gameName),
        orElse: () => false,
      );

  /// Get lobbies for a specific game
  List<Map<String, dynamic>> getLobbiesForGame(String gameName) =>
      state.maybeWhen(
        data: (data) => data.gameLobbies[gameName] ?? [],
        orElse: () => [],
      );

  /// Reload game data
  Future<void> refreshGameData() async {
    try {
      final newState = await _loadGameData();
      state = AsyncData(newState);
    } catch (e) {
      debugPrint('Error refreshing game data: $e');
    }
  }

  /// Integrate with DiscoveryNotifier for popular games
  Future<void> syncWithDiscovery() async {
    try {
      // Watch popular games from discovery
      final popularGames =
          await ref.read(discovery.popularGamesProvider.future);

      final currentState = state.valueOrNull;
      if (currentState != null) {
        // Update available games with popular games
        debugPrint(
            'Synced ${popularGames.length} popular games from discovery');
      }
    } catch (e) {
      debugPrint('Error syncing with discovery: $e');
    }
  }
}

// Backward compatibility alias (riverpod generates 'gameStateProvider')
final gameStateNotifierProvider =
    AutoDisposeAsyncNotifierProvider<GameStateNotifier, GameSelectionState>.new(
  GameStateNotifier.new,
);

/// Convenience provider to get current game
final currentGameProvider = Provider<Map<String, dynamic>?>((ref) {
  return ref.watch(
    gameStateNotifierProvider.select(
      (asyncState) => asyncState.maybeWhen(
        data: (state) => state.currentGame,
        orElse: () => null,
      ),
    ),
  );
});

/// Convenience provider to check if a game is muted
final isGameMutedProvider = Provider.family<bool, String>((ref, gameName) {
  return ref.watch(
    gameStateNotifierProvider.select(
      (asyncState) => asyncState.maybeWhen(
        data: (state) => state.mutedGames.contains(gameName),
        orElse: () => false,
      ),
    ),
  );
});

/// Convenience provider to get game history
final gameHistoryProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(
    gameStateNotifierProvider.select(
      (asyncState) => asyncState.maybeWhen(
        data: (state) => state.gameHistory,
        orElse: () => [],
      ),
    ),
  );
});
