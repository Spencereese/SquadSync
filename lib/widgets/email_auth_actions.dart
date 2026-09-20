import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/email_auth.dart';

/// SnackBar for email auth feedback. Sign In / Reset stay off the raw URI.
SnackBar emailAuthSnackBar(
  EmailAuthFeedback feedback, {
  VoidCallback? onSignIn,
  VoidCallback? onResetPassword,
}) {
  SnackBarAction? action;
  if (feedback.suggestSignIn && onSignIn != null) {
    action = SnackBarAction(label: 'Sign In', onPressed: onSignIn);
  } else if (feedback.offerPasswordReset && onResetPassword != null) {
    action = SnackBarAction(
      label: 'Reset Password',
      onPressed: onResetPassword,
    );
  }
  return SnackBar(
    content: Text(feedback.message),
    action: action,
    duration: const Duration(seconds: 6),
  );
}

/// Separate Sign In vs Create Account — never one catch-all button.
class EmailAuthActions extends StatelessWidget {
  const EmailAuthActions({
    super.key,
    required this.onSignIn,
    required this.onCreateAccount,
    this.enabled = true,
  });

  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeonPulseButton(
          onPressed: enabled ? onSignIn : null,
          child: const Text('Sign In'),
        ),
        const SizedBox(height: 10),
        NeonPulseButton(
          onPressed: enabled ? onCreateAccount : null,
          child: const Text('Create Account'),
        ),
      ],
    );
  }
}
