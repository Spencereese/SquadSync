import 'package:squad_sync/domain/repositories/lobby_repository.dart';

class LeaveLobby {
  final LobbyRepository _repository;

  LeaveLobby(this._repository);

  Future<void> call(String lobbyId, String userId) =>
      _repository.leaveLobby(lobbyId, userId);
}