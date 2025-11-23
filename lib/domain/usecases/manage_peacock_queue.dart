import 'package:squad_sync/domain/repositories/squad_repository.dart';

class ManagePeacockQueue {
  final SquadRepository _repository;

  ManagePeacockQueue(this._repository);

  Future<void> addToQueue(String userId, String gameName) =>
      _repository.addToPeacockQueue(userId, gameName);

  Future<void> removeFromQueue(String userId) =>
      _repository.removeFromPeacockQueue(userId);

  Future<void> processQueue() => _repository.processPeacockQueue();
}