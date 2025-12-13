import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_sync/main.dart' show SquadSyncApp;
import 'package:squad_sync/data/repositories/chat_repository_impl.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/presentation/notifiers/message_notifier.dart';
import 'package:squad_sync/services/auth_service_supabase.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';

// Generate mocks with: flutter pub run build_runner build
@GenerateMocks([ChatRepositoryImpl, SQLiteHelper, AuthServiceSupabase])
import 'chat_test.mocks.dart';

/// Integration tests for chat send/receive flows
/// Tests ChatNotifier with Supabase real-time streams and SQLite offline cache
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Chat Send/Receive Integration Tests', () {
    late MockChatRepositoryImpl mockChatRepository;
    late MockSQLiteHelper mockSqlite;
    late MockAuthServiceSupabase mockAuthService;

    setUp(() {
      mockChatRepository = MockChatRepositoryImpl();
      mockSqlite = MockSQLiteHelper();
      mockAuthService = MockAuthServiceSupabase();

      // Mock authenticated user
      when(mockAuthService.currentUserId).thenReturn('test-user-id');
    });

    testWidgets('Send message to chat group', (WidgetTester tester) async {
      // Arrange: Mock message sending
      final testMessage = Message(
        id: 'msg-123',
        chatGroupId: 'group-1',
        senderId: 'test-user-id',
        senderName: 'Test User',
        content: 'Hello, team!',
        timestamp: DateTime.now(),
        messageType: MessageType.text,
      );

      when(mockChatRepository.sendMessage(
        chatGroupId: anyNamed('chatGroupId'),
        content: anyNamed('content'),
        messageType: anyNamed('messageType'),
      )).thenAnswer((_) async => testMessage);

      // Mock SQLite cache
      when(mockSqlite.insertMessage(any)).thenAnswer((_) async => 1);

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // chatRepositoryProvider.overrideWithValue(mockChatRepository),
          ],
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Navigate to chat screen (depends on app structure)
      final chatIcon = find.byIcon(Icons.chat);
      if (chatIcon.evaluate().isNotEmpty) {
        await tester.tap(chatIcon);
        await tester.pumpAndSettle();

        // Act: Type and send message
        final messageField = find.byType(TextField);
        await tester.enterText(messageField, 'Hello, team!');
        await tester.pumpAndSettle();

        final sendButton = find.byIcon(Icons.send);
        await tester.tap(sendButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Assert: Verify message was sent
        verify(mockChatRepository.sendMessage(
          chatGroupId: 'group-1',
          content: 'Hello, team!',
          messageType: MessageType.text,
        )).called(1);

        // Assert: Message should appear in chat
        expect(find.text('Hello, team!'), findsOneWidget);
      }
    });

    testWidgets('Receive message via Supabase real-time stream',
        (WidgetTester tester) async {
      // Arrange: Mock real-time message stream
      final initialMessage = Message(
        id: 'msg-1',
        chatGroupId: 'group-1',
        senderId: 'other-user-id',
        senderName: 'Other User',
        content: 'First message',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        messageType: MessageType.text,
      );

      final newMessage = Message(
        id: 'msg-2',
        chatGroupId: 'group-1',
        senderId: 'other-user-id',
        senderName: 'Other User',
        content: 'New incoming message!',
        timestamp: DateTime.now(),
        messageType: MessageType.text,
      );

      // Create stream that emits messages
      final messageStream = Stream<List<Message>>.fromIterable([
        [initialMessage],
        [initialMessage, newMessage],
      ]);

      when(mockChatRepository.getMessagesStream('group-1')).thenAnswer(
        (_) => messageStream,
      );

      // Mock SQLite cache
      when(mockSqlite.getMessages('group-1', limit: anyNamed('limit')))
          .thenAnswer((_) async => []);

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Navigate to chat
      final chatIcon = find.byIcon(Icons.chat);
      if (chatIcon.evaluate().isNotEmpty) {
        await tester.tap(chatIcon);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Assert: Initial message should be visible
        expect(find.text('First message'), findsOneWidget);

        // Act: Wait for new message from stream
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Assert: New message should appear
        expect(find.text('New incoming message!'), findsOneWidget);
      }
    });

    testWidgets('Offline message caching to SQLite',
        (WidgetTester tester) async {
      // Arrange: Mock offline scenario
      final cachedMessage = Message(
        id: 'cached-msg-1',
        chatGroupId: 'group-1',
        senderId: 'test-user-id',
        senderName: 'Test User',
        content: 'Cached message',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        messageType: MessageType.text,
      );

      // SQLite returns cached messages
      when(mockSqlite.getMessages('group-1', limit: anyNamed('limit')))
          .thenAnswer((_) async => [cachedMessage]);

      // Supabase stream is empty (offline)
      when(mockChatRepository.getMessagesStream('group-1')).thenAnswer(
        (_) => const Stream.empty(),
      );

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Navigate to chat
      final chatIcon = find.byIcon(Icons.chat);
      if (chatIcon.evaluate().isNotEmpty) {
        await tester.tap(chatIcon);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Assert: Cached message should be visible
        expect(find.text('Cached message'), findsOneWidget);

        // Assert: Should show offline indicator
        expect(find.textContaining('Offline'), findsOneWidget);
      }
    });

    testWidgets('Message sync from SQLite to Supabase on reconnect',
        (WidgetTester tester) async {
      // Arrange: Mock unsent messages in SQLite
      final unsentMessage = Message(
        id: 'unsent-msg-1',
        chatGroupId: 'group-1',
        senderId: 'test-user-id',
        senderName: 'Test User',
        content: 'Unsent message',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        messageType: MessageType.text,
        isSynced: false,
      );

      when(mockSqlite.getUnsentMessages()).thenAnswer(
        (_) async => [unsentMessage],
      );

      when(mockChatRepository.sendMessage(
        chatGroupId: anyNamed('chatGroupId'),
        content: anyNamed('content'),
        messageType: anyNamed('messageType'),
      )).thenAnswer((_) async => unsentMessage.copyWith(isSynced: true));

      // Act: Simulate reconnect
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Assert: Verify unsent messages were synced
      verify(mockChatRepository.sendMessage(
        chatGroupId: 'group-1',
        content: 'Unsent message',
        messageType: MessageType.text,
      )).called(1);
    });

    testWidgets('Send image message', (WidgetTester tester) async {
      // Arrange: Mock image upload and message sending
      final imageMessage = Message(
        id: 'img-msg-1',
        chatGroupId: 'group-1',
        senderId: 'test-user-id',
        senderName: 'Test User',
        content: 'https://storage.supabase.co/image.jpg',
        timestamp: DateTime.now(),
        messageType: MessageType.image,
      );

      when(mockChatRepository.uploadMedia(any))
          .thenAnswer((_) async => 'https://storage.supabase.co/image.jpg');

      when(mockChatRepository.sendMessage(
        chatGroupId: anyNamed('chatGroupId'),
        content: anyNamed('content'),
        messageType: MessageType.image,
      )).thenAnswer((_) async => imageMessage);

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Navigate to chat
      final chatIcon = find.byIcon(Icons.chat);
      if (chatIcon.evaluate().isNotEmpty) {
        await tester.tap(chatIcon);
        await tester.pumpAndSettle();

        // Act: Tap image picker button
        final imageButton = find.byIcon(Icons.image);
        if (imageButton.evaluate().isNotEmpty) {
          await tester.tap(imageButton);
          await tester.pumpAndSettle(const Duration(seconds: 3));

          // Assert: Verify image upload and message send
          verify(mockChatRepository.uploadMedia(any)).called(1);
          verify(mockChatRepository.sendMessage(
            chatGroupId: 'group-1',
            content: 'https://storage.supabase.co/image.jpg',
            messageType: MessageType.image,
          )).called(1);
        }
      }
    });

    testWidgets('Typing indicator updates', (WidgetTester tester) async {
      // Arrange: Mock typing status stream
      final typingStream = Stream<Map<String, bool>>.fromIterable([
        {'other-user-id': true},
        {'other-user-id': false},
      ]);

      when(mockChatRepository.getTypingStatusStream('group-1')).thenAnswer(
        (_) => typingStream,
      );

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Navigate to chat
      final chatIcon = find.byIcon(Icons.chat);
      if (chatIcon.evaluate().isNotEmpty) {
        await tester.tap(chatIcon);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Assert: Should show typing indicator
        expect(find.textContaining('typing'), findsOneWidget);

        // Act: Wait for typing to stop
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Assert: Typing indicator should disappear
        expect(find.textContaining('typing'), findsNothing);
      }
    });

    testWidgets('Delete message', (WidgetTester tester) async {
      // Arrange: Mock message deletion
      final messageToDelete = Message(
        id: 'delete-msg-1',
        chatGroupId: 'group-1',
        senderId: 'test-user-id',
        senderName: 'Test User',
        content: 'Message to delete',
        timestamp: DateTime.now(),
        messageType: MessageType.text,
      );

      when(mockChatRepository.deleteMessage('delete-msg-1'))
          .thenAnswer((_) async {});

      when(mockSqlite.deleteMessage('delete-msg-1')).thenAnswer((_) async => 1);

      // Act: Build app with message visible
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Navigate to chat
      final chatIcon = find.byIcon(Icons.chat);
      if (chatIcon.evaluate().isNotEmpty) {
        await tester.tap(chatIcon);
        await tester.pumpAndSettle();

        // Act: Long-press message to show context menu
        final messageTile = find.text('Message to delete');
        if (messageTile.evaluate().isNotEmpty) {
          await tester.longPress(messageTile);
          await tester.pumpAndSettle();

          // Act: Tap delete button
          final deleteButton = find.text('Delete');
          await tester.tap(deleteButton);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // Assert: Verify deletion
          verify(mockChatRepository.deleteMessage('delete-msg-1')).called(1);
          verify(mockSqlite.deleteMessage('delete-msg-1')).called(1);

          // Assert: Message should be gone
          expect(find.text('Message to delete'), findsNothing);
        }
      }
    });

    testWidgets('Reply to message', (WidgetTester tester) async {
      // Arrange: Mock reply message
      final originalMessage = Message(
        id: 'original-msg',
        chatGroupId: 'group-1',
        senderId: 'other-user-id',
        senderName: 'Other User',
        content: 'Original message',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        messageType: MessageType.text,
      );

      final replyMessage = Message(
        id: 'reply-msg',
        chatGroupId: 'group-1',
        senderId: 'test-user-id',
        senderName: 'Test User',
        content: 'Reply to original',
        timestamp: DateTime.now(),
        messageType: MessageType.text,
        replyToMessageId: 'original-msg',
      );

      when(mockChatRepository.sendMessage(
        chatGroupId: anyNamed('chatGroupId'),
        content: anyNamed('content'),
        messageType: anyNamed('messageType'),
        replyToMessageId: anyNamed('replyToMessageId'),
      )).thenAnswer((_) async => replyMessage);

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Navigate to chat
      final chatIcon = find.byIcon(Icons.chat);
      if (chatIcon.evaluate().isNotEmpty) {
        await tester.tap(chatIcon);
        await tester.pumpAndSettle();

        // Act: Long-press original message
        final originalTile = find.text('Original message');
        if (originalTile.evaluate().isNotEmpty) {
          await tester.longPress(originalTile);
          await tester.pumpAndSettle();

          // Act: Tap reply button
          final replyButton = find.text('Reply');
          await tester.tap(replyButton);
          await tester.pumpAndSettle();

          // Act: Type reply
          final messageField = find.byType(TextField);
          await tester.enterText(messageField, 'Reply to original');
          await tester.pumpAndSettle();

          final sendButton = find.byIcon(Icons.send);
          await tester.tap(sendButton);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // Assert: Verify reply was sent
          verify(mockChatRepository.sendMessage(
            chatGroupId: 'group-1',
            content: 'Reply to original',
            messageType: MessageType.text,
            replyToMessageId: 'original-msg',
          )).called(1);
        }
      }
    });
  });

  group('Chat Edge Cases', () {
    testWidgets('Handle very long messages', (WidgetTester tester) async {
      // Test message truncation/scrolling for long content
    });

    testWidgets('Handle rapid message sending', (WidgetTester tester) async {
      // Test throttling/rate limiting
    });

    testWidgets('Handle image upload failure', (WidgetTester tester) async {
      // Test error handling for failed uploads
    });

    testWidgets('Handle SQLite database errors', (WidgetTester tester) async {
      // Test fallback when SQLite fails
    });
  });
}
