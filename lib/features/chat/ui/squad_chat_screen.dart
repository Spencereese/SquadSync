import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/auth/ui/sign_out_button.dart';
import 'package:squadsync/features/availability/ui/availability_controller.dart';
import 'package:squadsync/features/availability/ui/availability_screen.dart';
import 'package:squadsync/features/availability/ui/who_can_play_panel.dart';
import 'package:squadsync/features/invite/ui/invite_screen.dart';
import 'package:squadsync/features/chat/ui/message_bubble.dart';
import 'package:squadsync/features/chat/ui/squad_chat_controller.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';
import 'package:squadsync/features/squad/ui/member_strip.dart';

class SquadChatScreen extends ConsumerStatefulWidget {
  const SquadChatScreen({this.demo = false, super.key});

  final bool demo;

  @override
  ConsumerState<SquadChatScreen> createState() => _SquadChatScreenState();
}

class _SquadChatScreenState extends ConsumerState<SquadChatScreen>
    with WidgetsBindingObserver {
  var _boardOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(squadChatControllerProvider.notifier).open());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(
      ref.read(squadChatControllerProvider.notifier).refreshFromRoster(),
    );
    unawaited(ref.read(availabilityControllerProvider.notifier).refresh());
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
          if (squad != null && squad.ownerId == state.meId)
            IconButton(
              key: const Key('open-invite'),
              tooltip: 'Invite',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => InviteScreen(demo: widget.demo),
                  ),
                );
              },
              icon: const Icon(Icons.person_add_alt_1),
            ),
          if (squad != null)
            IconButton(
              key: const Key('open-availability'),
              tooltip: "Who's free",
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AvailabilityScreen(
                      squad: squad,
                      meId: state.meId,
                      demo: widget.demo,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.event_available),
            ),
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
          : _boardOpen
          ? Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    key: const Key('refresh-chat'),
                    onRefresh: _refreshHome,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (widget.demo) const _DemoBanner(),
                        if (state.linkDown) const _LinkDownBanner(),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Text(error, key: const Key('earlier-error')),
                          ),
                        _who(squad, state.meId),
                        MemberStrip(members: squad.members),
                      ],
                    ),
                  ),
                ),
                const _Composer(),
              ],
            )
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    key: const Key('refresh-chat'),
                    onRefresh: _refreshHome,
                    child: CustomScrollView(
                      key: const Key('home-scroll'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.demo) const _DemoBanner(),
                              if (state.linkDown) const _LinkDownBanner(),
                              if (error != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    0,
                                  ),
                                  child: Text(
                                    error,
                                    key: const Key('earlier-error'),
                                  ),
                                ),
                              _who(squad, state.meId),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                MemberStrip(members: squad.members),
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
                const SizedBox(height: 88, child: _MessageList()),
                const _Composer(),
              ],
            ),
    );
  }

  Widget _who(Squad squad, String meId) {
    return WhoCanPlayPanel(
      key: const Key('who-panel'),
      squad: squad,
      meId: meId,
      demo: widget.demo,
      showDemoLine: false,
      showRest: _boardOpen,
      onShowRest: (open) {
        if (!mounted) return;
        setState(() => _boardOpen = open);
      },
    );
  }

  Future<void> _refreshHome() async {
    await ref.read(squadChatControllerProvider.notifier).refreshFromRoster();
    await ref.read(availabilityControllerProvider.notifier).refresh();
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
    await showDialog<void>(
      context: context,
      builder: (context) => _ProfileDialog(
        displayName: mine.displayName,
        defaultGame: mine.defaultGame,
      ),
    );
  }
}

class _ProfileDialog extends ConsumerStatefulWidget {
  const _ProfileDialog({required this.displayName, required this.defaultGame});

  final String displayName;
  final String defaultGame;

  @override
  ConsumerState<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends ConsumerState<_ProfileDialog> {
  late final TextEditingController _name;
  late final TextEditingController _game;
  var _busy = false;
  String? _error;

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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const Key('profile-save-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('profile-save'),
          onPressed: _busy ? null : () => unawaited(_save()),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(squadRepositoryProvider)
          .saveProfile(displayName: _name.text, defaultGame: _game.text);
      final updated = await ref.read(squadRepositoryProvider).load();
      if (!mounted) return;
      ref.read(squadChatControllerProvider.notifier).replaceSquad(updated);
      Navigator.pop(context);
    } on RepositoryFailure {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save your name or game. Nothing was saved.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      return ListView(
        key: const Key('message-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 240, child: Center(child: Text('No messages yet'))),
        ],
      );
    }
    return ListView.builder(
      key: const Key('message-list'),
      reverse: true,
      physics: const AlwaysScrollableScrollPhysics(),
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
