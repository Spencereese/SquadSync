import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_metadata.freezed.dart';
part 'chat_metadata.g.dart';

/// **Chat Metadata Entity**
///
/// Stores chat context information:
/// - Last message timestamp
/// - Unread counts per user
/// - Typing indicators
/// - Read receipts
@freezed
class ChatMetadata with _$ChatMetadata {
  const factory ChatMetadata({
    required String chatId,
    @Default(0) int lastMessageTimestamp,
    @Default({}) Map<String, int> unreadCounts, // userId -> count
    @Default([]) List<String> typingUsers,
    @Default({}) Map<String, String> lastReadMessageId, // userId -> messageId
    DateTime? updatedAt,
  }) = _ChatMetadata;

  factory ChatMetadata.fromJson(Map<String, dynamic> json) =>
      _$ChatMetadataFromJson(json);
}
