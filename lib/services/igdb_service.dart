import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite/sqflite.dart';
import '../chat/sqlite_helper.dart';
import 'firestore_service.dart';

/// Error types for IGDB API calls
enum IgdbErrorType {
  network,
  auth,
  rateLimit,
  server,
  unknown,
}

/// IGDB Service with Riverpod integration, caching, and resilient error handling
class IgdbService {
  static const String _clientIdKey = 'igdb_client_id';
  static const String _clientSecretKey = 'igdb_client_secret';
  static const String _tokenKey = 'igdb_access_token';
  static const String _tokenExpiryKey = 'igdb_token_expiry';
  static const int _maxRetries = 3;
  static const List<Duration> _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  final SQLiteHelper _sqliteHelper;
  final FirestoreService _firestoreService;
  SharedPreferences? _storage;
  String? _accessToken;
  DateTime? _tokenExpiry;
  final http.Client _httpClient;

  IgdbService(this._sqliteHelper, this._firestoreService, [SharedPreferences? storage, http.Client? httpClient])
      : _httpClient = httpClient ?? http.Client() {
    _storage = storage;
  }

  /// Initialize storage
  Future<void> _ensureStorage() async {
    _storage ??= await SharedPreferences.getInstance();
  }

  /// Get stored client ID
  Future<String?> getClientId() async {
    await _ensureStorage();
    final storedId = _storage!.getString(_clientIdKey);
    if (storedId != null) return storedId;
    return dotenv.env['IGDB_CLIENT_ID'];
  }

  /// Get stored client secret
  Future<String?> getClientSecret() async {
    await _ensureStorage();
    final storedSecret = _storage!.getString(_clientSecretKey);
    if (storedSecret != null) return storedSecret;
    return dotenv.env['IGDB_CLIENT_SECRET'];
  }

  /// Fetch or retrieve access token with retry logic
  Future<String> getAccessToken() async {
    await _ensureStorage();

    // Check if we have a valid cached token
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
      return _accessToken!;
    }

    // Try to load from storage
    final storedToken = _storage!.getString(_tokenKey);
    final storedExpiry = _storage!.getString(_tokenExpiryKey);

    if (storedToken != null && storedExpiry != null) {
      final expiry = DateTime.parse(storedExpiry);
      if (DateTime.now().isBefore(expiry.subtract(const Duration(minutes: 5)))) {
        _accessToken = storedToken;
        _tokenExpiry = expiry;
        return _accessToken!;
      }
    }

    // Fetch new token with retries
    return await _fetchNewTokenWithRetries();
  }

  /// Fetch new access token from Twitch OAuth2 with retries
  Future<String> _fetchNewTokenWithRetries() async {
    final clientId = await getClientId();
    final clientSecret = await getClientSecret();

    if (clientId == null || clientSecret == null) {
      throw Exception('IGDB credentials not found. Please set IGDB_CLIENT_ID and IGDB_CLIENT_SECRET.');
    }

    IgdbErrorType? lastError;
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await _httpClient.post(
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
          await _storage!.setString(_tokenExpiryKey, _tokenExpiry!.toIso8601String());

          return _accessToken!;
        } else {
          lastError = _classifyError(response.statusCode, response.body);
          if (lastError == IgdbErrorType.auth || lastError == IgdbErrorType.server) {
            // Don't retry for auth or server errors
            break;
          }
        }
      } catch (e) {
        lastError = IgdbErrorType.network;
        debugPrint('Token fetch attempt ${attempt + 1} failed: $e');
      }

      // Wait before retry (except on last attempt)
      if (attempt < _maxRetries - 1) {
        await Future.delayed(_retryDelays[attempt]);
      }
    }

    throw Exception('Failed to fetch IGDB token after $_maxRetries attempts. Last error: $lastError');
  }

  /// Classify HTTP error responses
  IgdbErrorType _classifyError(int statusCode, String body) {
    switch (statusCode) {
      case 401:
        return IgdbErrorType.auth;
      case 429:
        return IgdbErrorType.rateLimit;
      case 500:
      case 502:
      case 503:
      case 504:
        return IgdbErrorType.server;
      default:
        if (statusCode >= 400 && statusCode < 500) {
          return IgdbErrorType.auth;
        }
        return IgdbErrorType.unknown;
    }
  }

  /// Fetch games with caching, retries, and offline fallback
  Future<List<Map<String, dynamic>>> fetchGames(String query, {int limit = 10}) async {
    // Try cache first
    final cachedGames = await _sqliteHelper.getCachedGames(query);
    if (cachedGames.isNotEmpty) {
      debugPrint('Returning cached games for query: $query');
      return cachedGames;
    }

    // Try API with retries
    try {
      final games = await _fetchGamesFromApi(query, limit: limit);

      // Cache successful results
      await _sqliteHelper.cacheGames(games, query);

      // Sync to Firestore for cross-device availability
      await _syncGamesToFirestore(query, games);

      return games;
    } catch (e) {
      debugPrint('API fetch failed for query "$query": $e');

      // Try offline fallback
      return await _getOfflineGames(query, limit);
    }
  }

  /// Fetch games from IGDB API with exponential backoff
  Future<List<Map<String, dynamic>>> _fetchGamesFromApi(String query, {int limit = 10}) async {
    final token = await getAccessToken();
    final clientId = await getClientId();
    if (clientId == null) throw Exception('IGDB client ID not found.');

    IgdbErrorType? lastError;
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
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

        final response = await _httpClient.post(
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
          return data.map((game) => _processGameData(game)).toList();
        } else if (response.statusCode == 401) {
          // Token expired, refresh and retry
          await _refreshToken();
          continue;
        } else {
          lastError = _classifyError(response.statusCode, response.body);
          if (lastError == IgdbErrorType.auth || lastError == IgdbErrorType.server) {
            break;
          }
        }
      } catch (e) {
        lastError = IgdbErrorType.network;
        debugPrint('Games fetch attempt ${attempt + 1} failed: $e');
      }

      // Wait before retry
      if (attempt < _maxRetries - 1) {
        await Future.delayed(_retryDelays[attempt]);
      }
    }

    throw Exception('Failed to fetch games after $_maxRetries attempts. Last error: $lastError');
  }

  /// Refresh token on 401 errors
  Future<void> _refreshToken() async {
    _accessToken = null;
    _tokenExpiry = null;
    await _storage?.remove(_tokenKey);
    await _storage?.remove(_tokenExpiryKey);
  }

  /// Process raw game data from IGDB API
  Map<String, dynamic> _processGameData(dynamic game) {
    final coverUrl = game['cover']?['url'];
    final processedCoverUrl = coverUrl != null
        ? 'https:${coverUrl.replaceAll('t_thumb', 't_cover_big')}'
        : null;

    final releaseTimestamp = game['first_release_date'];
    final releaseDate = releaseTimestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(releaseTimestamp * 1000)
        : null;

    final genres = game['genres'] as List<dynamic>?;
    final genreNames = genres?.map((g) => g['name'] as String).toList() ?? [];

    return {
      'name': game['name'] ?? '',
      'slug': game['slug'] ?? '',
      'coverUrl': processedCoverUrl,
      'summary': game['summary'] ?? '',
      'releaseDate': releaseDate,
      'genres': genreNames,
      'maxSpots': 6, // Default max spots for IGDB games
    };
  }

  /// Get offline games from assets
  Future<List<Map<String, dynamic>>> _getOfflineGames(String query, int limit) async {
    try {
      final jsonString = await rootBundle.loadString('assets/popular_games.json');
      final data = json.decode(jsonString) as List<dynamic>;

      final games = data.map((game) => _processGameData(game)).toList();

      // Filter by query if provided
      if (query.isNotEmpty) {
        final filtered = games.where((game) {
          final name = game['name'] as String? ?? '';
          return name.toLowerCase().contains(query.toLowerCase());
        }).toList();
        return filtered.take(limit).toList();
      }

      return games.take(limit).toList();
    } catch (e) {
      debugPrint('Failed to load offline games: $e');
      return [];
    }
  }

  /// Sync games to Firestore for cross-device availability
  Future<void> _syncGamesToFirestore(String query, List<Map<String, dynamic>> games) async {
    try {
      final gameData = {
        'query': query,
        'games': games,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      await _firestoreService.saveGameSearch(query, gameData);
    } catch (e) {
      debugPrint('Failed to sync games to Firestore: $e');
      // Don't throw - caching should work even if sync fails
    }
  }

  /// Clear stored credentials and tokens
  Future<void> clearStoredData() async {
    await _ensureStorage();
    await _storage!.remove(_clientIdKey);
    await _storage!.remove(_clientSecretKey);
    await _storage!.remove(_tokenKey);
    await _storage!.remove(_tokenExpiryKey);
    _accessToken = null;
    _tokenExpiry = null;
    debugPrint('IGDB stored data cleared');
  }

  /// Store IGDB credentials
  Future<void> storeCredentials() async {
    await _ensureStorage();
    await _storage!.setString(_clientIdKey, 'yq7hidzec8wv7khe9niom9m6znzrxf');
    await _storage!.setString(_clientSecretKey, '4ycghqkzf2ylgxbilypdxu4ga937u5');
    debugPrint('IGDB credentials stored');
  }
}