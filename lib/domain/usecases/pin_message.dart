import 'package:squad_sync/domain/repositories/chat_repository.dart';

class PinMessage {
  final ChatRepository _repository;

  PinMessage(this._repository);

  Future<void> call(String chatGroupId, String messageId) =>
      _repository.pinMessage(chatGroupId, messageId);
}