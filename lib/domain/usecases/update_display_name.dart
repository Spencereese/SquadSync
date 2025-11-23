import 'package:squad_sync/domain/repositories/user_repository.dart';

class UpdateDisplayName {
  final UserRepository _repository;

  UpdateDisplayName(this._repository);

  Future<void> call(String name) => _repository.updateDisplayName(name);
}