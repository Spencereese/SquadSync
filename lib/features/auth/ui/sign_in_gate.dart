import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/auth/domain/auth_user.dart';
import 'package:squadsync/features/auth/ui/sign_in_screen.dart';
import 'package:squadsync/features/auth/ui/sign_out_button.dart';
import 'package:squadsync/features/chat/ui/squad_chat_screen.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/ui/squad_setup_screen.dart';

final authUserProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchUser();
});

/// Sign-in, then profile and squad, then the chat. Never a fake squad.
class SignInGate extends ConsumerWidget {
  const SignInGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authUserProvider);
    return auth.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => const _GateProblem(
        message: 'Could not restore the session. Nothing was opened.',
      ),
      data: (user) {
        if (user == null) return const SignInScreen();
        return _AccountGate(key: ValueKey(user.id));
      },
    );
  }
}

class _AccountGate extends ConsumerStatefulWidget {
  const _AccountGate({super.key});

  @override
  ConsumerState<_AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends ConsumerState<_AccountGate> {
  var _loading = true;
  var _generation = 0;
  Member? _profile;
  var _hasSquad = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final squads = ref.read(squadRepositoryProvider);
      final profile = await squads.myProfile();
      final squad = profile == null ? null : await squads.findMine();
      if (!_current(generation, userId)) return;
      setState(() {
        _profile = profile;
        _hasSquad = squad != null;
        _loading = false;
      });
    } on Object {
      if (!_current(generation, userId)) return;
      setState(() {
        _error = 'Could not load your squad. Nothing was opened.';
        _loading = false;
      });
    }
  }

  bool _current(int generation, String? userId) {
    return mounted &&
        generation == _generation &&
        ref.read(authRepositoryProvider).currentUser?.id == userId;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(accountRevisionProvider, (previous, next) {
      if (previous != next) unawaited(_load());
    });
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(key: Key('gate-loading')),
        ),
      );
    }
    if (_error != null) {
      return _GateProblem(message: _error!, onRetry: () => unawaited(_load()));
    }
    final profile = _profile;
    if (profile == null) return const ProfileMissingScreen();
    if (!_hasSquad) return SquadSetupScreen(profile: profile);
    return const SquadChatScreen();
  }
}

class _GateProblem extends ConsumerWidget {
  const _GateProblem({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SquadSync'),
        actions: const [SignOutButton()],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                key: const Key('gate-error'),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('gate-retry'),
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
