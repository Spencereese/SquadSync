import 'package:riverpod/riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/repositories/game_repository.dart';
import '../../domain/entities/game.dart';
import '../../data/datasources/game_local_datasource.dart';
import '../../core/injection.dart' as di;
import '../../core/injection.dart';

part 'game_notifier.freezed.dart';

@freezed
class GameState with _$GameState {
  const factory GameState({
    required List<Game> availableGames,
    required List<Game> gameHistory,
    required Map<String, List<Map<String, dynamic>>> gameLobbies,
    required Game? currentGame,
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

class GameNotifier extends AutoDisposeAsyncNotifier<GameState> {
  late final GameRepository _repository;
  GameLocalDataSource? _localDataSource;

  GameLocalDataSource get localDataSource => _localDataSource!;

  @override
  Future<GameState> build() async {
    // Initialize dependencies
    _repository = ref.read(gameRepositoryProvider);
    _localDataSource ??= di.getIt<GameLocalDataSource>();

    // Initialize games and lobbies
    final availableGames = await _repository.getAvailableGames();
    final gameLobbies = await _repository.getGameLobbies();

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
      final games = await _repository.fetchGames(query);
      final dedupedGames = _dedupGamesBySlug(games);
      return AsyncValue.data(dedupedGames);
    } catch (e) {
      // Fallback to cached/offline
      try {
        final cachedGames = await localDataSource.getCachedGames(query);
        if (cachedGames.isNotEmpty) {
          final dedupedGames = _dedupGamesBySlug(cachedGames);
          return AsyncValue.data(dedupedGames);
        }
        // Offline: filter popular_games.json
        final offlineGames =
            await localDataSource.getOfflineGames(query, limit: 30);
        final dedupedGames = _dedupGamesBySlug(offlineGames);
        return AsyncValue.data(dedupedGames);
      } catch (offlineError) {
        return AsyncValue.error(e, StackTrace.current);
      }
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
    AutoDisposeAsyncNotifierProvider<GameNotifier, GameState>(
  () => GameNotifier(),
);
