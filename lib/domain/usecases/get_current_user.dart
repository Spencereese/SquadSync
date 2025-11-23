import 'package:squad_sync/domain/entities/app_user.dart';
import 'package:squad_sync/domain/repositories/user_repository.dart';

class GetCurrentUser {
  final UserRepository _repository;

  GetCurrentUser(this._repository);

  Future<AppUser?> call() => _repository.getCurrentUser();
}