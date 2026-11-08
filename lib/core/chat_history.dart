import '../domain/entities/message.dart';
import 'chat_send.dart';

/// First screen of a thread. Long groups were opening on the oldest page
/// because the query was `order ascending` + `limit`.
const int kOpenChatPageSize = 100;

/// Older history pulled in when the user scrolls up.
const int kOlderChatPageSize = 50;

/// True when [message] sits strictly before [cursor] in (timestamp, id) order.
bool isStrictlyOlder(Message message, Message cursor) {
  final byTime = message.timestamp.compareTo(cursor.timestamp);
  if (byTime < 0) return true;
  if (byTime > 0) return false;
  return message.id.compareTo(cursor.id) < 0;
}

/// Newest [limit] rows, oldest-of-that-page first so a reversed list can
/// pin offset 0 on the newest message.
List<Message> newestHistoryPage(List<Message> messages, {required int limit}) {
  final ordered = sortThread(messages);
  if (ordered.length <= limit) return ordered;
  return ordered.sublist(ordered.length - limit);
}

/// The page immediately before [cursor]. No overlap with the cursor row,
/// and no gap: the newest row left out is the one just older than [cursor].
List<Message> olderHistoryPage(
  List<Message> messages, {
  required Message cursor,
  required int limit,
}) {
  final older = sortThread(messages).where((m) => isStrictlyOlder(m, cursor));
  final ordered = older.toList();
  if (ordered.length <= limit) return ordered;
  return ordered.sublist(ordered.length - limit);
}

/// Trim a server window (same-timestamp siblings plus strictly earlier
/// rows) down to the single older page that belongs under [before]/[beforeId].
List<Message> takeOlderWindow({
  required List<Message> candidates,
  required DateTime before,
  required String beforeId,
  required int limit,
}) {
  final cursor = Message(
    id: beforeId,
    senderId: '',
    text: '',
    timestamp: before,
    messageType: MessageType.text,
  );
  return olderHistoryPage(candidates, cursor: cursor, limit: limit);
}

class HistoryStitch {
  const HistoryStitch({
    required this.messages,
    required this.added,
    required this.hasMore,
  });

  final List<Message> messages;
  final int added;
  final bool hasMore;
}

/// Drop ids already on screen, keep chronological order. [hasMore] is false
/// when the fetch was short or added nothing, so the next scroll does not
/// invent an empty page.
HistoryStitch stitchOlderPage({
  required List<Message> loaded,
  required List<Message> fetched,
  required int limit,
}) {
  final ids = loaded.map((m) => m.id).toSet();
  final fresh = <Message>[];
  for (final message in fetched) {
    if (message.id.isEmpty || !ids.add(message.id)) continue;
    fresh.add(message);
  }
  return HistoryStitch(
    messages: sortThread([...loaded, ...fresh]),
    added: fresh.length,
    hasMore: fresh.isNotEmpty && fetched.length >= limit,
  );
}

/// Opening a thread shows the newest remote page. A longer cache of older
/// rows must not win. A 1-row remote (the broken timestamp read) still
/// loses to a larger cache.
List<Message> openChatPage({
  required List<Message> cached,
  required List<Message> remote,
}) {
  if (remote.isEmpty) return sortThread(cached);
  if (remote.length <= 1 && cached.length > remote.length) {
    return sortThread(cached);
  }
  return sortThread(remote);
}

/// An older page is the remote window. Cache is only the offline fallback.
List<Message> olderChatPage({
  required List<Message> cached,
  required List<Message> remote,
  required bool remoteFailed,
}) {
  if (remoteFailed) return sortThread(cached);
  return sortThread(remote);
}
