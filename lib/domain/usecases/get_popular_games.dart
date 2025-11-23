import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/domain/repositories/game_repository.dart';

class GetPopularGames {
  final GameRepository _repository;

  GetPopularGames(this._repository);

  Future<List<Game>> call() => _repository.getPopularGames();
}