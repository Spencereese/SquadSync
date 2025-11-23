import 'package:squad_sync/domain/entities/squad_state.dart';
import 'package:squad_sync/domain/repositories/squad_repository.dart';

class LoadSquadState {
  final SquadRepository _repository;

  LoadSquadState(this._repository);

  Future<SquadState> call() => _repository.loadSquadState();
}