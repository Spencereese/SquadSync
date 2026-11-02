import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/chat/data/fake_chat_repository.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/domain/message_history.dart';
import 'package:squadsync/features/chat/domain/send_machine.dart';
import 'package:squadsync/features/chat/domain/unread.dart';

ChatMessage _message(String id, int second, {String text = 'hi'}) {
  return ChatMessage(
    id: id,
    chatId: 'squad',
    senderId: 'spencer',
    text: text,
    sentAt: DateTime.utc(2026, 1, 1, 0, 0, second),
    delivery: Delivery.sending,
  );
}

void main() {
  test('the failure toggle rejects a send and stores nothing', () async {
    final repo = FakeChatRepository(fail: true);
    final message = _message('client-1', 1, text: 'hello');

    await expectLater(repo.send(message), throwsA(isA<RepositoryFailure>()));
    expect(repo.newest('squad'), throwsA(isA<RepositoryFailure>()));

    repo.fail = false;
    final page = await repo.newest('squad');
    expect(page.messages, isEmpty);

    final stored = await repo.send(message);
    expect(stored, isA<SendConfirmed>());
    expect((await repo.newest('squad')).messages.single.text, 'hello');
  });

  test('sending the same id twice is one row and a conflict', () async {
    final repo = FakeChatRepository();
    final message = _message('client-1', 4, text: 'hello');

    final first = await repo.send(message);
    final second = await repo.send(message);
    final page = await repo.newest('squad');

    expect(first, const SendConfirmed('client-1'));
    expect(second, const SendConflict('client-1'));
    expect(outcomeConfirms(second, 'client-1'), isTrue);
    expect(page.messages, hasLength(1));
    expect(page.messages.single.delivery, Delivery.sent);
  });

  test(
    'newest page is the tail, and the older page continues without a gap',
    () async {
      final repo = FakeChatRepository(
        messages: [
          for (var i = 0; i < 10; i++)
            ChatMessage(
              id: 'm$i',
              chatId: 'squad',
              senderId: 'friend',
              text: 'm$i',
              sentAt: DateTime.utc(2026, 1, 1, 0, i),
            ),
        ],
      );

      final first = await repo.newest('squad', limit: 4);
      expect(first.messages.map((message) => message.id), [
        'm6',
        'm7',
        'm8',
        'm9',
      ]);
      expect(first.hasOlder, isTrue);

      final older = await repo.before(
        'squad',
        cursor: first.messages.first,
        limit: 4,
      );
      expect(older.messages.map((message) => message.id), [
        'm2',
        'm3',
        'm4',
        'm5',
      ]);

      final stitch = stitchOlder(
        loaded: first.messages,
        fetched: older.messages,
        limit: 4,
      );
      expect(stitch.messages.map((message) => message.id), [
        'm2',
        'm3',
        'm4',
        'm5',
        'm6',
        'm7',
        'm8',
        'm9',
      ]);
    },
  );

  test('equal timestamps page in id order through the repository', () async {
    final t = DateTime.utc(2026, 6, 1, 12);
    final repo = FakeChatRepository(
      messages: [
        for (final id in ['a', 'b', 'c', 'd'])
          ChatMessage(
            id: id,
            chatId: 'squad',
            senderId: 'friend',
            text: id,
            sentAt: t,
          ),
      ],
    );

    final first = await repo.newest('squad', limit: 2);
    final older = await repo.before(
      'squad',
      cursor: first.messages.first,
      limit: 2,
    );

    expect(first.messages.map((message) => message.id), ['c', 'd']);
    expect(older.messages.map((message) => message.id), ['a', 'b']);
  });

  test('watch emits a delivered row once', () async {
    final repo = FakeChatRepository();
    final seen = <List<ChatMessage>>[];
    final sub = repo.watch('squad').listen(seen.add);
    repo.deliver(
      ChatMessage(
        id: 'echo',
        chatId: 'squad',
        senderId: 'friend',
        text: 'echo',
        sentAt: DateTime.utc(2026, 1, 1),
      ),
    );
    repo.deliver(
      ChatMessage(
        id: 'echo',
        chatId: 'squad',
        senderId: 'friend',
        text: 'echo',
        sentAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await sub.cancel();

    expect(seen, hasLength(1));
    expect(seen.single.single.id, 'echo');
    expect((await repo.newest('squad')).messages, hasLength(1));
  });

  test('holdSends pauses the write until the future completes', () async {
    final gate = Completer<void>();
    final repo = FakeChatRepository(holdSends: gate.future);
    final pending = repo.send(_message('client-1', 1, text: 'held'));

    await Future<void>.delayed(Duration.zero);
    expect((await repo.newest('squad')).messages, isEmpty);

    gate.complete();
    expect(await pending, const SendConfirmed('client-1'));
    expect((await repo.newest('squad')).messages.single.text, 'held');
  });

  test('unread save replaces the book', () async {
    final repo = FakeChatRepository(
      unread: const UnreadBook({'squad': 3, 'other': 2}),
    );
    final cleared = (await repo.unread()).opened('squad');
    await repo.saveUnread(cleared);

    final stored = await repo.unread();
    expect(stored.of('squad'), 0);
    expect(stored.of('other'), 2);
  });
}
