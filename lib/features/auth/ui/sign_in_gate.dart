import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/auth/domain/auth_user.dart';
import 'package:squadsync/features/auth/ui/sign_in_screen.dart';
import 'package:squadsync/features/chat/ui/squad_chat_screen.dart';

final authUserProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchUser();
});

/// Sign-in until there is a session, then the squad chat.
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
        return const SquadChatScreen();
      },
    );
  }
}
