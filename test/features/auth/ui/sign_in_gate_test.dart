import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/auth/data/fake_auth_repository.dart';
import 'package:squadsync/features/auth/domain/auth_user.dart';
import 'package:squadsync/features/chat/data/fake_chat_repository.dart';
import 'package:squadsync/features/chat/ui/squad_chat_controller.dart';
import 'package:squadsync/features/squad/data/fake_squad_repository.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

void main() {
  testWidgets('a failed squad load can be retried or signed out', (
    tester,
  ) async {
    final squads = FakeSquadRepository(fail: true);
    final auth = FakeAuthRepository(
      signedIn: const AuthUser(id: 'spencer', email: 'spencer@example.com'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLinkProvider.overrideWithValue(AppLink.live),
          authRepositoryProvider.overrideWithValue(auth),
          squadRepositoryProvider.overrideWithValue(squads),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gate-retry')), findsOneWidget);
    expect(find.byKey(const Key('sign-out')), findsOneWidget);
    expect(find.textContaining('Nothing was opened'), findsOneWidget);
    expect(find.byKey(const Key('composer')), findsNothing);

    squads.fail = false;
    await tester.tap(find.byKey(const Key('gate-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('composer')), findsOneWidget);
    expect(find.byKey(const Key('gate-retry')), findsNothing);
  });

  testWidgets('sign out from a failed load returns to the email form', (
    tester,
  ) async {
    final auth = FakeAuthRepository(
      signedIn: const AuthUser(id: 'spencer', email: 'spencer@example.com'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLinkProvider.overrideWithValue(AppLink.live),
          authRepositoryProvider.overrideWithValue(auth),
          squadRepositoryProvider.overrideWithValue(
            FakeSquadRepository(fail: true),
          ),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sign-in-email')), findsOneWidget);
    expect(find.byKey(const Key('gate-retry')), findsNothing);
    expect(find.byKey(const Key('composer')), findsNothing);
    expect(auth.currentUser, isNull);
  });

  testWidgets('switching accounts drops the previous squad load', (
    tester,
  ) async {
    final gate = Completer<void>();
    final squads = FakeSquadRepository();
    final auth = FakeAuthRepository(
      signedIn: const AuthUser(id: 'spencer', email: 'spencer@example.com'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLinkProvider.overrideWithValue(AppLink.live),
          authRepositoryProvider.overrideWithValue(auth),
          squadRepositoryProvider.overrideWithValue(squads),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composer')), findsOneWidget);

    squads.holdProfile = gate.future;
    auth.restore(const AuthUser(id: 'friend', email: 'friend@example.com'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('gate-loading')), findsOneWidget);
    expect(find.byKey(const Key('composer')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composer')), findsOneWidget);
  });

  testWidgets('being seated while waiting opens the squad chat', (
    tester,
  ) async {
    final squads = FakeSquadRepository(startEmpty: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLinkProvider.overrideWithValue(AppLink.live),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(
              signedIn: const AuthUser(
                id: 'spencer',
                email: 'spencer@example.com',
              ),
            ),
          ),
          squadRepositoryProvider.overrideWithValue(squads),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start the squad'), findsOneWidget);

    squads.seat(
      Squad(
        id: 'joined',
        ownerId: 'owner',
        members: const [
          Member(
            id: 'owner',
            displayName: 'Owner',
            defaultGame: 'Call of Duty',
          ),
          spencer,
        ],
      ),
    );
    squads.notifyRoster();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('composer')), findsOneWidget);
    expect(find.text('Start the squad'), findsNothing);
  });

  testWidgets('pull to refresh on the no-squad screen picks up a seat', (
    tester,
  ) async {
    final squads = FakeSquadRepository(startEmpty: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLinkProvider.overrideWithValue(AppLink.live),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(
              signedIn: const AuthUser(
                id: 'spencer',
                email: 'spencer@example.com',
              ),
            ),
          ),
          squadRepositoryProvider.overrideWithValue(squads),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();

    squads.seat(Squad.seed());
    final refresh = tester.widget<RefreshIndicator>(
      find.byKey(const Key('refresh-setup')),
    );
    await refresh.onRefresh();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('composer')), findsOneWidget);
  });

  testWidgets('reload leaves after the seat is gone with no delete event', (
    tester,
  ) async {
    final squads = FakeSquadRepository(seed: _three());
    await _live(tester, squads);
    expect(find.text('3 of 8'), findsOneWidget);

    squads.unseat();
    await tester.tap(find.byKey(const Key('reload-chat')));
    await tester.pumpAndSettle();

    _expectLeft(tester);
  });

  testWidgets('pull to refresh leaves after the seat is gone', (tester) async {
    final squads = FakeSquadRepository(seed: _three());
    await _live(tester, squads);

    squads.unseat();
    final refresh = tester.widget<RefreshIndicator>(
      find.byKey(const Key('refresh-chat')),
    );
    await refresh.onRefresh();
    await tester.pumpAndSettle();

    _expectLeft(tester);
  });

  testWidgets('a member delete drops the removed person from the squad', (
    tester,
  ) async {
    final squads = FakeSquadRepository(seed: _three());
    await _live(tester, squads);

    squads.unseat();
    squads.notifyDeleted();
    await tester.pumpAndSettle();

    _expectLeft(tester);
  });

  testWidgets('a channel error re-checks membership and leaves', (
    tester,
  ) async {
    final squads = FakeSquadRepository(seed: _three());
    final chats = FakeChatRepository();
    await _live(tester, squads, chats: chats);
    expect(find.text('3 of 8'), findsOneWidget);

    squads.unseat();
    chats.dropLink();
    await tester.pumpAndSettle();

    _expectLeft(tester);
  });
}

Squad _three() {
  return Squad(
    id: 'squad',
    ownerId: 'owner',
    members: const [
      Member(id: 'owner', displayName: 'Owner', defaultGame: 'Halo'),
      Member(id: 'friend', displayName: 'Friend', defaultGame: 'Halo'),
      spencer,
    ],
  );
}

Future<void> _live(
  WidgetTester tester,
  FakeSquadRepository squads, {
  FakeChatRepository? chats,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLinkProvider.overrideWithValue(AppLink.live),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            signedIn: const AuthUser(
              id: 'spencer',
              email: 'spencer@example.com',
            ),
          ),
        ),
        squadRepositoryProvider.overrideWithValue(squads),
        if (chats != null) chatRepositoryProvider.overrideWithValue(chats),
      ],
      child: const SquadSyncApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectLeft(WidgetTester tester) {
  expect(find.text("You're no longer in this squad"), findsOneWidget);
  expect(find.byKey(const Key('composer')), findsNothing);
  expect(find.text('3 of 8'), findsNothing);
  final context = tester.element(find.byType(MaterialApp));
  final state = ProviderScope.containerOf(context)
      .read(squadChatControllerProvider);
  expect(state.squad, isNull);
  expect(state.messages, isEmpty);
}
