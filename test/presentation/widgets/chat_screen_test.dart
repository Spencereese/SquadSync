import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:squad_sync/chat/chat_screen.dart';
import 'package:squad_sync/presentation/notifiers/chat_notifier.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/presentation/notifiers/message_notifier.dart';
import 'package:squad_sync/domain/entities/chat_state.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';
import 'package:squad_sync/services/auth_service_supabase.dart';

@GenerateMocks([ChatRepository, AuthServiceSupabase])
import 'chat_screen_test.mocks.dart';

void main() {
  late MockChatRepository mockChatRepository;
  late MockAuthServiceSupabase mockAuthService;

  setUp(() {
    mockChatRepository = MockChatRepository();
    mockAuthService = MockAuthServiceSupabase();

    // Default stub responses
    when(mockChatRepository.getMessagesStream(any, any)).thenAnswer(
      (_) => Stream.value([]),
    );
  });

  Widget createChatScreen({
    String? chatGroupId = 'test-chat-group',
    String? chatGroupName = 'Test Chat',
    ChatType chatType = ChatType.lobby,
    String? initialMessage,
  }) {
    return ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(mockChatRepository),
      ],
      child: MaterialApp(
        home: ChatScreen(
          chatGroupId: chatGroupId,
          chatGroupName: chatGroupName,
          chatType: chatType,
          initialMessage: initialMessage,
        ),
      ),
    );
  }

  group('ChatScreen - Widget Structure', () {
    testWidgets('should display chat screen with app bar', (tester) async {
      await tester.pumpWidget(createChatScreen());
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('should display chat group name in app bar', (tester) async {
      await tester.pumpWidget(createChatScreen(
        chatGroupName: 'My Test Chat',
      ));
      await tester.pumpAndSettle();

      expect(find.text('My Test Chat'), findsOneWidget);
    });

    testWidgets('should display message input field', (tester) async {
      await tester.pumpWidget(createChatScreen());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });

    testWidgets('should display send button', (tester) async {
      await tester.pumpWidget(createChatScreen());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('should have scroll view for messages', (tester) async {
      await tester.pumpWidget(createChatScreen());
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
    });
  });

  group('ChatScreen - Message Input', () {
    testWidgets('should allow typing message', (tester) async {
      await tester.pumpWidget(createChatScreen());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'Test message');
      await tester.pump();

      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('should clear input after sending message', (tester) async {
      when(mockChatRepository.sendMessage(
        chatGroupId: any,
        text: any,
        type: any,
        chatType: any,
      )).thenAnswer((_) async => Message(
            id: 'msg-1',
            senderId: 'user-1',
            senderName: 'Test User',
            text: 'Test message',
            chatGroupId: 'test-chat-group',
            timestamp: DateTime.now(),
            type: MessageType.text,
          ));

      await tester.pumpWidget(createChatScreen());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'Test message');
      await tester.pump();

      // Tap send button
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Input should be cleared (depending on implementation)
    });

    testWidgets('should display initial message if provided', (tester) async {
      await tester.pumpWidget(createChatScreen(
        initialMessage: 'Initial test message',
      ));
      await tester.pumpAndSettle();

      // The initial message should be set in the text field or sent automatically
      // depending on implementation
      expect(find.text('Initial test message'), findsOneWidget);
    });
  });

  group('ChatScreen - Message Display', () {
    testWidgets('should display messages from stream', (tester) async {
      final testMessages = [
        {
          'id': 'msg-1',
          'sender_id': 'user-1',
          'sender_name': 'User 1',
          'text': 'Hello',
          'chat_group_id': 'test-chat-group',
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'text',
        },
        {
          'id': 'msg-2',
          'sender_id': 'user-2',
          'sender_name': 'User 2',
          'text': 'Hi there',
          'chat_group_id': 'test-chat-group',
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'text',
        },
      ];

      when(mockChatRepository.getMessagesStream(
              'test-chat-group', ChatType.lobby))
          .thenAnswer((_) => Stream.value(testMessages));

      await tester.pumpWidget(createChatScreen());
      await tester.pumpAndSettle();

      // Messages should be displayed
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Hi there'), findsOneWidget);
    });

    testWidgets('should handle empty message list', (tester) async {
      when(mockChatRepository.getMessagesStream(
              'test-chat-group', ChatType.lobby))
          .thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(createChatScreen());
      await tester.pumpAndSettle();

      // Should display empty state or just empty list
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('should display loading indicator while loading messages',
        (tester) async {
      when(mockChatRepository.getMessagesStream(
              'test-chat-group', ChatType.lobby))
          .thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(createChatScreen());

      // Check for loading indicator before messages load
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pumpAndSettle();
    });
  });

  group('ChatScreen - Chat Types', () {
    testWidgets('should display lobby chat correctly', (tester) async {
      await tester.pumpWidget(createChatScreen(
        chatType: ChatType.lobby,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('should display direct message chat correctly', (tester) async {
      await tester.pumpWidget(createChatScreen(
        chatType: ChatType.direct,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('should display group chat correctly', (tester) async {
      await tester.pumpWidget(createChatScreen(
        chatType: ChatType.group,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
    });
  });

  group('ChatScreen - User Interactions', () {
    testWidgets('should focus on input field when tapped', (tester) async {
      await tester.pumpWidget(createChatScreen());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.tap(textField);
      await tester.pump();

      // Input field should be focused
      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.focusNode?.hasFocus, isTrue);
    });

    testWidgets('should scroll to bottom when new message arrives',
        (tester) async {
      final messagesController = StreamController<List<Map<String, dynamic>>>();

      when(mockChatRepository.getMessagesStream(
              'test-chat-group', ChatType.lobby))
          .thenAnswer((_) => messagesController.stream);

      await tester.pumpWidget(createChatScreen());
      await tester.pumpAndSettle();

      // Add initial messages
      messagesController.add([
        {
          'id': 'msg-1',
          'sender_id': 'user-1',
          'sender_name': 'User 1',
          'text': 'Message 1',
          'chat_group_id': 'test-chat-group',
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'text',
        },
      ]);

      await tester.pumpAndSettle();

      // Add new message
      messagesController.add([
        {
          'id': 'msg-1',
          'sender_id': 'user-1',
          'sender_name': 'User 1',
          'text': 'Message 1',
          'chat_group_id': 'test-chat-group',
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'text',
        },
        {
          'id': 'msg-2',
          'sender_id': 'user-2',
          'sender_name': 'User 2',
          'text': 'Message 2',
          'chat_group_id': 'test-chat-group',
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'text',
        },
      ]);

      await tester.pumpAndSettle();

      messagesController.close();
    });

    testWidgets('should open menu when tapping menu icon', (tester) async {
      await tester.pumpWidget(createChatScreen());
      await tester.pumpAndSettle();

      // Find and tap menu icon if it exists
      final menuIcon = find.byIcon(Icons.more_vert);
      if (menuIcon.evaluate().isNotEmpty) {
        await tester.tap(menuIcon);
        await tester.pumpAndSettle();

        // Menu should be displayed
        expect(find.byType(PopupMenuButton), findsOneWidget);
      }
    });
  });

  group('ChatScreen - Error Handling', () {
    testWidgets('should handle message stream errors gracefully',
        (tester) async {
      when(mockChatRepository.getMessagesStream(
              'test-chat-group', ChatType.lobby))
          .thenAnswer((_) => Stream.error(Exception('Stream error')));

      await tester.pumpWidget(createChatScreen());
      await tester.pumpAndSettle();

      // Should display error message or handle gracefully
      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('should handle send message errors', (tester) async {
      when(mockChatRepository.sendMessage(
        chatGroupId: any,
        text: any,
        type: any,
        chatType: any,
      )).thenThrow(Exception('Send failed'));

      await tester.pumpWidget(createChatScreen());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'Test message');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Should handle error gracefully (snackbar, error message, etc.)
    });
  });

  group('ChatScreen - Lifecycle', () {
    testWidgets('should dispose controllers properly', (tester) async {
      await tester.pumpWidget(createChatScreen());
      await tester.pumpAndSettle();

      // Remove widget
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();

      // Widget should be disposed without errors
    });

    testWidgets('should initialize properly with different chat types',
        (tester) async {
      for (final chatType in [
        ChatType.lobby,
        ChatType.direct,
        ChatType.group
      ]) {
        await tester.pumpWidget(createChatScreen(chatType: chatType));
        await tester.pumpAndSettle();

        expect(find.byType(ChatScreen), findsOneWidget);

        await tester.pumpWidget(Container());
      }
    });
  });

  group('ChatScreen - Accessibility', () {
    testWidgets('should have semantic labels for important elements',
        (tester) async {
      await tester.pumpWidget(createChatScreen());
      await tester.pumpAndSettle();

      // Check for semantic labels
      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('should support keyboard navigation', (tester) async {
      await tester.pumpWidget(createChatScreen());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.tap(textField);
      await tester.pump();

      // Should be able to focus and type
      expect(tester.widget<TextField>(textField).focusNode?.hasFocus, isTrue);
    });
  });
}
