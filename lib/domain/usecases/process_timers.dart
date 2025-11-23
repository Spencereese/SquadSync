import 'package:squad_sync/domain/repositories/squad_repository.dart';

class ProcessTimers {
  final SquadRepository _repository;

  ProcessTimers(this._repository);

  Future<void> call() => _repository.processExpiredTimers();
}