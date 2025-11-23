import 'package:squad_sync/domain/repositories/chat_repository.dart';

class AddReaction {
  final ChatRepository _repository;

  AddReaction(this._repository);

  Future<void> call(String chatGroupId, String messageId, String reaction) =>
      _repository.addReaction(chatGroupId, messageId, reaction);
}