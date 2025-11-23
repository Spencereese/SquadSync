import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/data/datasources/game_remote_datasource.dart';

// Mock classes
class MockHttpClient extends Mock implements http.Client {
  @override
  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    return super.noSuchMethod(
      Invocation.method(#post, [url], {#headers: headers, #body: body, #encoding: encoding}),
      returnValue: Future.value(http.Response('', 200)),
    ) as Future<http.Response>;
  }
}

class MockIgdbAuthService extends Mock implements dynamic {
  Future<String> getAccessToken() async => 'mock_token';
  Future<String?> getClientId() async => 'mock_client_id';
  Future<void> refreshAccessToken() async {}
}

void main() {
  late GameRemoteDataSourceImpl dataSource;
  late MockHttpClient mockHttpClient;
  late MockIgdbAuthService mockAuthService;

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockAuthService = MockIgdbAuthService();
    dataSource = GameRemoteDataSourceImpl(mockHttpClient, mockAuthService);
  });

  group('GameRemoteDataSourceImpl', () {
    const clientId = 'mock_client_id';
    const token = 'mock_token';

    group('fetchGamesFromIgdb', () {
      test('should return games on successful API response', () async {
        // Arrange
        final mockResponse = [
          {
            'id': 12345,
            'name': 'Call of Duty: Modern Warfare',
            'slug': 'call-of-duty-modern-warfare',
            'cover': {'url': '//images.igdb.com/igdb/image/upload/t_cover_big/co1uqy.jpg'},
            'summary': 'A first-person shooter game',
            'first_release_date': 1577836800000,
            'genres': [{'name': 'Shooter'}, {'name': 'Action'}],
            'platforms': [{'name': 'PC'}, {'name': 'PlayStation 4'}],
          }
        ];

        when(mockHttpClient.post(
          Uri.parse('https://api.igdb.com/v4/games'),
          headers: {
            'Client-ID': clientId,
            'Authorization': 'Bearer $token',
            'Content-Type': 'text/plain',
          },
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

        when(mockAuthService.getAccessToken()).thenAnswer((_) async => token);
        when(mockAuthService.getClientId()).thenAnswer((_) async => clientId);

        // Act
        final result = await dataSource.fetchGamesFromIgdb('Call of Duty', limit: 10);

        // Assert
        expect(result, hasLength(1));
        expect(result.first.name, 'Call of Duty: Modern Warfare');
        expect(result.first.igdbId, 12345);
        expect(result.first.genres, ['Shooter', 'Action']);
        expect(result.first.platforms, ['PC', 'PlayStation 4']);
        verify(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body'))).called(1);
      });

      test('should handle 401 error with token refresh and retry', () async {
        // Arrange
        final mockResponse = [
          {
            'id': 12345,
            'name': 'Call of Duty: Modern Warfare',
            'slug': 'call-of-duty-modern-warfare',
          }
        ];

        // First call returns 401, second call succeeds
        when(mockHttpClient.post(
          Uri.parse('https://api.igdb.com/v4/games'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('Unauthorized', 401))
          .thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

        when(mockAuthService.getAccessToken()).thenAnswer((_) async => token);
        when(mockAuthService.getClientId()).thenAnswer((_) async => clientId);
        when(mockAuthService.refreshAccessToken()).thenAnswer((_) async {});

        // Act
        final result = await dataSource.fetchGamesFromIgdb('test', limit: 10);

        // Assert
        expect(result, hasLength(1));
        verify(mockAuthService.refreshAccessToken()).called(1);
        verify(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body'))).called(2);
      });

      test('should handle 429 rate limit with retry delays', () async {
        // Arrange
        final mockResponse = [{'id': 12345, 'name': 'Test Game'}];

        when(mockHttpClient.post(
          Uri.parse('https://api.igdb.com/v4/games'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('Rate limit exceeded', 429))
          .thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

        when(mockAuthService.getAccessToken()).thenAnswer((_) async => token);
        when(mockAuthService.getClientId()).thenAnswer((_) async => clientId);

        // Act
        final startTime = DateTime.now();
        final result = await dataSource.fetchGamesFromIgdb('test', limit: 10);
        final endTime = DateTime.now();

        // Assert
        expect(result, hasLength(1));
        // Should have waited at least 1 second for retry
        expect(endTime.difference(startTime).inMilliseconds, greaterThanOrEqualTo(1000));
        verify(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body'))).called(2);
      });

      test('should handle 500 server error and retry with exponential backoff', () async {
        // Arrange
        final mockResponse = [{'id': 12345, 'name': 'Test Game'}];

        when(mockHttpClient.post(
          Uri.parse('https://api.igdb.com/v4/games'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('Internal Server Error', 500))
          .thenAnswer((_) async => http.Response('Internal Server Error', 500))
          .thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

        when(mockAuthService.getAccessToken()).thenAnswer((_) async => token);
        when(mockAuthService.getClientId()).thenAnswer((_) async => clientId);

        // Act
        final startTime = DateTime.now();
        final result = await dataSource.fetchGamesFromIgdb('test', limit: 10);
        final endTime = DateTime.now();

        // Assert
        expect(result, hasLength(1));
        // Should have waited 1s + 2s = 3s minimum
        expect(endTime.difference(startTime).inMilliseconds, greaterThanOrEqualTo(3000));
        verify(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body'))).called(3);
      });

      test('should throw exception after max retries', () async {
        // Arrange
        when(mockHttpClient.post(
          Uri.parse('https://api.igdb.com/v4/games'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('Server Error', 500));

        when(mockAuthService.getAccessToken()).thenAnswer((_) async => token);
        when(mockAuthService.getClientId()).thenAnswer((_) async => clientId);

        // Act & Assert
        expect(
          () => dataSource.fetchGamesFromIgdb('test', limit: 10),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to fetch games after 3 attempts'),
          )),
        );
        verify(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body'))).called(3);
      });

      test('should handle empty query with popular games query', () async {
        // Arrange
        final mockResponse = [{'id': 12345, 'name': 'Popular Game'}];

        when(mockHttpClient.post(
          Uri.parse('https://api.igdb.com/v4/games'),
          headers: anyNamed('headers'),
          body: contains('rating > 70'),
        )).thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

        when(mockAuthService.getAccessToken()).thenAnswer((_) async => token);
        when(mockAuthService.getClientId()).thenAnswer((_) async => clientId);

        // Act
        final result = await dataSource.fetchGamesFromIgdb('', limit: 10);

        // Assert
        expect(result, hasLength(1));
        verify(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: argThat(contains('rating > 70')),
        )).called(1);
      });

      test('should handle invalid JSON response', () async {
        // Arrange
        when(mockHttpClient.post(
          Uri.parse('https://api.igdb.com/v4/games'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('Invalid JSON', 200));

        when(mockAuthService.getAccessToken()).thenAnswer((_) async => token);
        when(mockAuthService.getClientId()).thenAnswer((_) async => clientId);

        // Act & Assert
        expect(
          () => dataSource.fetchGamesFromIgdb('test', limit: 10),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getGameDetails', () {
      test('should return game on successful response', () async {
        // Arrange
        final mockResponse = [
          {
            'id': 12345,
            'name': 'Call of Duty: Modern Warfare',
            'slug': 'call-of-duty-modern-warfare',
            'genres': [{'name': 'Shooter'}],
            'platforms': [{'name': 'PC'}],
          }
        ];

        when(mockHttpClient.post(
          Uri.parse('https://api.igdb.com/v4/games'),
          headers: anyNamed('headers'),
          body: contains('where id = 12345'),
        )).thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

        when(mockAuthService.getAccessToken()).thenAnswer((_) async => token);
        when(mockAuthService.getClientId()).thenAnswer((_) async => clientId);

        // Act
        final result = await dataSource.getGameDetails(12345);

        // Assert
        expect(result, isNotNull);
        expect(result!.name, 'Call of Duty: Modern Warfare');
        expect(result.igdbId, 12345);
      });

      test('should return null when game not found', () async {
        // Arrange
        when(mockHttpClient.post(
          Uri.parse('https://api.igdb.com/v4/games'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('[]', 200));

        when(mockAuthService.getAccessToken()).thenAnswer((_) async => token);
        when(mockAuthService.getClientId()).thenAnswer((_) async => clientId);

        // Act
        final result = await dataSource.getGameDetails(99999);

        // Assert
        expect(result, isNull);
      });
    });

    group('getAccessToken', () {
      test('should delegate to auth service', () async {
        // Arrange
        when(mockAuthService.getAccessToken()).thenAnswer((_) async => 'test_token');

        // Act
        final result = await dataSource.getAccessToken();

        // Assert
        expect(result, 'test_token');
        verify(mockAuthService.getAccessToken()).called(1);
      });
    });

    group('refreshToken', () {
      test('should delegate to auth service', () async {
        // Arrange
        when(mockAuthService.refreshAccessToken()).thenAnswer((_) async {});

        // Act
        await dataSource.refreshToken();

        // Assert
        verify(mockAuthService.refreshAccessToken()).called(1);
      });
    });
  });
}