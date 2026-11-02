import 'package:squadsync/core/sq8_database.dart';
import 'package:squadsync/features/chat/data/chat_repository.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/domain/message_history.dart';
import 'package:squadsync/features/chat/domain/send_machine.dart';
import 'package:squadsync/features/chat/domain/unread.dart';

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._db);

  final Sq8Database _db;

  @override
  Future<HistoryPage> newest(String chatId, {int limit = openPageSize}) async {
    final rows = await _db.newestMessages(chatId, limit: limit + 1);
    return _page(rows, limit);
  }

  @override
  Future<HistoryPage> before(
    String chatId, {
    required ChatMessage cursor,
    int limit = olderPageSize,
  }) async {
    final rows = await _db.olderMessages(
      chatId,
      before: cursor.sentAt,
      beforeId: cursor.id,
      limit: limit + 1,
    );
    return _page(rows, limit);
  }

  @override
  Future<SendOutcome> send(ChatMessage message) async {
    try {
      await _db.insertMessage(
        Sq8Message(
          id: message.id,
          squadId: message.chatId,
          senderId: message.senderId,
          body: message.text,
          sentAt: message.sentAt,
        ),
      );
    } on Sq8DuplicateRow {
      return SendConflict(message.id);
    }
    return SendConfirmed(message.id);
  }

  @override
  Stream<List<ChatMessage>> watch(String chatId) {
    return _db.watchInserts(chatId).map((row) => [_toMessage(row)]);
  }

  @override
  Future<UnreadBook> unread() async {
    final squadId = await _db.mySquadId();
    if (squadId == null) return const UnreadBook();
    final cursor = await _db.readCursor(squadId);
    final count = await _db.unreadCount(squadId, cursor);
    return UnreadBook({squadId: count});
  }

  @override
  Future<void> saveUnread(UnreadBook book) async {
    final squadId = await _db.mySquadId();
    if (squadId == null || !book.counts.containsKey(squadId)) return;
    if (book.of(squadId) != 0) return;
    final latest = await _db.newestMessages(squadId, limit: 1);
    final message = latest.isEmpty ? null : latest.first;
    await _db.upsertCursor(
      squadId: squadId,
      lastReadAt: message?.sentAt ?? DateTime.now().toUtc(),
      lastReadId: message?.id,
    );
  }

  HistoryPage _page(List<Sq8Message> newestFirst, int limit) {
    final hasOlder = newestFirst.length > limit;
    final window = newestFirst.take(limit).toList().reversed;
    return HistoryPage(
      messages: [for (final row in window) _toMessage(row)],
      hasOlder: hasOlder,
    );
  }

  ChatMessage _toMessage(Sq8Message row) {
    final mine = row.senderId == _db.userId;
    return ChatMessage(
      id: row.id,
      chatId: row.squadId,
      senderId: row.senderId,
      text: row.body,
      sentAt: row.sentAt,
      delivery: mine ? Delivery.sent : null,
    );
  }
}
