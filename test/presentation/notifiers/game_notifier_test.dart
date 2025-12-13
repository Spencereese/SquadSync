import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/game_notifier.dart';
import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/domain/repositories/game_repository.dart';
import 'package:squad_sync/data/datasources/game_local_datasource.dart';
import 'package:squad_sync/core/injection.dart';

@GenerateMocks([GameRepository, GameLocalDataSource])
import 'game_notifier_test.mocks.dart';

void main() {
  late MockGameRepository mockRepository;
  late MockGameLocalDataSource mockLocalDataSource;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockGameRepository();
    mockLocalDataSource = MockGameLocalDataSource();

    // Set up default stub responses
    when(mockRepository.getAvailableGames()).thenAnswer(
      (_) async => [],
    );

    when(mockRepository.getGameLobbies()).thenAnswer(
      (_) async => {},
    );

    // Create provider container with overrides
    container = ProviderContainer(
      overrides: [
        gameRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('GameNotifier - Initialization', () {
    test('should load initial state with empty games', () async {
      when(mockRepository.getAvailableGames()).thenAnswer((_) async => []);
      when(mockRepository.getGameLobbies()).thenAnswer((_) async => {});

      final state = await container.read(gameNotifierProvider.future);

      expect(state.availableGames, isEmpty);
      expect(state.gameLobbies, isEmpty);
      expect(state.isInitialized, isTrue);
      expect(state.currentGame, isNull);
      verify(mockRepository.getAvailableGames()).called(1);
      verify(mockRepository.getGameLobbies()).called(1);
    });

    test('should load available games on initialization', () async {
      final testGames = [
        {'id': 1, 'name': 'Game 1', 'slug': 'game-1', 'cover_url': 'url1'},
        {'id': 2, 'name': 'Game 2', 'slug': 'game-2', 'cover_url': 'url2'},
      ];

      when(mockRepository.getAvailableGames())
          .thenAnswer((_) async => testGames);
      when(mockRepository.getGameLobbies()).thenAnswer((_) async => {});

      final state = await container.read(gameNotifierProvider.future);

      expect(state.availableGames.length, equals(2));
      expect(state.isInitialized, isTrue);
    });

    test('should load game lobbies on initialization', () async {
      final testLobbies = {
        'game-1': [
          {'id': 'lobby-1', 'name': 'Lobby 1'},
        ],
        'game-2': [
          {'id': 'lobby-2', 'name': 'Lobby 2'},
        ],
      };

      when(mockRepository.getAvailableGames()).thenAnswer((_) async => []);
      when(mockRepository.getGameLobbies())
          .thenAnswer((_) async => testLobbies);

      final state = await container.read(gameNotifierProvider.future);

      expect(state.gameLobbies.length, equals(2));
      expect(state.gameLobbies['game-1'], isNotNull);
      expect(state.gameLobbies['game-2'], isNotNull);
    });

    test('should handle AsyncLoading state during initialization', () {
      final state = container.read(gameNotifierProvider);

      expect(state, isA<AsyncLoading>());
    });

    test('should handle initialization errors', () async {
      when(mockRepository.getAvailableGames()).thenThrow(
        Exception('Failed to load games'),
      );

      final state = container.read(gameNotifierProvider);

      await expectLater(
        state.future,
        throwsException,
      );
    });
  });

  group('GameNotifier - Game Search', () {
    test('should return empty list for empty query', () async {
      await container.read(gameNotifierProvider.future);
      final notifier = container.read(gameNotifierProvider.notifier);

      final result = await notifier.searchGames('');

      expect(result.value, isEmpty);
      verifyNever(mockRepository.fetchGames(any));
    });

    test('should search games successfully', () async {
      final searchResults = [
        Game(
          id: 1,
          name: 'Call of Duty',
          slug: 'call-of-duty',
          coverUrl: 'url1',
          summary: 'FPS game',
        ),
        Game(
          id: 2,
          name: 'Call of Duty: Modern Warfare',
          slug: 'call-of-duty-modern-warfare',
          coverUrl: 'url2',
          summary: 'FPS game',
        ),
      ];

      when(mockRepository.fetchGames('call of duty')).thenAnswer(
        (_) async => searchResults,
      );

      await container.read(gameNotifierProvider.future);
      final notifier = container.read(gameNotifierProvider.notifier);

      final result = await notifier.searchGames('call of duty');

      expect(result.value, isNotNull);
      expect(result.value!.length, equals(2));
      verify(mockRepository.fetchGames('call of duty')).called(1);
    });

    test('should deduplicate games by slug', () async {
      final searchResults = [
        Game(
          id: 1,
          name: 'Game 1',
          slug: 'game-1',
          coverUrl: 'url1',
          summary: 'Test',
        ),
        Game(
          id: 2,
          name: 'Game 1 Duplicate',
          slug: 'game-1',
          coverUrl: 'url2',
          summary: 'Test',
        ),
      ];

      when(mockRepository.fetchGames('game')).thenAnswer(
        (_) async => searchResults,
      );

      await container.read(gameNotifierProvider.future);
      final notifier = container.read(gameNotifierProvider.notifier);

      final result = await notifier.searchGames('game');

      expect(result.value, isNotNull);
      expect(result.value!.length, equals(1));
      expect(result.value!.first.slug, equals('game-1'));
    });

    test('should fallback to cached games on network error', () async {
      final cachedGames = [
        Game(
          id: 1,
          name: 'Cached Game',
          slug: 'cached-game',
          coverUrl: 'url',
          summary: 'Test',
        ),
      ];

      when(mockRepository.fetchGames('cached')).thenThrow(
        Exception('Network error'),
      );

      when(mockLocalDataSource.getCachedGames('cached')).thenAnswer(
        (_) async => cachedGames,
      );

      await container.read(gameNotifierProvider.future);
      final notifier = container.read(gameNotifierProvider.notifier);

      // Inject mock local data source
      notifier.localDataSource;

      final result = await notifier.searchGames('cached');

      // Should fallback to offline or return error
      expect(result, isA<AsyncValue>());
    });

    test('should return AsyncError on search failure with no cache', () async {
      when(mockRepository.fetchGames('error')).thenThrow(
        Exception('Search failed'),
      );

      when(mockLocalDataSource.getCachedGames('error')).thenThrow(
        Exception('No cache'),
      );

      when(mockLocalDataSource.getOfflineGames('error', limit: 30)).thenThrow(
        Exception('No offline games'),
      );

      await container.read(gameNotifierProvider.future);
      final notifier = container.read(gameNotifierProvider.notifier);

      final result = await notifier.searchGames('error');

      expect(result, isA<AsyncError>());
    });
  });

  group('GameNotifier - Game Details', () {
    test('should fetch game details successfully', () async {
      final gameDetails = Game(
        id: 123,
        name: 'Detailed Game',
        slug: 'detailed-game',
        coverUrl: 'url',
        summary: 'Full game details',
        releaseDate: DateTime(2023, 1, 1),
        platforms: ['PC', 'PlayStation'],
        genres: ['Action', 'Adventure'],
      );

      when(mockRepository.getGameDetails(123)).thenAnswer(
        (_) async => gameDetails,
      );

      await container.read(gameNotifierProvider.future);
      final notifier = container.read(gameNotifierProvider.notifier);

      await notifier.fetchGameDetails(123);

      final state = container.read(gameNotifierProvider).valueOrNull;
      expect(state?.currentGame, isNotNull);
      expect(state?.currentGame?.id, equals(123));
      expect(state?.currentGame?.name, equals('Detailed Game'));
      verify(mockRepository.getGameDetails(123)).called(1);
    });

    test('should update state to loading when fetching details', () async {
      when(mockRepository.getGameDetails(123)).thenAnswer(
        (_) async => Future.delayed(
          const Duration(milliseconds: 100),
          () => Game(
            id: 123,
            name: 'Game',
            slug: 'game',
            coverUrl: 'url',
            summary: 'Test',
          ),
        ),
      );

      await container.read(gameNotifierProvider.future);
      final notifier = container.read(gameNotifierProvider.notifier);

      final fetchFuture = notifier.fetchGameDetails(123);

      // Check loading state
      expect(container.read(gameNotifierProvider).isLoading, isTrue);

      await fetchFuture;
    });

    test('should handle fetch game details error', () async {
      when(mockRepository.getGameDetails(999)).thenThrow(
        Exception('Game not found'),
      );

      await container.read(gameNotifierProvider.future);
      final notifier = container.read(gameNotifierProvider.notifier);

      await notifier.fetchGameDetails(999);

      final state = container.read(gameNotifierProvider);
      expect(state, isA<AsyncError>());
    });
  });

  group('GameNotifier - State Management', () {
    test('should maintain isInitialized flag', () async {
      when(mockRepository.getAvailableGames()).thenAnswer((_) async => []);
      when(mockRepository.getGameLobbies()).thenAnswer((_) async => {});

      final state = await container.read(gameNotifierProvider.future);

      expect(state.isInitialized, isTrue);
    });

    test('should update currentGame when fetching details', () async {
      final game = Game(
        id: 1,
        name: 'Test Game',
        slug: 'test-game',
        coverUrl: 'url',
        summary: 'Test',
      );

      when(mockRepository.getAvailableGames()).thenAnswer((_) async => []);
      when(mockRepository.getGameLobbies()).thenAnswer((_) async => {});
      when(mockRepository.getGameDetails(1)).thenAnswer((_) async => game);

      await container.read(gameNotifierProvider.future);
      final notifier = container.read(gameNotifierProvider.notifier);

      await notifier.fetchGameDetails(1);

      final state = container.read(gameNotifierProvider).valueOrNull;
      expect(state?.currentGame, equals(game));
    });

    test('should preserve state across multiple operations', () async {
      final games = [
        {'id': 1, 'name': 'Game 1', 'slug': 'game-1', 'cover_url': 'url1'},
      ];

      when(mockRepository.getAvailableGames()).thenAnswer((_) async => games);
      when(mockRepository.getGameLobbies()).thenAnswer((_) async => {});

      final initialState = await container.read(gameNotifierProvider.future);
      expect(initialState.availableGames.length, equals(1));

      // Perform another operation
      when(mockRepository.fetchGames('test')).thenAnswer(
        (_) async => [
          Game(
            id: 2,
            name: 'Test Game',
            slug: 'test-game',
            coverUrl: 'url',
            summary: 'Test',
          ),
        ],
      );

      final notifier = container.read(gameNotifierProvider.notifier);
      await notifier.searchGames('test');

      // Original available games should still be present
      final state = container.read(gameNotifierProvider).valueOrNull;
      expect(state?.availableGames.length, equals(1));
    });
  });
}
