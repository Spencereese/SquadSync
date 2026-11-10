import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/chat/data/chat_repository.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/domain/message_history.dart';
import 'package:squadsync/features/chat/domain/messenger.dart';
import 'package:squadsync/features/chat/domain/send_machine.dart';
import 'package:squadsync/features/chat/domain/typing.dart';
import 'package:squadsync/features/chat/domain/unread.dart';
import 'package:squadsync/core/sq8_database.dart';
import 'package:squadsync/features/squad/domain/squad.dart';
import 'package:squadsync/features/squad/ui/squad_setup_screen.dart';

class SquadChatState {
  const SquadChatState({
    this.squad,
    this.meId = 'spencer',
    this.messages = const [],
    this.hasOlder = false,
    this.unread = const UnreadBook(),
    this.readThroughId,
    this.messenger = MessengerBoard.disabled,
    this.messengerError,
    this.typing = const {},
    this.replyToId,
    this.replyText,
    this.error,
    this.linkDown = false,
  });

  final Squad? squad;
  final String meId;
  final List<ChatMessage> messages;
  final bool hasOlder;
  final UnreadBook unread;
  final String? readThroughId;
  final MessengerBoard messenger;

  /// Set when reactions or receipts failed for a reason other than a missing
  /// table. The message list still shows.
  final String? messengerError;
  final Set<String> typing;
  final String? replyToId;
  final String? replyText;
  final String? error;
  final bool linkDown;

  bool get ready => squad != null && error == null;

  SquadChatState copyWith({
    Squad? squad,
    List<ChatMessage>? messages,
    bool? hasOlder,
    UnreadBook? unread,
    String? readThroughId,
    MessengerBoard? messenger,
    String? messengerError,
    bool clearMessengerError = false,
    Set<String>? typing,
    String? replyToId,
    String? replyText,
    bool clearReply = false,
    String? error,
    bool clearError = false,
    bool? linkDown,
  }) {
    return SquadChatState(
      squad: squad ?? this.squad,
      meId: meId,
      messages: messages ?? this.messages,
      hasOlder: hasOlder ?? this.hasOlder,
      unread: unread ?? this.unread,
      readThroughId: readThroughId ?? this.readThroughId,
      messenger: messenger ?? this.messenger,
      messengerError: clearMessengerError
          ? null
          : (messengerError ?? this.messengerError),
      typing: typing ?? this.typing,
      replyToId: clearReply ? null : (replyToId ?? this.replyToId),
      replyText: clearReply ? null : (replyText ?? this.replyText),
      error: clearError ? null : (error ?? this.error),
      linkDown: linkDown ?? this.linkDown,
    );
  }
}

final squadChatControllerProvider =
    NotifierProvider<SquadChatController, SquadChatState>(
      SquadChatController.new,
    );

const removedFromSquadMessage = "You're no longer in this squad";

class RemovedNotice extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String message) => state = message;

  void clear() => state = null;
}

final removedNoticeProvider = NotifierProvider<RemovedNotice, String?>(
  RemovedNotice.new,
);

/// Without a signed-in user the phone acts as the squad owner (the fakes).
class SquadChatController extends Notifier<SquadChatState> {
  StreamSubscription<List<ChatMessage>>? _echo;
  StreamSubscription<RosterSignal>? _roster;
  StreamSubscription<Set<String>>? _typing;
  String? _typingChat;
  final _typingKeys = TypingThrottle();
  var _started = false;
  var _chatVisible = false;
  var _loadingOlder = false;
  var _epoch = 0;

  @override
  SquadChatState build() {
    ref.onDispose(() {
      final echo = _echo;
      _echo = null;
      if (echo != null) unawaited(echo.cancel());
      final roster = _roster;
      _roster = null;
      if (roster != null) unawaited(roster.cancel());
      final typing = _typing;
      _typing = null;
      _typingChat = null;
      if (typing != null) unawaited(typing.cancel());
      _typingKeys.stop();
    });
    return const SquadChatState();
  }

  Future<void> open() async {
    if (_started) return;
    _started = true;
    final squads = ref.read(squadRepositoryProvider);
    final chats = ref.read(chatRepositoryProvider);
    try {
      final squad = await squads.load();
      if (!ref.mounted) return;
      final page = await chats.newest(squad.chatId);
      if (!ref.mounted) return;
      final unread = await chats.unread();
      if (!ref.mounted) return;
      final through = await chats.readThrough(squad.chatId);
      if (!ref.mounted) return;
      final reactions = await _reactions(chats, squad.chatId);
      if (!ref.mounted) return;
      await _listen(chats, squad.chatId);
      final signedIn = ref.read(authRepositoryProvider).currentUser?.id;
      state = SquadChatState(
        squad: squad,
        meId: signedIn == null || signedIn.isEmpty ? squad.ownerId : signedIn,
        messages: page.messages,
        hasOlder: page.hasOlder,
        unread: unread,
        readThroughId: through,
        messenger: reactions.board,
        messengerError: reactions.error,
      );
      await _listenTyping(chats, squad.chatId);
      await _listenRoster();
    } on RepositoryFailure catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(error: error.message);
    }
  }

  void replaceSquad(Squad squad) {
    if (!ref.mounted) return;
    final switched = squad.chatId != state.squad?.chatId;
    if (switched) _epoch++;
    state = switched
        ? SquadChatState(squad: squad, meId: state.meId)
        : state.copyWith(squad: squad);
  }

  /// Drops the in-memory thread so the next sign-in cannot show it.
  void abandon() {
    _epoch++;
    _started = false;
    _loadingOlder = false;
    final echo = _echo;
    _echo = null;
    if (echo != null) unawaited(echo.cancel());
    final roster = _roster;
    _roster = null;
    if (roster != null) unawaited(roster.cancel());
    final typing = _typing;
    _typing = null;
    _typingChat = null;
    if (typing != null) unawaited(typing.cancel());
    if (_typingKeys.stop()) {
      final chatId = state.squad?.chatId;
      if (chatId != null) {
        unawaited(
          ref.read(chatRepositoryProvider).setTyping(chatId, typing: false),
        );
      }
    }
    state = const SquadChatState();
  }

  void setChatVisible(bool visible) {
    _chatVisible = visible;
  }

  void quote(ChatMessage message) {
    if (!ref.mounted) return;
    state = state.copyWith(replyToId: message.id, replyText: message.text);
  }

  void clearQuote() {
    if (!ref.mounted) return;
    state = state.copyWith(clearReply: true);
  }

  Future<void> react(String messageId, String emoji) async {
    final squad = state.squad;
    if (squad == null || !state.messenger.enabled) return;
    final me = state.meId;
    final next = toggleReaction(
      state.messenger.reactions,
      messageId: messageId,
      userId: me,
      emoji: emoji,
    );
    state = state.copyWith(
      messenger: MessengerBoard(
        enabled: true,
        reactions: next,
        reads: state.messenger.reads,
      ),
    );
    await ref
        .read(chatRepositoryProvider)
        .toggleReaction(
          chatId: squad.chatId,
          messageId: messageId,
          emoji: emoji,
        );
  }

  /// The person has seen the thread. The badge for this squad goes to zero.
  Future<void> catchUp() async {
    final squad = state.squad;
    if (squad == null) return;
    final newest = state.messages.isEmpty ? null : state.messages.last;
    final cleared = state.unread.opened(squad.chatId);
    state = state.copyWith(
      unread: cleared,
      readThroughId: newest?.id ?? state.readThroughId,
    );
    await ref.read(chatRepositoryProvider).saveUnread(cleared);
    if (newest != null && state.messenger.enabled) {
      await ref
          .read(chatRepositoryProvider)
          .saveReadReceipt(
            chatId: squad.chatId,
            messageId: newest.id,
            readAt: newest.sentAt,
          );
    }
  }

  Future<void> setTyping(bool typing) async {
    final squad = state.squad;
    if (squad == null) return;
    final chatId = squad.chatId;
    final send = _typingKeys.key(
      typing: typing,
      onIdle: () {
        final current = state.squad?.chatId;
        if (current == null) return;
        unawaited(
          ref.read(chatRepositoryProvider).setTyping(current, typing: false),
        );
      },
    );
    if (send == null) return;
    await ref.read(chatRepositoryProvider).setTyping(chatId, typing: send);
  }

  Future<void> loadOlder() async {
    final current = state;
    final squad = current.squad;
    if (_loadingOlder ||
        squad == null ||
        !current.hasOlder ||
        current.messages.isEmpty) {
      return;
    }
    _loadingOlder = true;
    try {
      final page = await ref
          .read(chatRepositoryProvider)
          .before(squad.chatId, cursor: current.messages.first);
      if (!ref.mounted) return;
      final stitched = stitchOlder(
        loaded: state.messages,
        fetched: page.messages,
        limit: olderPageSize,
      );
      state = state.copyWith(
        messages: stitched.messages,
        hasOlder: page.hasOlder,
        clearError: true,
      );
    } on RepositoryFailure catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(error: error.message);
    } finally {
      _loadingOlder = false;
    }
  }

  /// Reloads the member list and the newest messages. Safe when realtime is off.
  Future<void> refreshFromRoster() => reload();

  /// Re-reads membership, then the newest page. A missing seat leaves the squad.
  /// Local failed rows stay, and a row the server already has is not duplicated.
  Future<void> reload() async {
    if (!await _confirmSeat()) return;
    final current = state;
    final squad = current.squad;
    if (squad == null) return;
    final chats = ref.read(chatRepositoryProvider);
    final epoch = _epoch;
    final chatId = squad.chatId;
    try {
      final page = await chats.newest(chatId);
      if (!_reloadCurrent(epoch, chatId)) return;
      final unread = await chats.unread();
      if (!_reloadCurrent(epoch, chatId)) return;
      final through = await chats.readThrough(chatId);
      if (!_reloadCurrent(epoch, chatId)) return;
      final reactions = await _reactions(chats, chatId);
      if (!_reloadCurrent(epoch, chatId)) return;
      await _listen(chats, chatId);
      if (!_reloadCurrent(epoch, chatId)) return;
      await _listenRoster();
      if (!_reloadCurrent(epoch, chatId)) return;
      await _listenTyping(chats, chatId);
      if (!_reloadCurrent(epoch, chatId)) return;
      // Merge after the awaits so a row that arrived while they ran stays.
      final merged = ChatThread(state.messages)
          .mergeEcho(page.messages, meId: state.meId);
      state = state.copyWith(
        messages: merged.messages,
        hasOlder: page.hasOlder,
        unread: unread,
        readThroughId: through,
        messenger: reactions.board,
        messengerError: reactions.error,
        clearMessengerError: reactions.error == null,
        linkDown: false,
        clearError: true,
      );
    } on RepositoryFailure catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(error: error.message, linkDown: true);
    }
  }

  Future<void> send(String text) async {
    final body = text.trim();
    final current = state;
    final squad = current.squad;
    if (body.isEmpty || squad == null) return;
    final id = ref.read(clientIdFactoryProvider).create();
    final outgoing = ChatMessage(
      id: id,
      chatId: squad.chatId,
      senderId: current.meId,
      text: body,
      sentAt: DateTime.now().toUtc(),
      delivery: Delivery.sending,
      replyToId: current.replyToId,
      replyText: current.replyText,
    );
    state = current.copyWith(
      messages: ChatThread(current.messages).start(outgoing).messages,
      clearReply: true,
    );
    unawaited(setTyping(false));
    await _finish(id, outgoing);
  }

  Future<void> retry(String clientId) async {
    final current = state;
    final message = _byId(current.messages, clientId);
    if (message == null || message.delivery != Delivery.failed) return;
    state = current.copyWith(
      messages: ChatThread(current.messages).retry(clientId).messages,
    );
    await _finish(clientId, message);
  }

  Future<void> _finish(String clientId, ChatMessage message) async {
    final SendOutcome outcome;
    try {
      outcome = await ref.read(chatRepositoryProvider).send(message);
    } on RepositoryFailure {
      if (!ref.mounted) return;
      state = state.copyWith(
        messages: ChatThread(state.messages)
            .apply(clientId, const SendFailed())
            .messages,
      );
      return;
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      messages: ChatThread(state.messages).apply(clientId, outcome).messages,
    );
  }

  bool _reloadCurrent(int epoch, String chatId) {
    return ref.mounted && epoch == _epoch && state.squad?.chatId == chatId;
  }

  /// False when this person is no longer a member. A failed read stays put.
  Future<bool> _confirmSeat() async {
    if (state.squad == null) return false;
    final Squad? squad;
    try {
      squad = await ref.read(squadRepositoryProvider).findMine();
    } on RepositoryFailure catch (error) {
      if (!ref.mounted) return false;
      state = state.copyWith(error: error.message, linkDown: true);
      return false;
    }
    if (!ref.mounted || state.squad == null) return false;
    if (squad == null) {
      _leaveSquad();
      return false;
    }
    replaceSquad(squad);
    return true;
  }

  void _leaveSquad() {
    abandon();
    ref.read(removedNoticeProvider.notifier).show(removedFromSquadMessage);
    ref.read(accountRevisionProvider.notifier).bump();
  }

  Future<void> _listenRoster() async {
    final squad = state.squad;
    if (squad == null) {
      final previous = _roster;
      _roster = null;
      if (previous != null) unawaited(previous.cancel());
      return;
    }
    // Subscribe before cancel so a roster event is not dropped while the
    // previous channel's cancel future is still running.
    final previous = _roster;
    _roster = ref
        .read(squadRepositoryProvider)
        .watchRoster(squadId: squad.id, userId: state.meId)
        .listen((_) => unawaited(refreshFromRoster()));
    if (previous != null) unawaited(previous.cancel());
  }

  Future<void> _listen(ChatRepository chats, String chatId) async {
    final previous = _echo;
    _echo = chats.watch(chatId).listen(_onEcho, onError: _onLinkDown);
    if (previous != null) unawaited(previous.cancel());
  }

  void _onLinkDown(Object error, StackTrace stack) {
    if (!ref.mounted) return;
    state = state.copyWith(linkDown: true);
    unawaited(_confirmSeat());
  }

  Future<({MessengerBoard board, String? error})> _reactions(
    ChatRepository chats,
    String chatId,
  ) async {
    try {
      return (board: await chats.messenger(chatId), error: null);
    } on RepositoryFailure catch (error) {
      return (
        board: MessengerBoard.disabled,
        error: 'Reactions and read receipts are unavailable. ${error.message}',
      );
    }
  }

  Future<void> _listenTyping(ChatRepository chats, String chatId) async {
    if (_typingChat == chatId && _typing != null) return;
    final next = chats.watchTyping(chatId).listen((ids) {
      if (!ref.mounted) return;
      state = state.copyWith(typing: ids);
    });
    final previous = _typing;
    _typing = next;
    _typingChat = chatId;
    if (previous != null) unawaited(previous.cancel());
  }

  void _onEcho(List<ChatMessage> remote) {
    if (!ref.mounted || state.squad == null) return;
    final known = {for (final message in state.messages) message.id};
    final arrivals = [
      for (final message in remote)
        if (!known.contains(message.id)) message.senderId,
    ];
    var unread = state.unread;
    if (!_chatVisible) {
      final added = unreadArrivals(
        senderIds: arrivals,
        currentUserId: state.meId,
        chatIsOpen: false,
      );
      if (added > 0) unread = unread.add(state.squad!.chatId, added);
    }
    state = state.copyWith(
      linkDown: false,
      unread: unread,
      messages: ChatThread(state.messages)
          .mergeEcho(remote, meId: state.meId)
          .messages,
    );
  }
}

ChatMessage? _byId(List<ChatMessage> messages, String id) {
  for (final message in messages) {
    if (message.id == id) return message;
  }
  return null;
}
