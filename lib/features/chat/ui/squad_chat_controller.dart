import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/core/repository_failure.dart';
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
  });

  final Squad? squad;
  final String meId;
  final List<ChatMessage> messages;
  final bool hasOlder;
  final UnreadBook unread;
  final String? error;

  bool get ready => squad != null && error == null;

  SquadChatState copyWith({
    Squad? squad,
    List<ChatMessage>? messages,
    bool? hasOlder,
    UnreadBook? unread,
    String? error,
  }) {
    return SquadChatState(
      squad: squad ?? this.squad,
      meId: meId,
      messages: messages ?? this.messages,
      hasOlder: hasOlder ?? this.hasOlder,
      unread: unread ?? this.unread,
      error: error ?? this.error,
    );
  }
}

final squadChatControllerProvider =
    NotifierProvider<SquadChatController, SquadChatState>(
      SquadChatController.new,
    );

/// No auth in this slice. The phone user is the squad owner.
class SquadChatController extends Notifier<SquadChatState> {
  StreamSubscription<List<ChatMessage>>? _echo;
  var _started = false;

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
      await _echo?.cancel();
      _echo = chats.watch(squad.chatId).listen(_onEcho);
      state = SquadChatState(
        squad: squad,
        meId: squad.ownerId,
        messages: page.messages,
        hasOlder: page.hasOlder,
        unread: cleared,
      );
    } on RepositoryFailure catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(error: error.message);
    }
  }

  Future<void> loadOlder() async {
    final current = state;
    final squad = current.squad;
    if (squad == null || !current.hasOlder || current.messages.isEmpty) {
      return;
    }
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
    );
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

  void _onEcho(List<ChatMessage> remote) {
    if (!ref.mounted || state.squad == null) return;
    state = state.copyWith(
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
