import 'package:squad_sync/domain/repositories/chat_repository.dart';

class LoadMediaHistory {
  final ChatRepository _repository;

  LoadMediaHistory(this._repository);

  Future<List<Map<String, dynamic>>> call(String chatGroupId) =>
      _repository.getMediaHistory(chatGroupId);
}