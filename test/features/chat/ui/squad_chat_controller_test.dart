import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/client_id.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/chat/data/fake_chat_repository.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/domain/unread.dart';
import 'package:squadsync/features/chat/ui/squad_chat_controller.dart';
import 'package:squadsync/features/squad/data/fake_squad_repository.dart';

ChatMessage _row(String id, int minute, {String text = 'pad'}) {
  return ChatMessage(
    id: id,
    chatId: 'squad',
    senderId: 'friend',
    text: text,
    sentAt: DateTime.utc(2026, 1, 1, 0, minute),
  );
}

ProviderContainer _container({
  FakeSquadRepository? squads,
  FakeChatRepository? chats,
  ClientIdFactory? ids,
}) {
  return ProviderContainer(
    overrides: [
      squadRepositoryProvider.overrideWithValue(
        squads ?? FakeSquadRepository(),
      ),
      chatRepositoryProvider.overrideWithValue(chats ?? FakeChatRepository()),
      if (ids != null) clientIdFactoryProvider.overrideWithValue(ids),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('opening the squad keeps the unread count until catch up', () async {
    final chats = FakeChatRepository(
      unread: const UnreadBook({'squad': 4, 'other': 2}),
    );
    final container = _container(chats: chats);
    addTearDown(container.dispose);

    await container.read(squadChatControllerProvider.notifier).open();
    final opened = container.read(squadChatControllerProvider);

    expect(opened.ready, isTrue);
    expect(opened.meId, 'spencer');
    expect(opened.unread.of('squad'), 4);
    expect(opened.unread.of('other'), 2);

    await container.read(squadChatControllerProvider.notifier).catchUp();
    final caught = container.read(squadChatControllerProvider);
    expect(caught.unread.of('squad'), 0);
    expect(caught.unread.of('other'), 2);
    expect((await chats.unread()).of('squad'), 0);
    expect((await chats.unread()).of('other'), 2);
  });

  test(
    'a failed load surfaces the error and does not invent a squad',
    () async {
      final container = _container(squads: FakeSquadRepository(fail: true));
      addTearDown(container.dispose);

      await container.read(squadChatControllerProvider.notifier).open();
      final state = container.read(squadChatControllerProvider);

      expect(state.squad, isNull);
      expect(state.ready, isFalse);
      expect(state.error, contains('squad load failed'));
    },
  );

  test(
    'paging older history keeps the newest row last and adds no duplicates',
    () async {
      final chats = FakeChatRepository(
        messages: [for (var i = 0; i < 50; i++) _row('m$i', i, text: 'm$i')],
      );
      final container = _container(chats: chats);
      addTearDown(container.dispose);
      final controller = container.read(squadChatControllerProvider.notifier);

      await controller.open();
      var state = container.read(squadChatControllerProvider);
      expect(state.messages, hasLength(40));
      expect(state.hasOlder, isTrue);
      expect(state.messages.last.id, 'm49');
      expect(
        state.messages.map((message) => message.id),
        isNot(contains('m0')),
      );

      await controller.loadOlder();
      state = container.read(squadChatControllerProvider);
      expect(state.messages, hasLength(50));
      expect(state.hasOlder, isFalse);
      expect(state.messages.first.id, 'm0');
      expect(state.messages.last.id, 'm49');
      expect(
        state.messages.map((message) => message.id).toSet(),
        hasLength(50),
      );
    },
  );

  test(
    'an echo of the client id confirms it, and a late failure does not demote',
    () async {
      final gate = Completer<void>();
      final chats = FakeChatRepository(holdSends: gate.future);
      final container = _container(
        chats: chats,
        ids: SequenceClientIdFactory(['msg-1']),
      );
      addTearDown(container.dispose);
      final controller = container.read(squadChatControllerProvider.notifier);
      await controller.open();

      final pending = controller.send('hello');
      await Future<void>.delayed(Duration.zero);
      var state = container.read(squadChatControllerProvider);
      expect(state.messages.single.id, 'msg-1');
      expect(state.messages.single.delivery, Delivery.sending);

      chats.deliver(
        ChatMessage(
          id: 'msg-1',
          chatId: 'squad',
          senderId: 'spencer',
          text: 'hello',
          sentAt: DateTime.utc(2026, 11, 2),
          delivery: Delivery.sent,
        ),
      );
      chats.fail = true;
      gate.complete();
      await pending;

      state = container.read(squadChatControllerProvider);
      expect(
        state.messages.where((message) => message.id == 'msg-1'),
        hasLength(1),
      );
      expect(state.messages.single.delivery, Delivery.sent);
    },
  );

  test('a conflict on retry marks the same id sent', () async {
    final chats = FakeChatRepository();
    final container = _container(
      chats: chats,
      ids: SequenceClientIdFactory(['msg-1']),
    );
    addTearDown(container.dispose);
    final controller = container.read(squadChatControllerProvider.notifier);
    await controller.open();

    chats.fail = true;
    await controller.send('hello');
    var state = container.read(squadChatControllerProvider);
    expect(state.messages.single.delivery, Delivery.failed);

    chats.fail = false;
    chats.storeQuietly(
      ChatMessage(
        id: 'msg-1',
        chatId: 'squad',
        senderId: 'spencer',
        text: 'hello',
        sentAt: DateTime.utc(2026, 11, 2),
      ),
    );
    await controller.retry('msg-1');
    state = container.read(squadChatControllerProvider);

    expect(state.messages, hasLength(1));
    expect(state.messages.single.id, 'msg-1');
    expect(state.messages.single.delivery, Delivery.sent);
  });

  test(
    'reload keeps the failed row and does not duplicate the thread',
    () async {
      final chats = FakeChatRepository(
        messages: [
          ChatMessage(
            id: 'kept',
            chatId: 'squad',
            senderId: 'friend',
            text: 'kept',
            sentAt: DateTime.utc(2026, 11, 1),
          ),
        ],
      );
      final container = _container(
        chats: chats,
        ids: SequenceClientIdFactory(['msg-1']),
      );
      addTearDown(container.dispose);
      final controller = container.read(squadChatControllerProvider.notifier);
      await controller.open();

      chats.fail = true;
      await controller.send('nope');
      chats.fail = false;
      chats.deliver(
        ChatMessage(
          id: 'kept',
          chatId: 'squad',
          senderId: 'friend',
          text: 'kept',
          sentAt: DateTime.utc(2026, 11, 1),
        ),
      );
      await controller.reload();
      final state = container.read(squadChatControllerProvider);
      final failed = state.messages.where((message) => message.id == 'msg-1');

      expect(failed, hasLength(1));
      expect(failed.single.delivery, Delivery.failed);
      expect(
        state.messages.where((message) => message.id == 'kept'),
        hasLength(1),
      );
      expect(state.linkDown, isFalse);
    },
  );

  test('reload keeps a row that arrives while unread is saving', () async {
    final chats = FakeChatRepository(
      messages: [
        ChatMessage(
          id: 'kept',
          chatId: 'squad',
          senderId: 'friend',
          text: 'kept',
          sentAt: DateTime.utc(2026, 11, 1),
        ),
      ],
    );
    final container = _container(chats: chats);
    addTearDown(container.dispose);
    final controller = container.read(squadChatControllerProvider.notifier);
    await controller.open();

    final gate = Completer<void>();
    chats.holdUnread = gate.future;
    final pending = controller.reload();
    await Future<void>.delayed(Duration.zero);

    chats.deliver(
      ChatMessage(
        id: 'late',
        chatId: 'squad',
        senderId: 'friend',
        text: 'late',
        sentAt: DateTime.utc(2026, 11, 3),
      ),
    );
    chats.replay(
      ChatMessage(
        id: 'kept',
        chatId: 'squad',
        senderId: 'friend',
        text: 'kept',
        sentAt: DateTime.utc(2026, 11, 1),
      ),
    );
    final during = container.read(squadChatControllerProvider);
    expect(chats.rows.map((message) => message.id).toList(), ['kept', 'late']);
    expect(during.messages.map((message) => message.id), ['kept', 'late']);

    gate.complete();
    await pending;
    final after = container.read(squadChatControllerProvider);

    expect(after.messages.map((message) => message.id), ['kept', 'late']);
    expect(
      chats.rows.map((message) => message.id),
      containsAll(['kept', 'late']),
    );
    expect(
      after.messages.where((message) => message.id == 'kept'),
      hasLength(1),
    );
  });

  test(
    'reload does not write the old thread after the squad changes',
    () async {
      final chats = FakeChatRepository(
        messages: [
          ChatMessage(
            id: 'kept',
            chatId: 'squad',
            senderId: 'friend',
            text: 'kept',
            sentAt: DateTime.utc(2026, 11, 1),
          ),
        ],
      );
      final container = _container(chats: chats);
      addTearDown(container.dispose);
      final controller = container.read(squadChatControllerProvider.notifier);
      await controller.open();

      final gate = Completer<void>();
      chats.holdUnread = gate.future;
      final pending = controller.reload();
      await Future<void>.delayed(Duration.zero);
      controller.abandon();
      gate.complete();
      await pending;
      final state = container.read(squadChatControllerProvider);

      expect(state.squad, isNull);
      expect(state.messages, isEmpty);
    },
  );

  test('abandon drops an unsent row so the next open starts clean', () async {
    final chats = FakeChatRepository();
    final container = _container(
      chats: chats,
      ids: SequenceClientIdFactory(['msg-1']),
    );
    addTearDown(container.dispose);
    final controller = container.read(squadChatControllerProvider.notifier);
    await controller.open();
    chats.fail = true;
    await controller.send('nope');
    controller.abandon();
    chats.fail = false;
    await controller.open();
    final state = container.read(squadChatControllerProvider);

    expect(state.messages, isEmpty);
    expect(state.error, isNull);
  });

  test('a messenger error still opens the messages', () async {
    final chats =
        FakeChatRepository(
            messages: [
              ChatMessage(
                id: 'm1',
                chatId: 'squad',
                senderId: 'friend',
                text: 'hello',
                sentAt: DateTime.utc(2026, 11, 2),
              ),
            ],
          )
          ..messengerFailure = const RepositoryFailure(
            'permission denied for table sq8_message_reads',
            code: '42501',
          );
    final container = _container(chats: chats);
    addTearDown(container.dispose);

    await container.read(squadChatControllerProvider.notifier).open();
    final state = container.read(squadChatControllerProvider);

    expect(state.squad, isNotNull);
    expect(state.messages.single.text, 'hello');
    expect(state.messenger.enabled, isFalse);
    expect(state.error, isNull);
    expect(state.messengerError, contains('Reactions and read receipts'));
    expect(state.messengerError, contains('permission denied'));
  });

  test('typing starts once per burst and the channel is not stacked', () async {
    final chats = FakeChatRepository();
    final container = _container(chats: chats);
    final controller = container.read(squadChatControllerProvider.notifier);

    await controller.open();
    expect(chats.typingWatches, 1);
    expect(chats.openTypingWatches, 1);

    await controller.setTyping(true);
    await controller.setTyping(true);
    expect(chats.typingSends, [true]);

    await controller.reload();
    expect(chats.typingWatches, 1);
    expect(chats.openTypingWatches, 1);

    container.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(chats.openTypingWatches, 0);
  });
}
