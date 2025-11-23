import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:riverpod_test/riverpod_test.dart';
import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/domain/usecases/game_usecases.dart';
import 'package:squad_sync/presentation/notifiers/game_notifier.dart';

// Mock classes
class MockSearchGamesUseCase extends Mock implements SearchGamesUseCase {
  @override
  Future<List<Game>> call(String query, {int limit = 10}) async => [];
}

class MockGetGameDetailsUseCase extends Mock implements GetGameDetailsUseCase {
  @override
  Future<Game?> call(int igdbId) async => null;
}

class MockLoadPopularGamesUseCase extends Mock implements LoadPopularGamesUseCase {
  @override
  Future<List<Game>> call({int limit = 10}) async => [];
}

void main() {
  late MockSearchGamesUseCase mockSearchGamesUseCase;
  late MockGetGameDetailsUseCase mockGetGameDetailsUseCase;
  late MockLoadPopularGamesUseCase mockLoadPopularGamesUseCase;

  setUp(() {
    mockSearchGamesUseCase = MockSearchGamesUseCase();
    mockGetGameDetailsUseCase = MockGetGameDetailsUseCase();
    mockLoadPopularGamesUseCase = MockLoadPopularGamesUseCase();
  });

  final testGame = Game(
    igdbId: 12345,
    name: 'Test Game',
    slug: 'test-game',
    coverUrl: 'https://example.com/cover.jpg',
    summary: 'A test game',
    releaseDate: DateTime(2023, 1, 1),
    genres: ['Action'],
    platforms: ['PC'],
  );

  group('GameNotifier', () {
    testNotifier<GameNotifier, AsyncValue<List<Game>>>(
      'initial state should be AsyncLoading',
      provider: gameNotifierProvider,
      setUp: () {
        // Setup mocks for initialization
        when(mockLoadPopularGamesUseCase(limit: 20)).thenAnswer((_) async => []);
      },
      expect: () => [const AsyncLoading<List<Game>>()],
    );

    testNotifier<GameNotifier, AsyncValue<List<Game>>>(
      'build should initialize with popular games',
      provider: gameNotifierProvider,
      setUp: () {
        when(mockLoadPopularGamesUseCase(limit: 20)).thenAnswer((_) async => [testGame]);
      },
      expect: () => [
        const AsyncLoading<List<Game>>(),
        AsyncData<List<Game>>([testGame]),
      ],
    );

    testNotifier<GameNotifier, AsyncValue<List<Game>>>(
      'build should handle initialization errors',
      provider: gameNotifierProvider,
      setUp: () {
        when(mockLoadPopularGamesUseCase(limit: 20)).thenThrow(Exception('Init error'));
      },
      expect: () => [
        const AsyncLoading<List<Game>>(),
        isA<AsyncError<List<Game>>>(),
      ],
    );

    testNotifier<GameNotifier, AsyncValue<List<Game>>>(
      'searchGames should update state with search results',
      provider: gameNotifierProvider,
      setUp: () {
        when(mockLoadPopularGamesUseCase(limit: 20)).thenAnswer((_) async => []);
        when(mockSearchGamesUseCase('test query', limit: 10)).thenAnswer((_) async => [testGame]);
      },
      act: (notifier) => notifier.searchGames('test query', limit: 10),
      expect: () => [
        const AsyncLoading<List<Game>>(),
        const AsyncData<List<Game>>([]), // Initial popular games
        const AsyncLoading<List<Game>>(), // Loading during search
        AsyncData<List<Game>>([testGame]), // Search results
      ],
    );

    testNotifier<GameNotifier, AsyncValue<List<Game>>>(
      'searchGames should handle search errors',
      provider: gameNotifierProvider,
      setUp: () {
        when(mockLoadPopularGamesUseCase(limit: 20)).thenAnswer((_) async => []);
        when(mockSearchGamesUseCase('test query', limit: 10)).thenThrow(Exception('Search error'));
      },
      act: (notifier) => notifier.searchGames('test query', limit: 10),
      expect: () => [
        const AsyncLoading<List<Game>>(),
        const AsyncData<List<Game>>([]),
        const AsyncLoading<List<Game>>(),
        isA<AsyncError<List<Game>>>(),
      ],
    );

    testNotifier<GameNotifier, AsyncValue<Game?>>(
      'getGameDetails should return game details',
      provider: gameDetailsNotifierProvider(12345),
      setUp: () {
        when(mockGetGameDetailsUseCase(12345)).thenAnswer((_) async => testGame);
      },
      expect: () => [
        const AsyncLoading<Game?>(),
        AsyncData<Game?>(testGame),
      ],
    );

    testNotifier<GameNotifier, AsyncValue<Game?>>(
      'getGameDetails should handle null results',
      provider: gameDetailsNotifierProvider(99999),
      setUp: () {
        when(mockGetGameDetailsUseCase(99999)).thenAnswer((_) async => null);
      },
      expect: () => [
        const AsyncLoading<Game?>(),
        const AsyncData<Game?>(null),
      ],
    );

    testNotifier<GameNotifier, AsyncValue<Game?>>(
      'getGameDetails should handle errors',
      provider: gameDetailsNotifierProvider(12345),
      setUp: () {
        when(mockGetGameDetailsUseCase(12345)).thenThrow(Exception('Details error'));
      },
      expect: () => [
        const AsyncLoading<Game?>(),
        isA<AsyncError<Game?>>(),
      ],
    );

    testNotifier<GameNotifier, AsyncValue<List<Game>>>(
      'loadPopularGames should update with popular games',
      provider: gameNotifierProvider,
      setUp: () {
        when(mockLoadPopularGamesUseCase(limit: 20)).thenAnswer((_) async => []);
        when(mockLoadPopularGamesUseCase(limit: 15)).thenAnswer((_) async => [testGame]);
      },
      act: (notifier) => notifier.loadPopularGames(limit: 15),
      expect: () => [
        const AsyncLoading<List<Game>>(),
        const AsyncData<List<Game>>([]),
        const AsyncLoading<List<Game>>(),
        AsyncData<List<Game>>([testGame]),
      ],
    );

    testNotifier<GameNotifier, AsyncValue<List<Game>>>(
      'loadPopularGames should handle errors',
      provider: gameNotifierProvider,
      setUp: () {
        when(mockLoadPopularGamesUseCase(limit: 20)).thenAnswer((_) async => []);
        when(mockLoadPopularGamesUseCase(limit: 15)).thenThrow(Exception('Popular error'));
      },
      act: (notifier) => notifier.loadPopularGames(limit: 15),
      expect: () => [
        const AsyncLoading<List<Game>>(),
        const AsyncData<List<Game>>([]),
        const AsyncLoading<List<Game>>(),
        isA<AsyncError<List<Game>>>(),
      ],
    );

    testNotifier<GameNotifier, AsyncValue<List<Game>>>(
      'clearSearch should reset to popular games',
      provider: gameNotifierProvider,
      setUp: () {
        when(mockLoadPopularGamesUseCase(limit: 20)).thenAnswer((_) async => [testGame]);
        when(mockLoadPopularGamesUseCase(limit: 20)).thenAnswer((_) async => [testGame]); // Second call for clear
      },
      act: (notifier) => notifier.clearSearch(),
      expect: () => [
        const AsyncLoading<List<Game>>(),
        AsyncData<List<Game>>([testGame]),
        const AsyncLoading<List<Game>>(),
        AsyncData<List<Game>>([testGame]),
      ],
    );

    testNotifier<GameNotifier, AsyncValue<List<Game>>>(
      'refresh should reload popular games',
      provider: gameNotifierProvider,
      setUp: () {
        when(mockLoadPopularGamesUseCase(limit: 20)).thenAnswer((_) async => []);
        when(mockLoadPopularGamesUseCase(limit: 20)).thenAnswer((_) async => [testGame]); // For refresh
      },
      act: (notifier) => notifier.refresh(),
      expect: () => [
        const AsyncLoading<List<Game>>(),
        const AsyncData<List<Game>>([]),
        const AsyncLoading<List<Game>>(),
        AsyncData<List<Game>>([testGame]),
      ],
    );
  });
}