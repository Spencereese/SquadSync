import 'package:squad_sync/domain/repositories/user_repository.dart';

class UpdateProfileImage {
  final UserRepository _repository;

  UpdateProfileImage(this._repository);

  Future<void> call(String url) => _repository.updateProfileImage(url);
}