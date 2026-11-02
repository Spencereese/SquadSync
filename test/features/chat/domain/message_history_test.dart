import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/domain/message_history.dart';

ChatMessage _at(String id, DateTime sentAt) {
  return ChatMessage(
    id: id,
    chatId: 'squad',
    senderId: 'friend',
    text: id,
    sentAt: sentAt,
  );
}

ChatMessage _ms(String id, int millis) {
  return _at(id, DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true));
}

void main() {
  test('a long thread opens on the newest page', () {
    final all = List<ChatMessage>.generate(250, (i) => _ms('m$i', i * 1000));
    final page = newestPage(all, limit: openPageSize);

    expect(page.messages, hasLength(openPageSize));
    expect(page.hasOlder, isTrue);
    expect(page.messages.first.id, 'm${250 - openPageSize}');
    expect(page.messages.last.id, 'm249');
    expect(page.messages.map((message) => message.id), isNot(contains('m0')));
  });

  test('older pages cover the thread once, with no gaps', () {
    final all = List<ChatMessage>.generate(
      120,
      (i) => _ms('m${i.toString().padLeft(3, '0')}', i * 1000),
    );
    var loaded = newestPage(all, limit: 50);
    expect(loaded.messages.first.id, 'm070');
    expect(loaded.messages.last.id, 'm119');

    final seen = loaded.messages.map((message) => message.id).toSet();
    var guard = 0;
    while (loaded.messages.length < all.length && guard++ < 6) {
      final older = olderPage(all, cursor: loaded.messages.first, limit: 50);
      expect(older.messages, isNotEmpty);
      expect(
        isStrictlyOlder(older.messages.last, loaded.messages.first),
        isTrue,
      );
      for (final id in older.messages.map((message) => message.id)) {
        expect(seen.contains(id), isFalse, reason: 'duplicate $id');
      }
      final stitch = stitchOlder(
        loaded: loaded.messages,
        fetched: older.messages,
        limit: 50,
      );
      expect(
        stitch.messages.length - loaded.messages.length,
        older.messages.length,
      );
      expect(stitch.messages.last.id, 'm119');
      seen.addAll(stitch.messages.map((message) => message.id));
      loaded = stitch;
    }

    expect(
      loaded.messages.map((message) => message.id).toList(),
      all.map((message) => message.id).toList(),
    );
    expect(loaded.hasOlder, isFalse);
  });

  test('shared timestamps stay in id order across the page boundary', () {
    final t = DateTime.utc(2026, 6, 1, 12);
    final later = t.add(const Duration(seconds: 5));
    final all = [
      _at('a', t),
      _at('b', t),
      _at('c', t),
      _at('d', t),
      _at('e', later),
      _at('f', later),
    ];

    final first = newestPage(all, limit: 3);
    expect(first.messages.map((message) => message.id), ['d', 'e', 'f']);

    final older = olderPage(all, cursor: first.messages.first, limit: 2);
    expect(older.messages.map((message) => message.id), ['b', 'c']);
    expect(isStrictlyOlder(older.messages.last, first.messages.first), isTrue);

    final rest = olderPage(all, cursor: older.messages.first, limit: 2);
    expect(rest.messages.map((message) => message.id), ['a']);
    expect(rest.hasOlder, isFalse);

    final covered = {
      ...first.messages.map((message) => message.id),
      ...older.messages.map((message) => message.id),
      ...rest.messages.map((message) => message.id),
    };
    expect(covered, {'a', 'b', 'c', 'd', 'e', 'f'});
    expect({...first.messages, ...older.messages, ...rest.messages}.length, 6);
  });

  test('the cursor row itself is not repeated on the older page', () {
    final all = [_ms('m1', 1000), _ms('m2', 2000), _ms('m3', 3000)];
    final older = olderPage(all, cursor: all[2], limit: 10);

    expect(older.messages.map((message) => message.id), ['m1', 'm2']);
  });

  test('stitch drops a boundary row the server sent twice', () {
    final loaded = [_ms('m2', 2000), _ms('m3', 3000)];
    final fetched = [_ms('m1', 1000), _ms('m2', 2000)];
    final stitch = stitchOlder(loaded: loaded, fetched: fetched, limit: 50);

    expect(stitch.messages.map((message) => message.id), ['m1', 'm2', 'm3']);
    expect(stitch.hasOlder, isFalse);
  });

  test('a full fresh page reports that older rows may remain', () {
    final loaded = [_ms('m2', 2000)];
    final fetched = [_ms('m0', 0), _ms('m1', 1000)];
    final stitch = stitchOlder(loaded: loaded, fetched: fetched, limit: 2);

    expect(stitch.messages.map((message) => message.id), ['m0', 'm1', 'm2']);
    expect(stitch.hasOlder, isTrue);
  });

  test('after an older page the newest message is still last', () {
    final all = List<ChatMessage>.generate(80, (i) => _ms('m$i', i * 1000));
    final open = newestPage(all, limit: 30);
    final older = olderPage(all, cursor: open.messages.first, limit: 30);
    final stitch = stitchOlder(
      loaded: open.messages,
      fetched: older.messages,
      limit: 30,
    );

    expect(stitch.messages.last.id, 'm79');
    expect(stitch.messages.last.id, open.messages.last.id);
  });
}
