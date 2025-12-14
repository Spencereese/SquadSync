import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/services/igdb_auth_service.dart';

enum IgdbErrorType {
  network,
  auth,
  rateLimit,
  server,
  unknown,
}

abstract class GameRemoteDataSource {
  Future<List<Game>> fetchGamesFromIgdb(String query, {int limit = 10});
  Future<List<Game>> fetchPopularGames();
  Future<Game?> getGameDetails(int igdbId);
  Future<String> getAccessToken();
  Future<void> refreshToken();
}

class GameRemoteDataSourceImpl implements GameRemoteDataSource {
  final Dio _dio;
  final IgdbAuthService _authService;
  late final CacheOptions _cacheOptions;

  static const int _maxRetries = 3;
  static const List<Duration> _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  GameRemoteDataSourceImpl(this._dio, this._authService) {
    _initializeCache();
  }

  Future<void> _initializeCache() async {
    final cacheDir = await getTemporaryDirectory();
    _cacheOptions = CacheOptions(
      store: HiveCacheStore(cacheDir.path),
      policy: CachePolicy.refreshForceCache,
      maxStale: const Duration(days: 7),
      hitCacheOnErrorExcept: [401, 403],
      keyBuilder: (request) =>
          '${request.uri.path}_${request.data.toString().hashCode}',
    );

    _dio.interceptors.add(DioCacheInterceptor(options: _cacheOptions));
  }

  @override
  Future<List<Game>> fetchGamesFromIgdb(String query, {int limit = 10}) async {
    final token = await getAccessToken();
    final clientId = await _authService.getClientId();

    if (clientId == null) throw Exception('IGDB client ID not found.');

    IgdbErrorType? lastError;
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final queryBody = query.isEmpty
            ? '''
          fields name,slug,cover.url,summary,first_release_date,genres.name,platforms.name,category;
          where rating > 70 & cover.url != null & category = 0 & version_parent = null;
          sort rating desc;
          limit $limit;
        '''
            : '''
          search "$query";
          fields name,slug,cover.url,summary,first_release_date,genres.name,platforms.name,category;
          where category = (0,8,9,10) & version_parent = null;
          limit ${limit * 2};
        ''';

        final response = await _dio.post<String>(
          'https://api.igdb.com/v4/games',
          data: queryBody,
          options: Options(
            headers: {
              'Client-ID': clientId,
              'Authorization': 'Bearer $token',
              'Content-Type': 'text/plain',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = json.decode(response.data!) as List<dynamic>;
          final games = data
              .where((game) => _isValidGame(game))
              .map((game) => Game.fromIgdb(game))
              .toList();
          return _deduplicateGames(games).take(limit).toList();
        } else if (response.statusCode == 401) {
          await refreshToken();
          continue;
        } else {
          lastError =
              _classifyError(response.statusCode ?? 500, response.data ?? '');
          if (lastError == IgdbErrorType.auth ||
              lastError == IgdbErrorType.server) {
            break;
          }
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          await refreshToken();
          continue;
        }
        lastError = IgdbErrorType.network;
      } catch (e) {
        lastError = IgdbErrorType.network;
      }

      if (attempt < _maxRetries - 1) {
        await Future.delayed(_retryDelays[attempt]);
      }
    }

    throw Exception(
        'Failed to fetch games after $_maxRetries attempts. Last error: $lastError');
  }

  @override
  Future<Game?> getGameDetails(int igdbId) async {
    final token = await getAccessToken();
    final clientId = await _authService.getClientId();

    try {
      final response = await _dio.post<String>(
        'https://api.igdb.com/v4/games',
        data: '''
          fields name,slug,cover.url,summary,first_release_date,genres.name,platforms.name;
          where id = $igdbId;
          limit 1;
        ''',
        options: Options(
          headers: {
            'Client-ID': clientId!,
            'Authorization': 'Bearer $token',
            'Content-Type': 'text/plain',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = json.decode(response.data!) as List<dynamic>;
        if (data.isNotEmpty) {
          return Game.fromIgdb(data.first);
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await refreshToken();
        return getGameDetails(igdbId);
      }
    }

    return null;
  }

  @override
  Future<String> getAccessToken() async {
    return await _authService.getAccessToken();
  }

  @override
  Future<void> refreshToken() async {
    // Force a fresh token by calling getAccessToken which handles refresh internally
    await _authService.getAccessToken();
  }

  @override
  Future<List<Game>> fetchPopularGames() async {
    final token = await getAccessToken();
    final clientId = await _authService.getClientId();

    if (clientId == null) throw Exception('IGDB client ID not found.');

    IgdbErrorType? lastError;
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final queryBody = '''
          fields name,slug,cover.url,platforms.name,rating,rating_count,follows,hypes,category,game_modes.name,multiplayer_modes;
          limit 50;
          sort follows desc;
          where category = 0 & version_parent = null & follows > 500 & cover.url != null & (platforms = (6,48,49,130,167,169) | platforms = null) & game_modes != null & (game_modes = (1,2,3,5,6) | multiplayer_modes != null);
        ''';

        final response = await _dio.post<String>(
          'https://api.igdb.com/v4/games',
          data: queryBody,
          options: Options(
            headers: {
              'Client-ID': clientId,
              'Authorization': 'Bearer $token',
              'Content-Type': 'text/plain',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = json.decode(response.data!) as List<dynamic>;
          final games = data
              .where((game) => _isValidGame(game, requireMultiplayer: true))
              .map((game) => Game.fromIgdb(game))
              .toList();
          final deduped = _deduplicateGames(games);
          return _boostTopSquadGames(deduped).take(20).toList();
        } else if (response.statusCode == 401) {
          await refreshToken();
          continue;
        } else {
          lastError =
              _classifyError(response.statusCode ?? 500, response.data ?? '');
          if (lastError == IgdbErrorType.auth ||
              lastError == IgdbErrorType.server) {
            break;
          }
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          await refreshToken();
          continue;
        }
        lastError = IgdbErrorType.network;
      } catch (e) {
        lastError = IgdbErrorType.network;
      }

      if (attempt < _maxRetries - 1) {
        await Future.delayed(_retryDelays[attempt]);
      }
    }

    throw Exception(
        'Failed to fetch popular games after $_maxRetries attempts. Last error: $lastError');
  }

  /// Filter out DLC, editions, remasters, bundles
  bool _isValidGame(Map<String, dynamic> game,
      {bool requireMultiplayer = false}) {
    final name = (game['name'] as String? ?? '').toLowerCase();

    // Skip common DLC/expansion patterns
    final invalidPatterns = [
      'dlc',
      'season pass',
      'expansion',
      'bundle',
      'edition',
      'pack',
      'content',
      ': episode',
      'remaster',
      'remake',
      'definitive',
      'ultimate',
      'deluxe',
      'gold',
      'goty',
      'complete',
    ];

    // Allow games with these words in title (they're actual games)
    final allowPatterns = [
      'black ops',
      'modern warfare',
      'world at war',
    ];

    for (final allow in allowPatterns) {
      if (name.contains(allow)) return true;
    }

    for (final pattern in invalidPatterns) {
      if (name.contains(pattern)) return false;
    }

    // Require cover image
    if (game['cover'] == null) return false;

    // If multiplayer required, check for multiplayer modes or specific game modes
    if (requireMultiplayer) {
      final hasMpModes = game['multiplayer_modes'] != null &&
          (game['multiplayer_modes'] as List).isNotEmpty;
      final gameModes = game['game_modes'] as List<dynamic>?;
      // Game modes: 1=Multiplayer, 2=Co-op, 3=Split screen, 5=MMO, 6=Battle Royale
      final hasMultiplayerMode = gameModes?.any((mode) {
            final modeName = (mode['name'] as String? ?? '').toLowerCase();
            return modeName.contains('multiplayer') ||
                modeName.contains('co-op') ||
                modeName.contains('mmo') ||
                modeName.contains('battle royale');
          }) ??
          false;

      if (!hasMpModes && !hasMultiplayerMode) return false;
    }

    return true;
  }

  /// Deduplicate games by slug, keeping the first occurrence
  List<Game> _deduplicateGames(List<Game> games) {
    final seen = <String>{};
    final deduped = <Game>[];

    for (final game in games) {
      final key = game.slug.toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        deduped.add(game);
      }
    }

    return deduped;
  }

  List<Game> _boostTopSquadGames(List<Game> games) {
    const topSquadGames = [
      'call-of-duty',
      'battlefield',
      'counter-strike',
      'valorant',
      'apex-legends',
      'fortnite',
      'overwatch',
      'rainbow-six-siege',
      'warzone',
      'league-of-legends',
      'dota-2',
      'destiny',
      'halo',
      'pubg',
    ];
    final boosted = <Game>[];
    final others = <Game>[];

    for (final game in games) {
      final slug = game.slug.toLowerCase();
      if (topSquadGames.any((s) => slug.contains(s))) {
        boosted.add(game);
      } else {
        others.add(game);
      }
    }

    return boosted + others;
  }

  IgdbErrorType _classifyError(int statusCode, String body) {
    switch (statusCode) {
      case 401:
        return IgdbErrorType.auth;
      case 429:
        return IgdbErrorType.rateLimit;
      case 500:
      case 502:
      case 503:
        return IgdbErrorType.server;
      default:
        return IgdbErrorType.unknown;
    }
  }
}
