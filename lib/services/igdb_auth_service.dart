import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

/// IGDB (Internet Game Database) authentication and search service
/// Uses Twitch OAuth2 for authentication and Apicalypse query language
class IgdbAuthService {
  static final Logger _logger = Logger();
  static const String _clientIdKey = 'igdb_client_id';
  static const String _clientSecretKey = 'igdb_client_secret';
  static const String _tokenKey = 'igdb_access_token';
  static const String _tokenExpiryKey = 'igdb_token_expiry';

  SharedPreferences? _storage;
  String? _accessToken;
  DateTime? _tokenExpiry;

  /// Initialize the service with SharedPreferences
  Future<void> _ensureStorage() async {
    _storage ??= await SharedPreferences.getInstance();
  }

  /// Get stored client ID
  Future<String?> getClientId() async {
    await _ensureStorage();
    // First try SharedPreferences
    final storedId = _storage!.getString(_clientIdKey);
    if (storedId != null) return storedId;
    // Fall back to environment variables
    return dotenv.env['IGDB_CLIENT_ID'];
  }

  /// Get stored client secret
  Future<String?> getClientSecret() async {
    await _ensureStorage();
    // First try SharedPreferences
    final storedSecret = _storage!.getString(_clientSecretKey);
    if (storedSecret != null) return storedSecret;
    // Fall back to environment variables
    return dotenv.env['IGDB_CLIENT_SECRET'];
  }

  /// Fetch or retrieve access token
  Future<String> getAccessToken() async {
    await _ensureStorage();
    // Check if we have a valid cached token
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now()
            .isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
      return _accessToken!;
    }

    // Try to load from storage
    final storedToken = _storage!.getString(_tokenKey);
    final storedExpiry = _storage!.getString(_tokenExpiryKey);

    if (storedToken != null && storedExpiry != null) {
      final expiry = DateTime.parse(storedExpiry);
      if (DateTime.now()
          .isBefore(expiry.subtract(const Duration(minutes: 5)))) {
        _accessToken = storedToken;
        _tokenExpiry = expiry;
        return _accessToken!;
      }
    }

    // Fetch new token
    return await _fetchNewToken();
  }

  /// Fetch new access token from Twitch OAuth2
  Future<String> _fetchNewToken() async {
    final clientId = await getClientId();
    final clientSecret = await getClientSecret();

    if (clientId == null || clientSecret == null) {
      _logger.e('❌ IGDB credentials not found!');
      _logger.e('   Client ID: ${clientId != null ? "Found" : "Missing"}');
      _logger.e('   Client Secret: ${clientSecret != null ? "Found" : "Missing"}');
      _logger.e('   Please check .env file or environment variables');
      throw Exception(
          'IGDB credentials not found. Please run storeCredentials() first or set IGDB_CLIENT_ID and IGDB_CLIENT_SECRET environment variables.');
    }
    
    _logger.i('🔑 Fetching new IGDB access token...');

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

      // Cache token
      await _storage!.setString(_tokenKey, _accessToken!);
      await _storage!
          .setString(_tokenExpiryKey, _tokenExpiry!.toIso8601String());

      _logger.i('✅ IGDB access token fetched successfully (expires in ${expiresIn}s)');
      return _accessToken!;
    } else {
      _logger.e('❌ Failed to fetch IGDB token: ${response.statusCode}');
      _logger.e('   Response: ${response.body}');
      throw Exception(
          'Failed to fetch IGDB token: ${response.statusCode} - ${response.body}');
    }
  }

  /// Search games using IGDB API with Apicalypse query
  /// If query is empty, returns popular games
  Future<List<Map<String, dynamic>>> searchGames(String query,
      {int limit = 10}) async {
    final token = await getAccessToken();

    final clientId = await getClientId();
    if (clientId == null) throw Exception('IGDB client ID not found.');

    try {
      // If query is empty, get popular games instead of searching
      final queryBody = query.isEmpty
          ? '''
        fields name,slug,cover.url,summary,first_release_date,genres.name;
        where rating > 70 & cover.url != null;
        sort rating desc;
        limit $limit;
      '''
          : '''
        search "$query";
        fields name,slug,cover.url,summary,first_release_date,genres.name;
        limit $limit;
      ''';

      final response = await http.post(
        Uri.parse('https://api.igdb.com/v4/games'),
        headers: {
          'Client-ID': clientId,
          'Authorization': 'Bearer $token',
          'Content-Type': 'text/plain',
        },
        body: queryBody,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;

        return data.map((game) {
          final coverUrl = game['cover']?['url'];
          final processedCoverUrl = coverUrl != null
              ? 'https:${coverUrl.replaceAll('t_thumb', 't_cover_big')}'
              : null;

          // Process release date
          final releaseTimestamp = game['first_release_date'];
          final releaseDate = releaseTimestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(releaseTimestamp * 1000)
              : null;

          // Process genres
          final genres = game['genres'] as List<dynamic>?;
          final genreNames =
              genres?.map((g) => g['name'] as String).toList() ?? [];

          return {
            'name': game['name'] ?? '',
            'slug': game['slug'] ?? '',
            'coverUrl': processedCoverUrl,
            'summary': game['summary'] ?? '',
            'releaseDate': releaseDate,
            'genres': genreNames,
            'maxSpots': 6, // Default max spots for IGDB games
          };
        }).toList();
      } else {
        throw Exception(
            'IGDB search failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error searching IGDB: $e');
    }
  }

  /// Clear stored credentials and tokens (for testing/debugging)
  Future<void> clearStoredData() async {
    await _ensureStorage();
    await _storage!.remove(_clientIdKey);
    await _storage!.remove(_clientSecretKey);
    await _storage!.remove(_tokenKey);
    await _storage!.remove(_tokenExpiryKey);
    _accessToken = null;
    _tokenExpiry = null;
    _logger.i('IGDB stored data cleared');
  }

  /// Store IGDB credentials in SharedPreferences (for development/testing)
  Future<void> storeCredentials() async {
    await _ensureStorage();
    // Store test credentials (replace with real ones for production)
    await _storage!.setString(_clientIdKey, 'yq7hidzec8wv7khe9niom9m6znzrxf');
    await _storage!
        .setString(_clientSecretKey, '4ycghqkzf2ylgxbilypdxu4ga937u5');
    _logger.i('IGDB credentials stored');
  }
}
