import 'package:squad_sync/domain/repositories/system_repository.dart';

class PurgeOldData {
  final SystemRepository _repository;

  PurgeOldData(this._repository);

  Future<void> call() => _repository.purgeOldData();
}