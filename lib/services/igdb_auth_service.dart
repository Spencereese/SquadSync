import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// IGDB (Internet Game Database) authentication and search service
/// Uses Twitch OAuth2 for authentication and Apicalypse query language
class IgdbAuthService {
  static const String _clientIdKey = 'igdb_client_id';
  static const String _clientSecretKey = 'igdb_client_secret';
  static const String _tokenKey = 'igdb_access_token';
  static const String _tokenExpiryKey = 'igdb_token_expiry';

  final SharedPreferences _storage;
  String? _accessToken;
  DateTime? _tokenExpiry;

  IgdbAuthService(this._storage);

  /// Store IGDB credentials securely (call once during dev setup)
  Future<void> storeCredentials() async {
    const clientId = 'yq7hidzec8wv7khe9niom9m6znzrxf';
    const clientSecret = '4ycghqkzf2ylgxbilypdxu4ga937u5';

    await _storage.setString(_clientIdKey, clientId);
    await _storage.setString(_clientSecretKey, clientSecret);
    print('IGDB credentials stored securely');
  }

  /// Get stored client ID
  Future<String?> getClientId() async {
    return _storage.getString(_clientIdKey);
  }

  /// Get stored client secret
  Future<String?> getClientSecret() async {
    return _storage.getString(_clientSecretKey);
  }

  /// Get valid access token, refreshing if necessary
  Future<String?> getAccessToken() async {
    // Check if we have a cached token that's still valid
    if (_accessToken != null &&
        _tokenExpiry != null &&
        _tokenExpiry!.isAfter(DateTime.now())) {
      return _accessToken;
    }

    // Try to load from storage
    final storedToken = _storage.getString(_tokenKey);
    final storedExpiry = _storage.getString(_tokenExpiryKey);

    if (storedToken != null && storedExpiry != null) {
      final expiry = DateTime.parse(storedExpiry);
      if (expiry.isAfter(DateTime.now())) {
        _accessToken = storedToken;
        _tokenExpiry = expiry;
        return _accessToken;
      }
    }

    // Need to refresh token
    return await _refreshAccessToken();
  }

  /// Refresh access token using stored credentials
  Future<String?> _refreshAccessToken() async {
    final clientId = await getClientId();
    final clientSecret = await getClientSecret();

    if (clientId == null || clientSecret == null) {
      throw Exception(
          'IGDB credentials not found. Call storeCredentials() first.');
    }

    final response = await http.post(
      Uri.parse('https://id.twitch.tv/oauth2/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'grant_type': 'client_credentials',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _accessToken = data['access_token'];
      final expiresIn = data['expires_in'] as int;
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

      // Store in preferences
      await _storage.setString(_tokenKey, _accessToken!);
      await _storage.setString(
          _tokenExpiryKey, _tokenExpiry!.toIso8601String());

      return _accessToken;
    } else {
      throw Exception(
          'Failed to refresh IGDB access token: ${response.statusCode}');
    }
  }

  /// Search for games using IGDB API
  Future<List<Map<String, dynamic>>> searchGames(String query,
      {int limit = 10}) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('Failed to get access token');

    final clientId = await getClientId();
    if (clientId == null) throw Exception('Client ID not found');

    // IGDB Apicalypse query
    final body = '''
      search "$query";
      fields name, cover.url, genres.name, first_release_date, summary;
      where version_parent = null;
      limit $limit;
    ''';

    final response = await http.post(
      Uri.parse('https://api.igdb.com/v4/games'),
      headers: {
        'Client-ID': clientId,
        'Authorization': 'Bearer $token',
        'Content-Type': 'text/plain',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      return data.map((game) => game as Map<String, dynamic>).toList();
    } else {
      throw Exception(
          'IGDB API error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Clear stored credentials and tokens
  Future<void> clearCredentials() async {
    await _storage.remove(_clientIdKey);
    await _storage.remove(_clientSecretKey);
    await _storage.remove(_tokenKey);
    await _storage.remove(_tokenExpiryKey);
    _accessToken = null;
    _tokenExpiry = null;
  }
}
