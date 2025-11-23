import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    required String senderId,
    required String text,
    required DateTime timestamp,
    required MessageType messageType,
    String? mediaUrl,
    String? mediaType,
    Map<String, int>? reactions,
    String? replyTo,
    Poll? poll,
    String? voiceNoteUrl,
    int? voiceNoteDuration,
    String? aiResponse,
    Map<String, dynamic>? metadata,
    bool? isEdited,
    DateTime? editedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  factory Message.create({
    required String senderId,
    required String text,
    required MessageType messageType,
    String? mediaUrl,
    String? mediaType,
    String? replyTo,
    Poll? poll,
    String? voiceNoteUrl,
    int? voiceNoteDuration,
    Map<String, dynamic>? metadata,
  }) =>
      Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: senderId,
        text: text,
        timestamp: DateTime.now(),
        messageType: messageType,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        reactions: {},
        replyTo: replyTo,
        poll: poll,
        voiceNoteUrl: voiceNoteUrl,
        voiceNoteDuration: voiceNoteDuration,
        metadata: metadata,
        isEdited: false,
        isDeleted: false,
      );
}

@freezed
class Poll with _$Poll {
  const factory Poll({
    required String id,
    required String question,
    required List<String> options,
    required Map<String, List<String>> votes, // option -> list of voter UIDs
    required DateTime createdAt,
    required String createdBy,
    bool? isClosed,
    DateTime? closedAt,
  }) = _Poll;

  factory Poll.fromJson(Map<String, dynamic> json) =>
      _$PollFromJson(json);
}

enum MessageType {
  text,
  image,
  video,
  audio,
  voiceNote,
  file,
  poll,
  aiResponse,
  system,
}