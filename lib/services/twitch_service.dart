import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service for fetching Twitch clips for games using Helix API
class TwitchService {
  final Logger _logger = Logger();
  final Dio _dio;
  String? _accessToken;
  String? _clientId;
  String? _clientSecret;
  bool _initialized = false;

  TwitchService(this._dio);

  static bool _isPlaceholderTwitchCred(String? value) {
    if (value == null) return true;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    final lower = trimmed.toLowerCase();
    return lower.contains('your_') || lower.startsWith('your');
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _clientId = dotenv.env['TWITCH_CLIENT_ID'];
      _clientSecret = dotenv.env['TWITCH_CLIENT_SECRET'];

      if (_isPlaceholderTwitchCred(_clientId) ||
          _isPlaceholderTwitchCred(_clientSecret)) {
        _logger.w('Twitch credentials not configured; skipping token');
        return;
      }

      await _getAccessToken();
      _initialized = _accessToken != null;
      if (_initialized) {
        _logger.i('Twitch API initialized successfully');
      }
    } catch (e) {
      _logger.w('Twitch API skipped: token request failed');
      _initialized = false;
    }
  }

  Future<void> _getAccessToken() async {
    try {
      final response = await _dio.post<String>(
        'https://id.twitch.tv/oauth2/token',
        data: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'grant_type': 'client_credentials',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = json.decode(response.data!);
        _accessToken = data['access_token'];
      }
    } on DioException catch (e) {
      _logger.w(
          'Twitch token request failed (${e.response?.statusCode ?? e.type})');
    } catch (e) {
      _logger.w('Twitch token request failed');
    }
  }

  /// Fetch clips for a game by game name
  /// Returns list of clip data with url, thumbnail, title, creator, etc.
  Future<List<Map<String, dynamic>>> getClipsForGame(
    String gameName, {
    int limit = 20,
    String period = 'week', // day, week, month, all
  }) async {
    if (!_initialized || _accessToken == null) {
      _logger.w('Twitch client not initialized');
      return [];
    }

    try {
      // First, search for game to get game ID
      final gamesResponse = await _dio.get<String>(
        'https://api.twitch.tv/helix/games',
        queryParameters: {'name': gameName},
        options: Options(
          headers: {
            'Client-ID': _clientId,
            'Authorization': 'Bearer $_accessToken',
          },
        ),
      );

      if (gamesResponse.statusCode != 200 || gamesResponse.data == null) {
        return [];
      }

      final gamesData = json.decode(gamesResponse.data!);
      if (gamesData['data'] == null || (gamesData['data'] as List).isEmpty) {
        _logger.w('No Twitch game found for: $gameName');
        return [];
      }

      final gameId = gamesData['data'][0]['id'];

      // Fetch clips for the game
      final startedAt = _getStartDate(period).toIso8601String();
      final clipsResponse = await _dio.get<String>(
        'https://api.twitch.tv/helix/clips',
        queryParameters: {
          'game_id': gameId,
          'first': limit,
          'started_at': startedAt,
        },
        options: Options(
          headers: {
            'Client-ID': _clientId,
            'Authorization': 'Bearer $_accessToken',
          },
        ),
      );

      if (clipsResponse.statusCode != 200 || clipsResponse.data == null) {
        return [];
      }

      final clipsData = json.decode(clipsResponse.data!);
      final clips = clipsData['data'] as List<dynamic>;

      return clips.map<Map<String, dynamic>>((clip) {
        return {
          'id': clip['id'],
          'url': clip['url'],
          'embedUrl': clip['embed_url'],
          'broadcasterId': clip['broadcaster_id'],
          'broadcasterName': clip['broadcaster_name'],
          'creatorId': clip['creator_id'],
          'creatorName': clip['creator_name'],
          'videoId': clip['video_id'],
          'gameId': clip['game_id'],
          'language': clip['language'],
          'title': clip['title'],
          'viewCount': clip['view_count'],
          'createdAt': clip['created_at'],
          'thumbnailUrl': clip['thumbnail_url'],
          'duration': clip['duration'],
        };
      }).toList();
    } catch (e) {
      _logger.e('Error fetching Twitch clips for $gameName: $e');
      return [];
    }
  }

  /// Fetch top clips across all games
  /// Note: Twitch API requires game_id or broadcaster_id - cannot fetch global trending clips
  /// This method is deprecated and will return empty list
  @Deprecated(
      'Use getClipsForGame() instead - Twitch API requires game_id or broadcaster_id')
  Future<List<Map<String, dynamic>>> getTrendingClips({
    int limit = 20,
    String period = 'day',
  }) async {
    _logger.w(
        'getTrendingClips() is deprecated - Twitch API requires game_id or broadcaster_id parameter');
    return [];

    // Original implementation - kept for reference
    // Twitch Helix API requires either game_id or broadcaster_id
    // Cannot fetch global trending clips without these parameters
    /* 
    if (!_initialized || _accessToken == null) {
      _logger.w('Twitch client not initialized');
      return [];
    }

    try {
      final startedAt = _getStartDate(period).toIso8601String();
      final response = await _dio.get<String>(
        'https://api.twitch.tv/helix/clips',
        queryParameters: {
          'first': limit,
          'started_at': startedAt,
        },
        options: Options(
          headers: {
            'Client-ID': _clientId,
            'Authorization': 'Bearer $_accessToken',
          },
        },
      );

      if (response.statusCode != 200 || response.data == null) {
        return [];
      }

      final data = json.decode(response.data!);
      final clips = data['data'] as List<dynamic>;

      return clips.map<Map<String, dynamic>>((clip) {
        return {
          'id': clip['id'],
          'url': clip['url'],
          'embedUrl': clip['embed_url'],
          'broadcasterName': clip['broadcaster_name'],
          'creatorName': clip['creator_name'],
          'title': clip['title'],
          'viewCount': clip['view_count'],
          'createdAt': clip['created_at'],
          'thumbnailUrl': clip['thumbnail_url'],
          'duration': clip['duration'],
        };
      }).toList();
    } catch (e) {
      _logger.e('Error fetching trending clips: $e');
      return [];
    }
    */
  }

  DateTime _getStartDate(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'day':
        return now.subtract(const Duration(days: 1));
      case 'week':
        return now.subtract(const Duration(days: 7));
      case 'month':
        return now.subtract(const Duration(days: 30));
      case 'all':
        return now.subtract(const Duration(days: 365 * 2)); // 2 years
      default:
        return now.subtract(const Duration(days: 7));
    }
  }

  bool get isInitialized => _initialized;

  void dispose() {
    // Cleanup if needed
    _initialized = false;
  }
}
