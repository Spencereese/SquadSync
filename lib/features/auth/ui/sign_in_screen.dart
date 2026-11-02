import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/core/repository_failure.dart';

/// Email one-time code. Shown only when Supabase config is present.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  var _codeSent = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SquadSync')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Sign in with a code from your email.'),
          const SizedBox(height: 16),
          TextField(
            key: const Key('sign-in-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_codeSent) ...[
            TextField(
              key: const Key('sign-in-code'),
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            key: Key(_codeSent ? 'sign-in-verify' : 'sign-in-send'),
            onPressed: _busy ? null : (_codeSent ? _verify : _send),
            child: Text(_codeSent ? 'Verify code' : 'Send code'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const Key('sign-in-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _send() async {
    await _run(() async {
      await ref.read(authRepositoryProvider).sendEmailCode(_email.text);
      if (!mounted) return;
      setState(() => _codeSent = true);
    });
  }

  Future<void> _verify() async {
    await _run(
      () => ref
          .read(authRepositoryProvider)
          .verifyEmailCode(email: _email.text, code: _code.text),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on RepositoryFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
