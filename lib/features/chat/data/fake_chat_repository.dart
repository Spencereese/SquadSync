import 'dart:async';

import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/chat/data/chat_repository.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/domain/message_history.dart';
import 'package:squadsync/features/chat/domain/messenger.dart';
import 'package:squadsync/features/chat/domain/messenger.dart' as board;
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
    this.messengerEnabled = true,
    this.readThroughId,
    List<MessageReaction>? reactions,
    List<MemberRead>? reads,
  }) : _messages = List<ChatMessage>.of(messages ?? const []),
       _unread = unread ?? const UnreadBook(),
       _reactions = List<MessageReaction>.of(reactions ?? const []),
       _reads = List<MemberRead>.of(reads ?? const []);

  final List<ChatMessage> _messages;
  UnreadBook _unread;
  final List<void Function(List<ChatMessage>)> _listeners = [];
  final List<StreamController<List<ChatMessage>>> _watches = [];

  bool fail;
  bool messengerEnabled;
  String? readThroughId;
  final List<MessageReaction> _reactions;
  final List<MemberRead> _reads;
  final Set<String> _typing = {};
  final List<StreamController<Set<String>>> _typingWatches = [];
  final typingSends = <bool>[];
  var typingWatches = 0;
  var messengerLoads = 0;
  final _messengerEvents = StreamController<MessengerEvent>.broadcast();

  /// A stop that arrived after the watch was already closed. That used to
  /// open a channel and leave it.
  var channelsOpenedAfterClose = 0;

  int get openTypingWatches => _typingWatches.length;

  /// When set, [messenger] throws this instead of returning a board.
  Object? messengerFailure;
  Future<void>? holdSends;

  /// Pauses [unread] so a test can deliver a row while reload is waiting.
  Future<void>? holdUnread;

  /// Pauses [newest] so a cold start can show the loading skeleton.
  Future<void>? holdNewest;

  @override
  Future<HistoryPage> newest(String chatId, {int limit = openPageSize}) async {
    final hold = holdNewest;
    if (hold != null) await hold;
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
      replyToId: message.replyToId,
      replyText: message.replyText,
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

  @override
  Future<String?> readThrough(String chatId) async {
    _guard('readThrough');
    return readThroughId;
  }

  @override
  Future<MessengerBoard> messenger(String chatId) async {
    messengerLoads += 1;
    final failure = messengerFailure;
    if (failure != null) throw failure;
    _guard('messenger');
    if (!messengerEnabled) return MessengerBoard.disabled;
    return MessengerBoard(
      enabled: true,
      reactions: List<MessageReaction>.of(_reactions),
      reads: List<MemberRead>.of(_reads),
    );
  }

  @override
  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    _guard('toggleReaction');
    if (!messengerEnabled) return;
    final next = board.toggleReaction(
      _reactions,
      messageId: messageId,
      userId: 'spencer',
      emoji: emoji,
    );
    _reactions
      ..clear()
      ..addAll(next);
  }

  @override
  Future<void> saveReadReceipt({
    required String chatId,
    required String messageId,
    required DateTime readAt,
  }) async {
    _guard('saveReadReceipt');
    if (!messengerEnabled) return;
    _reads.removeWhere((row) => row.userId == 'spencer');
    _reads.add(
      MemberRead(userId: 'spencer', messageId: messageId, readAt: readAt),
    );
  }

  @override
  Stream<MessengerEvent> watchMessenger(String chatId) =>
      _messengerEvents.stream;

  void deliverMessenger(MessengerEvent event) {
    if (!_messengerEvents.isClosed) _messengerEvents.add(event);
  }

  @override
  Stream<Set<String>> watchTyping(String chatId) {
    typingWatches += 1;
    late StreamController<Set<String>> controller;
    controller = StreamController<Set<String>>.broadcast(
      onListen: () {
        if (!controller.isClosed) controller.add(Set<String>.of(_typing));
      },
      onCancel: () => _typingWatches.remove(controller),
    );
    _typingWatches.add(controller);
    return controller.stream;
  }

  @override
  Future<void> setTyping(String chatId, {required bool typing}) async {
    if (_typingWatches.isEmpty) {
      channelsOpenedAfterClose += 1;
      return;
    }
    typingSends.add(typing);
    if (typing) {
      _typing.add('spencer');
    } else {
      _typing.remove('spencer');
    }
    _emitTyping();
  }

  /// Another person's typing broadcast. Not stored.
  void deliverTyping(Set<String> names) {
    _typing
      ..clear()
      ..addAll(names);
    _emitTyping();
  }

  void _emitTyping() {
    final snapshot = Set<String>.of(_typing);
    for (final controller in List<StreamController<Set<String>>>.of(
      _typingWatches,
    )) {
      if (!controller.isClosed) controller.add(snapshot);
    }
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
