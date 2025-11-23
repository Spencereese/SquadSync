import 'package:squad_sync/domain/repositories/squad_repository.dart';

class UpdateMemberStatus {
  final SquadRepository _repository;

  UpdateMemberStatus(this._repository);

  Future<void> call(String squadId, String userId, String status) =>
      _repository.updateMemberStatus(squadId, userId, status);
}