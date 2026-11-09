import 'dart:async';

import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/chat/data/chat_repository.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/domain/message_history.dart';
import 'package:squadsync/features/chat/domain/send_machine.dart';
import 'package:squadsync/features/chat/domain/unread.dart';

/// In-memory chat. Set [fail] and calls throw without storing a row.
/// Set [holdSends] to pause [send] so a test can see the clock.
class FakeChatRepository implements ChatRepository {
  FakeChatRepository({
    List<ChatMessage>? messages,
    UnreadBook? unread,
    this.fail = false,
    this.holdSends,
    this.holdUnread,
  }) : _messages = List<ChatMessage>.of(messages ?? const []),
       _unread = unread ?? const UnreadBook();

  final List<ChatMessage> _messages;
  UnreadBook _unread;
  final List<void Function(List<ChatMessage>)> _listeners = [];
  final List<StreamController<List<ChatMessage>>> _watches = [];

  bool fail;
  Future<void>? holdSends;

  /// Pauses [unread] so a test can deliver a row while reload is waiting.
  Future<void>? holdUnread;

  @override
  Future<HistoryPage> newest(String chatId, {int limit = openPageSize}) async {
    _guard('newest');
    return newestPage(_for(chatId), limit: limit);
  }

  @override
  Future<HistoryPage> before(
    String chatId, {
    required ChatMessage cursor,
    int limit = olderPageSize,
  }) async {
    _guard('before');
    return olderPage(_for(chatId), cursor: cursor, limit: limit);
  }

  @override
  Future<SendOutcome> send(ChatMessage message) async {
    final hold = holdSends;
    if (hold != null) await hold;
    _guard('send');
    if (message.id.isEmpty) return const SendFailed();
    if (_messages.any((stored) => stored.id == message.id)) {
      return SendConflict(message.id);
    }
    final stored = ChatMessage(
      id: message.id,
      chatId: message.chatId,
      senderId: message.senderId,
      text: message.text,
      sentAt: message.sentAt,
      delivery: Delivery.sent,
    );
    _messages.add(stored);
    _emit([stored]);
    return SendConfirmed(message.id);
  }

  /// Records a row without an echo. Used when a response was lost and the
  /// next send of that id should come back as a conflict.
  void storeQuietly(ChatMessage message) {
    if (message.id.isEmpty) return;
    if (_messages.any((stored) => stored.id == message.id)) return;
    _messages.add(message);
  }

  /// Pushes a server row the client did not just send. Same id as a local
  /// bubble is the realtime echo.
  void deliver(ChatMessage message) {
    _guard('deliver');
    if (_messages.any((stored) => stored.id == message.id)) return;
    _messages.add(message);
    _emit([message]);
  }

  /// Notifies listeners about an id that is already stored. Does not add a row.
  void replay(ChatMessage message) {
    _emit([message]);
  }

  @override
  Stream<List<ChatMessage>> watch(String chatId) {
    late StreamController<List<ChatMessage>> controller;
    void onRows(List<ChatMessage> rows) {
      final matched = <ChatMessage>[
        for (final row in rows)
          if (row.chatId == chatId) row,
      ];
      if (matched.isNotEmpty && !controller.isClosed) {
        controller.add(matched);
      }
    }

    controller = StreamController<List<ChatMessage>>.broadcast(
      sync: true,
      onListen: () => _listeners.add(onRows),
      onCancel: () {
        _listeners.remove(onRows);
        _watches.remove(controller);
      },
    );
    _watches.add(controller);
    return controller.stream;
  }

  /// The live channel failed. Does not remove stored rows.
  void dropLink() {
    for (final controller in List<StreamController<List<ChatMessage>>>.of(
      _watches,
    )) {
      if (!controller.isClosed) {
        controller.addError(StateError('live updates stopped'));
      }
    }
  }

  @override
  Future<UnreadBook> unread() async {
    final hold = holdUnread;
    if (hold != null) await hold;
    _guard('unread');
    return _unread;
  }

  @override
  Future<void> saveUnread(UnreadBook book) async {
    _guard('saveUnread');
    _unread = book;
  }

  List<ChatMessage> get rows => List.unmodifiable(_messages);

  List<ChatMessage> _for(String chatId) {
    return [
      for (final message in _messages)
        if (message.chatId == chatId) message,
    ];
  }

  void _emit(List<ChatMessage> rows) {
    final snapshot = List<ChatMessage>.unmodifiable(rows);
    for (final listener in List<void Function(List<ChatMessage>)>.of(
      _listeners,
    )) {
      listener(snapshot);
    }
  }

  void _guard(String operation) {
    if (fail) throw RepositoryFailure('chat $operation failed');
  }
}
