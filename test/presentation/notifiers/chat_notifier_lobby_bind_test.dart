import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/lobby_chat_bind.dart';
import 'package:squad_sync/presentation/notifiers/chat_notifier.dart';

import 'chat_notifier_test.mocks.dart';
import 'package:squad_sync/core/injection.dart';

/// Slice G reds: ChatNotifier is the sole notifier writer of the active
/// lobby↔thread bind. It applies [switchActiveLobbyChatBind] — it does
/// not invent a second bind, and lobby_notifier / ChatScreen do not.
///
/// Loop: add `bindActiveLobbyChat` on ChatNotifier that calls the helper
/// then initializes the new thread. No chat_info_screen / message_bubble
/// rewrite. chat_screen.dart ≤40 lines if touched at all.
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(MockChatRepository()),
      ],
    );
  });

  tearDown(container.dispose);

  test(
    'ChatNotifier.bindActiveLobbyChat is the sole notifier writer of the bind',
    () async {
      await container.read(chatNotifierProvider.future);
      final notifier = container.read(chatNotifierProvider.notifier);

      notifier.bindActiveLobbyChat(
        lobbyId: 'lobby-a',
        lobbyChatGroupId: 'thread-a',
      );
      expect(notifier.activeLobbyChatBind.lobbyId, 'lobby-a');
      expect(notifier.activeLobbyChatBind.chatGroupId, 'thread-a');
      expect(notifier.activeLobbyChatBind.tornDownChatGroupId, isNull);

      notifier.bindActiveLobbyChat(
        lobbyId: 'lobby-b',
        lobbyChatGroupId: 'thread-b',
      );

      final bind = notifier.activeLobbyChatBind;
      expect(bind.lobbyId, 'lobby-b');
      expect(
        bind.chatGroupId,
        'thread-b',
        reason: 'switch binds Slice A chat_group_id of the new lobby',
      );
      expect(bind.tornDownChatGroupId, 'thread-a');
      expect(
        bind.steps.map((step) => step.action).toList(),
        [LobbyChatBindAction.teardown, LobbyChatBindAction.attach],
        reason: 'teardown previous thread before attaching the new bind',
      );
    },
  );

  test(
    'ChatNotifier applies switchActiveLobbyChatBind — not a second bind writer',
    () {
      final src =
          File('lib/presentation/notifiers/chat_notifier.dart').readAsStringSync();
      expect(src.contains('switchActiveLobbyChatBind'), isTrue);
      expect(src.contains('bindActiveLobbyChat'), isTrue);
      expect(src.contains('ActiveLobbyChatBind'), isTrue);
    },
  );

  test('lobby_notifier is not a writer of the active lobby↔thread bind', () {
    final src =
        File('lib/presentation/notifiers/lobby_notifier.dart').readAsStringSync();
    expect(src.contains('switchActiveLobbyChatBind'), isFalse);
    expect(src.contains('ActiveLobbyChatBind'), isFalse);
    expect(src.contains('bindActiveLobbyChat'), isFalse);
  });

  test('chat_info_screen and message_bubble do not write the bind', () {
    for (final path in const [
      'lib/chat/screens/chat_info_screen.dart',
      'lib/chat/message_bubble.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src.contains('switchActiveLobbyChatBind'), isFalse, reason: path);
      expect(src.contains('bindActiveLobbyChat'), isFalse, reason: path);
      expect(src.contains('ActiveLobbyChatBind'), isFalse, reason: path);
    }
  });
}
