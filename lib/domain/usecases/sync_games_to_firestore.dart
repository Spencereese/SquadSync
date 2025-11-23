import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/domain/repositories/game_repository.dart';

class SyncGamesToFirestore {
  final GameRepository _repository;

  SyncGamesToFirestore(this._repository);

  Future<void> call(String query, List<Game> games) =>
      _repository.syncGamesToFirestore(query, games);
}