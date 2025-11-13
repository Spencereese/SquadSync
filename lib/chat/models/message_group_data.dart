import '../models/message_data.dart';

/// Represents a group of messages consisting of a parent message and its replies
class MessageGroupData {
  final MessageData parentMessage;
  final List<MessageData> replies;

  const MessageGroupData({
    required this.parentMessage,
    required this.replies,
  });

  int get replyCount => replies.length;

  bool get hasReplies => replies.isNotEmpty;
}
