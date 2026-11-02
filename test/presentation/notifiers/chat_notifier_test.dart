import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/chat_state.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/presentation/notifiers/chat_notifier.dart';
import 'package:squad_sync/presentation/notifiers/message_notifier.dart';

Message _msg(String id) => Message(
      id: id,
      senderId: 'me',
      text: id,
      timestamp: DateTime.utc(2026, 4, 1),
      messageType: MessageType.text,
    );

void main() {
  test('ChatNotifier copies the owner thread and leaves other groups', () {
    final chat = ChatState.initial().copyWith(
      chatMessages: {
        'other': [_msg('keep')],
      },
      unreadCounts: const {'group-1': 3, 'other': 1},
    );
    final owner = MessageState(
      messages: {
        'group-1': [_msg('a'), _msg('b')],
      },
      reactions: const {},
      typingUsers: const {},
      lastSyncTimestamps: const {},
    );

    final next = applyMessageStateToChatState(chat, owner);

    expect(next.chatMessages['group-1']!.map((m) => m.id), ['a', 'b']);
    expect(next.unreadCounts, {'group-1': 3, 'other': 1});
  });

  test('syncing the same message instances still publishes that thread', () {
    final messages = {
      'group-1': [_msg('a')],
    };
    final chat = ChatState.initial().copyWith(chatMessages: messages);
    final owner = MessageState(
      messages: chat.chatMessages,
      reactions: const {},
      typingUsers: chat.typingIndicators,
      lastSyncTimestamps: const {},
    );

    final next = applyMessageStateToChatState(chat, owner);
    expect(next.chatMessages['group-1']!.single.id, 'a');
  });
}
