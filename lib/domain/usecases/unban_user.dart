import 'package:squad_sync/domain/repositories/system_repository.dart';

class UnbanUser {
  final SystemRepository _repository;

  UnbanUser(this._repository);

  Future<void> call(String userId) => _repository.unbanUser(userId);
}