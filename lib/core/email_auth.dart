import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps Supabase email AuthException codes to user-facing copy.
/// Sign-in and create-account are separate — never auto-signup on sign-in failure.
class EmailAuthFeedback {
  const EmailAuthFeedback({
    required this.message,
    this.offerPasswordReset = false,
    this.suggestSignIn = false,
  });

  final String message;
  final bool offerPasswordReset;
  final bool suggestSignIn;
}

class EmailAuth {
  EmailAuth._();

  static bool isInvalidCredentials(AuthException e) {
    final code = (e.code ?? '').toLowerCase();
    return code == 'invalid_credentials' || code == 'invalid_grant';
  }

  static bool isUnknownUser(AuthException e) {
    final code = (e.code ?? '').toLowerCase();
    return code == 'user_not_found' || code == 'user_not_exist';
  }

  static bool isAlreadyRegistered(AuthException e) {
    final code = (e.code ?? '').toLowerCase();
    final message = e.message.toLowerCase();
    return code == 'user_already_exists' ||
        code == 'email_exists' ||
        message.contains('already registered') ||
        message.contains('already been registered') ||
        message.contains('user already exists');
  }

  static EmailAuthFeedback forSignIn(AuthException e) {
    if (isInvalidCredentials(e)) {
      return const EmailAuthFeedback(
        message: 'Wrong email or password.',
        offerPasswordReset: true,
      );
    }
    if (isUnknownUser(e)) {
      return const EmailAuthFeedback(
        message: 'No account found for that email. Create an account.',
      );
    }
    if ((e.code ?? '') == 'email_not_confirmed') {
      return const EmailAuthFeedback(
        message: 'Confirm your email, then sign in.',
      );
    }
    return EmailAuthFeedback(message: 'Sign in failed: ${e.message}');
  }

  static EmailAuthFeedback forCreateAccount(AuthException e) {
    if (isAlreadyRegistered(e)) {
      return const EmailAuthFeedback(
        message: 'An account with this email already exists. Sign in instead.',
        suggestSignIn: true,
      );
    }
    if ((e.code ?? '') == 'weak_password') {
      return const EmailAuthFeedback(
        message: 'Password is too weak. Use at least 6 characters.',
      );
    }
    return EmailAuthFeedback(message: 'Could not create account: ${e.message}');
  }
}
