import 'package:squad_sync/domain/entities/squad.dart';
import 'package:squad_sync/domain/repositories/squad_repository.dart';

class JoinSquadByCode {
  final SquadRepository _repository;

  JoinSquadByCode(this._repository);

  Future<Squad?> call(String inviteCode, String userId) async {
    final squad = await _repository.getSquadByInviteCode(inviteCode);
    if (squad == null) return null;

    await _repository.joinSquad(squad.id, userId);
    return squad;
  }
}
