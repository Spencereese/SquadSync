import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/data/repositories/game_repository_impl.dart';

// Mock classes
class MockGameLocalDataSource extends Mock implements dynamic {
  Future<List<Game>> getCachedGames(String query) async => [];
  Future<void> cacheGames(List<Game> games) async {}
  Future<List<Game>> getOfflineGames({String? query, int? limit}) async => [];
}

class MockGameRemoteDataSource extends Mock implements dynamic {
  Future<List<Game>> fetchGamesFromIgdb(String query, {int limit = 10}) async => [];
  Future<Game?> getGameDetails(int igdbId) async => null;
  Future<String> getAccessToken() async => 'mock_token';
  Future<void> refreshToken() async {}
}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {
  @override
  WriteBatch batch() => MockWriteBatch();
}

class MockWriteBatch extends Mock implements WriteBatch {
  @override
  Future<void> commit() async {}
}

void main() {
  late GameRepositoryImpl repository;
  late MockGameLocalDataSource mockLocalDataSource;
  late MockGameRemoteDataSource mockRemoteDataSource;
  late MockFirebaseFirestore mockFirestore;

  setUp(() {
    mockLocalDataSource = MockGameLocalDataSource();
    mockRemoteDataSource = MockGameRemoteDataSource();
    mockFirestore = MockFirebaseFirestore();
    repository = GameRepositoryImpl(
      mockLocalDataSource,
      mockRemoteDataSource,
      mockFirestore,
    );
  });

  group('GameRepositoryImpl', () {
    final testGame = Game(
      igdbId: 12345,
      name: 'Test Game',
      slug: 'test-game',
      coverUrl: 'https://example.com/cover.jpg',
      summary: 'A test game',
      releaseDate: DateTime(2023, 1, 1),
      genres: ['Action', 'Adventure'],
      platforms: ['PC', 'PlayStation'],
    );

    group('fetchGames', () {
      test('should return cached games when available', () async {
        // Arrange
        final cachedGames = [testGame];
        when(mockLocalDataSource.getCachedGames('test')).thenAnswer((_) async => cachedGames);

        // Act
        final result = await repository.fetchGames('test', limit: 10);

        // Assert
        expect(result, cachedGames);
        verify(mockLocalDataSource.getCachedGames('test')).called(1);
        verifyNever(mockRemoteDataSource.fetchGamesFromIgdb(any, limit: anyNamed('limit')));
        verifyNever(mockLocalDataSource.cacheGames(any));
      });

      test('should fetch from remote when cache is empty and cache results', () async {
        // Arrange
        final remoteGames = [testGame];
        when(mockLocalDataSource.getCachedGames('test')).thenAnswer((_) async => []);
        when(mockRemoteDataSource.fetchGamesFromIgdb('test', limit: 10)).thenAnswer((_) async => remoteGames);
        when(mockLocalDataSource.cacheGames(remoteGames)).thenAnswer((_) async {});

        // Act
        final result = await repository.fetchGames('test', limit: 10);

        // Assert
        expect(result, remoteGames);
        verify(mockLocalDataSource.getCachedGames('test')).called(1);
        verify(mockRemoteDataSource.fetchGamesFromIgdb('test', limit: 10)).called(1);
        verify(mockLocalDataSource.cacheGames(remoteGames)).called(1);
      });

      test('should sync games to Firestore after caching', () async {
        // Arrange
        final remoteGames = [testGame];
        when(mockLocalDataSource.getCachedGames('test')).thenAnswer((_) async => []);
        when(mockRemoteDataSource.fetchGamesFromIgdb('test', limit: 10)).thenAnswer((_) async => remoteGames);
        when(mockLocalDataSource.cacheGames(remoteGames)).thenAnswer((_) async {});

        // Act
        await repository.fetchGames('test', limit: 10);

        // Assert
        verify(mockFirestore.collection('games')).called(1);
        // Note: Full Firestore batch verification would require more complex mocking
      });

      test('should fallback to offline games when remote fails', () async {
        // Arrange
        final offlineGames = [testGame];
        when(mockLocalDataSource.getCachedGames('test')).thenAnswer((_) async => []);
        when(mockRemoteDataSource.fetchGamesFromIgdb('test', limit: 10)).thenThrow(Exception('Network error'));
        when(mockLocalDataSource.getOfflineGames(query: 'test', limit: 10)).thenAnswer((_) async => offlineGames);

        // Act
        final result = await repository.fetchGames('test', limit: 10);

        // Assert
        expect(result, offlineGames);
        verify(mockLocalDataSource.getOfflineGames(query: 'test', limit: 10)).called(1);
      });

      test('should return empty list when both remote and offline fail', () async {
        // Arrange
        when(mockLocalDataSource.getCachedGames('test')).thenAnswer((_) async => []);
        when(mockRemoteDataSource.fetchGamesFromIgdb('test', limit: 10)).thenThrow(Exception('Network error'));
        when(mockLocalDataSource.getOfflineGames(query: 'test', limit: 10)).thenThrow(Exception('Asset error'));

        // Act
        final result = await repository.fetchGames('test', limit: 10);

        // Assert
        expect(result, isEmpty);
      });

      test('should handle empty query for popular games', () async {
        // Arrange
        final remoteGames = [testGame];
        when(mockLocalDataSource.getCachedGames('')).thenAnswer((_) async => []);
        when(mockRemoteDataSource.fetchGamesFromIgdb('', limit: 10)).thenAnswer((_) async => remoteGames);
        when(mockLocalDataSource.cacheGames(remoteGames)).thenAnswer((_) async {});

        // Act
        final result = await repository.fetchGames('', limit: 10);

        // Assert
        expect(result, remoteGames);
        verify(mockRemoteDataSource.fetchGamesFromIgdb('', limit: 10)).called(1);
      });
    });

    group('getGameDetails', () {
      test('should return game details from remote datasource', () async {
        // Arrange
        when(mockRemoteDataSource.getGameDetails(12345)).thenAnswer((_) async => testGame);

        // Act
        final result = await repository.getGameDetails(12345);

        // Assert
        expect(result, testGame);
        verify(mockRemoteDataSource.getGameDetails(12345)).called(1);
      });

      test('should return null when game not found', () async {
        // Arrange
        when(mockRemoteDataSource.getGameDetails(99999)).thenAnswer((_) async => null);

        // Act
        final result = await repository.getGameDetails(99999);

        // Assert
        expect(result, isNull);
      });

      test('should handle remote datasource errors', () async {
        // Arrange
        when(mockRemoteDataSource.getGameDetails(12345)).thenThrow(Exception('Network error'));

        // Act & Assert
        expect(
          () => repository.getGameDetails(12345),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('syncGamesToFirestore', () {
      test('should sync games to Firestore collection', () async {
        // Arrange
        final games = [testGame];
        final mockCollection = MockCollectionReference();
        final mockDoc = MockDocumentReference();

        when(mockFirestore.collection('games')).thenReturn(mockCollection);
        when(mockCollection.doc(testGame.slug)).thenReturn(mockDoc);
        when(mockDoc.set(any)).thenAnswer((_) async {});

        // Act
        await repository.syncGamesToFirestore(games);

        // Assert
        verify(mockFirestore.collection('games')).called(1);
        verify(mockCollection.doc(testGame.slug)).called(1);
        verify(mockDoc.set(any)).called(1);
      });

      test('should handle Firestore errors gracefully', () async {
        // Arrange
        final games = [testGame];
        when(mockFirestore.collection('games')).thenThrow(Exception('Firestore error'));

        // Act & Assert
        expect(
          () => repository.syncGamesToFirestore(games),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('clearCache', () {
      test('should delegate to local datasource', () async {
        // Arrange
        when(mockLocalDataSource.cacheGames([])).thenAnswer((_) async {});

        // Act
        await repository.clearCache();

        // Assert
        verify(mockLocalDataSource.cacheGames([])).called(1);
      });
    });
  });
}

// Additional mock classes for Firestore
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) => MockDocumentReference();
}

class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {}
}