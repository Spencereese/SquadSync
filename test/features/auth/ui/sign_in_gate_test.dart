import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/auth/data/fake_auth_repository.dart';
import 'package:squadsync/features/auth/domain/auth_user.dart';
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
}
