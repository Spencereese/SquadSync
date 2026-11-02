import 'package:squadsync/features/chat/domain/chat_message.dart';

/// First screen of a thread. Newest window, not the oldest.
const int openPageSize = 40;

/// Older history pulled in above the rows already on screen.
const int olderPageSize = 20;

class HistoryPage {
  const HistoryPage({required this.messages, required this.hasOlder});

  /// Oldest of this window first, newest last.
  final List<ChatMessage> messages;
  final bool hasOlder;
}

/// True when [message] sits strictly before [cursor] in (sentAt, id) order.
bool isStrictlyOlder(ChatMessage message, ChatMessage cursor) {
  final byTime = message.sentAt.compareTo(cursor.sentAt);
  if (byTime < 0) return true;
  if (byTime > 0) return false;
  return message.id.compareTo(cursor.id) < 0;
}

HistoryPage newestPage(List<ChatMessage> all, {int limit = openPageSize}) {
  if (limit <= 0) {
    throw ArgumentError.value(limit, 'limit', 'must be positive');
  }
  final ordered = sortedThread(all);
  if (ordered.length <= limit) {
    return HistoryPage(messages: ordered, hasOlder: false);
  }
  return HistoryPage(
    messages: ordered.sublist(ordered.length - limit),
    hasOlder: true,
  );
}

/// The page immediately before [cursor]. The cursor row is not included.
/// Nothing between the cursor and this page is skipped.
HistoryPage olderPage(
  List<ChatMessage> all, {
  required ChatMessage cursor,
  int limit = olderPageSize,
}) {
  if (limit <= 0) {
    throw ArgumentError.value(limit, 'limit', 'must be positive');
  }
  final older = sortedThread(all)
      .where((message) => isStrictlyOlder(message, cursor))
      .toList();
  if (older.length <= limit) {
    return HistoryPage(messages: older, hasOlder: false);
  }
  return HistoryPage(
    messages: older.sublist(older.length - limit),
    hasOlder: true,
  );
}

/// Drop ids already on screen. [hasOlder] is false when the fetch was short
/// or added nothing, so the next scroll does not invent an empty page.
HistoryPage stitchOlder({
  required List<ChatMessage> loaded,
  required List<ChatMessage> fetched,
  required int limit,
}) {
  final ids = <String>{for (final message in loaded) message.id};
  final fresh = <ChatMessage>[];
  for (final message in fetched) {
    if (message.id.isEmpty || !ids.add(message.id)) continue;
    fresh.add(message);
  }
  return HistoryPage(
    messages: sortedThread([...loaded, ...fresh]),
    hasOlder: fresh.isNotEmpty && fetched.length >= limit,
  );
}
