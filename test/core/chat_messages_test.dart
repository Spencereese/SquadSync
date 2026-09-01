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

  test('larger remote page wins over a smaller cache', () {
    final cached = [_msg('c1')];
    final remote = List.generate(22, (i) => _msg('r$i'));
    expect(
      preferRemoteMessagePage(cached: cached, remote: remote),
      hasLength(22),
    );
  });

  test('larger cache wins over a 1-row remote', () {
    final cached = List.generate(22, (i) => _msg('c$i'));
    final remote = [_msg('only-remote')];
    expect(
      preferRemoteMessagePage(cached: cached, remote: remote),
      hasLength(22),
    );
  });

  test('preferRemoteMessagePage does not prefer a smaller remote', () {
    expect(
      preferRemoteMessagePage(
        cached: [_msg('a'), _msg('b'), _msg('c')],
        remote: [_msg('1'), _msg('2')],
      ),
      hasLength(3),
    );
    expect(
      preferRemoteMessagePage(
        cached: [_msg('a'), _msg('b')],
        remote: [_msg('1')],
      ),
      hasLength(2),
    );
  });

  test('sameChatId matches epoch string vs int', () {
    expect(sameChatId('1766267555951', 1766267555951), isTrue);
    expect(sameChatId('1766267555951', '1766267555951'), isTrue);
    expect(sameChatId('1766267555951', 'other'), isFalse);
    expect(sameChatId(null, '1766267555951'), isFalse);
  });

  test('Message.fromJson accepts integer is_deleted', () {
    final live = Message.fromJson({
      'id': 'm1',
      'sender_id': 'u1',
      'text': 'hello',
      'timestamp': '2026-01-01T00:00:00Z',
      'message_type': 'text',
      'is_deleted': 0,
    });
    expect(live.isDeleted, isFalse);
    final gone = Message.fromJson({
      'id': 'm2',
      'sender_id': 'u1',
      'text': 'bye',
      'timestamp': '2026-01-01T00:00:00Z',
      'message_type': 'text',
      'is_deleted': 1,
    });
    expect(gone.isDeleted, isTrue);
  });

  test('isLiveChatMessageRow treats null/0/false as live', () {
    expect(isLiveChatMessageRow({}), isTrue);
    expect(isLiveChatMessageRow({'is_deleted': null}), isTrue);
    expect(isLiveChatMessageRow({'is_deleted': 0}), isTrue);
    expect(isLiveChatMessageRow({'is_deleted': false}), isTrue);
    expect(isLiveChatMessageRow({'is_deleted': true}), isFalse);
    expect(isLiveChatMessageRow({'is_deleted': 1}), isFalse);
    expect(isLiveChatMessageRow({'is_deleted': 'true'}), isFalse);
  });
}
