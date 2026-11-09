import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/auth/domain/auth_user.dart';
import 'package:squadsync/features/auth/ui/sign_in_screen.dart';
import 'package:squadsync/features/chat/ui/squad_chat_controller.dart';
import 'package:squadsync/features/auth/ui/sign_out_button.dart';
import 'package:squadsync/features/chat/ui/squad_chat_screen.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';
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
    ref.listen(authUserProvider, (previous, next) {
      final left =
          previous?.asData?.value != null &&
          next is AsyncData<AuthUser?> &&
          next.value == null;
      if (left) {
        ref.read(squadChatControllerProvider.notifier).abandon();
      }
    });
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

class _AccountGateState extends ConsumerState<_AccountGate>
    with WidgetsBindingObserver {
  var _loading = true;
  var _generation = 0;
  Member? _profile;
  Squad? _squad;
  String? _error;
  String? _rosterKey;
  StreamSubscription<void>? _roster;
  StreamSubscription<void>? _refresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh = ref.read(authRepositoryProvider).watchTokenRefresh().listen((_) {
      _rosterKey = null;
      _bindRoster(ref.read(authRepositoryProvider).currentUser?.id);
      unawaited(_load(silent: true));
      unawaited(ref.read(squadChatControllerProvider.notifier).reload());
    });
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(_load(silent: _profile != null));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_roster?.cancel());
    unawaited(_refresh?.cancel());
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_generation;
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final squads = ref.read(squadRepositoryProvider);
      final profile = await squads.myProfile();
      final hadSquad = _squad != null;
      final squad = profile == null ? null : await squads.findMine();
      if (!_current(generation, userId)) return;
      if (squad != null) {
        ref.read(removedNoticeProvider.notifier).clear();
      } else if (hadSquad) {
        ref.read(squadChatControllerProvider.notifier).abandon();
        ref.read(removedNoticeProvider.notifier).show(removedFromSquadMessage);
      }
      setState(() {
        _profile = profile;
        _squad = squad;
        _loading = false;
        _error = null;
      });
      _bindRoster(userId);
    } on Object {
      if (!_current(generation, userId)) return;
      if (silent && _profile != null) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _error = 'Could not load your squad. Nothing was opened.';
        _loading = false;
      });
    }
  }

  void _bindRoster(String? userId) {
    if (userId == null) return;
    final key = '${_squad?.id}|$userId';
    if (_rosterKey == key) return;
    _rosterKey = key;
    unawaited(_roster?.cancel());
    _roster = ref
        .read(squadRepositoryProvider)
        .watchRoster(squadId: _squad?.id, userId: userId)
        .listen((_) async {
          await _load(silent: true);
          if (!mounted) return;
          await ref
              .read(squadChatControllerProvider.notifier)
              .refreshFromRoster();
        });
  }

  bool _current(int generation, String? userId) {
    return mounted &&
        generation == _generation &&
        ref.read(authRepositoryProvider).currentUser?.id == userId;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(accountRevisionProvider, (previous, next) {
      if (previous != next) unawaited(_load(silent: _profile != null));
    });
    final removed = ref.watch(removedNoticeProvider);
    if (_loading && removed == null) {
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
    if (_squad == null || removed != null) {
      return SquadSetupScreen(
        profile: profile,
        notice: removed,
        onRefresh: () => _load(silent: true),
      );
    }
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
