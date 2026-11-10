import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/auth/ui/sign_out_button.dart';
import 'package:squadsync/features/availability/domain/who_can_play.dart';
import 'package:squadsync/features/availability/ui/availability_controller.dart';
import 'package:squadsync/features/availability/ui/availability_screen.dart';
import 'package:squadsync/features/availability/ui/who_can_play_panel.dart';
import 'package:squadsync/features/spot/ui/spot_controller.dart';
import 'package:squadsync/features/invite/ui/invite_screen.dart';
import 'package:squadsync/features/presence/ui/app_presence_controller.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/domain/messenger.dart';
import 'package:squadsync/features/chat/ui/message_bubble.dart';
import 'package:squadsync/features/chat/ui/squad_chat_controller.dart';
import 'package:squadsync/features/steam/ui/steam_link_field.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';
import 'package:squadsync/features/squad/ui/member_strip.dart';

enum SquadHomeView { who, chat }

/// Who's on until a thread is opened. A squad-message tap calls [openThread].
class SquadHomeViewController extends Notifier<SquadHomeView> {
  @override
  SquadHomeView build() => SquadHomeView.who;

  void openThread() => state = SquadHomeView.chat;

  void showWho() => state = SquadHomeView.who;

  void show(SquadHomeView view) => state = view;
}

final squadHomeViewProvider =
    NotifierProvider<SquadHomeViewController, SquadHomeView>(
      SquadHomeViewController.new,
    );

class SquadChatScreen extends ConsumerStatefulWidget {
  const SquadChatScreen({this.demo = false, super.key});

  final bool demo;

  @override
  ConsumerState<SquadChatScreen> createState() => _SquadChatScreenState();
}

class _SquadChatScreenState extends ConsumerState<SquadChatScreen>
    with WidgetsBindingObserver {
  AppPresenceController? _presence;

  @override
  void initState() {
    super.initState();
    _presence = ref.read(appPresenceControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(squadChatControllerProvider.notifier).open());
    });
  }

  @override
  void dispose() {
    final presence = _presence;
    _presence = null;
    if (presence != null) unawaited(presence.leave());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final presence = ref.read(appPresenceControllerProvider.notifier);
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(presence.leave());
    }
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(
      ref.read(squadChatControllerProvider.notifier).refreshFromRoster(),
    );
    unawaited(ref.read(availabilityControllerProvider.notifier).refresh());
    unawaited(ref.read(spotHomeProvider.notifier).refresh());
    ref.read(sessionRefreshProvider.notifier).bump();
    final chat = ref.read(squadChatControllerProvider);
    final squad = chat.squad;
    if (squad != null) {
      unawaited(presence.open(squadId: squad.id, userId: chat.meId));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(squadChatControllerProvider, (previous, next) {
      final id = next.squad?.id;
      final presence = ref.read(appPresenceControllerProvider.notifier);
      if (id == null) {
        if (previous?.squad != null) unawaited(presence.leave());
        return;
      }
      if (id == previous?.squad?.id) return;
      unawaited(presence.open(squadId: id, userId: next.meId));
      unawaited(ref.read(spotHomeProvider.notifier).open(id));
    });
    ref.listen(squadHomeViewProvider, (previous, next) {
      ref
          .read(squadChatControllerProvider.notifier)
          .setChatVisible(next == SquadHomeView.chat);
    });
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
          : KeyedSubtree(
              key: const Key('squad-home'),
              child: _views(squad, state, error),
            ),
    );
  }

  Widget _views(Squad squad, SquadChatState state, String? error) {
    final view = ref.watch(squadHomeViewProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedButton<SquadHomeView>(
            segments: [
              const ButtonSegment(
                value: SquadHomeView.who,
                label: Text("Who's on", key: Key('view-who')),
              ),
              ButtonSegment(
                value: SquadHomeView.chat,
                label: _ChatSegmentLabel(count: state.unread.of(squad.id)),
              ),
            ],
            selected: {view},
            showSelectedIcon: false,
            onSelectionChanged: (next) {
              ref.read(squadHomeViewProvider.notifier).show(next.first);
            },
          ),
        ),
        if (widget.demo) const _DemoBanner(),
        if (state.linkDown) const _LinkDownBanner(),
        if (state.messengerError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              state.messengerError!,
              key: const Key('messenger-error'),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(error, key: const Key('earlier-error')),
          ),
        if (view == SquadHomeView.who)
          Expanded(
            child: RefreshIndicator(
              key: const Key('refresh-chat'),
              onRefresh: _refreshHome,
              child: ListView(
                key: const Key('home-scroll'),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _who(squad, state.meId),
                  MemberStrip(members: squad.members),
                ],
              ),
            ),
          )
        else ...[
          _ChatSummary(
            onTap: () => ref.read(squadHomeViewProvider.notifier).showWho(),
          ),
          if (state.hasOlder)
            TextButton(
              key: const Key('earlier'),
              onPressed: () {
                unawaited(
                  ref.read(squadChatControllerProvider.notifier).loadOlder(),
                );
              },
              child: const Text('Earlier messages'),
            ),
          if (_firstUnread(state) != null)
            TextButton(
              key: const Key('jump-unread'),
              onPressed: () => _jumpUnread(context, _firstUnread(state)!),
              child: Text('${state.unread.of(squad.id)} unread'),
            ),
          Expanded(
            child: RefreshIndicator(
              key: const Key('refresh-chat'),
              onRefresh: _refreshHome,
              child: const _MessageList(),
            ),
          ),
          const _Composer(),
        ],
      ],
    );
  }

  String? _firstUnread(SquadChatState state) {
    if (state.squad == null || state.unread.of(state.squad!.id) <= 0) {
      return null;
    }
    return firstUnreadMessageId(
      messages: state.messages,
      meId: state.meId,
      readThroughId: state.readThroughId,
    );
  }

  void _jumpUnread(BuildContext context, String id) {
    context.visitChildElements((element) {
      _reveal(element, id);
    });
    unawaited(ref.read(squadChatControllerProvider.notifier).catchUp());
  }

  bool _reveal(Element element, String id) {
    if (element.widget.key == Key('message-$id')) {
      Scrollable.ensureVisible(element);
      return true;
    }
    var found = false;
    element.visitChildElements((child) {
      if (!found) found = _reveal(child, id);
    });
    return found;
  }

  Widget _who(Squad squad, String meId) {
    return WhoCanPlayPanel(
      key: const Key('who-panel'),
      squad: squad,
      meId: meId,
      demo: widget.demo,
      showDemoLine: false,
    );
  }

  Future<void> _refreshHome() async {
    await ref.read(squadChatControllerProvider.notifier).refreshFromRoster();
    await ref.read(availabilityControllerProvider.notifier).refresh();
    await ref.read(spotHomeProvider.notifier).refresh();
    ref.read(sessionRefreshProvider.notifier).bump();
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
          const SizedBox(height: 12),
          const SteamLinkField(),
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

class _ChatSummary extends ConsumerWidget {
  const _ChatSummary({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(availabilityControllerProvider);
    final board = state.board;
    final squad = state.squad;
    final summary = board == null || squad == null
        ? null
        : WhoCanPlay.group(board: board, members: squad.members).summary;
    return InkWell(
      key: const Key('chat-who-summary'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(summary ?? 'Who can play'),
      ),
    );
  }
}

class _ChatSegmentLabel extends StatelessWidget {
  const _ChatSegmentLabel({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 0 ? 'Chat, $count unread' : 'Chat';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Chat', key: Key('view-chat')),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Text('$count', key: const Key('unread-count')),
          ],
        ],
      ),
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
      return LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            key: const Key('message-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: const Center(
                  child: Text('No messages yet', key: Key('no-messages')),
                ),
              ),
            ],
          );
        },
      );
    }
    final lastMine = _lastMine(messages, state.meId);
    final names = <String, String>{
      for (final member in state.squad?.members ?? const <Member>[])
        member.id: member.displayName,
    };
    return ListView.builder(
      key: const Key('message-list'),
      reverse: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        final mine = message.senderId == state.meId;
        final seen = mine && message.id == lastMine
            ? seenByLine(
                seenByNames(
                  message: message,
                  thread: messages,
                  reads: state.messenger.reads,
                  names: names,
                  meId: state.meId,
                ),
              )
            : '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MessageBubble(
            message: message,
            mine: mine,
            chips: state.messenger.enabled
                ? reactionChips(
                    messageId: message.id,
                    reactions: state.messenger.reactions,
                    names: names,
                    meId: state.meId,
                  )
                : const [],
            seen: state.messenger.enabled ? seen : '',
            onLongPress: state.messenger.enabled
                ? () => _openReactions(context, ref, message)
                : () {
                    ref
                        .read(squadChatControllerProvider.notifier)
                        .quote(message);
                  },
            onToggle: (emoji) {
              unawaited(
                ref
                    .read(squadChatControllerProvider.notifier)
                    .react(message.id, emoji),
              );
            },
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

  String? _lastMine(List<ChatMessage> messages, String meId) {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].senderId == meId) return messages[i].id;
    }
    return null;
  }

  Future<void> _openReactions(
    BuildContext context,
    WidgetRef ref,
    ChatMessage message,
  ) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              for (final emoji in quickReactions)
                Semantics(
                  button: true,
                  label: 'React with ${reactionSpokenName[emoji]}',
                  child: IconButton(
                    key: Key('pick-$emoji'),
                    tooltip: reactionSpokenName[emoji],
                    onPressed: () => Navigator.of(context).pop(emoji),
                    icon: Text(emoji),
                  ),
                ),
              TextButton(
                key: const Key('pick-reply'),
                onPressed: () => Navigator.of(context).pop('reply'),
                child: const Text('Reply'),
              ),
            ],
          ),
        );
      },
    );
    if (emoji == null) return;
    if (emoji == 'reply') {
      ref.read(squadChatControllerProvider.notifier).quote(message);
      return;
    }
    await ref
        .read(squadChatControllerProvider.notifier)
        .react(message.id, emoji);
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
    final chat = ref.watch(squadChatControllerProvider);
    final names = <String, String>{
      for (final member in chat.squad?.members ?? const <Member>[])
        member.id: member.displayName,
    };
    final typing = typingLine(<String>[
      for (final id in chat.typing)
        if (id != chat.meId) names[id] ?? 'Someone',
    ]);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (typing.isNotEmpty)
              Semantics(
                liveRegion: true,
                label: typing,
                child: Text(typing, key: const Key('typing')),
              ),
            if (chat.replyText != null)
              Row(
                children: [
                  Expanded(
                    child: Text(chat.replyText!, key: const Key('replying-to')),
                  ),
                  IconButton(
                    key: const Key('reply-clear'),
                    tooltip: 'Cancel reply',
                    onPressed: () {
                      ref
                          .read(squadChatControllerProvider.notifier)
                          .clearQuote();
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            Row(
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
                    onChanged: (value) {
                      unawaited(
                        ref
                            .read(squadChatControllerProvider.notifier)
                            .setTyping(value.trim().isNotEmpty),
                      );
                    },
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
