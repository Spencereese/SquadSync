import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/domain/repositories/game_repository.dart';

class FetchGames {
  final GameRepository _repository;

  FetchGames(this._repository);

  Future<List<Game>> call(String query, {int limit = 10}) =>
      _repository.fetchGames(query, limit: limit);
}