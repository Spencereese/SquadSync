import 'package:squad_sync/domain/repositories/user_repository.dart';

class AddPinnedGame {
  final UserRepository _repository;

  AddPinnedGame(this._repository);

  Future<void> call(Map<String, dynamic> game) => _repository.addPinnedGame(game);
}