import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/chat/ui/squad_chat_controller.dart';

class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const Key('sign-out'),
      tooltip: 'Sign out',
      onPressed: () async {
        final pushes = ref.read(pushNotificationsProvider);
        final availability = await pushes.availability();
        if (availability.on) {
          await ref
              .read(pushTokenRepositoryProvider)
              .unregister(token: availability.token!);
          await pushes.deleteLocalToken();
        }
        ref.read(squadChatControllerProvider.notifier).abandon();
        await ref.read(authRepositoryProvider).signOut();
      },
      icon: const Icon(Icons.logout),
    );
  }
}
