import 'package:squad_sync/domain/repositories/squad_repository.dart';

class LeaveSquad {
  final SquadRepository _repository;

  LeaveSquad(this._repository);

  Future<void> call(String squadId, String userId) =>
      _repository.leaveSquad(squadId, userId);
}