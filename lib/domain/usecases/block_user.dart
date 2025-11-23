import 'package:squad_sync/domain/repositories/user_repository.dart';

class BlockUser {
  final UserRepository _repository;

  BlockUser(this._repository);

  Future<void> call(String userName) => _repository.blockUser(userName);
}