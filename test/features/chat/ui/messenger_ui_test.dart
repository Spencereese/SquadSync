import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/client_id.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/chat/data/fake_chat_repository.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
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
        squadClockProvider.overrideWithValue(
          ManualSquadClock(DateTime.utc(2026, 11, 10, 21, 2)),
        ),
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

    expect(find.text('Seen by Alex 2m ago'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Seen by Alex 2m ago')),
      findsOneWidget,
    );
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

    await tester.tap(find.byKey(const Key('reply-clear')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('message-m1')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('swipe-reply-m1')));
    await tester.pumpAndSettle();
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
}
