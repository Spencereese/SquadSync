import 'package:squad_sync/domain/repositories/lobby_repository.dart';

class JoinLobby {
  final LobbyRepository _repository;

  JoinLobby(this._repository);

  Future<void> call(String lobbyId, String userId) =>
      _repository.joinLobby(lobbyId, userId);
}