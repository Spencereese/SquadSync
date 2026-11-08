import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/chat/data/chat_repository.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/domain/message_history.dart';
import 'package:squadsync/features/chat/domain/send_machine.dart';
import 'package:squadsync/features/chat/domain/unread.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

class SquadChatState {
  const SquadChatState({
    this.squad,
    this.meId = 'spencer',
    this.messages = const [],
    this.hasOlder = false,
    this.unread = const UnreadBook(),
    this.error,
    this.linkDown = false,
  });

  final Squad? squad;
  final String meId;
  final List<ChatMessage> messages;
  final bool hasOlder;
  final UnreadBook unread;
  final String? error;
  final bool linkDown;

  bool get ready => squad != null && error == null;

  SquadChatState copyWith({
    Squad? squad,
    List<ChatMessage>? messages,
    bool? hasOlder,
    UnreadBook? unread,
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
      error: clearError ? null : (error ?? this.error),
      linkDown: linkDown ?? this.linkDown,
    );
  }
}

final squadChatControllerProvider =
    NotifierProvider<SquadChatController, SquadChatState>(
      SquadChatController.new,
    );

/// Without a signed-in user the phone acts as the squad owner (the fakes).
class SquadChatController extends Notifier<SquadChatState> {
  StreamSubscription<List<ChatMessage>>? _echo;
  var _started = false;
  var _loadingOlder = false;
  var _epoch = 0;

  @override
  SquadChatState build() {
    ref.onDispose(() {
      final echo = _echo;
      _echo = null;
      if (echo != null) unawaited(echo.cancel());
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
      final cleared = unread.opened(squad.chatId);
      await chats.saveUnread(cleared);
      if (!ref.mounted) return;
      await _listen(chats, squad.chatId);
      final signedIn = ref.read(authRepositoryProvider).currentUser?.id;
      state = SquadChatState(
        squad: squad,
        meId: signedIn == null || signedIn.isEmpty ? squad.ownerId : signedIn,
        messages: page.messages,
        hasOlder: page.hasOlder,
        unread: cleared,
      );
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
    state = const SquadChatState();
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

  /// Refetches the newest page and subscribes again. Local failed rows stay,
  /// and a row the server already has is not duplicated.
  Future<void> reload() async {
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
      final cleared = unread.opened(chatId);
      await chats.saveUnread(cleared);
      if (!_reloadCurrent(epoch, chatId)) return;
      await _listen(chats, chatId);
      if (!_reloadCurrent(epoch, chatId)) return;
      // Merge after the awaits so a row that arrived while they ran stays.
      final merged = ChatThread(state.messages)
          .mergeEcho(page.messages, meId: state.meId);
      state = state.copyWith(
        messages: merged.messages,
        hasOlder: page.hasOlder,
        unread: cleared,
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
    );
    state = current.copyWith(
      messages: ChatThread(current.messages).start(outgoing).messages,
    );
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

  Future<void> _listen(ChatRepository chats, String chatId) async {
    await _echo?.cancel();
    _echo = chats.watch(chatId).listen(_onEcho, onError: _onLinkDown);
  }

  void _onLinkDown(Object error, StackTrace stack) {
    if (!ref.mounted) return;
    state = state.copyWith(linkDown: true);
  }

  void _onEcho(List<ChatMessage> remote) {
    if (!ref.mounted || state.squad == null) return;
    state = state.copyWith(
      linkDown: false,
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
