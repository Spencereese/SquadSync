import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';

class SendMessage {
  final ChatRepository _repository;

  SendMessage(this._repository);

  Future<Message> call(String chatGroupId, String text, MessageType messageType,
          ChatType chatType,
          {String? mediaUrl,
          String? mediaType,
          String? replyTo,
          Poll? poll,
          String? voiceNoteUrl,
          int? voiceNoteDuration}) =>
      _repository.sendMessage(chatGroupId, text, messageType, chatType,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
          replyTo: replyTo,
          poll: poll,
          voiceNoteUrl: voiceNoteUrl,
          voiceNoteDuration: voiceNoteDuration);
}
