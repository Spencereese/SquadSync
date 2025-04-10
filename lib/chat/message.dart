class Message {
  final String sender;
  final DateTime timestamp;
  final String content;
  final List<Map<String, String>> reactions;
  final String? replyToMessageId; // ID of the message being replied to
  final String? replyToContent; // Content of the message being replied to

  Message({
    required this.sender,
    required this.timestamp,
    required this.content,
    this.reactions = const [],
    this.replyToMessageId,
    this.replyToContent,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      sender: json['s'] as String? ?? 'Unknown',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['t'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        isUtc: true,
      ),
      content: json['c'] as String? ?? '',
      reactions: (json['r'] as List<dynamic>?)
              ?.map((r) => {
                    'emoji': r['emoji'] as String? ?? '',
                    'userId': r['userId'] as String? ?? '',
                  })
              .toList() ??
          const [],
      replyToMessageId: json['replyToMessageId'] as String?,
      replyToContent: json['replyToContent'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        's': sender,
        't': timestamp.millisecondsSinceEpoch,
        'c': content,
        'r': reactions
            .map((r) => {'emoji': r['emoji'], 'userId': r['userId']})
            .toList(),
        'replyToMessageId': replyToMessageId,
        'replyToContent': replyToContent,
      };

  Message copyWith({
    String? sender,
    DateTime? timestamp,
    String? content,
    List<Map<String, String>>? reactions,
    String? replyToMessageId,
    String? replyToContent,
  }) {
    return Message(
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      content: content ?? this.content,
      reactions: reactions ?? this.reactions,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToContent: replyToContent ?? this.replyToContent,
    );
  }

  @override
  String toString() {
    return 'Message(sender: $sender, timestamp: ${timestamp.toIso8601String()}, content: $content, reactions: ${reactions.length} items, replyToMessageId: $replyToMessageId)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          sender == other.sender &&
          timestamp == other.timestamp &&
          content == other.content &&
          reactions == other.reactions &&
          replyToMessageId == other.replyToMessageId &&
          replyToContent == other.replyToContent;

  @override
  int get hashCode => Object.hash(
        sender,
        timestamp,
        content,
        reactions,
        replyToMessageId,
        replyToContent,
      );
}
