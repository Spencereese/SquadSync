import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';

class TimestampConverter implements JsonConverter<DateTime, dynamic> {
  const TimestampConverter();

  @override
  DateTime fromJson(dynamic json) {
    if (json == null) {
      return DateTime.now(); // Default to current time for null timestamps
    }
    // Supabase uses DateTime or ISO8601 strings
    if (json is DateTime) {
      return json;
    } else if (json is String) {
      return DateTime.parse(json);
    } else if (json is int) {
      return DateTime.fromMillisecondsSinceEpoch(json);
    }
    throw ArgumentError('Invalid timestamp format: $json');
  }

  @override
  dynamic toJson(DateTime object) => object.toIso8601String();
}

class MessageTypeConverter implements JsonConverter<MessageType, dynamic> {
  const MessageTypeConverter();

  @override
  MessageType fromJson(dynamic json) {
    if (json is String) {
      // Handle legacy format: "MessageType.text" -> "text"
      if (json.startsWith('MessageType.')) {
        json = json.substring('MessageType.'.length);
      }
      return MessageType.values.firstWhere(
        (e) => e.name == json,
        orElse: () => MessageType.text,
      );
    }
    return MessageType.text;
  }

  @override
  dynamic toJson(MessageType object) => object.name;
}

class ReactionConverter implements JsonConverter<Map<String, int>?, dynamic> {
  const ReactionConverter();

  @override
  Map<String, int>? fromJson(dynamic json) {
    if (json == null) return null;

    final reactionsMap = <String, int>{};

    if (json is Map<String, dynamic>) {
      // Handle Firestore reactions format (Map<userId, reaction>)
      for (final reaction in json.values) {
        if (reaction is String && reaction.isNotEmpty) {
          reactionsMap[reaction] = (reactionsMap[reaction] ?? 0) + 1;
        }
      }
    } else if (json is List<dynamic>) {
      // Handle reactions stored as a list of strings
      for (final reaction in json) {
        if (reaction is String && reaction.isNotEmpty) {
          reactionsMap[reaction] = (reactionsMap[reaction] ?? 0) + 1;
        }
      }
    }

    return reactionsMap.isEmpty ? null : reactionsMap;
  }

  @override
  Map<String, dynamic>? toJson(Map<String, int>? object) {
    // For toJson, we can just return the Map<String, int> as is, since Firestore can store it
    return object;
  }
}

enum MessageType {
  text,
  image,
  video,
  audio,
  file,
  poll,
  voiceNote,
  clip,
  aiResponse,
  system,
}

@freezed
class Message with _$Message {
  const Message._();

  const factory Message({
    required String id,
    required String senderId,
    required String text,
    @TimestampConverter() required DateTime timestamp,
    @MessageTypeConverter() required MessageType messageType,
    String? mediaUrl,
    String? mediaType,
    @ReactionConverter() Map<String, int>? reactions,
    String? replyTo,
    Poll? poll,
    String? voiceNoteUrl,
    int? voiceNoteDuration,
    String? aiResponse,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? clipData,
    bool? isEdited,
    @TimestampConverter() DateTime? editedAt,
    bool? isDeleted,
    @TimestampConverter() DateTime? deletedAt,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] ?? json['senderUid'] as String? ?? '',
      text: json['text'] as String? ?? '',
      timestamp: const TimestampConverter().fromJson(json['timestamp']),
      messageType: const MessageTypeConverter().fromJson(json['messageType']),
      mediaUrl: json['mediaUrl'] as String?,
      mediaType: json['mediaType'] as String?,
      reactions: const ReactionConverter().fromJson(json['reactions']),
      replyTo: json['replyTo'] as String?,
      poll: json['poll'] != null
          ? Poll.fromJson(json['poll'] as Map<String, dynamic>)
          : null,
      voiceNoteUrl: json['voiceNoteUrl'] as String?,
      voiceNoteDuration: json['voiceNoteDuration'] as int?,
      aiResponse: json['aiResponse'] as String?,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
      clipData: json['clipData'] is Map<String, dynamic>
          ? json['clipData'] as Map<String, dynamic>
          : null,
      isEdited: json['isEdited'] as bool?,
      editedAt: json['editedAt'] != null
          ? const TimestampConverter().fromJson(json['editedAt'])
          : null,
      isDeleted: json['isDeleted'] as bool?,
      deletedAt: json['deletedAt'] != null
          ? const TimestampConverter().fromJson(json['deletedAt'])
          : null,
    );
  }

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
    Map<String, dynamic>? clipData,
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
        clipData: clipData,
        isEdited: false,
        isDeleted: false,
      );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'timestamp': const TimestampConverter().toJson(timestamp),
      'messageType': const MessageTypeConverter().toJson(messageType),
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'reactions': const ReactionConverter().toJson(reactions),
      'replyTo': replyTo,
      'poll': poll?.toJson(),
      'voiceNoteUrl': voiceNoteUrl,
      'voiceNoteDuration': voiceNoteDuration,
      'aiResponse': aiResponse,
      'metadata': metadata,
      'clipData': clipData,
      'isEdited': isEdited,
      'editedAt': editedAt != null
          ? const TimestampConverter().toJson(editedAt!)
          : null,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null
          ? const TimestampConverter().toJson(deletedAt!)
          : null,
    };
  }
}

mixin MessageJsonMixin {
  Map<String, dynamic> toJson() {
    // This will be implemented by the class that uses this mixin
    throw UnimplementedError('toJson must be implemented');
  }
}

class Poll {
  const Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.votes, // option -> list of voter UIDs
    required this.createdAt,
    required this.createdBy,
    this.isClosed,
    this.closedAt,
  });

  final String id;
  final String question;
  final List<String> options;
  final Map<String, List<String>> votes; // option -> list of voter UIDs
  final DateTime createdAt;
  final String createdBy;
  final bool? isClosed;
  final DateTime? closedAt;

  factory Poll.fromJson(Map<String, dynamic> json) {
    // Handle Firestore Timestamp objects
    final createdAt = json['createdAt'];
    final closedAt = json['closedAt'];

    return Poll(
      id: json['id'] as String? ?? '',
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      votes: (json['votes'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k,
                (e as List<dynamic>?)?.map((e) => e as String).toList() ?? []),
          ) ??
          {},
      createdAt: const TimestampConverter().fromJson(createdAt),
      createdBy: json['createdBy'] as String? ?? '',
      isClosed: json['isClosed'] as bool?,
      closedAt: closedAt != null
          ? const TimestampConverter().fromJson(closedAt)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'votes': votes,
      'createdAt': const TimestampConverter().toJson(createdAt),
      'createdBy': createdBy,
      'isClosed': isClosed,
      'closedAt': closedAt != null
          ? const TimestampConverter().toJson(closedAt!)
          : null,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Poll) return false;
    return id == other.id &&
        question == other.question &&
        options == other.options &&
        votes == other.votes &&
        createdAt == other.createdAt &&
        createdBy == other.createdBy &&
        isClosed == other.isClosed &&
        closedAt == other.closedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        question.hashCode ^
        options.hashCode ^
        votes.hashCode ^
        createdAt.hashCode ^
        createdBy.hashCode ^
        isClosed.hashCode ^
        closedAt.hashCode;
  }
}

enum ChatType {
  dm,
  userGroup,
  squad,
}
