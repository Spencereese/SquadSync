import 'package:squad_sync/domain/repositories/chat_repository.dart';

class UpdateTypingIndicator {
  final ChatRepository _repository;

  UpdateTypingIndicator(this._repository);

  Future<void> call(String chatGroupId, bool isTyping) =>
      _repository.updateTypingIndicator(chatGroupId, isTyping);
}