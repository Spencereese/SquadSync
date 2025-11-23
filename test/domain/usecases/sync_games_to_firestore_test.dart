import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/domain/usecases/sync_games_to_firestore.dart';

import '../../helpers/mocks.mocks.dart';

void main() {
  late MockGameRepository mockGameRepository;
  late SyncGamesToFirestore usecase;

  setUp(() {
    mockGameRepository = MockGameRepository();
    usecase = SyncGamesToFirestore(mockGameRepository);
  });

  tearDown(() {
    reset(mockGameRepository);
  });

  group('SyncGamesToFirestore', () {
    const query = 'Call of Duty';

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

    test('should complete successfully when repository succeeds', () async {
      // Arrange
      when(mockGameRepository.syncGamesToFirestore(query, mockGames))
          .thenAnswer((_) async => Future.value());

      // Act
      await expectLater(
        usecase.call(query, mockGames),
        completes,
      );

      // Assert
      verify(mockGameRepository.syncGamesToFirestore(query, mockGames))
          .called(1);
      verifyNoMoreInteractions(mockGameRepository);
    });

    test('should handle empty games list', () async {
      // Arrange
      when(mockGameRepository.syncGamesToFirestore(query, []))
          .thenAnswer((_) async => Future.value());

      // Act
      await expectLater(
        usecase.call(query, []),
        completes,
      );

      // Assert
      verify(mockGameRepository.syncGamesToFirestore(query, [])).called(1);
    });

    test('should handle empty query', () async {
      // Arrange
      const emptyQuery = '';
      when(mockGameRepository.syncGamesToFirestore(emptyQuery, mockGames))
          .thenAnswer((_) async => Future.value());

      // Act
      await expectLater(
        usecase.call(emptyQuery, mockGames),
        completes,
      );

      // Assert
      verify(mockGameRepository.syncGamesToFirestore(emptyQuery, mockGames))
          .called(1);
    });

    test('should propagate repository exceptions', () async {
      // Arrange
      final exception = Exception('Firestore error');
      when(mockGameRepository.syncGamesToFirestore(query, mockGames))
          .thenThrow(exception);

      // Act & Assert
      expect(
        () => usecase.call(query, mockGames),
        throwsA(equals(exception)),
      );
      verify(mockGameRepository.syncGamesToFirestore(query, mockGames))
          .called(1);
    });

    test('should handle network timeout', () async {
      // Arrange
      final timeoutException = Exception('Timeout');
      when(mockGameRepository.syncGamesToFirestore(query, mockGames))
          .thenThrow(timeoutException);

      // Act & Assert
      expect(
        () => usecase.call(query, mockGames),
        throwsA(equals(timeoutException)),
      );
    });

    test('should handle Firestore permission denied', () async {
      // Arrange
      final permissionException = Exception('Permission denied');
      when(mockGameRepository.syncGamesToFirestore(query, mockGames))
          .thenThrow(permissionException);

      // Act & Assert
      expect(
        () => usecase.call(query, mockGames),
        throwsA(equals(permissionException)),
      );
    });

    test('should handle Firestore quota exceeded', () async {
      // Arrange
      final quotaException = Exception('Quota exceeded');
      when(mockGameRepository.syncGamesToFirestore(query, mockGames))
          .thenThrow(quotaException);

      // Act & Assert
      expect(
        () => usecase.call(query, mockGames),
        throwsA(equals(quotaException)),
      );
    });
  });
}
