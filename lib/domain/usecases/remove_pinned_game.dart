import 'package:squad_sync/domain/repositories/user_repository.dart';

class RemovePinnedGame {
  final UserRepository _repository;

  RemovePinnedGame(this._repository);

  Future<void> call(String gameName) => _repository.removePinnedGame(gameName);
}