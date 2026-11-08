import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/auth/data/fake_auth_repository.dart';
import 'package:squadsync/features/auth/domain/auth_user.dart';
import 'package:squadsync/features/squad/data/fake_squad_repository.dart';
import 'package:squadsync/features/squad/domain/member.dart';

void main() {
  testWidgets('a signed-in person with no squad starts one of eight', (
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
    expect(find.text('Create the squad'), findsOneWidget);
    expect(find.byKey(const Key('demo-banner')), findsNothing);
    expect(find.text('Call of Duty'), findsWidgets);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('setup-game')))
          .controller
          ?.text,
      'Call of Duty',
    );

    await tester.tap(find.byKey(const Key('start-squad')));
    await tester.pumpAndSettle();

    expect(find.text('1 of 8'), findsOneWidget);
    expect(find.text('Spencer · Call of Duty'), findsOneWidget);
    expect(squads.snapshot.members, hasLength(1));
    expect(squads.snapshot.ownerId, 'spencer');
  });

  testWidgets('saving a default game updates the member strip', (tester) async {
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
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-game')),
      'Battlefield',
    );
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    expect(find.text('Spencer · Battlefield'), findsOneWidget);
  });

  testWidgets('an account with no profile is not given a fake squad', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLinkProvider.overrideWithValue(AppLink.live),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(
              signedIn: const AuthUser(id: 'new', email: 'new@example.com'),
            ),
          ),
          squadRepositoryProvider.overrideWithValue(_NoProfileSquads()),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-missing')), findsOneWidget);
    expect(find.byKey(const Key('composer')), findsNothing);
  });
}

class _NoProfileSquads extends FakeSquadRepository {
  _NoProfileSquads() : super(startEmpty: true);

  @override
  Future<Member?> myProfile() async => null;
}
