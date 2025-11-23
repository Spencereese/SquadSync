import 'package:squad_sync/domain/repositories/system_repository.dart';

class SendLocalNotification {
  final SystemRepository _repository;

  SendLocalNotification(this._repository);

  Future<void> call(String title, String body, {Map<String, dynamic>? data}) =>
      _repository.sendLocalNotification(title, body, data: data);
}