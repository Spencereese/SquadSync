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

/// A non-empty remote page wins over a stale/partial cache row.
List<Message> preferRemoteMessagePage({
  required List<Message> cached,
  required List<Message> remote,
}) {
  if (remote.isNotEmpty) return remote;
  return cached;
}
