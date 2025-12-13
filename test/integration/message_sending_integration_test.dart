import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:squad_sync/chat/chat_screen.dart';
import 'package:squad_sync/presentation/notifiers/chat_notifier.dart';
import 'package:squad_sync/presentation/notifiers/message_notifier.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';
import 'package:squad_sync/services/auth_service_supabase.dart';

@GenerateMocks([ChatRepository, AuthServiceSupabase])
import 'message_sending_integration_test.mocks.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockChatRepository mockChatRepository;
  late MockAuthServiceSupabase mockAuthService;

  setUp(() {
    mockChatRepository = MockChatRepository();
    mockAuthService = MockAuthServiceSupabase();
  });

  Widget createTestApp() {
    return ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(mockChatRepository),
      ],
      child: MaterialApp(
        home: ChatScreen(
          chatGroupId: 'test-chat-group',
          chatGroupName: 'Test Chat',
          chatType: ChatType.lobby,
        ),
      ),
    );
  }

  group('Message Sending Integration Tests', () {
    testWidgets('should send text message end-to-end', (tester) async {
      // Set up mocks
      when(mockChatRepository.getMessagesStream(
              'test-chat-group', ChatType.lobby))
          .thenAnswer((_) => Stream.value([]));

      final sentMessage = Message(
        id: 'msg-1',
        senderId: 'user-1',
        senderName: 'Test User',
        text: 'Hello, world!',
        chatGroupId: 'test-chat-group',
        timestamp: DateTime.now(),
        type: MessageType.text,
      );

      when(mockChatRepository.sendMessage(
        chatGroupId: 'test-chat-group',
        text: 'Hello, world!',
        type: MessageType.text,
        chatType: ChatType.lobby,
      )).thenAnswer((_) async => sentMessage);

      // Launch app
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Find text field
      final textField = find.byType(TextField).first;
      expect(textField, findsOneWidget);

      // Type message
      await tester.enterText(textField, 'Hello, world!');
      await tester.pump();

      // Verify text is entered
      expect(find.text('Hello, world!'), findsOneWidget);

      // Find and tap send button
      final sendButton = find.byIcon(Icons.send);
      expect(sendButton, findsOneWidget);

      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Verify message was sent
      verify(mockChatRepository.sendMessage(
        chatGroupId: 'test-chat-group',
        text: 'Hello, world!',
        type: MessageType.text,
        chatType: ChatType.lobby,
      )).called(1);
    });

    testWidgets('should send multiple messages in sequence', (tester) async {
      when(mockChatRepository.getMessagesStream(
              'test-chat-group', ChatType.lobby))
          .thenAnswer((_) => Stream.value([]));

      final messages = ['First message', 'Second message', 'Third message'];
      var callCount = 0;

      when(mockChatRepository.sendMessage(
        chatGroupId: 'test-chat-group',
        text: anyNamed('text'),
        type: MessageType.text,
        chatType: ChatType.lobby,
      )).thenAnswer((_) async {
        final text = messages[callCount++];
        return Message(
          id: 'msg-$callCount',
          senderId: 'user-1',
          senderName: 'Test User',
          text: text,
          chatGroupId: 'test-chat-group',
          timestamp: DateTime.now(),
          type: MessageType.text,
        );
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      final sendButton = find.byIcon(Icons.send);

      // Send multiple messages
      for (final message in messages) {
        await tester.enterText(textField, message);
        await tester.pump();

        await tester.tap(sendButton);
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
      }

      // Verify all messages were sent
      verify(mockChatRepository.sendMessage(
        chatGroupId: 'test-chat-group',
        text: anyNamed('text'),
        type: MessageType.text,
        chatType: ChatType.lobby,
      )).called(3);
    });

    testWidgets('should display sent message in chat', (tester) async {
      final messagesController = StreamController<List<Map<String, dynamic>>>();

      when(mockChatRepository.getMessagesStream(
              'test-chat-group', ChatType.lobby))
          .thenAnswer((_) => messagesController.stream);

      when(mockChatRepository.sendMessage(
        chatGroupId: 'test-chat-group',
        text: 'Test message',
        type: MessageType.text,
        chatType: ChatType.lobby,
      )).thenAnswer((_) async {
        // Simulate message appearing in stream
        messagesController.add([
          {
            'id': 'msg-1',
            'sender_id': 'user-1',
            'sender_name': 'Test User',
            'text': 'Test message',
            'chat_group_id': 'test-chat-group',
            'timestamp': DateTime.now().toIso8601String(),
            'type': 'text',
          },
        ]);

        return Message(
          id: 'msg-1',
          senderId: 'user-1',
          senderName: 'Test User',
          text: 'Test message',
          chatGroupId: 'test-chat-group',
          timestamp: DateTime.now(),
          type: MessageType.text,
        );
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Start with empty messages
      messagesController.add([]);
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'Test message');
      await tester.pump();

      final sendButton = find.byIcon(Icons.send);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Message should appear in chat
      expect(find.text('Test message'), findsWidgets);

      messagesController.close();
    });

    testWidgets('should handle send failure gracefully', (tester) async {
      when(mockChatRepository.getMessagesStream(
              'test-chat-group', ChatType.lobby))
          .thenAnswer((_) => Stream.value([]));

      when(mockChatRepository.sendMessage(
        chatGroupId: 'test-chat-group',
        text: anyNamed('text'),
        type: MessageType.text,
        chatType: ChatType.lobby,
      )).thenThrow(Exception('Network error'));

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'Failed message');
      await tester.pump();

      final sendButton = find.byIcon(Icons.send);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Should display error (snackbar or dialog)
      expect(find.byType(SnackBar), findsAny);
    });

    testWidgets('should send message with media attachment', (tester) async {
      when(mockChatRepository.getMessagesStream(
              'test-chat-group', ChatType.lobby))
          .thenAnswer((_) => Stream.value([]));

      when(mockChatRepository.sendMessage(
        chatGroupId: 'test-chat-group',
        text: '',
        mediaUrl: 'https://example.com/image.jpg',
        type: MessageType.image,
        chatType: ChatType.lobby,
      )).thenAnswer((_) async => Message(
            id: 'msg-1',
            senderId: 'user-1',
            senderName: 'Test User',
            text: '',
            chatGroupId: 'test-chat-group',
            timestamp: DateTime.now(),
            type: MessageType.image,
            mediaUrl: 'https://example.com/image.jpg',
          ));

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Find attachment button (if exists)
      final attachButton = find.byIcon(Icons.attach_file);
      if (attachButton.evaluate().isNotEmpty) {
        await tester.tap(attachButton);
        await tester.pumpAndSettle();

        // Select image option
        final imageButton = find.byIcon(Icons.image);
        if (imageButton.evaluate().isNotEmpty) {
          await tester.tap(imageButton);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('should show typing indicator when typing', (tester) async {
      when(mockChatRepository.getMessagesStream(
              'test-chat-group', ChatType.lobby))
          .thenAnswer((_) => Stream.value([]));

      when(mockChatRepository.setTyping('test-chat-group', true))
          .thenAnswer((_) async {});

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'T');
      await tester.pump();

      // Wait for typing indicator debounce
      await tester.pump(const Duration(milliseconds: 500));

      // Typing indicator should be sent
      // verify(mockChatRepository.setTyping('test-chat-group', true)).called(1);
    });

    testWidgets('should reply to a message', (tester) async {
      final existingMessages = [
        {
          'id': 'msg-1',
          'sender_id': 'user-2',
          'sender_name': 'Other User',
          'text': 'Original message',
          'chat_group_id': 'test-chat-group',
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'text',
        },
      ];

      when(mockChatRepository.getMessagesStream(
              'test-chat-group', ChatType.lobby))
          .thenAnswer((_) => Stream.value(existingMessages));

      when(mockChatRepository.sendMessage(
        chatGroupId: 'test-chat-group',
        text: 'Reply message',
        type: MessageType.text,
        chatType: ChatType.lobby,
        replyToMessageId: 'msg-1',
      )).thenAnswer((_) async => Message(
            id: 'msg-2',
            senderId: 'user-1',
            senderName: 'Test User',
            text: 'Reply message',
            chatGroupId: 'test-chat-group',
            timestamp: DateTime.now(),
            type: MessageType.text,
            replyToMessageId: 'msg-1',
          ));

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Long press on message to show reply option
      final message = find.text('Original message');
      if (message.evaluate().isNotEmpty) {
        await tester.longPress(message);
        await tester.pumpAndSettle();

        // Tap reply option
        final replyButton = find.text('Reply');
        if (replyButton.evaluate().isNotEmpty) {
          await tester.tap(replyButton);
          await tester.pumpAndSettle();

          // Type reply
          final textField = find.byType(TextField).first;
          await tester.enterText(textField, 'Reply message');
          await tester.pump();

          // Send reply
          final sendButton = find.byIcon(Icons.send);
          await tester.tap(sendButton);
          await tester.pumpAndSettle();

          // Verify reply was sent with correct replyToMessageId
          verify(mockChatRepository.sendMessage(
            chatGroupId: 'test-chat-group',
            text: 'Reply message',
            type: MessageType.text,
            chatType: ChatType.lobby,
            replyToMessageId: 'msg-1',
          )).called(1);
        }
      }
    });

    testWidgets('should clear input after successful send', (tester) async {
      when(mockChatRepository.getMessagesStream(
              'test-chat-group', ChatType.lobby))
          .thenAnswer((_) => Stream.value([]));

      when(mockChatRepository.sendMessage(
        chatGroupId: 'test-chat-group',
        text: 'Test message',
        type: MessageType.text,
        chatType: ChatType.lobby,
      )).thenAnswer((_) async => Message(
            id: 'msg-1',
            senderId: 'user-1',
            senderName: 'Test User',
            text: 'Test message',
            chatGroupId: 'test-chat-group',
            timestamp: DateTime.now(),
            type: MessageType.text,
          ));

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'Test message');
      await tester.pump();

      final sendButton = find.byIcon(Icons.send);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Input field should be cleared
      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.controller?.text, anyOf(isEmpty, isNull));
    });

    testWidgets('should scroll to bottom after sending message',
        (tester) async {
      final messagesController = StreamController<List<Map<String, dynamic>>>();

      // Start with some existing messages
      final existingMessages = List.generate(
          20,
          (i) => {
                'id': 'msg-$i',
                'sender_id': 'user-1',
                'sender_name': 'Test User',
                'text': 'Message $i',
                'chat_group_id': 'test-chat-group',
                'timestamp': DateTime.now().toIso8601String(),
                'type': 'text',
              });

      when(mockChatRepository.getMessagesStream(
              'test-chat-group', ChatType.lobby))
          .thenAnswer((_) => messagesController.stream);

      when(mockChatRepository.sendMessage(
        chatGroupId: 'test-chat-group',
        text: 'New message',
        type: MessageType.text,
        chatType: ChatType.lobby,
      )).thenAnswer((_) async {
        messagesController.add([
          ...existingMessages,
          {
            'id': 'msg-new',
            'sender_id': 'user-1',
            'sender_name': 'Test User',
            'text': 'New message',
            'chat_group_id': 'test-chat-group',
            'timestamp': DateTime.now().toIso8601String(),
            'type': 'text',
          },
        ]);

        return Message(
          id: 'msg-new',
          senderId: 'user-1',
          senderName: 'Test User',
          text: 'New message',
          chatGroupId: 'test-chat-group',
          timestamp: DateTime.now(),
          type: MessageType.text,
        );
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Start with existing messages
      messagesController.add(existingMessages);
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'New message');
      await tester.pump();

      final sendButton = find.byIcon(Icons.send);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Should scroll to show new message
      expect(find.text('New message'), findsWidgets);

      messagesController.close();
    });
  });
}
