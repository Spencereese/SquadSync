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

/// A larger remote page always wins. A 1-row cache never beats remote.
List<Message> preferRemoteMessagePage({
  required List<Message> cached,
  required List<Message> remote,
}) {
  if (remote.length > cached.length) return remote;
  if (cached.length <= 1 && remote.isNotEmpty) return remote;
  if (remote.isNotEmpty) return remote;
  return cached;
}

/// `is_deleted` is often NULL/0 on older rows. Only explicit true is gone.
bool isLiveChatMessageRow(Map<String, dynamic> row) {
  final deleted = row['is_deleted'];
  if (deleted == true || deleted == 1 || deleted == 'true' || deleted == '1') {
    return false;
  }
  return true;
}
