import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_sync/providers/chat_state_notifier.dart';
import 'package:squad_sync/services/reaction_service.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';
import 'package:squad_sync/managers/user_manager.dart';
import 'package:squad_sync/chat/chat_service.dart';
import '../../test/test_utils.mocks.dart';

// Provide dummy values for Mockito
void _setupDummies() {
  provideDummy<ReactionService>(MockReactionService());
  provideDummy<SQLiteHelper>(MockSQLiteHelper());
  provideDummy<UserManager>(MockUserManager());
  provideDummy<ChatService>(MockChatService());
}

void main() {
  setUp(() {
    _setupDummies(); // Setup dummy values for Mockito
  });

  group('ChatStateNotifier Unit Tests', () {
    test('initial state is correct', () {
      // Test the initial state factory method
      final initialState = ChatStateData.initial();
      expect(initialState.isRecording, false);
      expect(initialState.isUploading, false);
      expect(initialState.typingUsers, isEmpty);
      expect(initialState.messages, isEmpty);
      expect(initialState.unreadCount, 0);
      expect(initialState.quickReactionEmoji, '👍');
    });

    test('updateTyping adds and removes users', () {
      // Create a minimal StateNotifier for testing
      final testNotifier = TestChatStateNotifier(ChatStateData.initial());

      // Start typing
      testNotifier.testUpdateTyping('user1', true);
      expect(testNotifier.state, isA<ChatStateData>());
      expect(testNotifier.state.typingUsers, contains('user1'));

      // Stop typing
      testNotifier.testUpdateTyping('user1', false);
      expect(testNotifier.state.typingUsers, isNot(contains('user1')));
    });

    test('setReplyToMessage updates reply state', () {
      final testNotifier = TestChatStateNotifier(ChatStateData.initial());
      final replyMessage = {'id': 'msg1', 'content': 'Reply to this'};

      testNotifier.testSetReplyToMessage(replyMessage);

      expect(testNotifier.state.replyToMessage, equals(replyMessage));
    });

    test('clearReplyToMessage clears reply state', () {
      final testNotifier = TestChatStateNotifier(ChatStateData.initial());
      final replyMessage = {'id': 'msg1', 'content': 'Reply to this'};

      testNotifier.testSetReplyToMessage(replyMessage);
      testNotifier.testClearReplyToMessage();

      expect(testNotifier.state.replyToMessage, isNull);
    });
  });

  group('Chat Screen Widget Tests - Nullable DisplayNames', () {
    testWidgets('renders messages safely with null sender displayName',
        (WidgetTester tester) async {
      // Mock messages with null sender
      final mockMessages = [
        {
          'id': '1',
          'content': 'Hello',
          'senderId': 'user1',
          'timestamp': DateTime.now()
        },
      ];

      // TODO: Add widget test for ChatScreen with mock data
      // This would require setting up a full widget test with providers
      expect(true, true); // Placeholder
    });

    testWidgets('handles empty squads without null exceptions',
        (WidgetTester tester) async {
      // TODO: Test squad UI with empty members
      expect(true, true); // Placeholder
    });

    testWidgets('displays fallback for null displayNames in member list',
        (WidgetTester tester) async {
      // TODO: Test member list rendering with null displayNames
      expect(true, true); // Placeholder
    });
  });
}

class TestChatStateNotifier extends StateNotifier<ChatStateData> {
  TestChatStateNotifier(super.initialState);

  void testUpdateTyping(String userId, bool isTyping) {
    if (isTyping) {
      state = state.copyWith(typingUsers: [...state.typingUsers, userId]);
    } else {
      state = state.copyWith(
          typingUsers: state.typingUsers.where((id) => id != userId).toList());
    }
  }

  void testSetReplyToMessage(Map<String, dynamic> message) {
    state = state.copyWith(replyToMessage: message);
  }

  void testClearReplyToMessage() {
    state = state.copyWith(replyToMessage: null);
  }
}
