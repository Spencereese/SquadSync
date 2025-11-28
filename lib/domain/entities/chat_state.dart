import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/entities/chat_group.dart';

part 'chat_state.freezed.dart';

@freezed
class ChatState with _$ChatState {
  const factory ChatState({
    required bool isInitialized,
    required bool isInitialDataLoaded,
    required String displayName,
    String? profileImage,

    // Messages and groups
    required Map<String, List<Message>> chatMessages, // chatGroupId -> messages
    required Map<String, ChatGroup> chatGroups,
    required Map<String, ChatGroup> userChatGroups,
    String? selectedChatGroupId,
    required Map<String, DateTime> lastReadTimestamps,

    // Real-time state
    required Map<String, Set<String>>
        typingIndicators, // chatGroupId -> typing user UIDs
    required Map<String, int> unreadCounts, // chatGroupId -> unread count
    required Map<String, bool> hasNewMessages,

    // Media and attachments
    required List<Map<String, dynamic>> mediaHistory,
    required Map<String, List<String>>
        pinnedMessages, // chatGroupId -> pinned message IDs
    required Map<String, Map<String, dynamic>>
        activePolls, // chatGroupId -> pollId -> poll data

    // Voice and audio
    required bool isRecording,
    required bool isPlayingVoiceNote,
    String? currentVoiceNoteId,
    required Map<String, double> voiceNoteProgress,

    // AI integration
    required bool isAiResponding,
    required Map<String, String> aiResponses,

    // UI state
    required bool showEmojiPicker,
    required bool showAttachmentOptions,
    String? replyingToMessageId,
    String? editingMessageId,
    required Map<String, bool> expandedMessages,
    required bool isUploading,
    required String quickReactionEmoji,
    required List<String> quickReactionEmojis,
    String? typingUser,
    Message? replyToMessage,

    // Connection and sync
    required bool isOnline,
    required bool isSyncing,
    required Map<String, DateTime> lastSyncTimestamps,
    required List<Map<String, dynamic>> pendingMessages,
    String? syncError,
    required List<Map<String, dynamic>> syncConflicts,

    // Analytics and metadata
    required Map<String, Map<String, dynamic>> messageAnalytics,
    required Map<String, List<Map<String, dynamic>>> messageReactions,

    // Search and filtering
    required List<Message> searchResults,
    required String searchQuery,
    required bool isSearching,

    // Voice chat integration
    required Map<String, bool> voiceChatActive, // chatGroupId -> is active
    required Map<String, List<String>>
        voiceChatParticipants, // chatGroupId -> participant UIDs

    // Settings and preferences
    required Map<String, bool> mutedChats,
    required Map<String, bool> pinnedChats,
    required Map<String, String> chatThemes,
    required bool notificationsEnabled,
  }) = _ChatState;

  factory ChatState.initial() => ChatState(
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
        quickReactionEmojis: ['❤️', '👍', '😂', '😢', '😡', '😮'],
        typingUser: null,
        replyToMessage: null,
        isOnline: true,
        isSyncing: false,
        lastSyncTimestamps: {},
        pendingMessages: [],
        syncError: null,
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
}
