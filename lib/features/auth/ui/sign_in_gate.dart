import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/auth/domain/auth_user.dart';
import 'package:squadsync/features/auth/ui/sign_in_screen.dart';
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
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      data: (user) {
        if (user == null) return const SignInScreen();
        return const _AccountGate();
      },
    );
  }
}

class _AccountGate extends ConsumerStatefulWidget {
  const _AccountGate();

  @override
  ConsumerState<_AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends ConsumerState<_AccountGate> {
  var _loading = true;
  Member? _profile;
  var _hasSquad = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final squads = ref.read(squadRepositoryProvider);
      final profile = await squads.myProfile();
      final squad = profile == null ? null : await squads.findMine();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _hasSquad = squad != null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(accountRevisionProvider, (previous, next) {
      if (previous != next) _load();
    });
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!)));
    }
    final profile = _profile;
    if (profile == null) return const ProfileMissingScreen();
    if (!_hasSquad) return SquadSetupScreen(profile: profile);
    return const SquadChatScreen();
  }
}
