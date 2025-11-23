import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:squad_sync/domain/entities/game.dart';
import '../../chat/sqlite_helper.dart';

abstract class GameLocalDataSource {
  Future<List<Game>> getCachedGames(String query);
  Future<void> cacheGames(String query, List<Game> games);
  Future<List<Game>> getOfflineGames(String query, {int limit = 10});
}

class GameLocalDataSourceImpl implements GameLocalDataSource {
  final SQLiteHelper _sqliteHelper;

  GameLocalDataSourceImpl(this._sqliteHelper);

  @override
  Future<List<Game>> getCachedGames(String query) async {
    final cachedData = await _sqliteHelper.getCachedGames(query);
    return cachedData.map((item) => Game.fromCache(item)).toList();
  }

  @override
  Future<void> cacheGames(String query, List<Game> games) async {
    await _sqliteHelper.cacheGames(games.map((g) => g.toJson()).toList(), query);
  }

  @override
  Future<List<Game>> getOfflineGames(String query, {int limit = 10}) async {
    try {
      final jsonString = await rootBundle.loadString('assets/popular_games.json');
      final data = json.decode(jsonString) as List<dynamic>;

      final games = data.map((item) => Game.fromCache(item)).toList();

      if (query.isEmpty) {
        return games.take(limit).toList();
      } else {
        return games
            .where((game) =>
                game.name.toLowerCase().contains(query.toLowerCase()) ||
                game.slug.toLowerCase().contains(query.toLowerCase()))
            .take(limit)
            .toList();
      }
    } catch (e) {
      return [];
    }
  }
}