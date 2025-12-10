import 'package:squad_sync/domain/repositories/lobby_repository.dart';

class SyncLobbyData {
  final LobbyRepository _repository;

  SyncLobbyData(this._repository);

  Future<void> call() => _repository.syncLobbyData();
}