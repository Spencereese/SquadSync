import 'package:squad_sync/domain/repositories/system_repository.dart';

class UpdateLastSync {
  final SystemRepository _repository;

  UpdateLastSync(this._repository);

  Future<void> call(DateTime timestamp) =>
      _repository.updateLastSyncTimestamp(timestamp);
}