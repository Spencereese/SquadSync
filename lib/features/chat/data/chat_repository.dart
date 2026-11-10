import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/domain/message_history.dart';
import 'package:squadsync/features/chat/domain/messenger.dart';
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

  /// The message the unread cursor has reached, when one is stored.
  Future<String?> readThrough(String chatId);

  /// Reactions and shared receipts. Disabled, and empty, when file 0014
  /// is not on the database. A missing table is not an error.
  Future<MessengerBoard> messenger(String chatId);

  /// Adds the emoji, or removes it when this person already used it.
  /// Does nothing when [messenger] is disabled.
  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  });

  /// Writes this person's shared cursor. Does nothing when file 0014 is absent.
  /// The private unread cursor is still [saveUnread].
  Future<void> saveReadReceipt({
    required String chatId,
    required String messageId,
    required DateTime readAt,
  });

  /// Reactions and receipts. Inserts and updates are for this squad.
  /// Deletes are not filtered; the caller drops ones it does not know.
  Stream<MessengerEvent> watchMessenger(String chatId);

  /// Broadcast only. There is no typing table.
  Stream<Set<String>> watchTyping(String chatId);

  Future<void> setTyping(String chatId, {required bool typing});
}

/// What file 0014 returned. [enabled] is false when those tables are absent.
class MessengerBoard {
  const MessengerBoard({
    this.enabled = false,
    this.reactions = const [],
    this.reads = const [],
  });

  final bool enabled;
  final List<MessageReaction> reactions;
  final List<MemberRead> reads;

  static const disabled = MessengerBoard();
}
