import 'package:squad_sync/domain/repositories/squad_repository.dart';

class AssignSpot {
  final SquadRepository _repository;

  AssignSpot(this._repository);

  Future<void> call(String squadId, int spotIndex, String? userId) =>
      _repository.assignSpot(squadId, spotIndex, userId);
}