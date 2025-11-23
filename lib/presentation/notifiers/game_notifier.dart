import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/game.dart';
import '../../domain/usecases/fetch_games.dart';
import '../../domain/usecases/get_game_details.dart';
import '../../domain/usecases/get_popular_games.dart';
import '../../domain/usecases/initialize_games.dart';
import '../../core/injection.dart' as di;

part 'game_notifier.freezed.dart';
part 'game_notifier.g.dart';

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

@riverpod
class GameNotifier extends _$GameNotifier {
  late final FetchGames _fetchGames;
  late final GetGameDetails _getGameDetails;
  late final GetPopularGames _getPopularGames;
  late final InitializeGames _initializeGames;

  @override
  Future<GameState> build() async {
    // Get dependencies from get_it
    _fetchGames = di.getIt<FetchGames>();
    _getGameDetails = di.getIt<GetGameDetails>();
    _getPopularGames = di.getIt<GetPopularGames>();
    _initializeGames = di.getIt<InitializeGames>();

    // Initialize games and lobbies
    final result = await _initializeGames();

    return GameState.initial().copyWith(
      availableGames:
          result.availableGames.map((g) => Game.fromCache(g)).toList(),
      gameLobbies: result.gameLobbies,
      isInitialized: true,
    );
  }

  Future<void> searchGames(String query) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final games = await _fetchGames(query);
      return state.value!.copyWith(availableGames: games);
    });
  }

  Future<void> getGameDetails(int igdbId) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final game = await _getGameDetails(igdbId);
      return state.value!.copyWith(currentGame: game);
    });
  }

  Future<void> loadPopularGames() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final games = await _getPopularGames();
      return state.value!.copyWith(availableGames: games);
    });
  }

  void setCurrentGame(Game game) {
    state = AsyncValue.data(state.value!.copyWith(currentGame: game));
  }

  void clearError() {
    state = AsyncValue.data(state.value!.copyWith(errorMessage: null));
  }
}
