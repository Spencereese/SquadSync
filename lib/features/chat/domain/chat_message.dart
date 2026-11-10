/// Where an outgoing row is. Null means the row is someone else's.
enum Delivery { sending, sent, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.delivery,
    this.replyToId,
    this.replyText,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final Delivery? delivery;

  /// The message this one quotes. Null when it is not a reply.
  final String? replyToId;
  final String? replyText;

  ChatMessage copyWith({
    String? text,
    DateTime? sentAt,
    Delivery? delivery,
    String? replyToId,
    String? replyText,
  }) {
    return ChatMessage(
      id: id,
      chatId: chatId,
      senderId: senderId,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
      delivery: delivery ?? this.delivery,
      replyToId: replyToId ?? this.replyToId,
      replyText: replyText ?? this.replyText,
    );
  }
}

/// Oldest first. Equal timestamps break ties by id so a page edge is stable.
int compareMessages(ChatMessage a, ChatMessage b) {
  final byTime = a.sentAt.compareTo(b.sentAt);
  if (byTime != 0) return byTime;
  return a.id.compareTo(b.id);
}

List<ChatMessage> sortedThread(Iterable<ChatMessage> messages) {
  final copy = List<ChatMessage>.of(messages);
  copy.sort(compareMessages);
  return copy;
}
