import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/features/chat/domain/unread.dart';

void main() {
  test('opening a chat clears only that chat', () {
    final counts = const UnreadBook({'other': 4}).add('squad', 2);

    expect(counts.of('other'), 4);
    expect(counts.of('squad'), 2);

    final opened = counts.opened('squad');
    expect(opened.of('squad'), 0);
    expect(opened.of('other'), 4);
    expect(counts.of('squad'), 2);
  });

  test('opening a chat that has no count leaves the book alone', () {
    const counts = UnreadBook({'other': 4});

    expect(identical(counts.opened('missing'), counts), isTrue);
    expect(identical(counts.opened(''), counts), isTrue);
  });

  test('adding unread to one chat does not change another', () {
    const counts = UnreadBook({'other': 1});
    final next = counts.add('squad', 3);

    expect(next.of('squad'), 3);
    expect(next.of('other'), 1);
    expect(counts.add('', 3), same(counts));
    expect(counts.add('squad', 0), same(counts));
  });

  test('incoming messages count only while that chat is closed', () {
    expect(
      unreadArrivals(
        senderIds: const ['friend', 'spencer', 'friend', ''],
        currentUserId: 'spencer',
        chatIsOpen: false,
      ),
      2,
    );
    expect(
      unreadArrivals(
        senderIds: const ['friend', 'friend'],
        currentUserId: 'spencer',
        chatIsOpen: true,
      ),
      0,
    );
  });

  test('opening one chat does not clear arrivals waiting on another', () {
    final waiting = const UnreadBook()
        .add(
          'squad',
          unreadArrivals(
            senderIds: const ['friend'],
            currentUserId: 'spencer',
            chatIsOpen: false,
          ),
        )
        .add(
          'other',
          unreadArrivals(
            senderIds: const ['friend', 'friend'],
            currentUserId: 'spencer',
            chatIsOpen: false,
          ),
        );

    final opened = waiting.opened('squad');
    expect(opened.of('squad'), 0);
    expect(opened.of('other'), 2);
  });
}
