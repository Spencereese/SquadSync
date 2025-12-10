import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/repositories/lobby_repository.dart';

class CreateLobby {
  final LobbyRepository _repository;

  CreateLobby(this._repository);

  Future<Lobby> call(String name, String gameName, int maxSpots) =>
      _repository.createLobby(name, gameName, maxSpots);
}