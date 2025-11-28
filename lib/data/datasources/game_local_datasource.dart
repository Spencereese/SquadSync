import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:squad_sync/domain/entities/game.dart';
import '../../chat/sqlite_helper.dart';

abstract class GameLocalDataSource {
  Future<List<Game>> getCachedGames(String query);
  Future<void> cacheGames(String query, List<Game> games);
  Future<List<Game>> getOfflineGames(String query, {int limit = 10});
  Future<List<Game>> getCachedPopularGames();
  Future<void> cachePopularGames(List<Game> games);
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
    await _sqliteHelper.cacheGames(
        games.map((g) => g.toJson()).toList(), query);
  }

  @override
  Future<List<Game>> getOfflineGames(String query, {int limit = 10}) async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/popular_games.json');
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

  @override
  Future<List<Game>> getCachedPopularGames() async {
    try {
      final db = await _sqliteHelper.database;
      final results = await db.query(
        'games_cache',
        where: 'id = ?',
        whereArgs: ['popular_games'],
        orderBy: 'cached_at DESC',
        limit: 1,
      );
      if (results.isNotEmpty) {
        final cachedAt = results.first['cached_at'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;
        final oneHour = 60 * 60 * 1000; // 1 hour in milliseconds
        if (now - cachedAt < oneHour) {
          final data = results.first['data'] as String;
          return List<Map<String, dynamic>>.from(json.decode(data))
              .map((item) => Game.fromCache(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> cachePopularGames(List<Game> games) async {
    try {
      final db = await _sqliteHelper.database;
      final data = json.encode(games.map((g) => g.toJson()).toList());
      await db.insert(
        'games_cache',
        {
          'id': 'popular_games',
          'query': 'popular',
          'data': data,
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Failed to cache popular games: $e');
    }
  }
}
