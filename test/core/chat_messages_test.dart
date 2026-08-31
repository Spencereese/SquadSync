import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/chat_messages.dart';
import 'package:squad_sync/domain/entities/message.dart';

Message _msg(String id) => Message(
      id: id,
      senderId: 'u1',
      text: 't$id',
      timestamp: DateTime.utc(2026, 1, 1),
      messageType: MessageType.text,
    );

void main() {
  test('ChatScreen uses owner messages when the owner has the thread', () {
    final owner = {
      'thread-1': [_msg('a'), _msg('b'), _msg('c')],
    };
    final fallback = {
      'thread-1': [_msg('stale')],
    };

    final messages = messagesForOpenThread(
      threadId: 'thread-1',
      ownerMessages: owner,
      fallback: fallback,
    );

    expect(messages, hasLength(3));
    expect(messages.map((m) => m.id), ['a', 'b', 'c']);
  });

  test('falls back to ChatNotifier only when owner has no key', () {
    final messages = messagesForOpenThread(
      threadId: 'thread-1',
      ownerMessages: const {},
      fallback: {
        'thread-1': [_msg('cached')],
      },
    );
    expect(messages, hasLength(1));
    expect(messages.single.id, 'cached');
  });

  test('remote page wins over a 1-row cache', () {
    final cached = [_msg('only-cache')];
    final remote = [_msg('1'), _msg('2'), _msg('3')];
    expect(
      preferRemoteMessagePage(cached: cached, remote: remote),
      hasLength(3),
    );
    expect(
      preferRemoteMessagePage(cached: cached, remote: const []),
      hasLength(1),
    );
  });
}
