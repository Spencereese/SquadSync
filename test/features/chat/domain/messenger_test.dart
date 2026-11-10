import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/domain/messenger.dart';

ChatMessage _message(String id, String sender, int minute) {
  return ChatMessage(
    id: id,
    chatId: 'squad',
    senderId: sender,
    text: id,
    sentAt: DateTime.utc(2026, 11, 10, 20, minute),
  );
}

void main() {
  test('a reaction toggles and the chip names who used it', () {
    final once = toggleReaction(
      const [],
      messageId: 'm1',
      userId: 'alex',
      emoji: '👍',
    );
    expect(once, hasLength(1));
    final twice = toggleReaction(
      once,
      messageId: 'm1',
      userId: 'alex',
      emoji: '👍',
    );
    expect(twice, isEmpty);
    expect(
      toggleReaction(const [], messageId: 'm1', userId: 'alex', emoji: 'nope'),
      isEmpty,
    );

    final chips = reactionChips(
      messageId: 'm1',
      reactions: const [
        MessageReaction(messageId: 'm1', userId: 'alex', emoji: '👍'),
        MessageReaction(messageId: 'm1', userId: 'spencer', emoji: '👍'),
      ],
      names: const {'alex': 'Alex', 'spencer': 'Spencer'},
      meId: 'spencer',
    );
    expect(chips.single.count, 2);
    expect(chips.single.mine, isTrue);
    expect(chips.single.spoken, '2 thumbs up, Alex, Spencer');
  });

  test('seen by lists people whose cursor is on this message or later', () {
    final thread = [_message('m1', 'spencer', 1), _message('m2', 'alex', 2)];
    final names = seenByNames(
      message: thread.first,
      thread: thread,
      reads: [
        MemberRead(
          userId: 'alex',
          messageId: 'm2',
          readAt: DateTime.utc(2026, 11, 10, 21),
        ),
        MemberRead(
          userId: 'spencer',
          messageId: 'm2',
          readAt: DateTime.utc(2026, 11, 10, 21),
        ),
      ],
      names: const {'alex': 'Alex', 'spencer': 'Spencer'},
      meId: 'spencer',
    );
    expect(seenByLine(names), 'Seen by Alex');
  });

  test('the first unread message is the oldest one after the cursor', () {
    final messages = [
      _message('old', 'alex', 1),
      _message('mine', 'spencer', 2),
      _message('new', 'alex', 3),
    ];
    expect(
      firstUnreadMessageId(
        messages: messages,
        meId: 'spencer',
        readThroughId: 'old',
      ),
      'new',
    );
    expect(
      firstUnreadMessageId(
        messages: messages,
        meId: 'spencer',
        readThroughId: null,
      ),
      'old',
    );
  });

  test('a missing messenger table is not a chat error', () {
    expect(messengerTableMissing('42P01', ''), isTrue);
    expect(messengerTableMissing('PGRST205', ''), isTrue);
    expect(messengerTableMissing('42703', 'reply_to_id'), isTrue);
    expect(messengerTableMissing('23505', 'duplicate'), isFalse);
    expect(typingLine(const ['Alex']), 'Alex is typing');
  });
}
