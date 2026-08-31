import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

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

class ReactionConverter
    implements JsonConverter<Map<String, dynamic>?, dynamic> {
  const ReactionConverter();

  @override
  Map<String, dynamic>? fromJson(dynamic json) {
    if (json == null) return null;

    try {
      if (json is Map) {
        final mapData = json;
        if (mapData.isEmpty) return null;

        // Check if this is the new format: Map<emoji, List<userId>>
        final firstValue = mapData.values.firstOrNull;
        if (firstValue is List) {
          // New format: emoji -> list of user IDs
          // Preserve this format for the UI
          return Map<String, dynamic>.from(mapData);
        } else if (firstValue is String) {
          // Old format: userId -> emoji, convert to aggregated counts
          final reactionsMap = <String, int>{};
          for (final reaction in mapData.values) {
            if (reaction is String && reaction.isNotEmpty) {
              reactionsMap[reaction] = (reactionsMap[reaction] ?? 0) + 1;
            }
          }
          return reactionsMap.isEmpty ? null : reactionsMap;
        } else if (firstValue is int) {
          // Direct count format (emoji -> count)
          return Map<String, dynamic>.from(mapData);
        }
      } else if (json is List<dynamic>) {
        // Handle reactions stored as a list of strings
        final reactionsMap = <String, int>{};
        for (final reaction in json) {
          if (reaction is String && reaction.isNotEmpty) {
            reactionsMap[reaction] = (reactionsMap[reaction] ?? 0) + 1;
          }
        }
        return reactionsMap.isEmpty ? null : reactionsMap;
      }

      return null;
    } catch (e) {
      // Return null if parsing fails
      debugPrint('ReactionConverter error: $e');
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(Map<String, dynamic>? object) {
    return object;
  }
}

/// PostgREST/SQLite may send 0/1/'true' instead of bool.
bool? _asBoolish(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value == 1 || value == '1' || value == 'true') return true;
  if (value == 0 || value == '0' || value == 'false') return false;
  return null;
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

@freezed // Disable DiagnosticableTreeMixin - has bugs in Freezed 3.0
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
    @ReactionConverter() Map<String, dynamic>? reactions,
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
    try {
      // Safe metadata parsing - completely skip if it contains old array fields
      Map<String, dynamic>? safeMetadata;
      final metadataRaw = json['metadata'];
      if (metadataRaw != null && metadataRaw is Map) {
        // Skip metadata completely if it has old schema fields
        final hasOldFields = metadataRaw.containsKey('photos') ||
            metadataRaw.containsKey('videos') ||
            metadataRaw.containsKey('audio');
        if (!hasOldFields) {
          safeMetadata = Map<String, dynamic>.from(metadataRaw);
        }
      }

      // Safe clipData parsing - skip if it's a List
      Map<String, dynamic>? safeClipData;
      final clipDataRaw = json['clipData'] ?? json['clip_data'];
      if (clipDataRaw != null && clipDataRaw is! List && clipDataRaw is Map) {
        safeClipData = Map<String, dynamic>.from(clipDataRaw);
      }

      return Message(
        id: json['id'] as String? ?? '',
        senderId: json['senderId'] ??
            json['senderUid'] ??
            json['sender_id'] as String? ??
            '',
        text: json['text'] as String? ?? '',
        timestamp: const TimestampConverter().fromJson(json['timestamp']),
        messageType: const MessageTypeConverter()
            .fromJson(json['messageType'] ?? json['message_type']),
        mediaUrl: json['mediaUrl'] ?? json['media_url'] as String?,
        mediaType: json['mediaType'] ?? json['media_type'] as String?,
        reactions: const ReactionConverter().fromJson(json['reactions']),
        replyTo: json['replyTo'] ?? json['reply_to'] as String?,
        poll: json['poll'] != null
            ? (json['poll'] is Map<String, dynamic>
                ? Poll.fromJson(json['poll'] as Map<String, dynamic>)
                : null)
            : null,
        voiceNoteUrl: json['voiceNoteUrl'] ?? json['voice_note_url'] as String?,
        voiceNoteDuration:
            json['voiceNoteDuration'] ?? json['voice_note_duration'] as int?,
        aiResponse: json['aiResponse'] ?? json['ai_response'] as String?,
        metadata: safeMetadata,
        clipData: safeClipData,
        isEdited: _asBoolish(json['isEdited'] ?? json['is_edited']),
        editedAt: (json['editedAt'] ?? json['edited_at']) != null
            ? const TimestampConverter()
                .fromJson(json['editedAt'] ?? json['edited_at'])
            : null,
        isDeleted: _asBoolish(json['isDeleted'] ?? json['is_deleted']),
        deletedAt: (json['deletedAt'] ?? json['deleted_at']) != null
            ? const TimestampConverter()
                .fromJson(json['deletedAt'] ?? json['deleted_at'])
            : null,
      );
    } catch (e, stackTrace) {
      // If parsing fails, log and rethrow with context
      debugPrint('❌ Message.fromJson failed for message ${json['id']}: $e');
      debugPrint('   Problematic JSON keys: ${json.keys.join(', ')}');
      debugPrint('   metadata type: ${json['metadata'].runtimeType}');
      debugPrint('   metadata value: ${json['metadata']}');
      debugPrint('   clip_data type: ${json['clip_data']?.runtimeType}');
      debugPrint('   poll type: ${json['poll']?.runtimeType}');
      debugPrint('   Stack trace: $stackTrace');
      rethrow;
    }
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
    // Use snake_case for Supabase compatibility
    final reactionsJson = const ReactionConverter().toJson(reactions);
    // if (kDebugMode) {
    //   debugPrint(
    //       '💬 Message.toJson for $id: reactions field = $reactions, toJson = $reactionsJson');
    // }
    return {
      'id': id,
      'sender_id': senderId,
      'text': text,
      'timestamp': const TimestampConverter().toJson(timestamp),
      'message_type': const MessageTypeConverter().toJson(messageType),
      'media_url': mediaUrl,
      'media_type': mediaType,
      'reactions': reactionsJson,
      'reply_to': replyTo,
      'poll': poll?.toJson(),
      'voice_note_url': voiceNoteUrl,
      'voice_note_duration': voiceNoteDuration,
      'ai_response': aiResponse,
      'metadata': metadata,
      'clip_data': clipData,
      'is_edited': isEdited,
      'edited_at': editedAt != null
          ? const TimestampConverter().toJson(editedAt!)
          : null,
      'is_deleted': isDeleted,
      'deleted_at': deletedAt != null
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
    try {
      // Handle both camelCase and snake_case column names
      final createdAt = json['createdAt'] ?? json['created_at'];
      final closedAt = json['closedAt'] ?? json['closed_at'];
      final createdBy = json['createdBy'] ?? json['created_by'];
      final isClosed = json['isClosed'] ?? json['is_closed'];

      // Safe votes parsing
      Map<String, List<String>> safeVotes = {};
      final votesRaw = json['votes'];
      if (votesRaw is Map) {
        for (final entry in votesRaw.entries) {
          final key = entry.key.toString();
          if (entry.value is List) {
            safeVotes[key] =
                (entry.value as List).map((e) => e.toString()).toList();
          }
        }
      }

      return Poll(
        id: json['id'] as String? ?? '',
        question: json['question'] as String? ?? '',
        options: (json['options'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        votes: safeVotes,
        createdAt: const TimestampConverter().fromJson(createdAt),
        createdBy: createdBy as String? ?? '',
        isClosed: isClosed as bool?,
        closedAt: closedAt != null
            ? const TimestampConverter().fromJson(closedAt)
            : null,
      );
    } catch (e) {
      debugPrint('❌ Poll.fromJson failed: $e');
      rethrow;
    }
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
