import 'package:squad_sync/domain/repositories/system_repository.dart';

class BanUser {
  final SystemRepository _repository;

  BanUser(this._repository);

  Future<void> call(String userId, String reason) =>
      _repository.banUser(userId, reason);
}