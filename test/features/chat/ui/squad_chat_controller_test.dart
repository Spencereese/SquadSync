import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/client_id.dart';
import 'package:squadsync/core/dependencies.dart';
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

  test('opening the squad chat clears only that chat', () async {
    final chats = FakeChatRepository(
      unread: const UnreadBook({'squad': 4, 'other': 2}),
    );
    final container = _container(chats: chats);
    addTearDown(container.dispose);

    await container.read(squadChatControllerProvider.notifier).open();
    final state = container.read(squadChatControllerProvider);

    expect(state.ready, isTrue);
    expect(state.meId, 'spencer');
    expect(state.unread.of('squad'), 0);
    expect(state.unread.of('other'), 2);
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
}
