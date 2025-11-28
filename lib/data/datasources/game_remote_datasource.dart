import 'dart:convert';
import 'package:http/http.dart' as http;
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
  final http.Client _httpClient;
  final IgdbAuthService _authService;

  static const int _maxRetries = 3;
  static const List<Duration> _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  GameRemoteDataSourceImpl(this._httpClient, this._authService);

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
          fields name,slug,cover.url,summary,first_release_date,genres.name,platforms.name;
          where rating > 70 & cover.url != null;
          sort rating desc;
          limit $limit;
        '''
            : '''
          search "$query";
          fields name,slug,cover.url,summary,first_release_date,genres.name,platforms.name;
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
          return data.map((game) => Game.fromIgdb(game)).toList();
        } else if (response.statusCode == 401) {
          await refreshToken();
          continue;
        } else {
          lastError = _classifyError(response.statusCode, response.body);
          if (lastError == IgdbErrorType.auth ||
              lastError == IgdbErrorType.server) {
            break;
          }
        }
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

    final response = await _httpClient.post(
      Uri.parse('https://api.igdb.com/v4/games'),
      headers: {
        'Client-ID': clientId!,
        'Authorization': 'Bearer $token',
        'Content-Type': 'text/plain',
      },
      body: '''
        fields name,slug,cover.url,summary,first_release_date,genres.name,platforms.name;
        where id = $igdbId;
        limit 1;
      ''',
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      if (data.isNotEmpty) {
        return Game.fromIgdb(data.first);
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
          fields name,slug,cover.url,platforms.name,rating,rating_count;
          limit 20;
          sort rating_count desc, total_rating desc;
          where first_release_date > 1577836800 & game_type = 0 & parent_game = null;
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
          final games = data.map((game) => Game.fromIgdb(game)).toList();
          return _boostTopSquadGames(games);
        } else if (response.statusCode == 401) {
          await refreshToken();
          continue;
        } else {
          lastError = _classifyError(response.statusCode, response.body);
          if (lastError == IgdbErrorType.auth ||
              lastError == IgdbErrorType.server) {
            break;
          }
        }
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

  List<Game> _boostTopSquadGames(List<Game> games) {
    const topSquadGames = ['call-of-duty', 'battlefield'];
    final boosted = <Game>[];
    final others = <Game>[];

    for (final game in games) {
      if (topSquadGames.contains(game.slug)) {
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
