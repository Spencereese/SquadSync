import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/chat_state.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/entities/chat_group.dart';

void main() {
  group('ChatState Entity', () {
    const testIsInitialized = true;
    const testIsInitialDataLoaded = true;
    const testDisplayName = 'Test User';
    const testProfileImage = 'https://example.com/profile.jpg';
    final testChatMessages = <String, List<Message>>{};
    final testChatGroups = <String, ChatGroup>{};
    final testUserChatGroups = <String, ChatGroup>{};
    const testSelectedChatGroupId = 'group1';
    final testLastReadTimestamps = {'group1': DateTime(2023, 12, 25, 10, 30)};
    final testTypingIndicators = {
      'group1': {'user2'}
    };
    final testUnreadCounts = {'group1': 5, 'group2': 2};
    final testHasNewMessages = {'group1': true, 'group2': false};
    final testMediaHistory = [
      {'url': 'https://example.com/image1.jpg', 'type': 'image'},
      {'url': 'https://example.com/image2.jpg', 'type': 'image'}
    ];
    final testPinnedMessages = {
      'group1': ['msg1', 'msg2']
    };
    final testActivePolls = <String, Map<String, Poll>>{};
    const testIsRecording = false;
    const testIsPlayingVoiceNote = true;
    const testCurrentVoiceNoteId = 'voice1';
    final testVoiceNoteProgress = {'voice1': 0.75};
    const testIsAiResponding = false;
    final testAiResponses = {'msg1': 'AI response'};
    const testShowEmojiPicker = false;
    const testShowAttachmentOptions = true;
    const testReplyingToMessageId = 'msg1';
    const testEditingMessageId = 'msg2';
    final testExpandedMessages = {'msg1': true, 'msg2': false};
    const testIsUploading = true;
    const testQuickReactionEmoji = '👍';
    const testQuickReactionEmojis = ['❤️', '👍', '😂'];
    const testTypingUser = 'user2';
    const testReplyToMessage = null;
    const testIsOnline = true;
    const testIsSyncing = false;
    final testLastSyncTimestamps = {'group1': DateTime(2023, 12, 25, 10, 30)};
    final testPendingMessages = [
      {'id': 'msg3', 'text': 'Pending message', 'groupId': 'group1'}
    ];
    const testSyncError = 'Connection failed';
    final testSyncConflicts = [
      {'messageId': 'msg1', 'conflictType': 'timestamp'}
    ];
    final testMessageAnalytics = {
      'msg1': {'views': 10, 'reactions': 5}
    };
    final testMessageReactions = {
      'msg1': [
        {
          'emoji': '👍',
          'userId': 'user1',
          'timestamp': DateTime(2023, 12, 25, 10, 35)
        }
      ]
    };
    final testSearchResults = <Message>[];
    const testSearchQuery = 'Hello';
    const testIsSearching = true;
    final testVoiceChatActive = {'group1': true, 'group2': false};
    final testVoiceChatParticipants = {
      'group1': ['user1', 'user2']
    };
    final testMutedChats = {'group2': true};
    final testPinnedChats = {'group1': true};
    final testChatThemes = {'group1': 'dark'};
    const testNotificationsEnabled = true;

    final testChatState = ChatState(
      isInitialized: testIsInitialized,
      isInitialDataLoaded: testIsInitialDataLoaded,
      displayName: testDisplayName,
      profileImage: testProfileImage,
      chatMessages: testChatMessages,
      chatGroups: testChatGroups,
      userChatGroups: testUserChatGroups,
      selectedChatGroupId: testSelectedChatGroupId,
      lastReadTimestamps: testLastReadTimestamps,
      typingIndicators: testTypingIndicators,
      unreadCounts: testUnreadCounts,
      hasNewMessages: testHasNewMessages,
      mediaHistory: testMediaHistory,
      pinnedMessages: testPinnedMessages,
      activePolls: testActivePolls,
      isRecording: testIsRecording,
      isPlayingVoiceNote: testIsPlayingVoiceNote,
      currentVoiceNoteId: testCurrentVoiceNoteId,
      voiceNoteProgress: testVoiceNoteProgress,
      isAiResponding: testIsAiResponding,
      aiResponses: testAiResponses,
      showEmojiPicker: testShowEmojiPicker,
      showAttachmentOptions: testShowAttachmentOptions,
      replyingToMessageId: testReplyingToMessageId,
      editingMessageId: testEditingMessageId,
      expandedMessages: testExpandedMessages,
      isUploading: testIsUploading,
      quickReactionEmoji: testQuickReactionEmoji,
      quickReactionEmojis: testQuickReactionEmojis,
      typingUser: testTypingUser,
      replyToMessage: testReplyToMessage,
      isOnline: testIsOnline,
      isSyncing: testIsSyncing,
      lastSyncTimestamps: testLastSyncTimestamps,
      pendingMessages: testPendingMessages,
      syncError: testSyncError,
      syncConflicts: testSyncConflicts,
      messageAnalytics: testMessageAnalytics,
      messageReactions: testMessageReactions,
      searchResults: testSearchResults,
      searchQuery: testSearchQuery,
      isSearching: testIsSearching,
      voiceChatActive: testVoiceChatActive,
      voiceChatParticipants: testVoiceChatParticipants,
      mutedChats: testMutedChats,
      pinnedChats: testPinnedChats,
      chatThemes: testChatThemes,
      notificationsEnabled: testNotificationsEnabled,
    );

    group('Constructor', () {
      test('should create ChatState with all required fields', () {
        expect(testChatState.isInitialized, testIsInitialized);
        expect(testChatState.isInitialDataLoaded, testIsInitialDataLoaded);
        expect(testChatState.displayName, testDisplayName);
        expect(testChatState.chatMessages, testChatMessages);
        expect(testChatState.chatGroups, testChatGroups);
        expect(testChatState.userChatGroups, testUserChatGroups);
        expect(testChatState.lastReadTimestamps, testLastReadTimestamps);
        expect(testChatState.typingIndicators, testTypingIndicators);
        expect(testChatState.unreadCounts, testUnreadCounts);
        expect(testChatState.hasNewMessages, testHasNewMessages);
        expect(testChatState.mediaHistory, testMediaHistory);
        expect(testChatState.pinnedMessages, testPinnedMessages);
        expect(testChatState.activePolls, testActivePolls);
        expect(testChatState.isRecording, testIsRecording);
        expect(testChatState.isPlayingVoiceNote, testIsPlayingVoiceNote);
        expect(testChatState.voiceNoteProgress, testVoiceNoteProgress);
        expect(testChatState.isAiResponding, testIsAiResponding);
        expect(testChatState.aiResponses, testAiResponses);
        expect(testChatState.showEmojiPicker, testShowEmojiPicker);
        expect(testChatState.showAttachmentOptions, testShowAttachmentOptions);
        expect(testChatState.expandedMessages, testExpandedMessages);
        expect(testChatState.isUploading, testIsUploading);
        expect(testChatState.quickReactionEmoji, testQuickReactionEmoji);
        expect(testChatState.quickReactionEmojis, testQuickReactionEmojis);
        expect(testChatState.isOnline, testIsOnline);
        expect(testChatState.isSyncing, testIsSyncing);
        expect(testChatState.lastSyncTimestamps, testLastSyncTimestamps);
        expect(testChatState.pendingMessages, testPendingMessages);
        expect(testChatState.syncConflicts, testSyncConflicts);
        expect(testChatState.messageAnalytics, testMessageAnalytics);
        expect(testChatState.messageReactions, testMessageReactions);
        expect(testChatState.searchResults, testSearchResults);
        expect(testChatState.searchQuery, testSearchQuery);
        expect(testChatState.isSearching, testIsSearching);
        expect(testChatState.voiceChatActive, testVoiceChatActive);
        expect(testChatState.voiceChatParticipants, testVoiceChatParticipants);
        expect(testChatState.mutedChats, testMutedChats);
        expect(testChatState.pinnedChats, testPinnedChats);
        expect(testChatState.chatThemes, testChatThemes);
        expect(testChatState.notificationsEnabled, testNotificationsEnabled);
      });

      test('should create ChatState with optional fields', () {
        expect(testChatState.profileImage, testProfileImage);
        expect(testChatState.selectedChatGroupId, testSelectedChatGroupId);
        expect(testChatState.currentVoiceNoteId, testCurrentVoiceNoteId);
        expect(testChatState.replyingToMessageId, testReplyingToMessageId);
        expect(testChatState.editingMessageId, testEditingMessageId);
        expect(testChatState.typingUser, testTypingUser);
        expect(testChatState.replyToMessage, testReplyToMessage);
        expect(testChatState.syncError, testSyncError);
      });
    });

    group('Factory initial', () {
      test('should create initial ChatState', () {
        final initialState = ChatState.initial();

        expect(initialState.isInitialized, false);
        expect(initialState.isInitialDataLoaded, false);
        expect(initialState.displayName, '');
        expect(initialState.chatMessages, {});
        expect(initialState.chatGroups, {});
        expect(initialState.userChatGroups, {});
        expect(initialState.lastReadTimestamps, {});
        expect(initialState.typingIndicators, {});
        expect(initialState.unreadCounts, {});
        expect(initialState.hasNewMessages, {});
        expect(initialState.mediaHistory, []);
        expect(initialState.pinnedMessages, {});
        expect(initialState.activePolls, {});
        expect(initialState.isRecording, false);
        expect(initialState.isPlayingVoiceNote, false);
        expect(initialState.voiceNoteProgress, {});
        expect(initialState.isAiResponding, false);
        expect(initialState.aiResponses, {});
        expect(initialState.showEmojiPicker, false);
        expect(initialState.showAttachmentOptions, false);
        expect(initialState.expandedMessages, {});
        expect(initialState.isUploading, false);
        expect(initialState.quickReactionEmoji, '👍');
        expect(initialState.quickReactionEmojis,
            ['❤️', '👍', '😂', '😢', '😡', '😮']);
        expect(initialState.typingUser, null);
        expect(initialState.replyToMessage, null);
        expect(initialState.isOnline, true);
        expect(initialState.isSyncing, false);
        expect(initialState.lastSyncTimestamps, {});
        expect(initialState.pendingMessages, []);
        expect(initialState.syncError, null);
        expect(initialState.syncConflicts, []);
        expect(initialState.messageAnalytics, {});
        expect(initialState.messageReactions, {});
        expect(initialState.searchResults, []);
        expect(initialState.searchQuery, '');
        expect(initialState.isSearching, false);
        expect(initialState.voiceChatActive, {});
        expect(initialState.voiceChatParticipants, {});
        expect(initialState.mutedChats, {});
        expect(initialState.pinnedChats, {});
        expect(initialState.chatThemes, {});
        expect(initialState.notificationsEnabled, true);
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final json = testChatState.toJson();

        expect(json['isInitialized'], testIsInitialized);
        expect(json['isInitialDataLoaded'], testIsInitialDataLoaded);
        expect(json['displayName'], testDisplayName);
        expect(json['profileImage'], testProfileImage);
        expect(json['selectedChatGroupId'], testSelectedChatGroupId);
        expect(json['isRecording'], testIsRecording);
        expect(json['isPlayingVoiceNote'], testIsPlayingVoiceNote);
        expect(json['currentVoiceNoteId'], testCurrentVoiceNoteId);
        expect(json['isAiResponding'], testIsAiResponding);
        expect(json['showEmojiPicker'], testShowEmojiPicker);
        expect(json['showAttachmentOptions'], testShowAttachmentOptions);
        expect(json['replyingToMessageId'], testReplyingToMessageId);
        expect(json['editingMessageId'], testEditingMessageId);
        expect(json['isUploading'], testIsUploading);
        expect(json['quickReactionEmoji'], testQuickReactionEmoji);
        expect(json['quickReactionEmojis'], testQuickReactionEmojis);
        expect(json['typingUser'], testTypingUser);
        expect(json['isOnline'], testIsOnline);
        expect(json['isSyncing'], testIsSyncing);
        expect(json['searchQuery'], testSearchQuery);
        expect(json['isSearching'], testIsSearching);
        expect(json['notificationsEnabled'], testNotificationsEnabled);
      });

      test('should deserialize from JSON correctly', () {
        final json = testChatState.toJson();
        final deserializedState = ChatState.fromJson(json);

        expect(deserializedState.isInitialized, testChatState.isInitialized);
        expect(deserializedState.displayName, testChatState.displayName);
        expect(deserializedState.isOnline, testChatState.isOnline);
      });

      test('should handle null optional fields in JSON', () {
        final minimalState = ChatState(
          isInitialized: false,
          isInitialDataLoaded: false,
          displayName: '',
          chatMessages: {},
          chatGroups: {},
          userChatGroups: {},
          lastReadTimestamps: {},
          typingIndicators: {},
          unreadCounts: {},
          hasNewMessages: {},
          mediaHistory: [],
          pinnedMessages: {},
          activePolls: {},
          isRecording: false,
          isPlayingVoiceNote: false,
          voiceNoteProgress: {},
          isAiResponding: false,
          aiResponses: {},
          showEmojiPicker: false,
          showAttachmentOptions: false,
          expandedMessages: {},
          isUploading: false,
          quickReactionEmoji: '👍',
          quickReactionEmojis: ['❤️', '👍', '😂'],
          isOnline: true,
          isSyncing: false,
          lastSyncTimestamps: {},
          pendingMessages: [],
          syncConflicts: [],
          messageAnalytics: {},
          messageReactions: {},
          searchResults: [],
          searchQuery: '',
          isSearching: false,
          voiceChatActive: {},
          voiceChatParticipants: {},
          mutedChats: {},
          pinnedChats: {},
          chatThemes: {},
          notificationsEnabled: true,
        );

        final json = minimalState.toJson();
        final deserialized = ChatState.fromJson(json);

        expect(deserialized.profileImage, isNull);
        expect(deserialized.selectedChatGroupId, isNull);
        expect(deserialized.currentVoiceNoteId, isNull);
        expect(deserialized.replyingToMessageId, isNull);
        expect(deserialized.editingMessageId, isNull);
        expect(deserialized.typingUser, isNull);
        expect(deserialized.replyToMessage, isNull);
        expect(deserialized.syncError, isNull);
      });
    });

    group('Equality and Hash', () {
      test('should be equal when all fields are the same', () {
        final anotherState = ChatState(
          isInitialized: testIsInitialized,
          isInitialDataLoaded: testIsInitialDataLoaded,
          displayName: testDisplayName,
          profileImage: testProfileImage,
          chatMessages: testChatMessages,
          chatGroups: testChatGroups,
          userChatGroups: testUserChatGroups,
          selectedChatGroupId: testSelectedChatGroupId,
          lastReadTimestamps: testLastReadTimestamps,
          typingIndicators: testTypingIndicators,
          unreadCounts: testUnreadCounts,
          hasNewMessages: testHasNewMessages,
          mediaHistory: testMediaHistory,
          pinnedMessages: testPinnedMessages,
          activePolls: testActivePolls,
          isRecording: testIsRecording,
          isPlayingVoiceNote: testIsPlayingVoiceNote,
          currentVoiceNoteId: testCurrentVoiceNoteId,
          voiceNoteProgress: testVoiceNoteProgress,
          isAiResponding: testIsAiResponding,
          aiResponses: testAiResponses,
          showEmojiPicker: testShowEmojiPicker,
          showAttachmentOptions: testShowAttachmentOptions,
          replyingToMessageId: testReplyingToMessageId,
          editingMessageId: testEditingMessageId,
          expandedMessages: testExpandedMessages,
          isUploading: testIsUploading,
          quickReactionEmoji: testQuickReactionEmoji,
          quickReactionEmojis: testQuickReactionEmojis,
          typingUser: testTypingUser,
          replyToMessage: testReplyToMessage,
          isOnline: testIsOnline,
          isSyncing: testIsSyncing,
          lastSyncTimestamps: testLastSyncTimestamps,
          pendingMessages: testPendingMessages,
          syncError: testSyncError,
          syncConflicts: testSyncConflicts,
          messageAnalytics: testMessageAnalytics,
          messageReactions: testMessageReactions,
          searchResults: testSearchResults,
          searchQuery: testSearchQuery,
          isSearching: testIsSearching,
          voiceChatActive: testVoiceChatActive,
          voiceChatParticipants: testVoiceChatParticipants,
          mutedChats: testMutedChats,
          pinnedChats: testPinnedChats,
          chatThemes: testChatThemes,
          notificationsEnabled: testNotificationsEnabled,
        );

        expect(testChatState, equals(anotherState));
        expect(testChatState.hashCode, equals(anotherState.hashCode));
      });

      test('should not be equal when displayName differs', () {
        final differentState =
            testChatState.copyWith(displayName: 'Different Name');

        expect(testChatState, isNot(equals(differentState)));
      });

      test('should not be equal when isOnline differs', () {
        final differentState = testChatState.copyWith(isOnline: false);

        expect(testChatState, isNot(equals(differentState)));
      });
    });

    group('CopyWith', () {
      test('should create copy with modified displayName', () {
        final copiedState = testChatState.copyWith(displayName: 'New Name');

        expect(copiedState.displayName, 'New Name');
        expect(copiedState.isInitialized, testIsInitialized); // unchanged
        expect(copiedState.isOnline, testIsOnline); // unchanged
      });

      test('should create copy with modified unreadCounts', () {
        final newUnreadCounts = {'group1': 10, 'group3': 1};
        final copiedState =
            testChatState.copyWith(unreadCounts: newUnreadCounts);

        expect(copiedState.unreadCounts, newUnreadCounts);
        expect(copiedState.displayName, testDisplayName); // unchanged
      });

      test('should create copy with null values', () {
        final copiedState = testChatState.copyWith(
          profileImage: null,
          selectedChatGroupId: null,
          syncError: null,
        );

        expect(copiedState.profileImage, isNull);
        expect(copiedState.selectedChatGroupId, isNull);
        expect(copiedState.syncError, isNull);
        expect(copiedState.displayName, testDisplayName); // unchanged
      });
    });

    group('Computed Properties', () {
      test('should return correct total unread count', () {
        final total = testChatState.unreadCounts.values
            .fold<int>(0, (sum, count) => sum + count);
        expect(total, 7); // 5 + 2
      });

      test('should return correct total unread count when empty', () {
        final emptyState = testChatState.copyWith(unreadCounts: {});
        final total = emptyState.unreadCounts.values
            .fold<int>(0, (sum, count) => sum + count);
        expect(total, 0);
      });

      test('should check if chat is muted', () {
        expect(testChatState.mutedChats['group2'], true);
        expect(testChatState.mutedChats['group1'], isNull);
      });

      test('should check if chat is pinned', () {
        expect(testChatState.pinnedChats['group1'], true);
        expect(testChatState.pinnedChats['group2'], isNull);
      });

      test('should get chat theme', () {
        expect(testChatState.chatThemes['group1'], 'dark');
        expect(testChatState.chatThemes['group2'], isNull);
      });

      test('should check if voice chat is active', () {
        expect(testChatState.voiceChatActive['group1'], true);
        expect(testChatState.voiceChatActive['group2'], false);
      });

      test('should get voice chat participants', () {
        expect(
            testChatState.voiceChatParticipants['group1'], ['user1', 'user2']);
        expect(testChatState.voiceChatParticipants['group3'], isNull);
      });

      test('should check if message is pinned', () {
        expect(testChatState.pinnedMessages['group1']?.contains('msg1'), true);
        expect(testChatState.pinnedMessages['group1']?.contains('msg3'), false);
      });

      test('should check if message is expanded', () {
        expect(testChatState.expandedMessages['msg1'], true);
        expect(testChatState.expandedMessages['msg3'], isNull);
      });

      test('should get active poll for group', () {
        expect(
            testChatState.activePolls['group1']?.containsKey('poll1'), isNull);
        expect(
            testChatState.activePolls['group1']?.containsKey('poll2'), isNull);
      });

      test('should check if user is typing in group', () {
        expect(
            testChatState.typingIndicators['group1']?.contains('user2'), true);
        expect(
            testChatState.typingIndicators['group1']?.contains('user3'), false);
      });
    });

    group('Edge Cases', () {
      test('should handle empty collections', () {
        final emptyState = testChatState.copyWith(
          chatMessages: {},
          unreadCounts: {},
          typingIndicators: {},
          pinnedMessages: {},
          activePolls: {},
          mediaHistory: [],
          pendingMessages: [],
          syncConflicts: [],
          searchResults: [],
          voiceChatParticipants: {},
        );

        expect(emptyState.chatMessages, isEmpty);
        expect(emptyState.unreadCounts, isEmpty);
        final total = emptyState.unreadCounts.values
            .fold<int>(0, (sum, count) => sum + count);
        expect(total, 0);
      });

      test('should handle null optional fields', () {
        final minimalState = ChatState(
          isInitialized: false,
          isInitialDataLoaded: false,
          displayName: '',
          chatMessages: {},
          chatGroups: {},
          userChatGroups: {},
          lastReadTimestamps: {},
          typingIndicators: {},
          unreadCounts: {},
          hasNewMessages: {},
          mediaHistory: [],
          pinnedMessages: {},
          activePolls: {},
          isRecording: false,
          isPlayingVoiceNote: false,
          voiceNoteProgress: {},
          isAiResponding: false,
          aiResponses: {},
          showEmojiPicker: false,
          showAttachmentOptions: false,
          expandedMessages: {},
          isUploading: false,
          quickReactionEmoji: '👍',
          quickReactionEmojis: ['❤️', '👍', '😂'],
          isOnline: true,
          isSyncing: false,
          lastSyncTimestamps: {},
          pendingMessages: [],
          syncConflicts: [],
          messageAnalytics: {},
          messageReactions: {},
          searchResults: [],
          searchQuery: '',
          isSearching: false,
          voiceChatActive: {},
          voiceChatParticipants: {},
          mutedChats: {},
          pinnedChats: {},
          chatThemes: {},
          notificationsEnabled: true,
        );

        expect(minimalState.profileImage, isNull);
        expect(minimalState.selectedChatGroupId, isNull);
        expect(minimalState.currentVoiceNoteId, isNull);
        expect(minimalState.replyingToMessageId, isNull);
        expect(minimalState.editingMessageId, isNull);
        expect(minimalState.typingUser, isNull);
        expect(minimalState.replyToMessage, isNull);
        expect(minimalState.syncError, isNull);
      });

      test('should handle zero values', () {
        final zeroState = testChatState.copyWith(
          unreadCounts: {'group1': 0},
          pendingMessages: [],
          voiceNoteProgress: {'voice1': 0.0},
        );

        final total = zeroState.unreadCounts.values
            .fold<int>(0, (sum, count) => sum + count);
        expect(total, 0);
        expect(zeroState.pendingMessages, isEmpty);
      });

      test('should handle single item collections', () {
        final singleState = testChatState.copyWith(
          quickReactionEmojis: ['👍'],
          typingIndicators: {
            'group1': {'user1'}
          },
          unreadCounts: {'group1': 1},
        );

        expect(singleState.quickReactionEmojis, hasLength(1));
        final total = singleState.unreadCounts.values
            .fold<int>(0, (sum, count) => sum + count);
        expect(total, 1);
      });
    });
  });
}
