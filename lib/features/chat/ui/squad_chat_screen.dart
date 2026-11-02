import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/features/chat/ui/message_bubble.dart';
import 'package:squadsync/features/chat/ui/squad_chat_controller.dart';
import 'package:squadsync/features/squad/ui/member_strip.dart';

class SquadChatScreen extends ConsumerStatefulWidget {
  const SquadChatScreen({super.key});

  @override
  ConsumerState<SquadChatScreen> createState() => _SquadChatScreenState();
}

class _SquadChatScreenState extends ConsumerState<SquadChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(squadChatControllerProvider.notifier).open());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(squadChatControllerProvider);
    final squad = state.squad;
    final error = state.error;
    return Scaffold(
      appBar: AppBar(title: const Text('SquadSync')),
      body: squad == null
          ? Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : Text(error),
            )
          : Column(
              children: [
                MemberStrip(members: squad.members),
                const Divider(height: 1),
                const Expanded(child: _MessageList()),
                const _Composer(),
              ],
            ),
    );
  }
}

class _MessageList extends ConsumerWidget {
  const _MessageList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(squadChatControllerProvider);
    final messages = state.messages;
    if (messages.isEmpty) {
      return const Center(child: Text('No messages yet'));
    }
    return ListView.builder(
      key: const Key('message-list'),
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MessageBubble(
            message: message,
            mine: message.senderId == state.meId,
            onRetry: (id) {
              unawaited(
                ref.read(squadChatControllerProvider.notifier).retry(id),
              );
            },
          ),
        );
      },
    );
  }
}

class _Composer extends ConsumerStatefulWidget {
  const _Composer();

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('composer'),
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Message the squad',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
              ),
            ),
            IconButton(
              key: const Key('send-button'),
              tooltip: 'Send',
              onPressed: () => _send(_controller.text),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  void _send(String text) {
    final body = text.trim();
    if (body.isEmpty) return;
    _controller.clear();
    unawaited(ref.read(squadChatControllerProvider.notifier).send(body));
  }
}
