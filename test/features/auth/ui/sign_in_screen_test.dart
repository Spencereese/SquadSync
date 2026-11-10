import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/config.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/auth/data/fake_auth_repository.dart';
import 'package:squadsync/features/auth/domain/auth_user.dart';

Future<void> _pump(WidgetTester tester, {FakeAuthRepository? auth}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLinkProvider.overrideWithValue(AppLink.live),
        squadSyncConfigProvider.overrideWithValue(
          const SquadSyncConfig(
            url: 'https://example.supabase.co',
            anonKey: 'public-anon-key',
          ),
        ),
        if (auth != null) authRepositoryProvider.overrideWithValue(auth),
      ],
      child: const SquadSyncApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without config the chat opens and sign-in stays hidden', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SquadSyncApp()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sign-in-email')), findsNothing);
    expect(find.byKey(const Key('demo-banner')), findsOneWidget);
    expect(
      find.text('Demo mode: messages clear when you close the app.'),
      findsOneWidget,
    );
    expect(find.textContaining('stay on this phone'), findsNothing);
    expect(find.text('Spencer · Call of Duty'), findsOneWidget);

    await tester.tap(find.byKey(const Key('view-chat')));
    await tester.pumpAndSettle();
    expect(find.text('No messages yet'), findsOneWidget);
    expect(
      find.text('Demo mode: messages clear when you close the app.'),
      findsOneWidget,
    );
  });

  testWidgets('a code sign-in is shown only when config is present', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await _pump(tester, auth: auth);

    expect(find.text('Send code'), findsOneWidget);
    expect(find.text('No messages yet'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('sign-in-email')),
      'spencer@example.com',
    );
    await tester.tap(find.byKey(const Key('sign-in-send')));
    await tester.pumpAndSettle();

    expect(auth.lastEmail, 'spencer@example.com');
    expect(find.byKey(const Key('sign-in-code')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('sign-in-code')), '123456');
    await tester.tap(find.byKey(const Key('sign-in-verify')));
    await tester.pumpAndSettle();

    expect(auth.lastCode, '123456');
    expect(find.text('Spencer · Call of Duty'), findsOneWidget);
    expect(find.byKey(const Key('sign-in-email')), findsNothing);
  });

  testWidgets('a rejected code stays on the sign-in screen', (tester) async {
    await _pump(tester, auth: FakeAuthRepository());

    await tester.enterText(
      find.byKey(const Key('sign-in-email')),
      'spencer@example.com',
    );
    await tester.tap(find.byKey(const Key('sign-in-send')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sign-in-code')), '12');
    await tester.tap(find.byKey(const Key('sign-in-verify')));
    await tester.pumpAndSettle();

    expect(find.text('code rejected'), findsOneWidget);
    expect(find.byKey(const Key('sign-in-email')), findsOneWidget);
    expect(find.byKey(const Key('sign-in-code')), findsOneWidget);
  });

  testWidgets('resend and a different email do not leave the code step stuck', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await _pump(tester, auth: auth);

    await tester.enterText(
      find.byKey(const Key('sign-in-email')),
      'spencer@example.com',
    );
    await tester.tap(find.byKey(const Key('sign-in-send')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sign-in-resend')));
    await tester.pumpAndSettle();

    expect(auth.sendCount, 2);
    expect(find.byKey(const Key('sign-in-code')), findsOneWidget);
    expect(find.byKey(const Key('sign-in-verify')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sign-in-change-email')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sign-in-code')), findsNothing);
    expect(find.byKey(const Key('sign-in-send')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('sign-in-email')))
          .controller
          ?.text,
      'spencer@example.com',
    );
    expect(auth.sendCount, 2);
  });

  testWidgets('a restored session opens the chat, and sign-out clears it', (
    tester,
  ) async {
    final auth = FakeAuthRepository(
      signedIn: const AuthUser(id: 'spencer', email: 'spencer@example.com'),
    );
    await _pump(tester, auth: auth);

    expect(find.byKey(const Key('sign-in-email')), findsNothing);
    expect(find.byKey(const Key('demo-banner')), findsNothing);
    expect(find.text('Spencer · Call of Duty'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sign-in-email')), findsOneWidget);
    expect(find.text('Spencer · Call of Duty'), findsNothing);
  });

  testWidgets('a URL without a client is not a successful demo', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          squadSyncConfigProvider.overrideWithValue(
            const SquadSyncConfig(
              url: 'https://example.supabase.co',
              anonKey: 'public-anon-key',
            ),
          ),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('link-misconfigured')), findsOneWidget);
    expect(find.byKey(const Key('demo-banner')), findsNothing);
    expect(find.text('Spencer · Call of Duty'), findsNothing);
    expect(find.byKey(const Key('sign-in-send')), findsNothing);
  });
}
