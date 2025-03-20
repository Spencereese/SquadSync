class Message {
  final String sender;
  final DateTime timestamp;
  final String content;
  final List<Map<String, String>> reactions;

  Message({
    required this.sender,
    required this.timestamp,
    required this.content,
    this.reactions = const [],
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      sender: json['s'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['t'] as int? ?? 0,
        isUtc: true,
      ),
      content: json['c'] as String? ?? '',
      reactions: (json['r'] as List<dynamic>?)
              ?.map((r) => Map<String, String>.from(r as Map))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        's': sender,
        't': timestamp.millisecondsSinceEpoch,
        'c': content,
        'r': reactions,
      };

  // Additional helpful methods
  Message copyWith({
    String? sender,
    DateTime? timestamp,
    String? content,
    List<Map<String, String>>? reactions,
  }) {
    return Message(
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      content: content ?? this.content,
      reactions: reactions ?? this.reactions,
    );
  }

  @override
  String toString() {
    return 'Message(sender: $sender, timestamp: $timestamp, content: $content, reactions: $reactions)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          sender == other.sender &&
          timestamp == other.timestamp &&
          content == other.content &&
          reactions == other.reactions;

  @override
  int get hashCode => Object.hash(sender, timestamp, content, reactions);
}
