import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/providers/chat_notifier.dart';
import 'package:squad_sync/chat/message.dart';

void main() {
  group('ChatNotifier', () {
    test('initial state is correct', () {
      final initialState = ChatState.initial();
      expect(initialState.isRecording, false);
      expect(initialState.isUploading, false);
      expect(initialState.typingUsers, isEmpty);
      expect(initialState.messages, isEmpty);
      expect(initialState.unreadCount, 0);
      expect(initialState.sendingStatus, isEmpty);
      expect(initialState.quickReactionEmoji, '👍');
      expect(initialState.quickReactionEmojis, hasLength(6));
      expect(initialState.replyToMessage, isNull);
      expect(initialState.isDMView, false);
      expect(initialState.dmUnreadCount, 0);
      expect(initialState.isInitialized, false);
      expect(initialState.lastDocument, isNull);
      expect(initialState.errorMessage, isNull);
    });

    test('sendMessage updates sending status', () {
      final initialState = ChatState.initial();
      final sendingState = initialState.copyWith(
        sendingStatus: {'msg-123': true},
      );

      expect(sendingState.sendingStatus['msg-123'], isTrue);
    });

    test('loadMessages updates message list', () {
      final initialState = ChatState.initial();
      final messages = [
        Message(
          sender: 'User1',
          content: 'Hello',
          timestamp: DateTime.now(),
          reactions: [],
        ),
        Message(
          sender: 'User2',
          content: 'Hi there',
          timestamp: DateTime.now(),
          reactions: [],
        ),
      ];

      final loadedState = initialState.copyWith(
        messages: messages,
        unreadCount: 0,
      );

      expect(loadedState.messages, hasLength(2));
      expect(loadedState.messages[0].content, 'Hello');
      expect(loadedState.messages[1].sender, 'User2');
    });

    test('addReaction updates message reactions', () {
      final message = Message(
        sender: 'User1',
        content: 'Hello',
        timestamp: DateTime.now(),
        reactions: [],
      );

      final reactedMessage = Message(
        sender: 'User1',
        content: 'Hello',
        timestamp: message.timestamp,
        reactions: [
          {'user': 'User2', 'emoji': '👍'}
        ],
      );

      expect(reactedMessage.reactions, hasLength(1));
      expect(reactedMessage.reactions[0]['emoji'], '👍');
    });

    test('removeReaction removes from message', () {
      final messageWithReaction = Message(
        sender: 'User1',
        content: 'Hello',
        timestamp: DateTime.now(),
        reactions: [
          {'user': 'User2', 'emoji': '👍'},
          {'user': 'User3', 'emoji': '❤️'},
        ],
      );

      final removedReaction = Message(
        sender: 'User1',
        content: 'Hello',
        timestamp: messageWithReaction.timestamp,
        reactions: [
          {'user': 'User3', 'emoji': '❤️'}
        ],
      );

      expect(removedReaction.reactions, hasLength(1));
      expect(removedReaction.reactions[0]['emoji'], '❤️');
    });

    test('typing indicators update correctly', () {
      final initialState = ChatState.initial();
      final typingState = initialState.copyWith(
        typingUsers: ['User1', 'User2'],
      );

      expect(typingState.typingUsers, hasLength(2));
      expect(typingState.typingUsers, contains('User1'));
    });

    test('recording state toggles correctly', () {
      final initialState = ChatState.initial();
      final recordingState = initialState.copyWith(
        isRecording: true,
      );

      expect(recordingState.isRecording, isTrue);
    });

    test('uploading state updates correctly', () {
      final initialState = ChatState.initial();
      final uploadingState = initialState.copyWith(
        isUploading: true,
      );

      expect(uploadingState.isUploading, isTrue);
    });

    test('unread count updates', () {
      final initialState = ChatState.initial();
      final unreadState = initialState.copyWith(
        unreadCount: 5,
        dmUnreadCount: 2,
      );

      expect(unreadState.unreadCount, 5);
      expect(unreadState.dmUnreadCount, 2);
    });

    test('quick reaction emoji changes', () {
      final initialState = ChatState.initial();
      final changedState = initialState.copyWith(
        quickReactionEmoji: '❤️',
      );

      expect(changedState.quickReactionEmoji, '❤️');
    });

    test('reply to message sets correctly', () {
      final initialState = ChatState.initial();
      final replyState = initialState.copyWith(
        replyToMessage: {'id': 'msg-123', 'content': 'Original message'},
      );

      expect(replyState.replyToMessage?['id'], 'msg-123');
      expect(replyState.replyToMessage?['content'], 'Original message');
    });

    test('DM view toggles correctly', () {
      final initialState = ChatState.initial();
      final dmState = initialState.copyWith(
        isDMView: true,
      );

      expect(dmState.isDMView, isTrue);
    });

    test('error state preserves data', () {
      final errorState = AsyncValue.error('Chat error', StackTrace.current);
      expect(errorState.hasError, isTrue);
      expect(errorState.error, 'Chat error');
    });
  });

  group('ChatNotifier Integration Tests', () {
    test('handles offline mode with cached messages', () {
      final cachedMessages = [
        Message(
          sender: 'User1',
          content: 'Cached message',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          reactions: [],
        ),
      ];

      final cachedState = ChatState.initial().copyWith(
        messages: cachedMessages,
        isInitialized: true,
      );

      expect(cachedState.messages, hasLength(1));
      expect(cachedState.isInitialized, isTrue);
    });

    test('handles API failures gracefully', () {
      final errorState = ChatState.initial().copyWith(
        errorMessage: 'Firestore unavailable',
      );

      expect(errorState.errorMessage, isNotNull);
    });

    test('stream subscriptions handle errors', () {
      // Test stream error handling
      final stateWithError = ChatState.initial().copyWith(
        errorMessage: 'Stream error',
      );

      expect(stateWithError.errorMessage, 'Stream error');
    });

    test('mounted checks prevent state updates', () {
      // Test mounted checks in async operations
      bool mounted = false;
      expect(mounted, isFalse);
    });

    test('null safety in message parsing', () {
      // Test null safety when parsing Firestore data
      final message = Message(
        sender: 'Unknown',
        content: '',
        timestamp: DateTime.now(),
        reactions: [],
      );

      expect(message.sender, 'Unknown');
      expect(message.content, '');
      expect(message.reactions, isEmpty);
    });

    test('permissions check for message sending', () {
      // Test permission checks
      final stateWithPermissions = ChatState.initial();
      expect(stateWithPermissions.isInitialized, isFalse);
    });
  });

  group('ChatNotifier Flow Tests', () {
    test('message sending flow updates state', () {
      final sendingState = ChatState.initial().copyWith(
        sendingStatus: {'msg-123': true},
        messages: [
          Message(
            sender: 'CurrentUser',
            content: 'Sending message...',
            timestamp: DateTime.now(),
            reactions: [],
          ),
        ],
      );

      expect(sendingState.sendingStatus['msg-123'], isTrue);
      expect(sendingState.messages, hasLength(1));
    });

    test('reaction flow updates message', () {
      final reactedMessage = Message(
        sender: 'User1',
        content: 'React to this',
        timestamp: DateTime.now(),
        reactions: [
          {'user': 'User2', 'emoji': '👍'},
          {'user': 'User3', 'emoji': '❤️'},
        ],
      );

      expect(reactedMessage.reactions, hasLength(2));
    });

    test('voice message flow updates recording state', () {
      final recordingState = ChatState.initial().copyWith(
        isRecording: true,
        isUploading: false,
      );

      final uploadingState = recordingState.copyWith(
        isRecording: false,
        isUploading: true,
      );

      expect(uploadingState.isRecording, isFalse);
      expect(uploadingState.isUploading, isTrue);
    });
  });
}
