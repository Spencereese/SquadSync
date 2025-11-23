import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';

class CreatePoll {
  final ChatRepository _repository;

  CreatePoll(this._repository);

  Future<Poll> call(String chatGroupId, String question, List<String> options) =>
      _repository.createPoll(chatGroupId, question, options);
}