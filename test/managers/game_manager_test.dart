import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'dart:convert';
import 'package:squad_sync/managers/game_manager.dart';
import 'game_manager_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameManager gameManager;
  late MockClient mockHttpClient;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() async {
    mockHttpClient = MockClient();
    fakeFirestore = FakeFirebaseFirestore();

    // Create GameManager with fake firestore and mock http client for testing
    gameManager = GameManager(
        firestore: fakeFirestore,
        httpClient: mockHttpClient,
        skipInitialization: true);
  });

  tearDown(() {
    gameManager.dispose();
  });

  group('GameManager - fetchGames', () {
    test('should fetch games successfully from IGDB API', () async {
      // Arrange
      final mockResponse = {
        'games': [
          {
            'id': 1,
            'name': 'Test Game',
            'slug': 'test-game',
            'coverUrl': 'https://example.com/cover.jpg',
            'summary': 'A test game'
          }
        ]
      };

      when(mockHttpClient.get(any)).thenAnswer(
          (_) async => http.Response(jsonEncode(mockResponse), 200));

      // Act
      await gameManager.fetchGames(pageSize: 1);

      // Assert
      verify(mockHttpClient.get(any)).called(1);

      // Check that game was added to fake firestore
      final gamesCollection = fakeFirestore.collection('games');
      final doc = await gamesCollection.doc('test-game').get();
      expect(doc.exists, true);
      expect(doc.data()!['name'], 'Test Game');
    });

    test('should handle IGDB API failure and continue', () async {
      // Arrange
      when(mockHttpClient.get(any))
          .thenAnswer((_) async => http.Response('Server Error', 500));

      // Act & Assert - should not throw
      await expectLater(gameManager.fetchGames(pageSize: 1), completes);
    });

    test('should handle network errors gracefully', () async {
      // Arrange
      when(mockHttpClient.get(any)).thenThrow(Exception('Network error'));

      // Act & Assert - should not throw
      await expectLater(gameManager.fetchGames(pageSize: 1), completes);
    });
  });

  group('GameManager - searchGames', () {
    test('should return IGDB results when API succeeds', () async {
      // Arrange
      final mockResponse = {
        'games': [
          {
            'id': 1,
            'name': 'Call of Duty',
            'slug': 'call-of-duty',
            'coverUrl': 'https://example.com/cover.jpg'
          }
        ]
      };

      when(mockHttpClient.get(any)).thenAnswer(
          (_) async => http.Response(jsonEncode(mockResponse), 200));

      // Act
      final results = await gameManager.searchGames('call of duty');

      // Assert
      expect(results.length, 1);
      expect(results[0]['name'], 'Call of Duty');
      verify(mockHttpClient.get(any)).called(1);

      // Check that game was cached in fake firestore
      final gamesCollection = fakeFirestore.collection('games');
      final doc = await gamesCollection.doc('call-of-duty').get();
      expect(doc.exists, true);
      expect(doc.data()!['name'], 'Call of Duty');
    });

    test('should fallback to Firestore when IGDB API fails', () async {
      // Arrange
      when(mockHttpClient.get(any))
          .thenAnswer((_) async => http.Response('Server Error', 500));

      // Add test data to fake firestore
      await fakeFirestore.collection('games').doc('call-of-duty').set({
        'id': 1,
        'name': 'call of duty', // Use lowercase to match query
        'slug': 'call-of-duty'
      });

      // Act
      final results = await gameManager.searchGames('call of duty');

      // Assert
      expect(results.length, 1);
      expect(results[0]['name'], 'call of duty');
    });

    test('should fallback to local games when both API and Firestore fail',
        () async {
      // Arrange
      when(mockHttpClient.get(any))
          .thenAnswer((_) async => http.Response('Server Error', 500));

      // Act
      final results = await gameManager.searchGames('Call of Duty');

      // Assert
      expect(results.length, greaterThan(0));
      expect(
          results.any((game) =>
              game['name'].toString().toLowerCase().contains('call of duty')),
          true);
    });

    test('should return empty list for empty query', () async {
      // Act
      final results = await gameManager.searchGames('');

      // Assert
      expect(results, isEmpty);
    });

    test('should handle network errors in IGDB search', () async {
      // Arrange
      when(mockHttpClient.get(any)).thenThrow(Exception('Network error'));

      // Add test data to fake firestore
      await fakeFirestore.collection('games').doc('call-of-duty').set({
        'id': 1,
        'name': 'call of duty', // Use lowercase to match query
        'slug': 'call-of-duty'
      });

      // Act
      final results = await gameManager.searchGames('call of duty');

      // Assert
      expect(results.length, 1);
      expect(results[0]['name'], 'call of duty');
    });
  });

  group('GameManager - selectGame', () {
    test('should update current game and notify listeners', () {
      // Arrange
      final game = {'id': 1, 'name': 'Test Game'};

      // Act
      gameManager.selectGame(game);

      // Assert
      expect(gameManager.currentGame, game);
    });
  });

  group('GameManager - togglePreferredPeacockGame', () {
    test('should add game to preferred when not present', () {
      // Arrange
      const gameName = 'Test Game';

      // Act
      gameManager.togglePreferredPeacockGame(gameName);

      // Assert
      expect(gameManager.preferredPeacockGames.contains(gameName), true);
    });

    test('should remove game from preferred when already present', () {
      // Arrange
      const gameName = 'Test Game';
      gameManager.togglePreferredPeacockGame(gameName);

      // Act
      gameManager.togglePreferredPeacockGame(gameName);

      // Assert
      expect(gameManager.preferredPeacockGames.contains(gameName), false);
    });
  });

  group('GameManager - toggleMutedGame', () {
    test('should add game to muted when not present', () {
      // Arrange
      const gameName = 'Test Game';

      // Act
      gameManager.toggleMutedGame(gameName);

      // Assert
      expect(gameManager.mutedGames.contains(gameName), true);
    });

    test('should remove game from muted when already present', () {
      // Arrange
      const gameName = 'Test Game';
      gameManager.toggleMutedGame(gameName);

      // Act
      gameManager.toggleMutedGame(gameName);

      // Assert
      expect(gameManager.mutedGames.contains(gameName), false);
    });
  });

  group('GameManager - toggleHiddenGame', () {
    test('should add game to hidden and muted when not present', () {
      // Arrange
      const gameName = 'Test Game';

      // Act
      gameManager.toggleHiddenGame(gameName);

      // Assert
      expect(gameManager.hiddenGames.contains(gameName), true);
      expect(gameManager.mutedGames.contains(gameName), true);
    });

    test('should remove game from hidden and muted when already present', () {
      // Arrange
      const gameName = 'Test Game';
      gameManager.toggleHiddenGame(gameName);

      // Act
      gameManager.toggleHiddenGame(gameName);

      // Assert
      expect(gameManager.hiddenGames.contains(gameName), false);
      expect(gameManager.mutedGames.contains(gameName), false);
    });
  });
}
