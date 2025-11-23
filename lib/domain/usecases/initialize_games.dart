import 'package:squad_sync/domain/repositories/game_repository.dart';

class InitializeGames {
  final GameRepository _repository;

  InitializeGames(this._repository);

  Future<({
    List<Map<String, dynamic>> availableGames,
    Map<String, List<Map<String, dynamic>>> gameLobbies,
  })> call() async {
    final availableGames = await _repository.getAvailableGames();
    final gameLobbies = await _repository.getGameLobbies();

    return (
      availableGames: availableGames,
      gameLobbies: gameLobbies,
    );
  }
}