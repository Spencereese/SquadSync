import 'package:squad_sync/domain/repositories/squad_repository.dart';

class JoinSquad {
  final SquadRepository _repository;

  JoinSquad(this._repository);

  Future<void> call(String squadId, String userId) =>
      _repository.joinSquad(squadId, userId);
}