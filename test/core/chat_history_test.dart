import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/chat_history.dart';
import 'package:squad_sync/core/chat_send.dart';
import 'package:squad_sync/domain/entities/message.dart';

Message _at(String id, DateTime timestamp) {
  return Message(
    id: id,
    senderId: 'u',
    text: id,
    timestamp: timestamp,
    messageType: MessageType.text,
  );
}

Message _ms(String id, int millis) =>
    _at(id, DateTime.fromMillisecondsSinceEpoch(millis));

void main() {
  test('a long thread opens on the newest page', () {
    final all = List.generate(250, (i) => _ms('m$i', i * 1000));
    final page = newestHistoryPage(all, limit: kOpenChatPageSize);

    expect(page, hasLength(kOpenChatPageSize));
    expect(page.first.id, 'm150');
    expect(page.last.id, 'm249');
    expect(page.map((m) => m.id), isNot(contains('m0')));
  });

  test('older pages prepend without duplicating or skipping', () {
    final all = List.generate(
      120,
      (i) => _ms('m${i.toString().padLeft(3, '0')}', i * 1000),
    );
    var loaded = newestHistoryPage(all, limit: 50);
    expect(loaded.first.id, 'm070');
    expect(loaded.last.id, 'm119');

    final seen = loaded.map((m) => m.id).toSet();
    var guard = 0;
    while (loaded.length < all.length && guard++ < 6) {
      final older = olderHistoryPage(
        all,
        cursor: loaded.first,
        limit: 50,
      );
      expect(older, isNotEmpty);
      expect(isStrictlyOlder(older.last, loaded.first), isTrue);
      for (final id in older.map((m) => m.id)) {
        expect(seen.contains(id), isFalse, reason: 'duplicate $id');
      }
      final stitch = stitchOlderPage(
        loaded: loaded,
        fetched: older,
        limit: 50,
      );
      expect(stitch.added, older.length);
      seen.addAll(stitch.messages.map((m) => m.id));
      expect(stitch.messages.last.id, 'm119');
      loaded = stitch.messages;
    }

    expect(loaded.map((m) => m.id).toList(), all.map((m) => m.id).toList());
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

    final first = newestHistoryPage(all, limit: 3);
    expect(first.map((m) => m.id), ['d', 'e', 'f']);

    final older = olderHistoryPage(all, cursor: first.first, limit: 2);
    expect(older.map((m) => m.id), ['b', 'c']);

    final rest = olderHistoryPage(all, cursor: older.first, limit: 2);
    expect(rest.map((m) => m.id), ['a']);

    final covered = {...first, ...older, ...rest}.map((m) => m.id).toSet();
    expect(covered, {'a', 'b', 'c', 'd', 'e', 'f'});
  });

  test('stitch drops a boundary row the server sent twice', () {
    final loaded = [_ms('m2', 2000), _ms('m3', 3000)];
    final fetched = [_ms('m1', 1000), _ms('m2', 2000)];
    final stitch = stitchOlderPage(loaded: loaded, fetched: fetched, limit: 50);

    expect(stitch.added, 1);
    expect(stitch.messages.map((m) => m.id), ['m1', 'm2', 'm3']);
    expect(stitch.hasMore, isFalse);
  });

  test('newest remote page beats a longer cache of older rows', () {
    final cached = List.generate(80, (i) => _ms('old$i', i * 1000));
    final remote = List.generate(50, (i) => _ms('new$i', (1000 + i) * 1000));
    final page = openChatPage(cached: cached, remote: remote);

    expect(page.map((m) => m.id), remote.map((m) => m.id));
    expect(page.map((m) => m.id), isNot(contains('old0')));
  });

  test('a 1-row remote does not wipe a larger cache', () {
    final cached = List.generate(45, (i) => _ms('c$i', i * 1000));
    final remote = [_ms('only', 1)];
    expect(openChatPage(cached: cached, remote: remote), hasLength(45));
  });

  test('an older remote page is kept when it is shorter than cache', () {
    final cached = List.generate(40, (i) => _ms('c$i', i * 1000));
    final remote = List.generate(3, (i) => _ms('r$i', i * 1000));
    final page = olderChatPage(
      cached: cached,
      remote: remote,
      remoteFailed: false,
    );
    expect(page.map((m) => m.id), ['r0', 'r1', 'r2']);
  });

  test('offline older page falls back to cache', () {
    final cached = [_ms('c0', 0), _ms('c1', 1000)];
    final page = olderChatPage(
      cached: cached,
      remote: const [],
      remoteFailed: true,
    );
    expect(page.map((m) => m.id), ['c0', 'c1']);
  });

  test('after an older page the newest message is still last', () {
    final all = List.generate(80, (i) => _ms('m$i', i * 1000));
    final open = newestHistoryPage(all, limit: 30);
    final older = olderHistoryPage(all, cursor: open.first, limit: 30);
    final stitch = stitchOlderPage(loaded: open, fetched: older, limit: 30);

    expect(stitch.messages.last.id, 'm79');
    expect(sortThread(stitch.messages).last.id, open.last.id);
  });
}
