import 'package:squad_sync/domain/repositories/squad_repository.dart';

class StartSpotTimer {
  final SquadRepository _repository;

  StartSpotTimer(this._repository);

  Future<void> call(String squadId, int spotIndex, Duration duration) =>
      _repository.startSpotTimer(squadId, spotIndex, duration);
}