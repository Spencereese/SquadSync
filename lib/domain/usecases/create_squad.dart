import 'package:squad_sync/domain/entities/squad.dart';
import 'package:squad_sync/domain/repositories/squad_repository.dart';

class CreateSquad {
  final SquadRepository _repository;

  CreateSquad(this._repository);

  Future<Squad> call(String name, String gameName, int maxSpots) =>
      _repository.createSquad(name, gameName, maxSpots);
}