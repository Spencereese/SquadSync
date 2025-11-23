import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/domain/repositories/game_repository.dart';
import 'package:squad_sync/domain/usecases/fetch_games.dart';

// Mock class for GameRepository
class MockGameRepository implements GameRepository {
  List<Game>? _fetchGamesResponse;
  Exception? _fetchGamesException;

  void setFetchGamesResponse(List<Game> response) {
    _fetchGamesResponse = response;
    _fetchGamesException = null;
  }

  void setFetchGamesException(Exception exception) {
    _fetchGamesException = exception;
    _fetchGamesResponse = null;
  }

  @override
  Future<List<Game>> fetchGames(String query, {int limit = 10}) async {
    if (_fetchGamesException != null) {
      throw _fetchGamesException!;
    }
    return _fetchGamesResponse ?? [];
  }

  @override
  Future<Game?> getGameDetails(int igdbId) => throw UnimplementedError();

  @override
  Future<List<Game>> getPopularGames() => throw UnimplementedError();

  @override
  Future<void> syncGamesToFirestore(String query, List<Game> games) => throw UnimplementedError();

  @override
  Future<void> cacheGamesLocally(String query, List<Game> games) => throw UnimplementedError();

  @override
  Future<List<Game>> getCachedGames(String query) => throw UnimplementedError();

  @override
  Future<List<Game>> getOfflineGames(String query, {int limit = 10}) => throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getAvailableGames() => throw UnimplementedError();

  @override
  Future<Map<String, List<Map<String, dynamic>>>> getGameLobbies() => throw UnimplementedError();
}

void main() {
  late MockGameRepository mockGameRepository;
  late FetchGames usecase;

  setUp(() {
    mockGameRepository = MockGameRepository();
    usecase = FetchGames(mockGameRepository);
  });

  group('FetchGames', () {
    const query = 'Call of Duty';
    const limit = 10;

    final mockGames = [
      const Game(
        name: 'Call of Duty: Modern Warfare',
        slug: 'call-of-duty-modern-warfare',
        igdbId: 12345,
        coverUrl: 'https://example.com/cover1.jpg',
        summary: 'A first-person shooter game',
        firstReleaseDate: null,
        genres: ['Shooter', 'Action'],
        platforms: ['PC', 'PlayStation', 'Xbox'],
        maxSpots: 4,
        isCached: false,
        cachedAt: null,
      ),
      const Game(
        name: 'Call of Duty: Warzone',
        slug: 'call-of-duty-warzone',
        igdbId: 12346,
        coverUrl: 'https://example.com/cover2.jpg',
        summary: 'A battle royale game',
        firstReleaseDate: null,
        genres: ['Shooter', 'Battle Royale'],
        platforms: ['PC', 'PlayStation', 'Xbox'],
        maxSpots: 6,
        isCached: false,
        cachedAt: null,
      ),
    ];

    test('should return games when repository succeeds', () async {
      // Arrange
      mockGameRepository.setFetchGamesResponse(mockGames);

      // Act
      final result = await usecase.call(query, limit: limit);

      // Assert
      expect(result, equals(mockGames));
    });

    test('should return empty list when no games found', () async {
      // Arrange
      mockGameRepository.setFetchGamesResponse([]);

      // Act
      final result = await usecase.call(query, limit: limit);

      // Assert
      expect(result, isEmpty);
    });

    test('should use default limit when not specified', () async {
      // Arrange
      mockGameRepository.setFetchGamesResponse(mockGames);

      // Act
      final result = await usecase.call(query);

      // Assert
      expect(result, equals(mockGames));
    });

    test('should handle empty query', () async {
      // Arrange
      const emptyQuery = '';
      mockGameRepository.setFetchGamesResponse(mockGames);

      // Act
      final result = await usecase.call(emptyQuery, limit: limit);

      // Assert
      expect(result, equals(mockGames));
    });

    test('should propagate repository exceptions', () async {
      // Arrange
      final exception = Exception('Network error');
      mockGameRepository.setFetchGamesException(exception);

      // Act & Assert
      expect(
        () => usecase.call(query, limit: limit),
        throwsA(equals(exception)),
      );
    });

    test('should handle network timeout', () async {
      // Arrange
      final timeoutException = Exception('Timeout');
      mockGameRepository.setFetchGamesException(timeoutException);

      // Act & Assert
      expect(
        () => usecase.call(query, limit: limit),
        throwsA(equals(timeoutException)),
      );
    });

    test('should handle rate limiting', () async {
      // Arrange
      final rateLimitException = Exception('Rate limit exceeded');
      mockGameRepository.setFetchGamesException(rateLimitException);

      // Act & Assert
      expect(
        () => usecase.call(query, limit: limit),
        throwsA(equals(rateLimitException)),
      );
    });

    test('should handle invalid JSON response', () async {
      // Arrange
      final jsonException = Exception('Invalid JSON');
      mockGameRepository.setFetchGamesException(jsonException);

      // Act & Assert
      expect(
        () => usecase.call(query, limit: limit),
        throwsA(equals(jsonException)),
      );
    });
  });
}