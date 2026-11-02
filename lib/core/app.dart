import 'package:flutter/material.dart';
import 'package:squadsync/features/chat/ui/squad_chat_screen.dart';

class SquadSyncApp extends StatelessWidget {
  const SquadSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SquadSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2457D6)),
        useMaterial3: true,
      ),
      home: const SquadChatScreen(),
    );
  }
}
