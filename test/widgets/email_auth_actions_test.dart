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

  testWidgets('already-registered snackbar Sign In action fires', (tester) async {
    var signedIn = false;
    final feedback = EmailAuth.forCreateAccount(
      AuthException('User already registered',
          statusCode: '422', code: 'user_already_exists'),
    );
    expect(feedback.suggestSignIn, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    emailAuthSnackBar(
                      feedback,
                      onSignIn: () => signedIn = true,
                    ),
                  );
                },
                child: const Text('trigger'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    expect(find.textContaining('already exists'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(signedIn, isTrue);
  });

  testWidgets('recover ClientException snackbar never contains http',
      (tester) async {
    final error = AuthException(
      'ClientException: Failed to fetch, uri=https://your-project.supabase.co/auth/v1/recover?',
      statusCode: '0',
    );
    final message = EmailAuth.forUnexpected(error).message;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                },
                child: const Text('recover'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('recover'));
    await tester.pumpAndSettle();
    expect(find.textContaining('http'), findsNothing);
    expect(find.textContaining('your-project'), findsNothing);
    expect(find.text(EmailAuth.unavailableMessage), findsOneWidget);
  });
}
