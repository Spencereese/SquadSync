import 'package:squad_sync/domain/entities/game.dart';

abstract class GameRepository {
  Future<List<Game>> fetchGames(String query, {int limit = 10});
  Future<Game?> getGameDetails(int igdbId);
  Future<List<Game>> getPopularGames();
  /// Persist searched games to the remote catalog (Supabase). Currently a no-op.
  Future<void> persistGames(String query, List<Game> games);
  Future<void> cacheGamesLocally(String query, List<Game> games);
  Future<List<Game>> getCachedGames(String query);
  Future<List<Game>> getOfflineGames(String query, {int limit = 10});
  Future<List<Map<String, dynamic>>> getAvailableGames();
  Future<Map<String, List<Map<String, dynamic>>>> getGameLobbies();
}