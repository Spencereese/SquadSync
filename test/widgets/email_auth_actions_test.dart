import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/email_auth.dart';
import 'package:squad_sync/widgets/email_auth_actions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('Sign In and Create Account are separate actions', (tester) async {
    var signInCount = 0;
    var createCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmailAuthActions(
            onSignIn: () => signInCount++,
            onCreateAccount: () => createCount++,
          ),
        ),
      ),
    );

    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);

    await tester.tap(find.text('Sign In'));
    await tester.pump();
    expect(signInCount, 1);
    expect(createCount, 0);

    await tester.tap(find.text('Create Account'));
    await tester.pump();
    expect(signInCount, 1);
    expect(createCount, 1);
  });

  testWidgets('disabled actions do not fire while loading', (tester) async {
    var signInCount = 0;
    var createCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmailAuthActions(
            enabled: false,
            onSignIn: () => signInCount++,
            onCreateAccount: () => createCount++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Sign In'), warnIfMissed: false);
    await tester.tap(find.text('Create Account'), warnIfMissed: false);
    await tester.pump();
    expect(signInCount, 0);
    expect(createCount, 0);
  });

  testWidgets('sign-in vs create-account errors stay on their own path',
      (tester) async {
    final signIn = EmailAuth.forSignIn(
      AuthException('Invalid login credentials',
          statusCode: '400', code: 'invalid_credentials'),
    );
    final create = EmailAuth.forCreateAccount(
      AuthException('User already registered',
          statusCode: '422', code: 'user_already_exists'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text(signIn.message, key: const Key('sign-in-feedback')),
              Text(create.message, key: const Key('create-feedback')),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('sign-in-feedback')), findsOneWidget);
    expect(find.textContaining('Wrong email or password'), findsOneWidget);
    expect(find.textContaining('already exists'), findsOneWidget);
    expect(signIn.offerPasswordReset, isTrue);
    expect(create.suggestSignIn, isTrue);
    expect(signIn.suggestSignIn, isFalse);
    expect(create.offerPasswordReset, isFalse);
  });
}
