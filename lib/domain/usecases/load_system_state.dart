import 'package:squad_sync/domain/entities/system_state.dart';
import 'package:squad_sync/domain/repositories/system_repository.dart';

class LoadSystemState {
  final SystemRepository _repository;

  LoadSystemState(this._repository);

  Future<SystemState> call() => _repository.loadSystemState();
}