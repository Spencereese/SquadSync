import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/data/datasources/game_local_datasource.dart';
import 'package:squad_sync/data/datasources/game_remote_datasource.dart';
import 'package:squad_sync/data/repositories/game_repository_impl.dart';
import 'package:squad_sync/domain/usecases/fetch_games.dart';
import 'package:squad_sync/domain/usecases/get_game_details.dart';
import 'package:squad_sync/domain/usecases/get_popular_games.dart';
import 'package:squad_sync/presentation/notifiers/game_notifier.dart';
import 'package:squad_sync/screens/add_game_screen.dart';

// Mock classes for integration test
class MockHttpClient extends Mock implements http.Client {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockSQLiteHelper extends Mock implements dynamic {
  Future<List<Map<String, dynamic>>> getCachedGames(String query) async => [];
  Future<void> insertGames(List<Map<String, dynamic>> games) async {}
}

class MockAssetBundle extends Mock implements AssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async => '[]';
}

void main() {
  late MockHttpClient mockHttpClient;
  late MockFirebaseFirestore mockFirestore;
  late MockSQLiteHelper mockSQLiteHelper;
  late MockAssetBundle mockAssetBundle;

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockFirestore = MockFirebaseFirestore();
    mockSQLiteHelper = MockSQLiteHelper();
    mockAssetBundle = MockAssetBundle();
  });

  final testGame = Game(
    igdbId: 12345,
    name: 'Call of Duty: Modern Warfare',
    slug: 'call-of-duty-modern-warfare',
    coverUrl: '//images.igdb.com/igdb/image/upload/t_cover_big/co1uqy.jpg',
    summary: 'A first-person shooter game',
    releaseDate: DateTime(2019, 10, 25),
    genres: ['Shooter', 'Action'],
    platforms: ['PC', 'PlayStation 4'],
  );

  group('Game Search Flow Integration Test', () {
    testWidgets('should complete full game search flow from UI to data layer',
        (WidgetTester tester) async {
      // Arrange - Mock IGDB API response
      final igdbResponse = [
        {
          'id': 12345,
          'name': 'Call of Duty: Modern Warfare',
          'slug': 'call-of-duty-modern-warfare',
          'cover': {
            'url': '//images.igdb.com/igdb/image/upload/t_cover_big/co1uqy.jpg'
          },
          'summary': 'A first-person shooter game',
          'first_release_date': 1571961600000,
          'genres': [
            {'name': 'Shooter'},
            {'name': 'Action'}
          ],
          'platforms': [
            {'name': 'PC'},
            {'name': 'PlayStation 4'}
          ],
        }
      ];

      // Mock HTTP client for IGDB API
      when(mockHttpClient.post(
        Uri.parse('https://api.igdb.com/v4/games'),
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(json.encode(igdbResponse), 200));

      // Mock Firestore collection and document
      final mockCollection = MockCollectionReference();
      final mockDoc = MockDocumentReference();
      when(mockFirestore.collection('games')).thenReturn(mockCollection);
      when(mockCollection.doc(any)).thenReturn(mockDoc);
      when(mockDoc.set(any)).thenAnswer((_) async {});

      // Mock SQLite for caching
      when(mockSQLiteHelper.getCachedGames(any)).thenAnswer((_) async => []);
      when(mockSQLiteHelper.insertGames(any)).thenAnswer((_) async {});

      // Create real implementations with mocks
      final remoteDataSource =
          GameRemoteDataSourceImpl(mockHttpClient, MockIgdbAuthService());
      final localDataSource =
          GameLocalDataSourceImpl(mockSQLiteHelper, mockAssetBundle);
      final repository =
          GameRepositoryImpl(localDataSource, remoteDataSource, mockFirestore);

      // Create use cases
      final searchGamesUseCase = SearchGamesUseCase(repository);
      final getGameDetailsUseCase = GetGameDetailsUseCase(repository);
      final loadPopularGamesUseCase = LoadPopularGamesUseCase(repository);

      // Create notifier
      final container = ProviderContainer(
        overrides: [
          searchGamesUseCaseProvider.overrideWithValue(searchGamesUseCase),
          getGameDetailsUseCaseProvider
              .overrideWithValue(getGameDetailsUseCase),
          loadPopularGamesUseCaseProvider
              .overrideWithValue(loadPopularGamesUseCase),
        ],
      );

      // Act - Build the widget with real providers
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AddGameScreen(),
          ),
        ),
      );

      // Wait for initial load
      await tester.pump();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Call of Duty');
      await tester.pump(const Duration(milliseconds: 500)); // Wait for debounce

      // Wait for search to complete
      await tester.pump();

      // Assert - Verify the game appears in the list
      expect(find.text('Call of Duty: Modern Warfare'), findsOneWidget);
      expect(find.text('Shooter • Action'), findsOneWidget);
      expect(find.text('PC • PlayStation 4'), findsOneWidget);

      // Verify HTTP call was made
      verify(mockHttpClient.post(
        Uri.parse('https://api.igdb.com/v4/games'),
        headers: anyNamed('headers'),
        body: contains('Call of Duty'),
      )).called(1);

      // Verify caching occurred
      verify(mockSQLiteHelper.insertGames(any)).called(1);

      // Verify Firestore sync
      verify(mockFirestore.collection('games')).called(1);
    });

    testWidgets('should handle API errors and fallback to offline games',
        (WidgetTester tester) async {
      // Arrange - Mock API failure
      when(mockHttpClient.post(
        Uri.parse('https://api.igdb.com/v4/games'),
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response('Server Error', 500));

      // Mock offline games from assets
      final offlineGamesJson = json.encode([
        {
          'igdbId': 67890,
          'name': 'Offline Game',
          'slug': 'offline-game',
          'coverUrl': 'https://example.com/offline.jpg',
          'summary': 'An offline game',
          'releaseDate': '2023-01-01T00:00:00.000Z',
          'genres': ['Adventure'],
          'platforms': ['PC'],
        }
      ]);
      when(mockAssetBundle.loadString('assets/popular_games.json'))
          .thenAnswer((_) async => offlineGamesJson);

      // Mock empty cache
      when(mockSQLiteHelper.getCachedGames(any)).thenAnswer((_) async => []);

      // Create implementations
      final remoteDataSource =
          GameRemoteDataSourceImpl(mockHttpClient, MockIgdbAuthService());
      final localDataSource =
          GameLocalDataSourceImpl(mockSQLiteHelper, mockAssetBundle);
      final repository =
          GameRepositoryImpl(localDataSource, remoteDataSource, mockFirestore);

      final searchGamesUseCase = SearchGamesUseCase(repository);
      final getGameDetailsUseCase = GetGameDetailsUseCase(repository);
      final loadPopularGamesUseCase = LoadPopularGamesUseCase(repository);

      final container = ProviderContainer(
        overrides: [
          searchGamesUseCaseProvider.overrideWithValue(searchGamesUseCase),
          getGameDetailsUseCaseProvider
              .overrideWithValue(getGameDetailsUseCase),
          loadPopularGamesUseCaseProvider
              .overrideWithValue(loadPopularGamesUseCase),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AddGameScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.enterText(find.byType(TextField), 'test query');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Assert - Should show offline games
      expect(find.text('Offline Game'), findsOneWidget);
      expect(find.text('Adventure'), findsOneWidget);
    });

    testWidgets('should handle cache hits and avoid API calls',
        (WidgetTester tester) async {
      // Arrange - Mock cached games
      final cachedGamesMap = [
        {
          'igdbId': 12345,
          'name': 'Cached Game',
          'slug': 'cached-game',
          'coverUrl': 'https://example.com/cached.jpg',
          'summary': 'A cached game',
          'releaseDate': '2023-01-01T00:00:00.000Z',
          'genres': 'Adventure',
          'platforms': 'PC',
        }
      ];
      when(mockSQLiteHelper.getCachedGames('cached'))
          .thenAnswer((_) async => cachedGamesMap);

      // Create implementations
      final remoteDataSource =
          GameRemoteDataSourceImpl(mockHttpClient, MockIgdbAuthService());
      final localDataSource =
          GameLocalDataSourceImpl(mockSQLiteHelper, mockAssetBundle);
      final repository =
          GameRepositoryImpl(localDataSource, remoteDataSource, mockFirestore);

      final searchGamesUseCase = SearchGamesUseCase(repository);
      final getGameDetailsUseCase = GetGameDetailsUseCase(repository);
      final loadPopularGamesUseCase = LoadPopularGamesUseCase(repository);

      final container = ProviderContainer(
        overrides: [
          searchGamesUseCaseProvider.overrideWithValue(searchGamesUseCase),
          getGameDetailsUseCaseProvider
              .overrideWithValue(getGameDetailsUseCase),
          loadPopularGamesUseCaseProvider
              .overrideWithValue(loadPopularGamesUseCase),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AddGameScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.enterText(find.byType(TextField), 'cached');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Assert - Should show cached game without API call
      expect(find.text('Cached Game'), findsOneWidget);
      verifyNever(mockHttpClient.post(any,
          headers: anyNamed('headers'), body: anyNamed('body')));
    });

    testWidgets('should handle rate limiting with retry delays',
        (WidgetTester tester) async {
      // Arrange - Mock rate limit then success
      final igdbResponse = [
        {'id': 12345, 'name': 'Rate Limited Game'}
      ];

      when(mockHttpClient.post(
        Uri.parse('https://api.igdb.com/v4/games'),
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      ))
          .thenAnswer((_) async => http.Response('Rate limit exceeded', 429))
          .thenAnswer(
              (_) async => http.Response(json.encode(igdbResponse), 200));

      when(mockSQLiteHelper.getCachedGames(any)).thenAnswer((_) async => []);
      when(mockSQLiteHelper.insertGames(any)).thenAnswer((_) async {});

      // Create implementations
      final remoteDataSource =
          GameRemoteDataSourceImpl(mockHttpClient, MockIgdbAuthService());
      final localDataSource =
          GameLocalDataSourceImpl(mockSQLiteHelper, mockAssetBundle);
      final repository =
          GameRepositoryImpl(localDataSource, remoteDataSource, mockFirestore);

      final searchGamesUseCase = SearchGamesUseCase(repository);
      final container = ProviderContainer(
        overrides: [
          searchGamesUseCaseProvider.overrideWithValue(searchGamesUseCase),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AddGameScreen(),
          ),
        ),
      );

      await tester.pump();
      final startTime = DateTime.now();
      await tester.enterText(find.byType(TextField), 'rate limited');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 2)); // Wait for retry
      final endTime = DateTime.now();

      // Assert - Should eventually succeed after retry delay
      expect(find.text('Rate Limited Game'), findsOneWidget);
      expect(endTime.difference(startTime).inMilliseconds,
          greaterThanOrEqualTo(1000));
    });
  });
}

// Additional mock classes
class MockIgdbAuthService extends Mock implements dynamic {
  Future<String> getAccessToken() async => 'mock_token';
  Future<String?> getClientId() async => 'mock_client_id';
  Future<void> refreshAccessToken() async {}
}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      MockDocumentReference();
}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {}
}
