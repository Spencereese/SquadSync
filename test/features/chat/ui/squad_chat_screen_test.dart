import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/client_id.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/availability/data/fake_availability_repository.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
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
  bool chat = true,
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
  if (chat) {
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
  }
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

      expect(find.text('0 of 8 available'), findsOneWidget);
      expect(find.byKey(const Key('squad-home')), findsOneWidget);

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

    await _pump(tester, squads: FakeSquadRepository(seed: squad), chat: false);

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

  testWidgets('a failed earlier page stays on screen and can be retried', (
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
    chats.fail = true;

    await tester.tap(find.byKey(const Key('earlier')));
    await tester.pumpAndSettle();

    expect(find.text('line-44'), findsOneWidget);
    expect(find.text('line-0'), findsNothing);
    expect(find.text('chat before failed'), findsOneWidget);

    chats.fail = false;
    await tester.tap(find.byKey(const Key('earlier')));
    await tester.pumpAndSettle();

    final state = ProviderScope.containerOf(
      tester.element(find.byType(SquadChatScreen)),
    ).read(squadChatControllerProvider);
    expect(state.messages.first.id, 'm0');
    expect(state.error, isNull);
    expect(find.text('line-44'), findsOneWidget);
    expect(find.text('chat before failed'), findsNothing);
  });

  testWidgets('a realtime member and message show up without a restart', (
    tester,
  ) async {
    final squads = FakeSquadRepository();
    final chats = FakeChatRepository();
    await _pump(tester, squads: squads, chats: chats);
    expect(find.byKey(const Key('member-friend')), findsNothing);

    await squads.addMember(
      const Member(id: 'friend', displayName: 'Friend', defaultGame: 'Halo'),
    );
    squads.notifyRoster();
    await tester.pumpAndSettle();

    await tester.tap(find.text("Who's on"));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('member-friend')), findsOneWidget);
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    chats.deliver(
      ChatMessage(
        id: 'late',
        chatId: 'squad',
        senderId: 'friend',
        text: 'hello from the other phone',
        sentAt: DateTime.utc(2026, 11, 9, 8),
      ),
    );
    chats.deliver(
      ChatMessage(
        id: 'late',
        chatId: 'squad',
        senderId: 'friend',
        text: 'hello from the other phone',
        sentAt: DateTime.utc(2026, 11, 9, 8),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('hello from the other phone'), findsOneWidget);
  });

  testWidgets(
    'resume and pull to refresh load a message that realtime missed',
    (tester) async {
      final chats = FakeChatRepository();
      await _pump(tester, chats: chats);

      chats.storeQuietly(
        ChatMessage(
          id: 'stored',
          chatId: 'squad',
          senderId: 'friend',
          text: 'saved while the phone was away',
          sentAt: DateTime.utc(2026, 11, 9, 8),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('saved while the phone was away'), findsOneWidget);

      chats.storeQuietly(
        ChatMessage(
          id: 'pulled',
          chatId: 'squad',
          senderId: 'friend',
          text: 'pulled into view',
          sentAt: DateTime.utc(2026, 11, 9, 9),
        ),
      );
      final refresh = tester.widget<RefreshIndicator>(
        find.byKey(const Key('refresh-chat')),
      );
      await refresh.onRefresh();
      await tester.pumpAndSettle();

      expect(find.text('pulled into view'), findsOneWidget);
      expect(find.text('saved while the phone was away'), findsOneWidget);
    },
  );

  testWidgets('a member delete updates the count for everyone else', (
    tester,
  ) async {
    final squads = FakeSquadRepository();
    await _pump(tester, squads: squads, chat: false);
    expect(find.text('1 of 8'), findsOneWidget);

    await squads.addMember(
      const Member(id: 'friend', displayName: 'Friend', defaultGame: 'Halo'),
    );
    await squads.addMember(
      const Member(id: 'other', displayName: 'Other', defaultGame: 'Halo'),
    );
    squads.notifyDeleted();
    await tester.pumpAndSettle();

    expect(find.text('3 of 8'), findsOneWidget);

    await squads.removeMember('other');
    squads.notifyDeleted();
    await tester.pumpAndSettle();

    expect(find.text('2 of 8'), findsOneWidget);
    expect(find.byKey(const Key('member-other')), findsNothing);
    expect(find.byKey(const Key('member-friend')), findsOneWidget);
    expect(find.byKey(const Key('squad-home')), findsOneWidget);
  });

  testWidgets('pull to refresh loads a check-in realtime missed', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 20));
    final availability = FakeAvailabilityRepository(clock: clock);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          squadClockProvider.overrideWithValue(clock),
          localOffsetProvider.overrideWithValue(Duration.zero),
          availabilityTickProvider.overrideWithValue(Duration.zero),
          availabilityRepositoryProvider.overrideWithValue(availability),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 of 8 available'), findsOneWidget);

    availability.store(
      StoredCheckIn(
        userId: 'spencer',
        squadId: 'squad',
        kind: CheckInKind.availableNow,
        checkedAt: clock.now(),
        until: clock.now().add(const Duration(minutes: 60)),
      ),
    );
    final refresh = tester.widget<RefreshIndicator>(
      find.byKey(const Key('refresh-chat')),
    );
    await refresh.onRefresh();
    await tester.pumpAndSettle();

    expect(find.text('1 of 8 available'), findsOneWidget);
    expect(find.textContaining('checked in, not detected'), findsOneWidget);
  });
}
