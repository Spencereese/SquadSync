import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/core/misconfigured_screen.dart';
import 'package:squadsync/features/auth/ui/sign_in_gate.dart';
import 'package:squadsync/features/chat/ui/squad_chat_screen.dart';
import 'package:squadsync/features/push/ui/push_inbox.dart';

class SquadSyncApp extends ConsumerWidget {
  const SquadSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(appLinkProvider);
    final home = switch (link) {
      AppLink.demo => const SquadChatScreen(demo: true),
      AppLink.misconfigured => const MisconfiguredScreen(),
      AppLink.live => const SignInGate(),
    };
    return MaterialApp(
      title: 'SquadSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2457D6)),
        useMaterial3: true,
      ),
      home: Column(
        children: [
          const PushListener(),
          Expanded(
            child: RepaintBoundary(key: const Key('app-frame'), child: home),
          ),
        ],
      ),
    );
  }
}
