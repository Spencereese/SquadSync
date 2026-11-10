import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/core/sq8_database.dart';
import 'package:squadsync/core/sq8_rows.dart';
import 'package:squadsync/features/chat/data/supabase_chat_repository.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/domain/send_machine.dart';
import 'package:squadsync/features/chat/domain/unread.dart';

import '../../../core/mock_sq8_database.dart';

Sq8Message _row(String id, int minute) {
  return Sq8Message(
    id: id,
    squadId: 'squad',
    senderId: 'user-1',
    body: id,
    sentAt: DateTime.utc(2026, 11, 2, 12, minute),
  );
}

void main() {
  test('the newest page is oldest-first and knows when more exist', () async {
    final db = MockSq8Database()
      ..messages = [_row('m3', 3), _row('m2', 2), _row('m1', 1)];
    final repo = SupabaseChatRepository(db);

    final page = await repo.newest('squad', limit: 2);

    expect(db.lastNewestLimit, 3);
    expect(page.hasOlder, isTrue);
    expect(page.messages.map((message) => message.id), ['m2', 'm3']);
    expect(page.messages.last.delivery, Delivery.sent);
  });

  test('older pages ask for the cursor and stay oldest-first', () async {
    final db = MockSq8Database()..messages = [_row('m1', 1), _row('m0', 0)];
    final repo = SupabaseChatRepository(db);
    final cursor = ChatMessage(
      id: 'm2',
      chatId: 'squad',
      senderId: 'user-1',
      text: 'm2',
      sentAt: DateTime.utc(2026, 11, 2, 12, 2),
    );

    final page = await repo.before('squad', cursor: cursor, limit: 2);

    expect(db.lastOlderBefore, cursor.sentAt);
    expect(db.lastOlderBeforeId, 'm2');
    expect(page.messages.map((message) => message.id), ['m0', 'm1']);
  });

  test('a duplicate client id is a conflict and the same id', () async {
    final db = MockSq8Database()..duplicate = true;
    final repo = SupabaseChatRepository(db);
    final message = ChatMessage(
      id: 'msg-1',
      chatId: 'squad',
      senderId: 'user-1',
      text: 'hello',
      sentAt: DateTime.utc(2026, 11, 2),
      delivery: Delivery.sending,
    );

    final outcome = await repo.send(message);

    expect(outcome, const SendConflict('msg-1'));
    expect(db.insertedMessages, isEmpty);
  });

  test('a confirmed send stores that client id', () async {
    final db = MockSq8Database();
    final repo = SupabaseChatRepository(db);
    final message = ChatMessage(
      id: 'msg-1',
      chatId: 'squad',
      senderId: 'user-1',
      text: 'hello',
      sentAt: DateTime.utc(2026, 11, 2),
      delivery: Delivery.sending,
    );

    expect(await repo.send(message), const SendConfirmed('msg-1'));
    expect(db.insertedMessages.single.id, 'msg-1');
  });

  test('a store failure is not reported as sent', () async {
    final db = MockSq8Database()..insertError = const RepositoryFailure('down');
    final repo = SupabaseChatRepository(db);
    final message = ChatMessage(
      id: 'msg-1',
      chatId: 'squad',
      senderId: 'user-1',
      text: 'hello',
      sentAt: DateTime.utc(2026, 11, 2),
      delivery: Delivery.sending,
    );

    expect(repo.send(message), throwsA(isA<RepositoryFailure>()));
  });

  test('an insert echo becomes one message', () async {
    final db = MockSq8Database();
    final repo = SupabaseChatRepository(db);
    final seen = <List<ChatMessage>>[];
    final sub = repo.watch('squad').listen(seen.add);
    await Future<void>.delayed(Duration.zero);

    db.emit(_row('echo', 4));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen, hasLength(1));
    expect(seen.single.single.id, 'echo');
  });

  test('opening to zero moves the read cursor and a count does not', () async {
    final db = MockSq8Database()
      ..messages = [_row('m1', 1)]
      ..cursor = Sq8Cursor(
        lastReadAt: DateTime.utc(2026, 11, 1),
        lastReadId: 'old',
      )
      ..unread = 2;
    final repo = SupabaseChatRepository(db);

    final book = await repo.unread();
    expect(book.of('squad'), 2);
    expect(db.lastUnreadCursor?.lastReadId, 'old');

    await repo.saveUnread(const UnreadBook({'squad': 2}));
    expect(db.cursorWrites, 0);

    await repo.saveUnread(book.opened('squad'));
    expect(db.cursorWrites, 1);
    expect(db.cursor?.lastReadId, 'm1');
  });

  test('a server row with reply_to_id keeps its quote after reload', () async {
    final original = messageFromRow({
      'id': 'm1',
      'squad_id': 'squad',
      'sender_id': 'alex',
      'body': 'be on in five',
      'sent_at': '2026-11-02T12:00:00.000Z',
    });
    final reply = messageFromRow({
      'id': 'm2',
      'squad_id': 'squad',
      'sender_id': 'user-1',
      'body': 'on my way',
      'sent_at': '2026-11-02T12:01:00.000Z',
      'reply_to_id': 'm1',
    });
    expect(reply.replyToId, 'm1');
    final db = MockSq8Database()..messages = [reply, original];
    final repo = SupabaseChatRepository(db);

    final page = await repo.newest('squad');
    final loaded = page.messages.last;
    expect(loaded.id, 'm2');
    expect(loaded.replyToId, 'm1');
    expect(loaded.replyText, 'be on in five');

    db.messages = [reply];
    final gone = await repo.newest('squad');
    expect(gone.messages.single.replyToId, 'm1');
    expect(gone.messages.single.replyText, 'Original message unavailable');
  });

  test('a failed quote lookup still loads the thread', () async {
    final plain = messageFromRow({
      'id': 'm1',
      'squad_id': 'squad',
      'sender_id': 'alex',
      'body': 'hello',
      'sent_at': '2026-11-02T12:00:00.000Z',
    });
    final reply = messageFromRow({
      'id': 'm2',
      'squad_id': 'squad',
      'sender_id': 'user-1',
      'body': 'on my way',
      'sent_at': '2026-11-02T12:01:00.000Z',
      'reply_to_id': 'm1',
    });
    final db = MockSq8Database()
      ..messages = [reply, plain]
      ..bodiesError = const RepositoryFailure('500');
    final repo = SupabaseChatRepository(db);

    final page = await repo.newest('squad');

    expect(page.messages.map((message) => message.text), [
      'hello',
      'on my way',
    ]);
    expect(page.messages.first.replyText, isNull);
    expect(page.messages.last.replyToId, 'm1');
    expect(page.messages.last.replyText, 'Original message unavailable');

    final seen = <List<ChatMessage>>[];
    final errors = <Object>[];
    final sub = repo.watch('squad').listen(seen.add, onError: errors.add);
    db.emit(reply);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(errors, isEmpty);
    expect(seen.single.single.text, 'on my way');
    expect(seen.single.single.replyText, 'Original message unavailable');
  });
}
