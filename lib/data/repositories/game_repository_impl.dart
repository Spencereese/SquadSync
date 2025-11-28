import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/domain/repositories/game_repository.dart';
import 'package:squad_sync/data/datasources/game_local_datasource.dart';
import 'package:squad_sync/data/datasources/game_remote_datasource.dart';

class GameRepositoryImpl implements GameRepository {
  final GameLocalDataSource _localDataSource;
  final GameRemoteDataSource _remoteDataSource;
  final FirebaseFirestore _firestore;

  GameRepositoryImpl(
    this._localDataSource,
    this._remoteDataSource,
    this._firestore,
  );

  @override
  Future<List<Game>> fetchGames(String query, {int limit = 10}) async {
    // Try cache first
    final cachedGames = await _localDataSource.getCachedGames(query);
    if (cachedGames.isNotEmpty) {
      return cachedGames;
    }

    // Try API
    try {
      final games =
          await _remoteDataSource.fetchGamesFromIgdb(query, limit: limit);

      // Cache results
      await _localDataSource.cacheGames(query, games);

      // Sync to Firestore
      await syncGamesToFirestore(query, games);

      return games;
    } catch (e) {
      // Fallback to offline
      return await _localDataSource.getOfflineGames(query, limit: limit);
    }
  }

  @override
  Future<Game?> getGameDetails(int igdbId) async {
    return await _remoteDataSource.getGameDetails(igdbId);
  }

  @override
  Future<List<Game>> getPopularGames() async {
    // Try cache first (1 hour TTL)
    final cachedGames = await _localDataSource.getCachedPopularGames();
    if (cachedGames.isNotEmpty) {
      return cachedGames;
    }

    // Try API
    try {
      final games = await _remoteDataSource.fetchPopularGames();

      // Cache results with 1 hour TTL
      await _localDataSource.cachePopularGames(games);

      // Sync to Firestore
      await syncGamesToFirestore('popular', games);

      return games;
    } catch (e) {
      // Fallback to offline
      return await _getOfflinePopularGames();
    }
  }

  Future<List<Game>> _getOfflinePopularGames() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/popular_games.json');
      final data = json.decode(jsonString) as List<dynamic>;
      final games = data.map((item) => Game.fromCache(item)).toList();

      // Sort by popularity_score if available, else by name
      games.sort((a, b) {
        final aScore = (a as dynamic).popularityScore ?? 0;
        final bScore = (b as dynamic).popularityScore ?? 0;
        if (aScore != bScore) {
          return bScore.compareTo(aScore); // Descending
        }
        return a.name.compareTo(b.name);
      });

      return games.take(20).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> syncGamesToFirestore(String query, List<Game> games) async {
    final batch = _firestore.batch();

    for (final game in games) {
      final docRef = _firestore.collection('games').doc(game.slug);
      batch.set(docRef, game.toJson(), SetOptions(merge: true));
    }

    await batch.commit();
  }

  @override
  Future<void> cacheGamesLocally(String query, List<Game> games) async {
    await _localDataSource.cacheGames(query, games);
  }

  @override
  Future<List<Game>> getCachedGames(String query) async {
    return await _localDataSource.getCachedGames(query);
  }

  @override
  Future<List<Game>> getOfflineGames(String query, {int limit = 10}) async {
    return await _localDataSource.getOfflineGames(query, limit: limit);
  }

  @override
  Future<List<Map<String, dynamic>>> getAvailableGames() async {
    final snapshot = await _firestore.collection('games').orderBy('name').get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> getGameLobbies() async {
    final snapshot = await _firestore
        .collection('lobbies')
        .where('isVisible', isEqualTo: true)
        .get();

    final gameLobbies = <String, List<Map<String, dynamic>>>{};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final gameName = data['gameName'] as String;
      gameLobbies.putIfAbsent(gameName, () => []).add(data);
    }

    return gameLobbies;
  }
}
