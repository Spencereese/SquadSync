import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/auth/data/fake_auth_repository.dart';
import 'package:squadsync/features/auth/data/supabase_auth_repository.dart';
import 'package:squadsync/features/auth/domain/auth_user.dart';
import 'package:squadsync/features/chat/ui/squad_chat_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

User _user() {
  return const User(
    id: 'spencer',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    email: 'spencer@example.com',
    createdAt: '2026-11-09T00:00:00Z',
  );
}

void main() {
  test('a refreshed token keeps the session and a failed refresh does not', () {
    final user = _user();
    expect(restoredUser(AuthChangeEvent.initialSession, user)?.id, 'spencer');
    expect(
      restoredUser(AuthChangeEvent.tokenRefreshed, user),
      isA<AuthUser>().having(
        (value) => value.email,
        'email',
        'spencer@example.com',
      ),
    );
    expect(restoredUser(AuthChangeEvent.tokenRefreshed, null), isNull);
    expect(restoredUser(AuthChangeEvent.signedOut, user), isNull);
  });

  testWidgets('a cold launch with a saved session opens the squad', (
    tester,
  ) async {
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

    expect(find.byKey(const Key('sign-in-email')), findsNothing);
    expect(find.byKey(const Key('composer')), findsOneWidget);
    expect(find.text('Spencer · Call of Duty'), findsOneWidget);
  });

  testWidgets(
    'a silent refresh stays in the squad and a failed refresh returns to email',
    (tester) async {
      final auth = FakeAuthRepository(
        signedIn: const AuthUser(id: 'spencer', email: 'spencer@example.com'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLinkProvider.overrideWithValue(AppLink.live),
            authRepositoryProvider.overrideWithValue(auth),
          ],
          child: const SquadSyncApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('composer')), findsOneWidget);

      auth.tokenRefresh();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sign-in-email')), findsNothing);
      expect(find.byKey(const Key('composer')), findsOneWidget);

      auth.restore(null);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sign-in-email')), findsOneWidget);
      expect(find.byKey(const Key('composer')), findsNothing);
      final context = tester.element(find.byType(MaterialApp));
      expect(
        ProviderScope.containerOf(context)
            .read(squadChatControllerProvider)
            .squad,
        isNull,
      );
    },
  );
}
