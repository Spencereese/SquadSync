import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/auth/ui/sign_out_button.dart';
import 'package:squadsync/features/chat/ui/message_bubble.dart';
import 'package:squadsync/features/chat/ui/squad_chat_controller.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/ui/member_strip.dart';

class SquadChatScreen extends ConsumerStatefulWidget {
  const SquadChatScreen({this.demo = false, super.key});

  final bool demo;

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
      appBar: AppBar(
        title: Text(widget.demo ? 'SquadSync demo' : 'SquadSync'),
        actions: [
          if (!widget.demo && squad != null)
            IconButton(
              key: const Key('edit-profile'),
              tooltip: 'Your name and default game',
              onPressed: () => _editProfile(context, ref),
              icon: const Icon(Icons.person),
            ),
          if (!widget.demo) const SignOutButton(),
          if (squad != null)
            IconButton(
              key: const Key('reload-chat'),
              tooltip: 'Reload',
              onPressed: () {
                unawaited(
                  ref.read(squadChatControllerProvider.notifier).reload(),
                );
              },
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: squad == null
          ? Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : Text(error),
            )
          : Column(
              children: [
                if (widget.demo) const _DemoBanner(),
                if (state.linkDown) const _LinkDownBanner(),
                MemberStrip(members: squad.members),
                const Divider(height: 1),
                if (state.hasOlder)
                  TextButton(
                    key: const Key('earlier'),
                    onPressed: () {
                      unawaited(
                        ref
                            .read(squadChatControllerProvider.notifier)
                            .loadOlder(),
                      );
                    },
                    child: const Text('Earlier messages'),
                  ),
                const Expanded(child: _MessageList()),
                const _Composer(),
              ],
            ),
    );
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final squad = ref.read(squadChatControllerProvider).squad;
    final meId = ref.read(squadChatControllerProvider).meId;
    if (squad == null) return;
    Member? me;
    for (final member in squad.members) {
      if (member.id == meId) me = member;
    }
    final Member mine = me ?? squad.members.first;
    final saved = await showDialog<({String name, String game})>(
      context: context,
      builder: (context) => _ProfileDialog(
        displayName: mine.displayName,
        defaultGame: mine.defaultGame,
      ),
    );
    if (saved == null) return;
    try {
      await ref
          .read(squadRepositoryProvider)
          .saveProfile(displayName: saved.name, defaultGame: saved.game);
      final updated = await ref.read(squadRepositoryProvider).load();
      ref.read(squadChatControllerProvider.notifier).replaceSquad(updated);
    } on RepositoryFailure {
      // The chat screen keeps the previous profile. The next edit can retry.
    }
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.displayName, required this.defaultGame});

  final String displayName;
  final String defaultGame;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _name;
  late final TextEditingController _game;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.displayName);
    _game = TextEditingController(text: widget.defaultGame);
  }

  @override
  void dispose() {
    _name.dispose();
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('You'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('profile-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            key: const Key('profile-game'),
            controller: _game,
            decoration: const InputDecoration(labelText: 'Default game'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('profile-save'),
          onPressed: () => Navigator.pop(context, (
            name: _name.text,
            game: _game.text,
          )),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Color(0xFFFFF3CD),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          'Demo. Not connected. Messages stay on this phone.',
          key: Key('demo-banner'),
        ),
      ),
    );
  }
}

class _LinkDownBanner extends StatelessWidget {
  const _LinkDownBanner();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Color(0xFFFFE0E0),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          'Live updates stopped. Reload to fetch the thread.',
          key: Key('link-down'),
        ),
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
