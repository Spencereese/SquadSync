import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';

class LoadMessages {
  final ChatRepository _repository;

  LoadMessages(this._repository);

  Future<List<Message>> call(String chatGroupId, {int limit = 50, DateTime? before}) =>
      _repository.loadMessages(chatGroupId, limit: limit, before: before);
}