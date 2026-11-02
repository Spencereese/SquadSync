import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/auth/ui/sign_in_gate.dart';
import 'package:squadsync/features/chat/ui/squad_chat_screen.dart';

class SquadSyncApp extends ConsumerWidget {
  const SquadSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(squadSyncConfigProvider);
    return MaterialApp(
      title: 'SquadSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2457D6)),
        useMaterial3: true,
      ),
      home: config.isPresent ? const SignInGate() : const SquadChatScreen(),
    );
  }
}
