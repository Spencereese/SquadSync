import 'package:riverpod/riverpod.dart';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logger/logger.dart';
import 'package:dio/dio.dart';
import '../../domain/repositories/game_repository.dart';
import '../../domain/entities/game.dart';
import '../../data/datasources/game_local_datasource.dart';
import '../../services/twitch_service.dart';
import '../../core/injection.dart' as di;
import '../../core/injection.dart';

part 'game_notifier.freezed.dart';

@freezed // Disable DiagnosticableTreeMixin - has bugs in Freezed 3.0
class GameState with _$GameState {
  const factory GameState({
    required List<Game> availableGames,
    required List<Game> gameHistory,
    required Map<String, List<Map<String, dynamic>>> gameLobbies,
    required Game? currentGame,
    required Map<String, dynamic>? onboardingFlow,
    required bool isInitialized,
    required List<Map<String, dynamic>> twitchClips,
    String? errorMessage,
  }) = _GameState;

  factory GameState.initial() => const GameState(
        availableGames: [],
        gameHistory: [],
        gameLobbies: {},
        currentGame: null,
        onboardingFlow: null,
        isInitialized: false,
        twitchClips: [],
        errorMessage: null,
      );
}

class GameNotifier extends AutoDisposeAsyncNotifier<GameState> {
  late final GameRepository _repository;
  GameLocalDataSource? _localDataSource;
  TwitchService? _twitchService;
  final Logger _logger = Logger();

  GameLocalDataSource get localDataSource => _localDataSource!;

  @override
  Future<GameState> build() async {
    _logger.i('🎮 GameNotifier: Initializing...');
    
    // Initialize dependencies
    _repository = ref.read(gameRepositoryProvider);
    _localDataSource ??= di.getIt<GameLocalDataSource>();
    _twitchService = TwitchService(di.getIt<Dio>());

    // Initialize Twitch service (non-blocking)
    _twitchService?.initialize().catchError((e) {
      _logger.w('⚠️ Twitch service initialization failed: $e');
    });

    _logger.i('📚 GameNotifier: Loading available games and lobbies...');
    
    // Initialize games and lobbies
    final availableGames = await _repository.getAvailableGames();
    final gameLobbies = await _repository.getGameLobbies();
    
    _logger.i('✅ GameNotifier: Initialized with ${availableGames.length} games');

    return GameState.initial().copyWith(
      availableGames: availableGames.map((g) => Game.fromCache(g)).toList(),
      gameLobbies: gameLobbies,
      isInitialized: true,
    );
  }

  Future<AsyncValue<List<Game>>> searchGames(String query) async {
    if (query.isEmpty || state.isLoading) {
      return AsyncValue.data([]);
    }

    try {
      // Try IGDB first
      final games = await _repository.fetchGames(query);
      final dedupedGames = _dedupGamesBySlug(games);
      return AsyncValue.data(dedupedGames);
    } catch (e) {
      _logger.w('IGDB search failed, falling back to cache/local: $e');

      // Fallback chain: cached -> local JSON
      try {
        final cachedGames = await localDataSource.getCachedGames(query);
        if (cachedGames.isNotEmpty) {
          final dedupedGames = _dedupGamesBySlug(cachedGames);
          return AsyncValue.data(dedupedGames);
        }

        // Final fallback: filter popular_games.json
        final offlineGames =
            await localDataSource.getOfflineGames(query, limit: 30);
        final dedupedGames = _dedupGamesBySlug(offlineGames);
        return AsyncValue.data(dedupedGames);
      } catch (offlineError) {
        _logger.e('All search fallbacks failed: $offlineError');
        return AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  /// Fetch Twitch clips for current game
  Future<void> fetchTwitchClips({
    String? gameName,
    int limit = 20,
    String period = 'week',
  }) async {
    if (_twitchService == null || !_twitchService!.isInitialized) {
      _logger.w('Twitch service not available');
      return;
    }

    final targetGame = gameName ?? state.value?.currentGame?.name;
    if (targetGame == null) {
      _logger.w('No game specified for Twitch clips');
      return;
    }

    try {
      final clips = await _twitchService!.getClipsForGame(
        targetGame,
        limit: limit,
        period: period,
      );

      state = AsyncValue.data(
        state.value!.copyWith(twitchClips: clips),
      );
    } catch (e) {
      _logger.e('Error fetching Twitch clips: $e');
    }
  }

  /// Fetch trending Twitch clips (not game-specific)
  Future<void> fetchTrendingClips({
    int limit = 20,
    String period = 'day',
  }) async {
    if (_twitchService == null || !_twitchService!.isInitialized) {
      _logger.w('Twitch service not available');
      return;
    }

    try {
      final clips = await _twitchService!.getTrendingClips(
        limit: limit,
        period: period,
      );

      state = AsyncValue.data(
        state.value!.copyWith(twitchClips: clips),
      );
    } catch (e) {
      _logger.e('Error fetching trending clips: $e');
    }
  }

  List<Game> _dedupGamesBySlug(List<Game> games) {
    final Map<String, Game> deduped = {};
    for (final game in games) {
      deduped[game.slug] = game; // Overwrite duplicates by slug
    }
    return deduped.values.toList();
  }

  Future<void> fetchGameDetails(int igdbId) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final game = await _repository.getGameDetails(igdbId);
      return state.value!.copyWith(currentGame: game);
    });
  }

  Future<AsyncValue<List<Game>>> loadPopularGames() async {
    try {
      final games = await _repository.getPopularGames();
      state = AsyncValue.data(state.value!.copyWith(availableGames: games));
      return AsyncValue.data(games);
    } catch (e) {
      return AsyncValue.error(e, StackTrace.current);
    }
  }

  void setCurrentGame(Game game) {
    state = AsyncValue.data(state.value!.copyWith(currentGame: game));
  }

  void clearError() {
    state = AsyncValue.data(state.value!.copyWith(errorMessage: null));
  }

  Future<List<Map<String, dynamic>>> fetchGamesFromIGDB(String query) async {
    final games = await _repository.fetchGames(query);
    return games.map((game) => game.toJson()).toList();
  }

  bool isGameHidden(String gameName) {
    // TODO: Implement logic to check if game is hidden
    return false;
  }

  Future<void> selectGame(Map<String, dynamic> game) async {
    // TODO: Set current game
  }
}

final gameNotifierProvider =
    AutoDisposeAsyncNotifierProvider<GameNotifier, GameState>.new(
  GameNotifier.new,
);
