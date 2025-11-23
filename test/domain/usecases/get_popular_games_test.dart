import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/domain/usecases/get_popular_games.dart';

import '../../helpers/mocks.mocks.dart';

void main() {
  late MockGameRepository mockGameRepository;
  late GetPopularGames usecase;

  setUp(() {
    mockGameRepository = MockGameRepository();
    usecase = GetPopularGames(mockGameRepository);
  });

  tearDown(() {
    reset(mockGameRepository);
  });

  group('GetPopularGames', () {
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
        name: 'FIFA 23',
        slug: 'fifa-23',
        igdbId: 12346,
        coverUrl: 'https://example.com/cover2.jpg',
        summary: 'A football simulation game',
        firstReleaseDate: null,
        genres: ['Sports', 'Simulation'],
        platforms: ['PC', 'PlayStation', 'Xbox'],
        maxSpots: 2,
        isCached: false,
        cachedAt: null,
      ),
    ];

    test('should return games when repository succeeds', () async {
      // Arrange
      when(mockGameRepository.getPopularGames())
          .thenAnswer((_) async => mockGames);

      // Act
      final result = await usecase.call();

      // Assert
      expect(result, equals(mockGames));
      verify(mockGameRepository.getPopularGames()).called(1);
      verifyNoMoreInteractions(mockGameRepository);
    });

    test('should return empty list when no popular games available', () async {
      // Arrange
      when(mockGameRepository.getPopularGames()).thenAnswer((_) async => []);

      // Act
      final result = await usecase.call();

      // Assert
      expect(result, isEmpty);
      verify(mockGameRepository.getPopularGames()).called(1);
    });

    test('should propagate repository exceptions', () async {
      // Arrange
      final exception = Exception('Network error');
      when(mockGameRepository.getPopularGames()).thenThrow(exception);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(exception)),
      );
      verify(mockGameRepository.getPopularGames()).called(1);
    });

    test('should handle network timeout', () async {
      // Arrange
      final timeoutException = Exception('Timeout');
      when(mockGameRepository.getPopularGames()).thenThrow(timeoutException);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(timeoutException)),
      );
    });

    test('should handle rate limiting', () async {
      // Arrange
      final rateLimitException = Exception('Rate limit exceeded');
      when(mockGameRepository.getPopularGames()).thenThrow(rateLimitException);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(rateLimitException)),
      );
    });

    test('should handle asset loading failure', () async {
      // Arrange
      final assetException = Exception('Asset not found');
      when(mockGameRepository.getPopularGames()).thenThrow(assetException);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(assetException)),
      );
    });

    test('should handle invalid JSON in assets', () async {
      // Arrange
      final jsonException = Exception('Invalid JSON');
      when(mockGameRepository.getPopularGames()).thenThrow(jsonException);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(jsonException)),
      );
    });
  });
}
