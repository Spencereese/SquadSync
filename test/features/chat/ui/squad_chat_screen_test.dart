import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/client_id.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/chat/data/fake_chat_repository.dart';
import 'package:squadsync/features/chat/ui/squad_chat_controller.dart';
import 'package:squadsync/features/chat/ui/squad_chat_screen.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/squad/data/fake_squad_repository.dart';
import 'package:squadsync/features/squad/data/squad_repository.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

Future<void> _pump(
  WidgetTester tester, {
  SquadRepository? squads,
  FakeChatRepository? chats,
  ClientIdFactory? ids,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (squads != null) squadRepositoryProvider.overrideWithValue(squads),
        if (chats != null) chatRepositoryProvider.overrideWithValue(chats),
        if (ids != null) clientIdFactoryProvider.overrideWithValue(ids),
      ],
      child: const SquadSyncApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'send shows a clock until the repository confirms, then a check',
    (tester) async {
      final gate = Completer<void>();
      final chats = FakeChatRepository(holdSends: gate.future);
      await _pump(
        tester,
        chats: chats,
        ids: SequenceClientIdFactory(['msg-1']),
      );

      expect(find.text('Spencer · Call of Duty'), findsOneWidget);
      expect(find.text('1 of 8'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('composer')), 'hello squad');
      await tester.tap(find.byKey(const Key('send-button')));
      await tester.pump();

      expect(find.text('hello squad'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byKey(const Key('message-msg-1')), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsNothing);
      expect(find.text('Not sent. Tap to retry'), findsNothing);
      expect(find.byKey(const Key('message-msg-1')), findsOneWidget);
    },
  );

  testWidgets('a failed send stays on screen as not sent', (tester) async {
    final chats = FakeChatRepository();
    await _pump(tester, chats: chats, ids: SequenceClientIdFactory(['msg-1']));
    chats.fail = true;

    await tester.enterText(find.byKey(const Key('composer')), 'hello squad');
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();

    expect(find.text('hello squad'), findsOneWidget);
    expect(find.text('Not sent. Tap to retry'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byKey(const Key('message-msg-1')), findsOneWidget);
  });

  testWidgets('tap to retry sends the same id and then shows a check', (
    tester,
  ) async {
    final chats = FakeChatRepository();
    await _pump(tester, chats: chats, ids: SequenceClientIdFactory(['msg-1']));
    chats.fail = true;
    await tester.enterText(find.byKey(const Key('composer')), 'hello squad');
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();
    expect(find.text('Not sent. Tap to retry'), findsOneWidget);

    chats.fail = false;
    await tester.tap(find.text('Not sent. Tap to retry'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('Not sent. Tap to retry'), findsNothing);
    expect(find.text('hello squad'), findsOneWidget);
    expect(find.byKey(const Key('message-msg-1')), findsOneWidget);
  });

  testWidgets('the thread opens on the newest message', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const count = 36;
    final start = DateTime.utc(2026, 1, 1);
    final chats = FakeChatRepository(
      messages: [
        for (var i = 0; i < count; i++)
          ChatMessage(
            id: 'm${i.toString().padLeft(2, '0')}',
            chatId: 'squad',
            senderId: 'friend',
            text: i == 0
                ? 'oldest-ping'
                : i == count - 1
                ? 'newest-ping'
                : 'pad-$i',
            sentAt: start.add(Duration(minutes: i)),
          ),
      ],
    );
    await _pump(tester, chats: chats);

    expect(find.text('newest-ping'), findsOneWidget);
    expect(find.text('oldest-ping'), findsNothing);
    final top = tester.getTopLeft(find.text('newest-ping'));
    final bottom = tester.getBottomRight(find.text('newest-ping'));
    expect(top.dy, greaterThanOrEqualTo(0));
    expect(bottom.dy, lessThanOrEqualTo(520));
  });

  testWidgets('the member strip shows eight and no more', (tester) async {
    var squad = Squad.seed();
    for (var n = 1; n <= 7; n++) {
      final result = squad.add(
        Member(
          id: 'friend-$n',
          displayName: 'Friend $n',
          defaultGame: 'Battlefield',
        ),
      );
      squad = (result as AddMemberAccepted).squad;
    }
    expect(
      squad.add(
        const Member(id: 'friend-8', displayName: 'Nine', defaultGame: 'Halo'),
      ),
      isA<AddMemberRejected>(),
    );

    await _pump(tester, squads: FakeSquadRepository(seed: squad));

    expect(find.text('8 of 8'), findsOneWidget);
    expect(find.text('Spencer · Call of Duty'), findsOneWidget);
    expect(find.byKey(const Key('member-spencer')), findsOneWidget);
    for (var n = 1; n <= 7; n++) {
      expect(find.byKey(Key('member-friend-$n')), findsOneWidget);
    }
    expect(find.byKey(const Key('member-friend-8')), findsNothing);
  });

  testWidgets('a blank composer does not send', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();

    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsNothing);
  });

  testWidgets('earlier messages pulls the older page into the thread', (
    tester,
  ) async {
    final start = DateTime.utc(2026, 1, 1);
    final chats = FakeChatRepository(
      messages: [
        for (var i = 0; i < 45; i++)
          ChatMessage(
            id: 'm$i',
            chatId: 'squad',
            senderId: 'friend',
            text: 'line-$i',
            sentAt: start.add(Duration(minutes: i)),
          ),
      ],
    );
    await _pump(tester, chats: chats);

    expect(find.byKey(const Key('earlier')), findsOneWidget);
    expect(find.text('line-0'), findsNothing);

    await tester.tap(find.byKey(const Key('earlier')));
    await tester.pumpAndSettle();

    final state = ProviderScope.containerOf(
      tester.element(find.byType(SquadChatScreen)),
    ).read(squadChatControllerProvider);
    expect(state.messages.first.id, 'm0');
    expect(state.messages, hasLength(45));
  });
}
