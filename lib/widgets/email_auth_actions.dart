import 'package:flutter/material.dart';

import '../core/app_theme.dart';

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
