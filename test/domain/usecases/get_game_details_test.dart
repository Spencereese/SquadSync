import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/domain/repositories/game_repository.dart';
import 'package:squad_sync/domain/usecases/get_game_details.dart';

// Mock class for GameRepository
class MockGameRepository implements GameRepository {
  Game? _getGameDetailsResponse;
  Exception? _getGameDetailsException;

  void setGetGameDetailsResponse(Game? response) {
    _getGameDetailsResponse = response;
    _getGameDetailsException = null;
  }

  void setGetGameDetailsException(Exception exception) {
    _getGameDetailsException = exception;
    _getGameDetailsResponse = null;
  }

  @override
  Future<Game?> getGameDetails(int igdbId) async {
    if (_getGameDetailsException != null) {
      throw _getGameDetailsException!;
    }
    return _getGameDetailsResponse;
  }

  @override
  Future<List<Game>> fetchGames(String query, {int limit = 10}) => throw UnimplementedError();

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
  late GetGameDetails usecase;

  setUp(() {
    mockGameRepository = MockGameRepository();
    usecase = GetGameDetails(mockGameRepository);
  });

  group('GetGameDetails', () {
    const igdbId = 12345;

    final mockGame = Game(
      name: 'Call of Duty: Modern Warfare',
      slug: 'call-of-duty-modern-warfare',
      igdbId: igdbId,
      coverUrl: 'https://example.com/cover.jpg',
      summary: 'A first-person shooter game',
      firstReleaseDate: DateTime(2020, 1, 1),
      genres: ['Shooter', 'Action'],
      platforms: ['PC', 'PlayStation', 'Xbox'],
      maxSpots: 4,
      isCached: false,
      cachedAt: null,
    );

    test('should return game when repository succeeds', () async {
      // Arrange
      mockGameRepository.setGetGameDetailsResponse(mockGame);

      // Act
      final result = await usecase.call(igdbId);

      // Assert
      expect(result, equals(mockGame));
    });

    test('should return null when game not found', () async {
      // Arrange
      mockGameRepository.setGetGameDetailsResponse(null);

      // Act
      final result = await usecase.call(igdbId);

      // Assert
      expect(result, isNull);
    });

    test('should handle invalid IGDB ID', () async {
      // Arrange
      const invalidId = -1;
      mockGameRepository.setGetGameDetailsResponse(null);

      // Act
      final result = await usecase.call(invalidId);

      // Assert
      expect(result, isNull);
    });

    test('should propagate repository exceptions', () async {
      // Arrange
      final exception = Exception('Network error');
      mockGameRepository.setGetGameDetailsException(exception);

      // Act & Assert
      expect(
        () => usecase.call(igdbId),
        throwsA(equals(exception)),
      );
    });

    test('should handle network timeout', () async {
      // Arrange
      final timeoutException = Exception('Timeout');
      mockGameRepository.setGetGameDetailsException(timeoutException);

      // Act & Assert
      expect(
        () => usecase.call(igdbId),
        throwsA(equals(timeoutException)),
      );
    });

    test('should handle rate limiting', () async {
      // Arrange
      final rateLimitException = Exception('Rate limit exceeded');
      mockGameRepository.setGetGameDetailsException(rateLimitException);

      // Act & Assert
      expect(
        () => usecase.call(igdbId),
        throwsA(equals(rateLimitException)),
      );
    });

    test('should handle invalid JSON response', () async {
      // Arrange
      final jsonException = Exception('Invalid JSON');
      mockGameRepository.setGetGameDetailsException(jsonException);

      // Act & Assert
      expect(
        () => usecase.call(igdbId),
        throwsA(equals(jsonException)),
      );
    });
  });
}