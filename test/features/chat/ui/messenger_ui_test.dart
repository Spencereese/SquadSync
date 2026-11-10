import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/client_id.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/chat/data/fake_chat_repository.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/ui/message_bubble.dart';
import 'package:squadsync/features/chat/domain/messenger.dart';
import 'package:squadsync/features/chat/domain/unread.dart';
import 'package:squadsync/features/squad/data/fake_squad_repository.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

const _alex = Member(id: 'alex', displayName: 'Alex', defaultGame: 'Halo');

ChatMessage _mine(String id, String text) {
  return ChatMessage(
    id: id,
    chatId: 'squad',
    senderId: 'spencer',
    text: text,
    sentAt: DateTime.utc(2026, 11, 10, 20),
  );
}

ChatMessage _fromAlex(String id, String text, int minute) {
  return ChatMessage(
    id: id,
    chatId: 'squad',
    senderId: 'alex',
    text: text,
    sentAt: DateTime.utc(2026, 11, 10, 20, minute),
  );
}

Future<void> _open(
  WidgetTester tester, {
  required FakeChatRepository chats,
  FakeSquadRepository? squads,
  ClientIdFactory? ids,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(chats),
        if (squads != null) squadRepositoryProvider.overrideWithValue(squads),
        if (ids != null) clientIdFactoryProvider.overrideWithValue(ids),
      ],
      child: const SquadSyncApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a long press toggles a reaction and names who used it', (
    tester,
  ) async {
    final chats = FakeChatRepository(messages: [_mine('m1', 'hello')]);
    await _open(tester, chats: chats);
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const Key('message-m1')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('React with thumbs up'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pick-👍')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('thumbs up')), findsOneWidget);
    expect(find.text('👍 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reaction-m1-👍')));
    await tester.pumpAndSettle();
    expect(find.text('👍 1'), findsNothing);
  });

  testWidgets('my last message says who has seen it', (tester) async {
    final chats = FakeChatRepository(
      messages: [_mine('m1', 'hello')],
      reads: [
        MemberRead(
          userId: 'alex',
          messageId: 'm1',
          readAt: DateTime.utc(2026, 11, 10, 21),
        ),
      ],
    );
    await _open(
      tester,
      chats: chats,
      squads: FakeSquadRepository(
        seed: Squad(
          id: 'squad',
          ownerId: 'spencer',
          members: const [spencer, _alex],
        ),
      ),
    );
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(find.text('Seen by Alex'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Seen by Alex')), findsOneWidget);
  });

  testWidgets('the chat badge jumps to the first unread message', (
    tester,
  ) async {
    final chats = FakeChatRepository(
      messages: [
        _fromAlex('old', 'first unread', 1),
        _fromAlex('new', 'later', 2),
      ],
      unread: const UnreadBook({'squad': 2}),
    );
    await _open(tester, chats: chats);

    expect(find.text('2'), findsOneWidget);
    expect(find.bySemanticsLabel('Chat, 2 unread'), findsOneWidget);

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('jump-unread')));
    await tester.pumpAndSettle();

    expect(find.text('first unread'), findsOneWidget);
    expect(find.byKey(const Key('unread-count')), findsNothing);
    expect((await chats.unread()).of('squad'), 0);
    expect((await chats.unread()).of('other'), 0);
  });

  testWidgets('a reply quotes the message and still sends optimistically', (
    tester,
  ) async {
    final gate = Completer<void>();
    final chats = FakeChatRepository(
      messages: [_fromAlex('m1', 'want to play', 1)],
      holdSends: gate.future,
    );
    await _open(
      tester,
      chats: chats,
      ids: SequenceClientIdFactory(['reply-1']),
    );
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const Key('message-m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-reply')));
    await tester.pumpAndSettle();
    expect(find.text('want to play'), findsWidgets);
    expect(find.byKey(const Key('replying-to')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('composer')), 'yes');
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pump();

    expect(find.byKey(const Key('quote-reply-1')), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byKey(const Key('quote-reply-1')), findsOneWidget);
    expect(chats.rows.last.replyToId, 'm1');
  });

  testWidgets('typing is a broadcast line and not a stored row', (
    tester,
  ) async {
    final chats = FakeChatRepository();
    await _open(
      tester,
      chats: chats,
      squads: FakeSquadRepository(
        seed: Squad(
          id: 'squad',
          ownerId: 'spencer',
          members: const [spencer, _alex],
        ),
      ),
    );
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    chats.deliverTyping({'alex'});
    await tester.pumpAndSettle();
    expect(find.text('Alex is typing'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Alex is typing')), findsOneWidget);
    expect(chats.rows, isEmpty);
  });

  testWidgets('a missing messenger file hides reactions and receipts', (
    tester,
  ) async {
    final chats = FakeChatRepository(
      messengerEnabled: false,
      messages: [_mine('m1', 'hello')],
      reads: [
        MemberRead(
          userId: 'alex',
          messageId: 'm1',
          readAt: DateTime.utc(2026, 11, 10, 21),
        ),
      ],
    );
    await _open(tester, chats: chats);
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(find.text('Seen by Alex'), findsNothing);
    expect(find.text('hello'), findsOneWidget);
    await tester.longPress(find.byKey(const Key('message-m1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pick-👍')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a quote is smaller than the reply and fits at double text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: ChatMessage(
              id: 'reply-1',
              chatId: 'squad',
              senderId: 'spencer',
              text: 'yes I can play tonight after work',
              sentAt: DateTime.utc(2026, 11, 10, 20),
              replyToId: 'm1',
              replyText: 'want to play a long game of Halo tonight',
            ),
            mine: true,
            onRetry: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scheme = Theme.of(tester.element(find.byType(MessageBubble)))
        .colorScheme;
    final quote = tester.widget<Text>(find.byKey(const Key('quote-reply-1')));
    final replyStyle = DefaultTextStyle.of(
      tester.element(find.text('yes I can play tonight after work')),
    ).style;
    final box = tester.widget<DecoratedBox>(
      find.byKey(const Key('quote-box-reply-1')),
    );
    final decoration = box.decoration as BoxDecoration;
    final border = decoration.border! as Border;

    expect(quote.style!.fontSize!, lessThan(replyStyle.fontSize!));
    expect(quote.style?.color, scheme.onSurface);
    expect(decoration.color, scheme.surface);
    expect(border.left.width, 3);
    expect(
      find.text('want to play a long game of Halo tonight'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the thread shows before a quote lookup finishes', (
    tester,
  ) async {
    final gate = Completer<void>();
    final chats = FakeChatRepository(
      messages: [
        _fromAlex('m1', 'want to play', 1),
        ChatMessage(
          id: 'm2',
          chatId: 'squad',
          senderId: 'spencer',
          text: 'on my way',
          sentAt: DateTime.utc(2026, 11, 10, 20, 2),
          replyToId: 'm1',
        ),
      ],
    )..holdQuotes = gate.future;
    await _open(tester, chats: chats);
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(find.text('on my way'), findsOneWidget);
    expect(find.byKey(const Key('quote-m2')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quote-m2')), findsOneWidget);
    expect(find.text('want to play'), findsWidgets);
  });
}
