import 'package:squad_sync/domain/repositories/system_repository.dart';

class CheckAvailability {
  final SystemRepository _repository;

  CheckAvailability(this._repository);

  Future<bool> call() => _repository.checkAvailability();
}