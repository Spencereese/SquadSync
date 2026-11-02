import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/domain/message_history.dart';
import 'package:squadsync/features/chat/domain/send_machine.dart';
import 'package:squadsync/features/chat/domain/unread.dart';

abstract class ChatRepository {
  Future<HistoryPage> newest(String chatId, {int limit = openPageSize});

  Future<HistoryPage> before(
    String chatId, {
    required ChatMessage cursor,
    int limit = olderPageSize,
  });

  /// Resolves when the row is stored. A duplicate id comes back as
  /// [SendConflict], which the send machine treats as sent.
  Future<SendOutcome> send(ChatMessage message);

  /// Changed rows only, not the whole history. An event whose id matches
  /// a local bubble is the realtime echo.
  Stream<List<ChatMessage>> watch(String chatId);

  Future<UnreadBook> unread();

  Future<void> saveUnread(UnreadBook book);
}
