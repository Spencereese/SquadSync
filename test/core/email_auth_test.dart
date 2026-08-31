import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/email_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('EmailAuth sign-in', () {
    test('invalid_credentials is not treated as unknown user', () {
      final error = AuthException('Invalid login credentials',
          statusCode: '400', code: 'invalid_credentials');

      expect(EmailAuth.isInvalidCredentials(error), isTrue);
      expect(EmailAuth.isUnknownUser(error), isFalse);
      expect(EmailAuth.isAlreadyRegistered(error), isFalse);

      final feedback = EmailAuth.forSignIn(error);
      expect(feedback.offerPasswordReset, isTrue);
      expect(feedback.message, contains('Wrong email or password'));
    });

    test('unknown user is distinct from a wrong password', () {
      final error =
          AuthException('User not found', statusCode: '400', code: 'user_not_found');

      expect(EmailAuth.isUnknownUser(error), isTrue);
      expect(EmailAuth.isInvalidCredentials(error), isFalse);

      final feedback = EmailAuth.forSignIn(error);
      expect(feedback.offerPasswordReset, isFalse);
      expect(feedback.message, contains('Create an account'));
    });
  });

  group('EmailAuth create account', () {
    test('already registered tells the user to sign in', () {
      final error = AuthException('User already registered',
          statusCode: '422', code: 'user_already_exists');

      expect(EmailAuth.isAlreadyRegistered(error), isTrue);

      final feedback = EmailAuth.forCreateAccount(error);
      expect(feedback.suggestSignIn, isTrue);
      expect(feedback.message, contains('Sign in'));
    });
  });
}
