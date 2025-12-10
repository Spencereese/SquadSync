import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/domain/repositories/lobby_repository.dart';

class LoadLobbyState {
  final LobbyRepository _repository;

  LoadLobbyState(this._repository);

  Future<LobbyState> call() => _repository.loadLobbyState();
}