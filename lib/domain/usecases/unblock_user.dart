import 'package:squad_sync/domain/repositories/user_repository.dart';

class UnblockUser {
  final UserRepository _repository;

  UnblockUser(this._repository);

  Future<void> call(String userName) => _repository.unblockUser(userName);
}