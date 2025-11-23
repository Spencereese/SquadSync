import 'package:squad_sync/domain/repositories/squad_repository.dart';

class SyncSquadData {
  final SquadRepository _repository;

  SyncSquadData(this._repository);

  Future<void> call() => _repository.syncSquadData();
}