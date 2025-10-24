import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import '../lib/services/igdb_auth_service.dart';

// Create a mock for HTTP client
class MockClient extends Mock implements http.Client {}

void main() {
  group('IgdbAuthService', () {
    late IgdbAuthService igdbService;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      igdbService = IgdbAuthService();
    });

    tearDown(() async {
      // Clear stored data after each test
      await igdbService.clearStoredData();
    });

    test('storeCredentials stores client ID and secret', () async {
      await igdbService.storeCredentials();

      final clientId = await igdbService.getClientId();
      final clientSecret = await igdbService.getClientSecret();

      expect(clientId, isNotNull);
      expect(clientSecret, isNotNull);
      expect(clientId, equals('yq7hidzec8wv7khe9niom9m6znzrxf'));
      expect(clientSecret, equals('4ycghqkzf2ylgxbilypdxu4ga937u5'));
    });

    test('getAccessToken returns null when credentials not stored', () async {
      final token = await igdbService.getAccessToken();
      expect(token, isNull);
    });

    test('searchGames returns empty list for empty query', () async {
      final results = await igdbService.searchGames('');
      expect(results, isEmpty);
    });

    test('clearStoredData removes all stored data', () async {
      await igdbService.storeCredentials();

      // Verify data is stored
      var clientId = await igdbService.getClientId();
      expect(clientId, isNotNull);

      // Clear data
      await igdbService.clearStoredData();

      // Verify data is cleared
      clientId = await igdbService.getClientId();
      expect(clientId, isNull);
    });

    // Note: Integration tests with real API would require network mocking
    // For now, we test the structure and error handling
  });
}
