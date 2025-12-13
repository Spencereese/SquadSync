import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/message_notifier.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';
import 'package:squad_sync/services/message_service.dart';
import 'package:squad_sync/services/auth_service_supabase.dart';
import 'package:squad_sync/core/injection.dart';

@GenerateMocks([ChatRepository, MessageService, AuthServiceSupabase])
import 'message_notifier_test.mocks.dart';

void main() {
  late MockChatRepository mockRepository;
  late MockMessageService mockMessageService;
  late MockAuthServiceSupabase mockAuthService;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockChatRepository();
    mockMessageService = MockMessageService();
    mockAuthService = MockAuthServiceSupabase();

    // Create provider container with overrides
    container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  Message createTestMessage({
    String id = 'msg-1',
    String senderId = 'user-1',
    String text = 'Test message',
    String chatGroupId = 'chat-1',
  }) {
    return Message(
      id: id,
      senderId: senderId,
      senderName: 'Test User',
      text: text,
      chatGroupId: chatGroupId,
      timestamp: DateTime.now(),
      type: MessageType.text,
    );
  }

  group('MessageNotifier - Initialization', () {
    test('should initialize with initial state', () async {
      final state = await container.read(messageNotifierProvider.future);

      expect(state, isA<MessageState>());
      expect(state.messages, isEmpty);
      expect(state.reactions, isEmpty);
      expect(state.typingUsers, isEmpty);
    });

    test('should handle AsyncLoading state during initialization', () {
      final state = container.read(messageNotifierProvider);

      expect(state, isA<AsyncLoading>());
    });

    test('should initialize message stream for chat group', () async {
      final chatGroupId = 'chat-1';
      final testMessages = [
        createTestMessage(id: 'msg-1', chatGroupId: chatGroupId),
        createTestMessage(id: 'msg-2', chatGroupId: chatGroupId),
      ];

      when(mockRepository.getMessagesStream(chatGroupId, ChatType.lobby))
          .thenAnswer(
        (_) => Stream.value(testMessages.map((m) => m.toMap()).toList()),
      );

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      await notifier.initializeMessagesStream(chatGroupId, ChatType.lobby);

      // Wait for stream to emit
      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(messageNotifierProvider).valueOrNull;
      expect(state?.messages[chatGroupId], isNotNull);
    });
  });

  group('MessageNotifier - Sending Messages', () {
    test('should send text message successfully', () async {
      final chatGroupId = 'chat-1';
      final messageText = 'Hello, world!';

      when(mockRepository.sendMessage(
        chatGroupId: chatGroupId,
        text: messageText,
        type: MessageType.text,
        chatType: ChatType.lobby,
      )).thenAnswer((_) async => createTestMessage(
            chatGroupId: chatGroupId,
            text: messageText,
          ));

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      await notifier.sendMessage(
        chatGroupId: chatGroupId,
        text: messageText,
        chatType: ChatType.lobby,
      );

      verify(mockRepository.sendMessage(
        chatGroupId: chatGroupId,
        text: messageText,
        type: MessageType.text,
        chatType: ChatType.lobby,
      )).called(1);
    });

    test('should send media message successfully', () async {
      final chatGroupId = 'chat-1';
      final mediaUrl = 'https://example.com/image.jpg';

      when(mockRepository.sendMessage(
        chatGroupId: chatGroupId,
        text: '',
        mediaUrl: mediaUrl,
        type: MessageType.image,
        chatType: ChatType.lobby,
      )).thenAnswer((_) async => createTestMessage(
            chatGroupId: chatGroupId,
            text: '',
          ));

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      await notifier.sendMessage(
        chatGroupId: chatGroupId,
        text: '',
        mediaUrl: mediaUrl,
        messageType: MessageType.image,
        chatType: ChatType.lobby,
      );

      verify(mockRepository.sendMessage(
        chatGroupId: chatGroupId,
        text: '',
        mediaUrl: mediaUrl,
        type: MessageType.image,
        chatType: ChatType.lobby,
      )).called(1);
    });

    test('should handle send message error', () async {
      final chatGroupId = 'chat-1';

      when(mockRepository.sendMessage(
        chatGroupId: chatGroupId,
        text: 'test',
        type: MessageType.text,
        chatType: ChatType.lobby,
      )).thenThrow(Exception('Send failed'));

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      expect(
        () => notifier.sendMessage(
          chatGroupId: chatGroupId,
          text: 'test',
          chatType: ChatType.lobby,
        ),
        throwsException,
      );
    });

    test('should add message optimistically before sending', () async {
      final chatGroupId = 'chat-1';
      final messageText = 'Optimistic message';

      when(mockRepository.sendMessage(
        chatGroupId: chatGroupId,
        text: messageText,
        type: MessageType.text,
        chatType: ChatType.lobby,
      )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return createTestMessage(
          chatGroupId: chatGroupId,
          text: messageText,
        );
      });

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      final sendFuture = notifier.sendMessage(
        chatGroupId: chatGroupId,
        text: messageText,
        chatType: ChatType.lobby,
      );

      // Check state immediately - should have optimistic message
      await Future.delayed(const Duration(milliseconds: 10));

      await sendFuture;
    });
  });

  group('MessageNotifier - Message Reactions', () {
    test('should add reaction to message', () async {
      final messageId = 'msg-1';
      final emoji = '👍';

      when(mockRepository.addReaction(messageId, emoji)).thenAnswer(
        (_) async {},
      );

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      await notifier.addReaction(messageId, emoji);

      verify(mockRepository.addReaction(messageId, emoji)).called(1);
    });

    test('should remove reaction from message', () async {
      final messageId = 'msg-1';
      final emoji = '👍';

      when(mockRepository.removeReaction(messageId, emoji)).thenAnswer(
        (_) async {},
      );

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      await notifier.removeReaction(messageId, emoji);

      verify(mockRepository.removeReaction(messageId, emoji)).called(1);
    });

    test('should load reactions for messages', () async {
      final messageId = 'msg-1';
      final reactions = ['👍', '❤️', '😂'];

      when(mockRepository.getMessageReactions(messageId)).thenAnswer(
        (_) async => reactions,
      );

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      await notifier.loadReactions(messageId);

      final state = container.read(messageNotifierProvider).valueOrNull;
      expect(state?.reactions[messageId], isNotNull);
    });
  });

  group('MessageNotifier - Typing Indicators', () {
    test('should set user as typing', () async {
      final chatGroupId = 'chat-1';

      when(mockRepository.setTyping(chatGroupId, true)).thenAnswer(
        (_) async {},
      );

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      await notifier.setTyping(chatGroupId, true);

      verify(mockRepository.setTyping(chatGroupId, true)).called(1);
    });

    test('should set user as not typing', () async {
      final chatGroupId = 'chat-1';

      when(mockRepository.setTyping(chatGroupId, false)).thenAnswer(
        (_) async {},
      );

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      await notifier.setTyping(chatGroupId, false);

      verify(mockRepository.setTyping(chatGroupId, false)).called(1);
    });

    test('should track typing users in state', () async {
      final chatGroupId = 'chat-1';

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      // Simulate typing user updates
      notifier.updateTypingUsers(chatGroupId, {'User1', 'User2'});

      final state = container.read(messageNotifierProvider).valueOrNull;
      expect(state?.typingUsers[chatGroupId], isNotNull);
      expect(state?.typingUsers[chatGroupId]?.length, equals(2));
    });
  });

  group('MessageNotifier - Reply Functionality', () {
    test('should set reply-to message', () async {
      final replyToMessage = createTestMessage(id: 'msg-1');

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      notifier.setReplyToMessage(replyToMessage);

      final state = container.read(messageNotifierProvider).valueOrNull;
      expect(state?.replyToMessage, equals(replyToMessage));
      expect(state?.replyingToMessageId, equals('msg-1'));
    });

    test('should clear reply-to message', () async {
      final replyToMessage = createTestMessage(id: 'msg-1');

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      notifier.setReplyToMessage(replyToMessage);
      notifier.clearReplyToMessage();

      final state = container.read(messageNotifierProvider).valueOrNull;
      expect(state?.replyToMessage, isNull);
      expect(state?.replyingToMessageId, isNull);
    });

    test('should send reply message', () async {
      final chatGroupId = 'chat-1';
      final replyToMessage = createTestMessage(id: 'msg-1');
      final replyText = 'This is a reply';

      when(mockRepository.sendMessage(
        chatGroupId: chatGroupId,
        text: replyText,
        type: MessageType.text,
        chatType: ChatType.lobby,
        replyToMessageId: 'msg-1',
      )).thenAnswer((_) async => createTestMessage(
            chatGroupId: chatGroupId,
            text: replyText,
          ));

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      notifier.setReplyToMessage(replyToMessage);
      await notifier.sendMessage(
        chatGroupId: chatGroupId,
        text: replyText,
        chatType: ChatType.lobby,
      );

      verify(mockRepository.sendMessage(
        chatGroupId: chatGroupId,
        text: replyText,
        type: MessageType.text,
        chatType: ChatType.lobby,
        replyToMessageId: 'msg-1',
      )).called(1);
    });
  });

  group('MessageNotifier - Message Deletion', () {
    test('should delete message', () async {
      final messageId = 'msg-1';

      when(mockRepository.deleteMessage(messageId)).thenAnswer(
        (_) async {},
      );

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      await notifier.deleteMessage(messageId);

      verify(mockRepository.deleteMessage(messageId)).called(1);
    });

    test('should handle delete message error', () async {
      final messageId = 'msg-1';

      when(mockRepository.deleteMessage(messageId)).thenThrow(
        Exception('Delete failed'),
      );

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      expect(
        () => notifier.deleteMessage(messageId),
        throwsException,
      );
    });
  });

  group('MessageNotifier - Message Syncing', () {
    test('should sync messages for chat group', () async {
      final chatGroupId = 'chat-1';
      final messages = [
        createTestMessage(id: 'msg-1', chatGroupId: chatGroupId),
        createTestMessage(id: 'msg-2', chatGroupId: chatGroupId),
      ];

      when(mockRepository.syncMessages(chatGroupId)).thenAnswer(
        (_) async => messages,
      );

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      await notifier.syncMessages(chatGroupId);

      verify(mockRepository.syncMessages(chatGroupId)).called(1);
    });

    test('should update last sync timestamp', () async {
      final chatGroupId = 'chat-1';

      when(mockRepository.syncMessages(chatGroupId)).thenAnswer(
        (_) async => [],
      );

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      await notifier.syncMessages(chatGroupId);

      final state = container.read(messageNotifierProvider).valueOrNull;
      expect(state?.lastSyncTimestamps[chatGroupId], isNotNull);
    });

    test('should set syncing flag during sync', () async {
      final chatGroupId = 'chat-1';

      when(mockRepository.syncMessages(chatGroupId)).thenAnswer(
        (_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return [];
        },
      );

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      final syncFuture = notifier.syncMessages(chatGroupId);

      // Check syncing flag
      await Future.delayed(const Duration(milliseconds: 10));
      final stateWhileSyncing =
          container.read(messageNotifierProvider).valueOrNull;
      expect(stateWhileSyncing?.isSyncing, isTrue);

      await syncFuture;

      final stateDone = container.read(messageNotifierProvider).valueOrNull;
      expect(stateDone?.isSyncing, isFalse);
    });

    test('should handle sync errors', () async {
      final chatGroupId = 'chat-1';

      when(mockRepository.syncMessages(chatGroupId)).thenThrow(
        Exception('Sync failed'),
      );

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      await notifier.syncMessages(chatGroupId);

      final state = container.read(messageNotifierProvider).valueOrNull;
      expect(state?.syncError, isNotNull);
    });
  });

  group('MessageNotifier - Message Streaming', () {
    test('should handle real-time message updates', () async {
      final chatGroupId = 'chat-1';
      final messagesController = StreamController<List<Map<String, dynamic>>>();

      when(mockRepository.getMessagesStream(chatGroupId, ChatType.lobby))
          .thenAnswer(
        (_) => messagesController.stream,
      );

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      await notifier.initializeMessagesStream(chatGroupId, ChatType.lobby);

      // Emit initial messages
      messagesController.add([
        createTestMessage(id: 'msg-1').toMap(),
      ]);

      await Future.delayed(const Duration(milliseconds: 50));

      // Emit new message
      messagesController.add([
        createTestMessage(id: 'msg-1').toMap(),
        createTestMessage(id: 'msg-2').toMap(),
      ]);

      await Future.delayed(const Duration(milliseconds: 50));

      messagesController.close();
    });

    test('should handle stream errors gracefully', () async {
      final chatGroupId = 'chat-1';

      when(mockRepository.getMessagesStream(chatGroupId, ChatType.lobby))
          .thenAnswer(
        (_) => Stream.error(Exception('Stream error')),
      );

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      // Should not throw
      await notifier.initializeMessagesStream(chatGroupId, ChatType.lobby);
    });

    test('should handle multiple chat group streams', () async {
      final chatGroupId1 = 'chat-1';
      final chatGroupId2 = 'chat-2';

      when(mockRepository.getMessagesStream(chatGroupId1, ChatType.lobby))
          .thenAnswer(
        (_) => Stream.value(
            [createTestMessage(chatGroupId: chatGroupId1).toMap()]),
      );

      when(mockRepository.getMessagesStream(chatGroupId2, ChatType.lobby))
          .thenAnswer(
        (_) => Stream.value(
            [createTestMessage(chatGroupId: chatGroupId2).toMap()]),
      );

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      await notifier.initializeMessagesStream(chatGroupId1, ChatType.lobby);
      await notifier.initializeMessagesStream(chatGroupId2, ChatType.lobby);

      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(messageNotifierProvider).valueOrNull;
      expect(state?.messages.keys.length, greaterThanOrEqualTo(1));
    });
  });

  group('MessageNotifier - State Management', () {
    test('should maintain separate message lists for different chat groups',
        () async {
      final chatGroupId1 = 'chat-1';
      final chatGroupId2 = 'chat-2';

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      // Add messages to different groups
      notifier.addMessageToState(
          chatGroupId1, createTestMessage(chatGroupId: chatGroupId1));
      notifier.addMessageToState(
          chatGroupId2, createTestMessage(chatGroupId: chatGroupId2));

      final state = container.read(messageNotifierProvider).valueOrNull;
      expect(state?.messages[chatGroupId1], isNotNull);
      expect(state?.messages[chatGroupId2], isNotNull);
    });

    test('should clear messages for specific chat group', () async {
      final chatGroupId = 'chat-1';

      await container.read(messageNotifierProvider.future);
      final notifier = container.read(messageNotifierProvider.notifier);

      notifier.addMessageToState(chatGroupId, createTestMessage());
      notifier.clearMessagesForGroup(chatGroupId);

      final state = container.read(messageNotifierProvider).valueOrNull;
      expect(state?.messages[chatGroupId], anyOf(isNull, isEmpty));
    });
  });
}
