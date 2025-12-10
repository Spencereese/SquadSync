import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/repositories/lobby_repository.dart';

class JoinLobbyByCode {
  final LobbyRepository _repository;

  JoinLobbyByCode(this._repository);

  Future<Squad?> call(String inviteCode, String userId) async {
    final squad = await _repository.getSquadByInviteCode(inviteCode);
    if (squad == null) return null;

    await _repository.joinLobby(squad.id, userId);
    return squad;
  }
}
