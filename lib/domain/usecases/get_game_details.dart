import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/domain/repositories/game_repository.dart';

class GetGameDetails {
  final GameRepository _repository;

  GetGameDetails(this._repository);

  Future<Game?> call(int igdbId) => _repository.getGameDetails(igdbId);
}