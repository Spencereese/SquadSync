import 'package:squad_sync/domain/repositories/system_repository.dart';

class UpdateNotificationSettings {
  final SystemRepository _repository;

  UpdateNotificationSettings(this._repository);

  Future<void> call(Map<String, bool> settings) =>
      _repository.updateNotificationSettings(settings);
}