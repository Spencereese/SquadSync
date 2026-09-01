import '../domain/entities/message.dart';

/// Messages for the open thread. Prefer the owner (MessageNotifier)
/// map; fall back to ChatNotifier only when the owner has no key yet.
List<Message> messagesForOpenThread({
  required String? threadId,
  required Map<String, List<Message>> ownerMessages,
  Map<String, List<Message>> fallback = const {},
}) {
  if (threadId == null || threadId.isEmpty) return const [];
  if (ownerMessages.containsKey(threadId)) {
    return ownerMessages[threadId]!;
  }
  return fallback[threadId] ?? const [];
}

/// Larger page wins. A 1-row (or smaller) remote never beats a larger cache.
List<Message> preferRemoteMessagePage({
  required List<Message> cached,
  required List<Message> remote,
}) {
  if (remote.length > cached.length) return remote;
  if (cached.length > remote.length) return cached;
  if (remote.isNotEmpty) return remote;
  return cached;
}

/// PostgREST may return `chat_id` as int or String for epoch ids.
bool sameChatId(Object? left, Object? right) {
  if (left == null || right == null) return false;
  return left.toString() == right.toString();
}

/// `is_deleted` is often NULL/0 on older rows. Only explicit true is gone.
bool isLiveChatMessageRow(Map<String, dynamic> row) {
  final deleted = row['is_deleted'];
  if (deleted == true || deleted == 1 || deleted == 'true' || deleted == '1') {
    return false;
  }
  return true;
}
