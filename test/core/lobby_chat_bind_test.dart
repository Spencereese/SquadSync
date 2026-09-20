import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/lobby_chat_bind.dart';

/// Slice G reds: switching / opening a lobby tears down the previous chat
/// thread and binds THAT lobby's Slice A `chat_group_id`. No product
/// behavior in this commit — Loop greens in ≤3 lib files:
/// 1. [switchActiveLobbyChatBind] / [ActiveLobbyChatBind] in
///    `lib/core/lobby_chat_bind.dart` (prefer; sole bind helper)
/// 2. ChatNotifier applies the helper (`bindActiveLobbyChat`) — sole
///    notifier writer of the active lobby↔thread bind
/// 3. `lib/chat/chat_screen.dart` only if unavoidable and ≤40 lines
///    (call the helper / notifier — do not keep a parallel bind)
///
/// Do NOT rewrite `chat_info_screen` or `message_bubble`. Prefer NOT
/// `lobby_notifier`. Prefer NOT a chat_screen rewrite.
///
/// Friend taps / sees:
/// - Tonight lobby switch (dropdown / `/squad?lobby_id=`) unbinds the
///   previous Squad Chat thread, then shows the new lobby's thread
/// - Push / open of a lobby lands in THAT lobby's chat (Slice A
///   `lobbies.chat_group_id`), not leftover history from the last lobby
void main() {
  const previous = ActiveLobbyChatBind(
    lobbyId: 'lobby-a',
    chatGroupId: 'thread-a',
  );

  group('switchActiveLobbyChatBind — teardown then attach', () {
    test(
      'lobby switch tears down previous thread binding before attaching '
      'the new lobby chat_group_id',
      () {
        final next = switchActiveLobbyChatBind(
          current: previous,
          nextLobbyId: 'lobby-b',
          nextLobbyChatGroupId: 'thread-b',
        );

        expect(
          next.steps.map((step) => step.action).toList(),
          [LobbyChatBindAction.teardown, LobbyChatBindAction.attach],
          reason: 'previous thread must unbind before the new lobby attaches',
        );
        expect(next.steps[0].chatGroupId, 'thread-a');
        expect(next.steps[0].lobbyId, 'lobby-a');
        expect(next.steps[1].chatGroupId, 'thread-b');
        expect(next.steps[1].lobbyId, 'lobby-b');
        expect(next.tornDownChatGroupId, 'thread-a');
        expect(next.lobbyId, 'lobby-b');
        expect(next.chatGroupId, 'thread-b');
        expect(next.isBound, isTrue);
      },
    );

    test(
      'opening a lobby binds Slice A chat_group_id with no prior teardown',
      () {
        final opened = switchActiveLobbyChatBind(
          current: ActiveLobbyChatBind.empty,
          nextLobbyId: 'lobby-from-chat',
          nextLobbyChatGroupId: 'chat-friday',
        );

        expect(opened.lobbyId, 'lobby-from-chat');
        expect(
          opened.chatGroupId,
          'chat-friday',
          reason: 'createLobby persist/bind path (Slice A) is the thread',
        );
        expect(opened.tornDownChatGroupId, isNull);
        expect(opened.steps, hasLength(1));
        expect(opened.steps.single.action, LobbyChatBindAction.attach);
        expect(opened.steps.single.chatGroupId, 'chat-friday');
      },
    );

    test(
      'push/open of a different lobby lands in THAT lobby chat, not leftover',
      () {
        final opened = switchActiveLobbyChatBind(
          current: previous,
          nextLobbyId: 'lobby-9',
          nextLobbyChatGroupId: 'chat-9',
        );

        expect(opened.lobbyId, 'lobby-9');
        expect(opened.chatGroupId, 'chat-9');
        expect(opened.tornDownChatGroupId, 'thread-a');
        expect(opened.steps.first.action, LobbyChatBindAction.teardown);
        expect(opened.steps.last.action, LobbyChatBindAction.attach);
        expect(opened.chatGroupId, isNot(equals('thread-a')));
      },
    );

    test(
      'lobby switch does not keep the previous thread via leftover history',
      () {
        final next = switchActiveLobbyChatBind(
          current: previous,
          nextLobbyId: 'lobby-b',
          nextLobbyChatGroupId: 'thread-b',
          previousHistoryCounts: const {
            'thread-a': 46,
            'thread-b': 0,
          },
        );

        expect(
          next.chatGroupId,
          'thread-b',
          reason: 'Slice A chat_group_id wins over the previous lobby '
              'thread even when that thread has more history',
        );
        expect(next.lobbyId, 'lobby-b');
        expect(next.tornDownChatGroupId, 'thread-a');
      },
    );

    test('same lobby + same thread is a no-op (no teardown)', () {
      final same = switchActiveLobbyChatBind(
        current: previous,
        nextLobbyId: 'lobby-a',
        nextLobbyChatGroupId: 'thread-a',
      );

      expect(same.lobbyId, 'lobby-a');
      expect(same.chatGroupId, 'thread-a');
      expect(same.tornDownChatGroupId, isNull);
      expect(same.steps, isEmpty);
    });

    test(
      'blank next chat_group_id still tears down the previous bind',
      () {
        final cleared = switchActiveLobbyChatBind(
          current: previous,
          nextLobbyId: 'lobby-b',
          nextLobbyChatGroupId: '',
        );

        expect(cleared.steps.first.action, LobbyChatBindAction.teardown);
        expect(cleared.tornDownChatGroupId, 'thread-a');
        expect(cleared.lobbyId, 'lobby-b');
        expect(
          chatIdOrNull(cleared.chatGroupId),
          isNull,
          reason: 'do not keep thread-a after switching away',
        );
        expect(cleared.isBound, isFalse);
      },
    );
  });

  group('sole writer of the active lobby↔thread bind', () {
    test('bind helper / chat_notifier are the only allowed writers', () {
      expect(
        kActiveLobbyChatBindWriterPaths,
        {
          'lib/core/lobby_chat_bind.dart',
          'lib/presentation/notifiers/chat_notifier.dart',
        },
      );
      expect(
        kActiveLobbyChatBindWriterPaths,
        isNot(contains('lib/presentation/notifiers/lobby_notifier.dart')),
      );
      expect(
        kActiveLobbyChatBindWriterPaths,
        isNot(contains('lib/chat/chat_screen.dart')),
      );
      expect(
        kActiveLobbyChatBindWriterPaths,
        isNot(contains('lib/chat/screens/chat_info_screen.dart')),
      );
      expect(
        kActiveLobbyChatBindWriterPaths,
        isNot(contains('lib/chat/message_bubble.dart')),
      );
    });

    test('lib writers of ActiveLobbyChatBind stay on the helper/notifier', () {
      final hits = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final text = entity.readAsStringSync();
        if (text.contains('switchActiveLobbyChatBind') ||
            text.contains('ActiveLobbyChatBind(') ||
            text.contains('bindActiveLobbyChat(')) {
          hits.add(entity.path.replaceAll('\\', '/'));
        }
      }
      expect(
        hits.every(
          (path) =>
              path.endsWith('lib/core/lobby_chat_bind.dart') ||
              path.endsWith('lib/presentation/notifiers/chat_notifier.dart') ||
              path.endsWith('lib/chat/chat_screen.dart') ||
              path.endsWith('lib/core/deep_link_routes.dart') ||
              path.endsWith('lib/core/app_router.dart'),
        ),
        isTrue,
        reason: 'only helper + chat_notifier write the bind; '
            'chat_screen / applyLobbyDeepLink may call them',
      );
      expect(
        hits.any((path) => path.endsWith('lib/core/lobby_chat_bind.dart')),
        isTrue,
      );
      expect(
        hits.any(
          (path) =>
              path.endsWith('lib/presentation/notifiers/chat_notifier.dart'),
        ),
        isTrue,
        reason: 'ChatNotifier must apply switchActiveLobbyChatBind',
      );
    });
  });

  group('Slice G lease — no chat_info / message_bubble rewrite', () {
    const base = '0712929864f27468592ccea715bbc82bfc05508d';

    test('does not rewrite chat_info_screen or message_bubble', () {
      for (final path in const [
        'lib/chat/screens/chat_info_screen.dart',
        'lib/chat/message_bubble.dart',
      ]) {
        final diff = Process.runSync('git', ['diff', base, '--', path]);
        expect(diff.exitCode, 0, reason: path);
        expect(
          diff.stdout.toString().trim(),
          isEmpty,
          reason: 'Slice G must not rewrite $path',
        );
      }
    });

    test('chat_screen.dart is ≤40 lines if touched at all', () {
      final stat = Process.runSync(
        'git',
        ['diff', '--numstat', base, '--', 'lib/chat/chat_screen.dart'],
      );
      expect(stat.exitCode, 0);
      final line = stat.stdout.toString().trim();
      if (line.isEmpty) return;
      final parts = line.split(RegExp(r'\s+'));
      final added = int.parse(parts[0] == '-' ? '0' : parts[0]);
      final removed = int.parse(parts[1] == '-' ? '0' : parts[1]);
      expect(
        added + removed,
        lessThanOrEqualTo(40),
        reason: 'chat_screen.dart +$added/-$removed exceeds the ≤40 lease',
      );
    });
  });
}
