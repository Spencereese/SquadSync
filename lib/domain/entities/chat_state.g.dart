// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatStateImpl _$$ChatStateImplFromJson(Map<String, dynamic> json) =>
    _$ChatStateImpl(
      isInitialized: json['isInitialized'] as bool,
      isInitialDataLoaded: json['isInitialDataLoaded'] as bool,
      displayName: json['displayName'] as String,
      profileImage: json['profileImage'] as String?,
      chatMessages: (json['chatMessages'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
            k,
            (e as List<dynamic>)
                .map((e) => Message.fromJson(e as Map<String, dynamic>))
                .toList()),
      ),
      chatGroups: (json['chatGroups'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, ChatGroup.fromJson(e as Map<String, dynamic>)),
      ),
      userChatGroups: (json['userChatGroups'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, ChatGroup.fromJson(e as Map<String, dynamic>)),
      ),
      selectedChatGroupId: json['selectedChatGroupId'] as String?,
      lastReadTimestamps:
          (json['lastReadTimestamps'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, DateTime.parse(e as String)),
      ),
      typingIndicators: (json['typingIndicators'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toSet()),
      ),
      unreadCounts: Map<String, int>.from(json['unreadCounts'] as Map),
      hasNewMessages: Map<String, bool>.from(json['hasNewMessages'] as Map),
      mediaHistory: (json['mediaHistory'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      pinnedMessages: (json['pinnedMessages'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
      activePolls: (json['activePolls'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
            k,
            (e as Map<String, dynamic>).map(
              (k, e) => MapEntry(k, Poll.fromJson(e as Map<String, dynamic>)),
            )),
      ),
      isRecording: json['isRecording'] as bool,
      isPlayingVoiceNote: json['isPlayingVoiceNote'] as bool,
      currentVoiceNoteId: json['currentVoiceNoteId'] as String?,
      voiceNoteProgress:
          (json['voiceNoteProgress'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      isAiResponding: json['isAiResponding'] as bool,
      aiResponses: Map<String, String>.from(json['aiResponses'] as Map),
      showEmojiPicker: json['showEmojiPicker'] as bool,
      showAttachmentOptions: json['showAttachmentOptions'] as bool,
      replyingToMessageId: json['replyingToMessageId'] as String?,
      editingMessageId: json['editingMessageId'] as String?,
      expandedMessages: Map<String, bool>.from(json['expandedMessages'] as Map),
      isUploading: json['isUploading'] as bool,
      quickReactionEmoji: json['quickReactionEmoji'] as String,
      quickReactionEmojis: (json['quickReactionEmojis'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      typingUser: json['typingUser'] as String?,
      replyToMessage: json['replyToMessage'] == null
          ? null
          : Message.fromJson(json['replyToMessage'] as Map<String, dynamic>),
      isOnline: json['isOnline'] as bool,
      isSyncing: json['isSyncing'] as bool,
      lastSyncTimestamps:
          (json['lastSyncTimestamps'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, DateTime.parse(e as String)),
      ),
      pendingMessages: (json['pendingMessages'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      syncError: json['syncError'] as String?,
      syncConflicts: (json['syncConflicts'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      messageAnalytics: (json['messageAnalytics'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, e as Map<String, dynamic>),
      ),
      messageReactions: (json['messageReactions'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
            k,
            (e as List<dynamic>)
                .map((e) => e as Map<String, dynamic>)
                .toList()),
      ),
      searchResults: (json['searchResults'] as List<dynamic>)
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList(),
      searchQuery: json['searchQuery'] as String,
      isSearching: json['isSearching'] as bool,
      voiceChatActive: Map<String, bool>.from(json['voiceChatActive'] as Map),
      voiceChatParticipants:
          (json['voiceChatParticipants'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
      mutedChats: Map<String, bool>.from(json['mutedChats'] as Map),
      pinnedChats: Map<String, bool>.from(json['pinnedChats'] as Map),
      chatThemes: Map<String, String>.from(json['chatThemes'] as Map),
      notificationsEnabled: json['notificationsEnabled'] as bool,
    );

Map<String, dynamic> _$$ChatStateImplToJson(_$ChatStateImpl instance) =>
    <String, dynamic>{
      'isInitialized': instance.isInitialized,
      'isInitialDataLoaded': instance.isInitialDataLoaded,
      'displayName': instance.displayName,
      'profileImage': instance.profileImage,
      'chatMessages': instance.chatMessages,
      'chatGroups': instance.chatGroups,
      'userChatGroups': instance.userChatGroups,
      'selectedChatGroupId': instance.selectedChatGroupId,
      'lastReadTimestamps': instance.lastReadTimestamps
          .map((k, e) => MapEntry(k, e.toIso8601String())),
      'typingIndicators':
          instance.typingIndicators.map((k, e) => MapEntry(k, e.toList())),
      'unreadCounts': instance.unreadCounts,
      'hasNewMessages': instance.hasNewMessages,
      'mediaHistory': instance.mediaHistory,
      'pinnedMessages': instance.pinnedMessages,
      'activePolls': instance.activePolls,
      'isRecording': instance.isRecording,
      'isPlayingVoiceNote': instance.isPlayingVoiceNote,
      'currentVoiceNoteId': instance.currentVoiceNoteId,
      'voiceNoteProgress': instance.voiceNoteProgress,
      'isAiResponding': instance.isAiResponding,
      'aiResponses': instance.aiResponses,
      'showEmojiPicker': instance.showEmojiPicker,
      'showAttachmentOptions': instance.showAttachmentOptions,
      'replyingToMessageId': instance.replyingToMessageId,
      'editingMessageId': instance.editingMessageId,
      'expandedMessages': instance.expandedMessages,
      'isUploading': instance.isUploading,
      'quickReactionEmoji': instance.quickReactionEmoji,
      'quickReactionEmojis': instance.quickReactionEmojis,
      'typingUser': instance.typingUser,
      'replyToMessage': instance.replyToMessage,
      'isOnline': instance.isOnline,
      'isSyncing': instance.isSyncing,
      'lastSyncTimestamps': instance.lastSyncTimestamps
          .map((k, e) => MapEntry(k, e.toIso8601String())),
      'pendingMessages': instance.pendingMessages,
      'syncError': instance.syncError,
      'syncConflicts': instance.syncConflicts,
      'messageAnalytics': instance.messageAnalytics,
      'messageReactions': instance.messageReactions,
      'searchResults': instance.searchResults,
      'searchQuery': instance.searchQuery,
      'isSearching': instance.isSearching,
      'voiceChatActive': instance.voiceChatActive,
      'voiceChatParticipants': instance.voiceChatParticipants,
      'mutedChats': instance.mutedChats,
      'pinnedChats': instance.pinnedChats,
      'chatThemes': instance.chatThemes,
      'notificationsEnabled': instance.notificationsEnabled,
    };
