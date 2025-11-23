// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ChatState _$ChatStateFromJson(Map<String, dynamic> json) {
  return _ChatState.fromJson(json);
}

/// @nodoc
mixin _$ChatState {
  bool get isInitialized => throw _privateConstructorUsedError;
  bool get isInitialDataLoaded => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String? get profileImage =>
      throw _privateConstructorUsedError; // Messages and groups
  Map<String, List<Message>> get chatMessages =>
      throw _privateConstructorUsedError; // chatGroupId -> messages
  Map<String, ChatGroup> get chatGroups => throw _privateConstructorUsedError;
  Map<String, ChatGroup> get userChatGroups =>
      throw _privateConstructorUsedError;
  String? get selectedChatGroupId => throw _privateConstructorUsedError;
  Map<String, DateTime> get lastReadTimestamps =>
      throw _privateConstructorUsedError; // Real-time state
  Map<String, Set<String>> get typingIndicators =>
      throw _privateConstructorUsedError; // chatGroupId -> typing user UIDs
  Map<String, int> get unreadCounts =>
      throw _privateConstructorUsedError; // chatGroupId -> unread count
  Map<String, bool> get hasNewMessages =>
      throw _privateConstructorUsedError; // Media and attachments
  List<Map<String, dynamic>> get mediaHistory =>
      throw _privateConstructorUsedError;
  Map<String, List<String>> get pinnedMessages =>
      throw _privateConstructorUsedError; // chatGroupId -> pinned message IDs
  Map<String, Map<String, Poll>> get activePolls =>
      throw _privateConstructorUsedError; // chatGroupId -> pollId -> poll data
// Voice and audio
  bool get isRecording => throw _privateConstructorUsedError;
  bool get isPlayingVoiceNote => throw _privateConstructorUsedError;
  String? get currentVoiceNoteId => throw _privateConstructorUsedError;
  Map<String, double> get voiceNoteProgress =>
      throw _privateConstructorUsedError; // AI integration
  bool get isAiResponding => throw _privateConstructorUsedError;
  Map<String, String> get aiResponses =>
      throw _privateConstructorUsedError; // UI state
  bool get showEmojiPicker => throw _privateConstructorUsedError;
  bool get showAttachmentOptions => throw _privateConstructorUsedError;
  String? get replyingToMessageId => throw _privateConstructorUsedError;
  String? get editingMessageId => throw _privateConstructorUsedError;
  Map<String, bool> get expandedMessages => throw _privateConstructorUsedError;
  bool get isUploading => throw _privateConstructorUsedError;
  String get quickReactionEmoji => throw _privateConstructorUsedError;
  List<String> get quickReactionEmojis => throw _privateConstructorUsedError;
  String? get typingUser => throw _privateConstructorUsedError;
  Message? get replyToMessage =>
      throw _privateConstructorUsedError; // Connection and sync
  bool get isOnline => throw _privateConstructorUsedError;
  bool get isSyncing => throw _privateConstructorUsedError;
  Map<String, DateTime> get lastSyncTimestamps =>
      throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get pendingMessages =>
      throw _privateConstructorUsedError;
  String? get syncError => throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get syncConflicts =>
      throw _privateConstructorUsedError; // Analytics and metadata
  Map<String, Map<String, dynamic>> get messageAnalytics =>
      throw _privateConstructorUsedError;
  Map<String, List<Map<String, dynamic>>> get messageReactions =>
      throw _privateConstructorUsedError; // Search and filtering
  List<Message> get searchResults => throw _privateConstructorUsedError;
  String get searchQuery => throw _privateConstructorUsedError;
  bool get isSearching =>
      throw _privateConstructorUsedError; // Voice chat integration
  Map<String, bool> get voiceChatActive =>
      throw _privateConstructorUsedError; // chatGroupId -> is active
  Map<String, List<String>> get voiceChatParticipants =>
      throw _privateConstructorUsedError; // chatGroupId -> participant UIDs
// Settings and preferences
  Map<String, bool> get mutedChats => throw _privateConstructorUsedError;
  Map<String, bool> get pinnedChats => throw _privateConstructorUsedError;
  Map<String, String> get chatThemes => throw _privateConstructorUsedError;
  bool get notificationsEnabled => throw _privateConstructorUsedError;

  /// Serializes this ChatState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatStateCopyWith<ChatState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatStateCopyWith<$Res> {
  factory $ChatStateCopyWith(ChatState value, $Res Function(ChatState) then) =
      _$ChatStateCopyWithImpl<$Res, ChatState>;
  @useResult
  $Res call(
      {bool isInitialized,
      bool isInitialDataLoaded,
      String displayName,
      String? profileImage,
      Map<String, List<Message>> chatMessages,
      Map<String, ChatGroup> chatGroups,
      Map<String, ChatGroup> userChatGroups,
      String? selectedChatGroupId,
      Map<String, DateTime> lastReadTimestamps,
      Map<String, Set<String>> typingIndicators,
      Map<String, int> unreadCounts,
      Map<String, bool> hasNewMessages,
      List<Map<String, dynamic>> mediaHistory,
      Map<String, List<String>> pinnedMessages,
      Map<String, Map<String, Poll>> activePolls,
      bool isRecording,
      bool isPlayingVoiceNote,
      String? currentVoiceNoteId,
      Map<String, double> voiceNoteProgress,
      bool isAiResponding,
      Map<String, String> aiResponses,
      bool showEmojiPicker,
      bool showAttachmentOptions,
      String? replyingToMessageId,
      String? editingMessageId,
      Map<String, bool> expandedMessages,
      bool isUploading,
      String quickReactionEmoji,
      List<String> quickReactionEmojis,
      String? typingUser,
      Message? replyToMessage,
      bool isOnline,
      bool isSyncing,
      Map<String, DateTime> lastSyncTimestamps,
      List<Map<String, dynamic>> pendingMessages,
      String? syncError,
      List<Map<String, dynamic>> syncConflicts,
      Map<String, Map<String, dynamic>> messageAnalytics,
      Map<String, List<Map<String, dynamic>>> messageReactions,
      List<Message> searchResults,
      String searchQuery,
      bool isSearching,
      Map<String, bool> voiceChatActive,
      Map<String, List<String>> voiceChatParticipants,
      Map<String, bool> mutedChats,
      Map<String, bool> pinnedChats,
      Map<String, String> chatThemes,
      bool notificationsEnabled});

  $MessageCopyWith<$Res>? get replyToMessage;
}

/// @nodoc
class _$ChatStateCopyWithImpl<$Res, $Val extends ChatState>
    implements $ChatStateCopyWith<$Res> {
  _$ChatStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isInitialized = null,
    Object? isInitialDataLoaded = null,
    Object? displayName = null,
    Object? profileImage = freezed,
    Object? chatMessages = null,
    Object? chatGroups = null,
    Object? userChatGroups = null,
    Object? selectedChatGroupId = freezed,
    Object? lastReadTimestamps = null,
    Object? typingIndicators = null,
    Object? unreadCounts = null,
    Object? hasNewMessages = null,
    Object? mediaHistory = null,
    Object? pinnedMessages = null,
    Object? activePolls = null,
    Object? isRecording = null,
    Object? isPlayingVoiceNote = null,
    Object? currentVoiceNoteId = freezed,
    Object? voiceNoteProgress = null,
    Object? isAiResponding = null,
    Object? aiResponses = null,
    Object? showEmojiPicker = null,
    Object? showAttachmentOptions = null,
    Object? replyingToMessageId = freezed,
    Object? editingMessageId = freezed,
    Object? expandedMessages = null,
    Object? isUploading = null,
    Object? quickReactionEmoji = null,
    Object? quickReactionEmojis = null,
    Object? typingUser = freezed,
    Object? replyToMessage = freezed,
    Object? isOnline = null,
    Object? isSyncing = null,
    Object? lastSyncTimestamps = null,
    Object? pendingMessages = null,
    Object? syncError = freezed,
    Object? syncConflicts = null,
    Object? messageAnalytics = null,
    Object? messageReactions = null,
    Object? searchResults = null,
    Object? searchQuery = null,
    Object? isSearching = null,
    Object? voiceChatActive = null,
    Object? voiceChatParticipants = null,
    Object? mutedChats = null,
    Object? pinnedChats = null,
    Object? chatThemes = null,
    Object? notificationsEnabled = null,
  }) {
    return _then(_value.copyWith(
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      isInitialDataLoaded: null == isInitialDataLoaded
          ? _value.isInitialDataLoaded
          : isInitialDataLoaded // ignore: cast_nullable_to_non_nullable
              as bool,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      profileImage: freezed == profileImage
          ? _value.profileImage
          : profileImage // ignore: cast_nullable_to_non_nullable
              as String?,
      chatMessages: null == chatMessages
          ? _value.chatMessages
          : chatMessages // ignore: cast_nullable_to_non_nullable
              as Map<String, List<Message>>,
      chatGroups: null == chatGroups
          ? _value.chatGroups
          : chatGroups // ignore: cast_nullable_to_non_nullable
              as Map<String, ChatGroup>,
      userChatGroups: null == userChatGroups
          ? _value.userChatGroups
          : userChatGroups // ignore: cast_nullable_to_non_nullable
              as Map<String, ChatGroup>,
      selectedChatGroupId: freezed == selectedChatGroupId
          ? _value.selectedChatGroupId
          : selectedChatGroupId // ignore: cast_nullable_to_non_nullable
              as String?,
      lastReadTimestamps: null == lastReadTimestamps
          ? _value.lastReadTimestamps
          : lastReadTimestamps // ignore: cast_nullable_to_non_nullable
              as Map<String, DateTime>,
      typingIndicators: null == typingIndicators
          ? _value.typingIndicators
          : typingIndicators // ignore: cast_nullable_to_non_nullable
              as Map<String, Set<String>>,
      unreadCounts: null == unreadCounts
          ? _value.unreadCounts
          : unreadCounts // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      hasNewMessages: null == hasNewMessages
          ? _value.hasNewMessages
          : hasNewMessages // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      mediaHistory: null == mediaHistory
          ? _value.mediaHistory
          : mediaHistory // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      pinnedMessages: null == pinnedMessages
          ? _value.pinnedMessages
          : pinnedMessages // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
      activePolls: null == activePolls
          ? _value.activePolls
          : activePolls // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, Poll>>,
      isRecording: null == isRecording
          ? _value.isRecording
          : isRecording // ignore: cast_nullable_to_non_nullable
              as bool,
      isPlayingVoiceNote: null == isPlayingVoiceNote
          ? _value.isPlayingVoiceNote
          : isPlayingVoiceNote // ignore: cast_nullable_to_non_nullable
              as bool,
      currentVoiceNoteId: freezed == currentVoiceNoteId
          ? _value.currentVoiceNoteId
          : currentVoiceNoteId // ignore: cast_nullable_to_non_nullable
              as String?,
      voiceNoteProgress: null == voiceNoteProgress
          ? _value.voiceNoteProgress
          : voiceNoteProgress // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      isAiResponding: null == isAiResponding
          ? _value.isAiResponding
          : isAiResponding // ignore: cast_nullable_to_non_nullable
              as bool,
      aiResponses: null == aiResponses
          ? _value.aiResponses
          : aiResponses // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      showEmojiPicker: null == showEmojiPicker
          ? _value.showEmojiPicker
          : showEmojiPicker // ignore: cast_nullable_to_non_nullable
              as bool,
      showAttachmentOptions: null == showAttachmentOptions
          ? _value.showAttachmentOptions
          : showAttachmentOptions // ignore: cast_nullable_to_non_nullable
              as bool,
      replyingToMessageId: freezed == replyingToMessageId
          ? _value.replyingToMessageId
          : replyingToMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      editingMessageId: freezed == editingMessageId
          ? _value.editingMessageId
          : editingMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      expandedMessages: null == expandedMessages
          ? _value.expandedMessages
          : expandedMessages // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      isUploading: null == isUploading
          ? _value.isUploading
          : isUploading // ignore: cast_nullable_to_non_nullable
              as bool,
      quickReactionEmoji: null == quickReactionEmoji
          ? _value.quickReactionEmoji
          : quickReactionEmoji // ignore: cast_nullable_to_non_nullable
              as String,
      quickReactionEmojis: null == quickReactionEmojis
          ? _value.quickReactionEmojis
          : quickReactionEmojis // ignore: cast_nullable_to_non_nullable
              as List<String>,
      typingUser: freezed == typingUser
          ? _value.typingUser
          : typingUser // ignore: cast_nullable_to_non_nullable
              as String?,
      replyToMessage: freezed == replyToMessage
          ? _value.replyToMessage
          : replyToMessage // ignore: cast_nullable_to_non_nullable
              as Message?,
      isOnline: null == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      isSyncing: null == isSyncing
          ? _value.isSyncing
          : isSyncing // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSyncTimestamps: null == lastSyncTimestamps
          ? _value.lastSyncTimestamps
          : lastSyncTimestamps // ignore: cast_nullable_to_non_nullable
              as Map<String, DateTime>,
      pendingMessages: null == pendingMessages
          ? _value.pendingMessages
          : pendingMessages // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      syncError: freezed == syncError
          ? _value.syncError
          : syncError // ignore: cast_nullable_to_non_nullable
              as String?,
      syncConflicts: null == syncConflicts
          ? _value.syncConflicts
          : syncConflicts // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      messageAnalytics: null == messageAnalytics
          ? _value.messageAnalytics
          : messageAnalytics // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, dynamic>>,
      messageReactions: null == messageReactions
          ? _value.messageReactions
          : messageReactions // ignore: cast_nullable_to_non_nullable
              as Map<String, List<Map<String, dynamic>>>,
      searchResults: null == searchResults
          ? _value.searchResults
          : searchResults // ignore: cast_nullable_to_non_nullable
              as List<Message>,
      searchQuery: null == searchQuery
          ? _value.searchQuery
          : searchQuery // ignore: cast_nullable_to_non_nullable
              as String,
      isSearching: null == isSearching
          ? _value.isSearching
          : isSearching // ignore: cast_nullable_to_non_nullable
              as bool,
      voiceChatActive: null == voiceChatActive
          ? _value.voiceChatActive
          : voiceChatActive // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      voiceChatParticipants: null == voiceChatParticipants
          ? _value.voiceChatParticipants
          : voiceChatParticipants // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
      mutedChats: null == mutedChats
          ? _value.mutedChats
          : mutedChats // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      pinnedChats: null == pinnedChats
          ? _value.pinnedChats
          : pinnedChats // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      chatThemes: null == chatThemes
          ? _value.chatThemes
          : chatThemes // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      notificationsEnabled: null == notificationsEnabled
          ? _value.notificationsEnabled
          : notificationsEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessageCopyWith<$Res>? get replyToMessage {
    if (_value.replyToMessage == null) {
      return null;
    }

    return $MessageCopyWith<$Res>(_value.replyToMessage!, (value) {
      return _then(_value.copyWith(replyToMessage: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ChatStateImplCopyWith<$Res>
    implements $ChatStateCopyWith<$Res> {
  factory _$$ChatStateImplCopyWith(
          _$ChatStateImpl value, $Res Function(_$ChatStateImpl) then) =
      __$$ChatStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool isInitialized,
      bool isInitialDataLoaded,
      String displayName,
      String? profileImage,
      Map<String, List<Message>> chatMessages,
      Map<String, ChatGroup> chatGroups,
      Map<String, ChatGroup> userChatGroups,
      String? selectedChatGroupId,
      Map<String, DateTime> lastReadTimestamps,
      Map<String, Set<String>> typingIndicators,
      Map<String, int> unreadCounts,
      Map<String, bool> hasNewMessages,
      List<Map<String, dynamic>> mediaHistory,
      Map<String, List<String>> pinnedMessages,
      Map<String, Map<String, Poll>> activePolls,
      bool isRecording,
      bool isPlayingVoiceNote,
      String? currentVoiceNoteId,
      Map<String, double> voiceNoteProgress,
      bool isAiResponding,
      Map<String, String> aiResponses,
      bool showEmojiPicker,
      bool showAttachmentOptions,
      String? replyingToMessageId,
      String? editingMessageId,
      Map<String, bool> expandedMessages,
      bool isUploading,
      String quickReactionEmoji,
      List<String> quickReactionEmojis,
      String? typingUser,
      Message? replyToMessage,
      bool isOnline,
      bool isSyncing,
      Map<String, DateTime> lastSyncTimestamps,
      List<Map<String, dynamic>> pendingMessages,
      String? syncError,
      List<Map<String, dynamic>> syncConflicts,
      Map<String, Map<String, dynamic>> messageAnalytics,
      Map<String, List<Map<String, dynamic>>> messageReactions,
      List<Message> searchResults,
      String searchQuery,
      bool isSearching,
      Map<String, bool> voiceChatActive,
      Map<String, List<String>> voiceChatParticipants,
      Map<String, bool> mutedChats,
      Map<String, bool> pinnedChats,
      Map<String, String> chatThemes,
      bool notificationsEnabled});

  @override
  $MessageCopyWith<$Res>? get replyToMessage;
}

/// @nodoc
class __$$ChatStateImplCopyWithImpl<$Res>
    extends _$ChatStateCopyWithImpl<$Res, _$ChatStateImpl>
    implements _$$ChatStateImplCopyWith<$Res> {
  __$$ChatStateImplCopyWithImpl(
      _$ChatStateImpl _value, $Res Function(_$ChatStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isInitialized = null,
    Object? isInitialDataLoaded = null,
    Object? displayName = null,
    Object? profileImage = freezed,
    Object? chatMessages = null,
    Object? chatGroups = null,
    Object? userChatGroups = null,
    Object? selectedChatGroupId = freezed,
    Object? lastReadTimestamps = null,
    Object? typingIndicators = null,
    Object? unreadCounts = null,
    Object? hasNewMessages = null,
    Object? mediaHistory = null,
    Object? pinnedMessages = null,
    Object? activePolls = null,
    Object? isRecording = null,
    Object? isPlayingVoiceNote = null,
    Object? currentVoiceNoteId = freezed,
    Object? voiceNoteProgress = null,
    Object? isAiResponding = null,
    Object? aiResponses = null,
    Object? showEmojiPicker = null,
    Object? showAttachmentOptions = null,
    Object? replyingToMessageId = freezed,
    Object? editingMessageId = freezed,
    Object? expandedMessages = null,
    Object? isUploading = null,
    Object? quickReactionEmoji = null,
    Object? quickReactionEmojis = null,
    Object? typingUser = freezed,
    Object? replyToMessage = freezed,
    Object? isOnline = null,
    Object? isSyncing = null,
    Object? lastSyncTimestamps = null,
    Object? pendingMessages = null,
    Object? syncError = freezed,
    Object? syncConflicts = null,
    Object? messageAnalytics = null,
    Object? messageReactions = null,
    Object? searchResults = null,
    Object? searchQuery = null,
    Object? isSearching = null,
    Object? voiceChatActive = null,
    Object? voiceChatParticipants = null,
    Object? mutedChats = null,
    Object? pinnedChats = null,
    Object? chatThemes = null,
    Object? notificationsEnabled = null,
  }) {
    return _then(_$ChatStateImpl(
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      isInitialDataLoaded: null == isInitialDataLoaded
          ? _value.isInitialDataLoaded
          : isInitialDataLoaded // ignore: cast_nullable_to_non_nullable
              as bool,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      profileImage: freezed == profileImage
          ? _value.profileImage
          : profileImage // ignore: cast_nullable_to_non_nullable
              as String?,
      chatMessages: null == chatMessages
          ? _value._chatMessages
          : chatMessages // ignore: cast_nullable_to_non_nullable
              as Map<String, List<Message>>,
      chatGroups: null == chatGroups
          ? _value._chatGroups
          : chatGroups // ignore: cast_nullable_to_non_nullable
              as Map<String, ChatGroup>,
      userChatGroups: null == userChatGroups
          ? _value._userChatGroups
          : userChatGroups // ignore: cast_nullable_to_non_nullable
              as Map<String, ChatGroup>,
      selectedChatGroupId: freezed == selectedChatGroupId
          ? _value.selectedChatGroupId
          : selectedChatGroupId // ignore: cast_nullable_to_non_nullable
              as String?,
      lastReadTimestamps: null == lastReadTimestamps
          ? _value._lastReadTimestamps
          : lastReadTimestamps // ignore: cast_nullable_to_non_nullable
              as Map<String, DateTime>,
      typingIndicators: null == typingIndicators
          ? _value._typingIndicators
          : typingIndicators // ignore: cast_nullable_to_non_nullable
              as Map<String, Set<String>>,
      unreadCounts: null == unreadCounts
          ? _value._unreadCounts
          : unreadCounts // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      hasNewMessages: null == hasNewMessages
          ? _value._hasNewMessages
          : hasNewMessages // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      mediaHistory: null == mediaHistory
          ? _value._mediaHistory
          : mediaHistory // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      pinnedMessages: null == pinnedMessages
          ? _value._pinnedMessages
          : pinnedMessages // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
      activePolls: null == activePolls
          ? _value._activePolls
          : activePolls // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, Poll>>,
      isRecording: null == isRecording
          ? _value.isRecording
          : isRecording // ignore: cast_nullable_to_non_nullable
              as bool,
      isPlayingVoiceNote: null == isPlayingVoiceNote
          ? _value.isPlayingVoiceNote
          : isPlayingVoiceNote // ignore: cast_nullable_to_non_nullable
              as bool,
      currentVoiceNoteId: freezed == currentVoiceNoteId
          ? _value.currentVoiceNoteId
          : currentVoiceNoteId // ignore: cast_nullable_to_non_nullable
              as String?,
      voiceNoteProgress: null == voiceNoteProgress
          ? _value._voiceNoteProgress
          : voiceNoteProgress // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      isAiResponding: null == isAiResponding
          ? _value.isAiResponding
          : isAiResponding // ignore: cast_nullable_to_non_nullable
              as bool,
      aiResponses: null == aiResponses
          ? _value._aiResponses
          : aiResponses // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      showEmojiPicker: null == showEmojiPicker
          ? _value.showEmojiPicker
          : showEmojiPicker // ignore: cast_nullable_to_non_nullable
              as bool,
      showAttachmentOptions: null == showAttachmentOptions
          ? _value.showAttachmentOptions
          : showAttachmentOptions // ignore: cast_nullable_to_non_nullable
              as bool,
      replyingToMessageId: freezed == replyingToMessageId
          ? _value.replyingToMessageId
          : replyingToMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      editingMessageId: freezed == editingMessageId
          ? _value.editingMessageId
          : editingMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      expandedMessages: null == expandedMessages
          ? _value._expandedMessages
          : expandedMessages // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      isUploading: null == isUploading
          ? _value.isUploading
          : isUploading // ignore: cast_nullable_to_non_nullable
              as bool,
      quickReactionEmoji: null == quickReactionEmoji
          ? _value.quickReactionEmoji
          : quickReactionEmoji // ignore: cast_nullable_to_non_nullable
              as String,
      quickReactionEmojis: null == quickReactionEmojis
          ? _value._quickReactionEmojis
          : quickReactionEmojis // ignore: cast_nullable_to_non_nullable
              as List<String>,
      typingUser: freezed == typingUser
          ? _value.typingUser
          : typingUser // ignore: cast_nullable_to_non_nullable
              as String?,
      replyToMessage: freezed == replyToMessage
          ? _value.replyToMessage
          : replyToMessage // ignore: cast_nullable_to_non_nullable
              as Message?,
      isOnline: null == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      isSyncing: null == isSyncing
          ? _value.isSyncing
          : isSyncing // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSyncTimestamps: null == lastSyncTimestamps
          ? _value._lastSyncTimestamps
          : lastSyncTimestamps // ignore: cast_nullable_to_non_nullable
              as Map<String, DateTime>,
      pendingMessages: null == pendingMessages
          ? _value._pendingMessages
          : pendingMessages // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      syncError: freezed == syncError
          ? _value.syncError
          : syncError // ignore: cast_nullable_to_non_nullable
              as String?,
      syncConflicts: null == syncConflicts
          ? _value._syncConflicts
          : syncConflicts // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      messageAnalytics: null == messageAnalytics
          ? _value._messageAnalytics
          : messageAnalytics // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, dynamic>>,
      messageReactions: null == messageReactions
          ? _value._messageReactions
          : messageReactions // ignore: cast_nullable_to_non_nullable
              as Map<String, List<Map<String, dynamic>>>,
      searchResults: null == searchResults
          ? _value._searchResults
          : searchResults // ignore: cast_nullable_to_non_nullable
              as List<Message>,
      searchQuery: null == searchQuery
          ? _value.searchQuery
          : searchQuery // ignore: cast_nullable_to_non_nullable
              as String,
      isSearching: null == isSearching
          ? _value.isSearching
          : isSearching // ignore: cast_nullable_to_non_nullable
              as bool,
      voiceChatActive: null == voiceChatActive
          ? _value._voiceChatActive
          : voiceChatActive // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      voiceChatParticipants: null == voiceChatParticipants
          ? _value._voiceChatParticipants
          : voiceChatParticipants // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
      mutedChats: null == mutedChats
          ? _value._mutedChats
          : mutedChats // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      pinnedChats: null == pinnedChats
          ? _value._pinnedChats
          : pinnedChats // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      chatThemes: null == chatThemes
          ? _value._chatThemes
          : chatThemes // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      notificationsEnabled: null == notificationsEnabled
          ? _value.notificationsEnabled
          : notificationsEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatStateImpl implements _ChatState {
  const _$ChatStateImpl(
      {required this.isInitialized,
      required this.isInitialDataLoaded,
      required this.displayName,
      this.profileImage,
      required final Map<String, List<Message>> chatMessages,
      required final Map<String, ChatGroup> chatGroups,
      required final Map<String, ChatGroup> userChatGroups,
      this.selectedChatGroupId,
      required final Map<String, DateTime> lastReadTimestamps,
      required final Map<String, Set<String>> typingIndicators,
      required final Map<String, int> unreadCounts,
      required final Map<String, bool> hasNewMessages,
      required final List<Map<String, dynamic>> mediaHistory,
      required final Map<String, List<String>> pinnedMessages,
      required final Map<String, Map<String, Poll>> activePolls,
      required this.isRecording,
      required this.isPlayingVoiceNote,
      this.currentVoiceNoteId,
      required final Map<String, double> voiceNoteProgress,
      required this.isAiResponding,
      required final Map<String, String> aiResponses,
      required this.showEmojiPicker,
      required this.showAttachmentOptions,
      this.replyingToMessageId,
      this.editingMessageId,
      required final Map<String, bool> expandedMessages,
      required this.isUploading,
      required this.quickReactionEmoji,
      required final List<String> quickReactionEmojis,
      this.typingUser,
      this.replyToMessage,
      required this.isOnline,
      required this.isSyncing,
      required final Map<String, DateTime> lastSyncTimestamps,
      required final List<Map<String, dynamic>> pendingMessages,
      this.syncError,
      required final List<Map<String, dynamic>> syncConflicts,
      required final Map<String, Map<String, dynamic>> messageAnalytics,
      required final Map<String, List<Map<String, dynamic>>> messageReactions,
      required final List<Message> searchResults,
      required this.searchQuery,
      required this.isSearching,
      required final Map<String, bool> voiceChatActive,
      required final Map<String, List<String>> voiceChatParticipants,
      required final Map<String, bool> mutedChats,
      required final Map<String, bool> pinnedChats,
      required final Map<String, String> chatThemes,
      required this.notificationsEnabled})
      : _chatMessages = chatMessages,
        _chatGroups = chatGroups,
        _userChatGroups = userChatGroups,
        _lastReadTimestamps = lastReadTimestamps,
        _typingIndicators = typingIndicators,
        _unreadCounts = unreadCounts,
        _hasNewMessages = hasNewMessages,
        _mediaHistory = mediaHistory,
        _pinnedMessages = pinnedMessages,
        _activePolls = activePolls,
        _voiceNoteProgress = voiceNoteProgress,
        _aiResponses = aiResponses,
        _expandedMessages = expandedMessages,
        _quickReactionEmojis = quickReactionEmojis,
        _lastSyncTimestamps = lastSyncTimestamps,
        _pendingMessages = pendingMessages,
        _syncConflicts = syncConflicts,
        _messageAnalytics = messageAnalytics,
        _messageReactions = messageReactions,
        _searchResults = searchResults,
        _voiceChatActive = voiceChatActive,
        _voiceChatParticipants = voiceChatParticipants,
        _mutedChats = mutedChats,
        _pinnedChats = pinnedChats,
        _chatThemes = chatThemes;

  factory _$ChatStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatStateImplFromJson(json);

  @override
  final bool isInitialized;
  @override
  final bool isInitialDataLoaded;
  @override
  final String displayName;
  @override
  final String? profileImage;
// Messages and groups
  final Map<String, List<Message>> _chatMessages;
// Messages and groups
  @override
  Map<String, List<Message>> get chatMessages {
    if (_chatMessages is EqualUnmodifiableMapView) return _chatMessages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_chatMessages);
  }

// chatGroupId -> messages
  final Map<String, ChatGroup> _chatGroups;
// chatGroupId -> messages
  @override
  Map<String, ChatGroup> get chatGroups {
    if (_chatGroups is EqualUnmodifiableMapView) return _chatGroups;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_chatGroups);
  }

  final Map<String, ChatGroup> _userChatGroups;
  @override
  Map<String, ChatGroup> get userChatGroups {
    if (_userChatGroups is EqualUnmodifiableMapView) return _userChatGroups;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_userChatGroups);
  }

  @override
  final String? selectedChatGroupId;
  final Map<String, DateTime> _lastReadTimestamps;
  @override
  Map<String, DateTime> get lastReadTimestamps {
    if (_lastReadTimestamps is EqualUnmodifiableMapView)
      return _lastReadTimestamps;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_lastReadTimestamps);
  }

// Real-time state
  final Map<String, Set<String>> _typingIndicators;
// Real-time state
  @override
  Map<String, Set<String>> get typingIndicators {
    if (_typingIndicators is EqualUnmodifiableMapView) return _typingIndicators;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_typingIndicators);
  }

// chatGroupId -> typing user UIDs
  final Map<String, int> _unreadCounts;
// chatGroupId -> typing user UIDs
  @override
  Map<String, int> get unreadCounts {
    if (_unreadCounts is EqualUnmodifiableMapView) return _unreadCounts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_unreadCounts);
  }

// chatGroupId -> unread count
  final Map<String, bool> _hasNewMessages;
// chatGroupId -> unread count
  @override
  Map<String, bool> get hasNewMessages {
    if (_hasNewMessages is EqualUnmodifiableMapView) return _hasNewMessages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_hasNewMessages);
  }

// Media and attachments
  final List<Map<String, dynamic>> _mediaHistory;
// Media and attachments
  @override
  List<Map<String, dynamic>> get mediaHistory {
    if (_mediaHistory is EqualUnmodifiableListView) return _mediaHistory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_mediaHistory);
  }

  final Map<String, List<String>> _pinnedMessages;
  @override
  Map<String, List<String>> get pinnedMessages {
    if (_pinnedMessages is EqualUnmodifiableMapView) return _pinnedMessages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_pinnedMessages);
  }

// chatGroupId -> pinned message IDs
  final Map<String, Map<String, Poll>> _activePolls;
// chatGroupId -> pinned message IDs
  @override
  Map<String, Map<String, Poll>> get activePolls {
    if (_activePolls is EqualUnmodifiableMapView) return _activePolls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_activePolls);
  }

// chatGroupId -> pollId -> poll data
// Voice and audio
  @override
  final bool isRecording;
  @override
  final bool isPlayingVoiceNote;
  @override
  final String? currentVoiceNoteId;
  final Map<String, double> _voiceNoteProgress;
  @override
  Map<String, double> get voiceNoteProgress {
    if (_voiceNoteProgress is EqualUnmodifiableMapView)
      return _voiceNoteProgress;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_voiceNoteProgress);
  }

// AI integration
  @override
  final bool isAiResponding;
  final Map<String, String> _aiResponses;
  @override
  Map<String, String> get aiResponses {
    if (_aiResponses is EqualUnmodifiableMapView) return _aiResponses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_aiResponses);
  }

// UI state
  @override
  final bool showEmojiPicker;
  @override
  final bool showAttachmentOptions;
  @override
  final String? replyingToMessageId;
  @override
  final String? editingMessageId;
  final Map<String, bool> _expandedMessages;
  @override
  Map<String, bool> get expandedMessages {
    if (_expandedMessages is EqualUnmodifiableMapView) return _expandedMessages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_expandedMessages);
  }

  @override
  final bool isUploading;
  @override
  final String quickReactionEmoji;
  final List<String> _quickReactionEmojis;
  @override
  List<String> get quickReactionEmojis {
    if (_quickReactionEmojis is EqualUnmodifiableListView)
      return _quickReactionEmojis;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_quickReactionEmojis);
  }

  @override
  final String? typingUser;
  @override
  final Message? replyToMessage;
// Connection and sync
  @override
  final bool isOnline;
  @override
  final bool isSyncing;
  final Map<String, DateTime> _lastSyncTimestamps;
  @override
  Map<String, DateTime> get lastSyncTimestamps {
    if (_lastSyncTimestamps is EqualUnmodifiableMapView)
      return _lastSyncTimestamps;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_lastSyncTimestamps);
  }

  final List<Map<String, dynamic>> _pendingMessages;
  @override
  List<Map<String, dynamic>> get pendingMessages {
    if (_pendingMessages is EqualUnmodifiableListView) return _pendingMessages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pendingMessages);
  }

  @override
  final String? syncError;
  final List<Map<String, dynamic>> _syncConflicts;
  @override
  List<Map<String, dynamic>> get syncConflicts {
    if (_syncConflicts is EqualUnmodifiableListView) return _syncConflicts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_syncConflicts);
  }

// Analytics and metadata
  final Map<String, Map<String, dynamic>> _messageAnalytics;
// Analytics and metadata
  @override
  Map<String, Map<String, dynamic>> get messageAnalytics {
    if (_messageAnalytics is EqualUnmodifiableMapView) return _messageAnalytics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_messageAnalytics);
  }

  final Map<String, List<Map<String, dynamic>>> _messageReactions;
  @override
  Map<String, List<Map<String, dynamic>>> get messageReactions {
    if (_messageReactions is EqualUnmodifiableMapView) return _messageReactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_messageReactions);
  }

// Search and filtering
  final List<Message> _searchResults;
// Search and filtering
  @override
  List<Message> get searchResults {
    if (_searchResults is EqualUnmodifiableListView) return _searchResults;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_searchResults);
  }

  @override
  final String searchQuery;
  @override
  final bool isSearching;
// Voice chat integration
  final Map<String, bool> _voiceChatActive;
// Voice chat integration
  @override
  Map<String, bool> get voiceChatActive {
    if (_voiceChatActive is EqualUnmodifiableMapView) return _voiceChatActive;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_voiceChatActive);
  }

// chatGroupId -> is active
  final Map<String, List<String>> _voiceChatParticipants;
// chatGroupId -> is active
  @override
  Map<String, List<String>> get voiceChatParticipants {
    if (_voiceChatParticipants is EqualUnmodifiableMapView)
      return _voiceChatParticipants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_voiceChatParticipants);
  }

// chatGroupId -> participant UIDs
// Settings and preferences
  final Map<String, bool> _mutedChats;
// chatGroupId -> participant UIDs
// Settings and preferences
  @override
  Map<String, bool> get mutedChats {
    if (_mutedChats is EqualUnmodifiableMapView) return _mutedChats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_mutedChats);
  }

  final Map<String, bool> _pinnedChats;
  @override
  Map<String, bool> get pinnedChats {
    if (_pinnedChats is EqualUnmodifiableMapView) return _pinnedChats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_pinnedChats);
  }

  final Map<String, String> _chatThemes;
  @override
  Map<String, String> get chatThemes {
    if (_chatThemes is EqualUnmodifiableMapView) return _chatThemes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_chatThemes);
  }

  @override
  final bool notificationsEnabled;

  @override
  String toString() {
    return 'ChatState(isInitialized: $isInitialized, isInitialDataLoaded: $isInitialDataLoaded, displayName: $displayName, profileImage: $profileImage, chatMessages: $chatMessages, chatGroups: $chatGroups, userChatGroups: $userChatGroups, selectedChatGroupId: $selectedChatGroupId, lastReadTimestamps: $lastReadTimestamps, typingIndicators: $typingIndicators, unreadCounts: $unreadCounts, hasNewMessages: $hasNewMessages, mediaHistory: $mediaHistory, pinnedMessages: $pinnedMessages, activePolls: $activePolls, isRecording: $isRecording, isPlayingVoiceNote: $isPlayingVoiceNote, currentVoiceNoteId: $currentVoiceNoteId, voiceNoteProgress: $voiceNoteProgress, isAiResponding: $isAiResponding, aiResponses: $aiResponses, showEmojiPicker: $showEmojiPicker, showAttachmentOptions: $showAttachmentOptions, replyingToMessageId: $replyingToMessageId, editingMessageId: $editingMessageId, expandedMessages: $expandedMessages, isUploading: $isUploading, quickReactionEmoji: $quickReactionEmoji, quickReactionEmojis: $quickReactionEmojis, typingUser: $typingUser, replyToMessage: $replyToMessage, isOnline: $isOnline, isSyncing: $isSyncing, lastSyncTimestamps: $lastSyncTimestamps, pendingMessages: $pendingMessages, syncError: $syncError, syncConflicts: $syncConflicts, messageAnalytics: $messageAnalytics, messageReactions: $messageReactions, searchResults: $searchResults, searchQuery: $searchQuery, isSearching: $isSearching, voiceChatActive: $voiceChatActive, voiceChatParticipants: $voiceChatParticipants, mutedChats: $mutedChats, pinnedChats: $pinnedChats, chatThemes: $chatThemes, notificationsEnabled: $notificationsEnabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatStateImpl &&
            (identical(other.isInitialized, isInitialized) ||
                other.isInitialized == isInitialized) &&
            (identical(other.isInitialDataLoaded, isInitialDataLoaded) ||
                other.isInitialDataLoaded == isInitialDataLoaded) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.profileImage, profileImage) ||
                other.profileImage == profileImage) &&
            const DeepCollectionEquality()
                .equals(other._chatMessages, _chatMessages) &&
            const DeepCollectionEquality()
                .equals(other._chatGroups, _chatGroups) &&
            const DeepCollectionEquality()
                .equals(other._userChatGroups, _userChatGroups) &&
            (identical(other.selectedChatGroupId, selectedChatGroupId) ||
                other.selectedChatGroupId == selectedChatGroupId) &&
            const DeepCollectionEquality()
                .equals(other._lastReadTimestamps, _lastReadTimestamps) &&
            const DeepCollectionEquality()
                .equals(other._typingIndicators, _typingIndicators) &&
            const DeepCollectionEquality()
                .equals(other._unreadCounts, _unreadCounts) &&
            const DeepCollectionEquality()
                .equals(other._hasNewMessages, _hasNewMessages) &&
            const DeepCollectionEquality()
                .equals(other._mediaHistory, _mediaHistory) &&
            const DeepCollectionEquality()
                .equals(other._pinnedMessages, _pinnedMessages) &&
            const DeepCollectionEquality()
                .equals(other._activePolls, _activePolls) &&
            (identical(other.isRecording, isRecording) ||
                other.isRecording == isRecording) &&
            (identical(other.isPlayingVoiceNote, isPlayingVoiceNote) ||
                other.isPlayingVoiceNote == isPlayingVoiceNote) &&
            (identical(other.currentVoiceNoteId, currentVoiceNoteId) ||
                other.currentVoiceNoteId == currentVoiceNoteId) &&
            const DeepCollectionEquality()
                .equals(other._voiceNoteProgress, _voiceNoteProgress) &&
            (identical(other.isAiResponding, isAiResponding) ||
                other.isAiResponding == isAiResponding) &&
            const DeepCollectionEquality()
                .equals(other._aiResponses, _aiResponses) &&
            (identical(other.showEmojiPicker, showEmojiPicker) ||
                other.showEmojiPicker == showEmojiPicker) &&
            (identical(other.showAttachmentOptions, showAttachmentOptions) ||
                other.showAttachmentOptions == showAttachmentOptions) &&
            (identical(other.replyingToMessageId, replyingToMessageId) ||
                other.replyingToMessageId == replyingToMessageId) &&
            (identical(other.editingMessageId, editingMessageId) ||
                other.editingMessageId == editingMessageId) &&
            const DeepCollectionEquality()
                .equals(other._expandedMessages, _expandedMessages) &&
            (identical(other.isUploading, isUploading) ||
                other.isUploading == isUploading) &&
            (identical(other.quickReactionEmoji, quickReactionEmoji) ||
                other.quickReactionEmoji == quickReactionEmoji) &&
            const DeepCollectionEquality()
                .equals(other._quickReactionEmojis, _quickReactionEmojis) &&
            (identical(other.typingUser, typingUser) ||
                other.typingUser == typingUser) &&
            (identical(other.replyToMessage, replyToMessage) ||
                other.replyToMessage == replyToMessage) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline) &&
            (identical(other.isSyncing, isSyncing) ||
                other.isSyncing == isSyncing) &&
            const DeepCollectionEquality()
                .equals(other._lastSyncTimestamps, _lastSyncTimestamps) &&
            const DeepCollectionEquality()
                .equals(other._pendingMessages, _pendingMessages) &&
            (identical(other.syncError, syncError) ||
                other.syncError == syncError) &&
            const DeepCollectionEquality()
                .equals(other._syncConflicts, _syncConflicts) &&
            const DeepCollectionEquality()
                .equals(other._messageAnalytics, _messageAnalytics) &&
            const DeepCollectionEquality()
                .equals(other._messageReactions, _messageReactions) &&
            const DeepCollectionEquality()
                .equals(other._searchResults, _searchResults) &&
            (identical(other.searchQuery, searchQuery) ||
                other.searchQuery == searchQuery) &&
            (identical(other.isSearching, isSearching) ||
                other.isSearching == isSearching) &&
            const DeepCollectionEquality()
                .equals(other._voiceChatActive, _voiceChatActive) &&
            const DeepCollectionEquality().equals(other._voiceChatParticipants, _voiceChatParticipants) &&
            const DeepCollectionEquality().equals(other._mutedChats, _mutedChats) &&
            const DeepCollectionEquality().equals(other._pinnedChats, _pinnedChats) &&
            const DeepCollectionEquality().equals(other._chatThemes, _chatThemes) &&
            (identical(other.notificationsEnabled, notificationsEnabled) || other.notificationsEnabled == notificationsEnabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        isInitialized,
        isInitialDataLoaded,
        displayName,
        profileImage,
        const DeepCollectionEquality().hash(_chatMessages),
        const DeepCollectionEquality().hash(_chatGroups),
        const DeepCollectionEquality().hash(_userChatGroups),
        selectedChatGroupId,
        const DeepCollectionEquality().hash(_lastReadTimestamps),
        const DeepCollectionEquality().hash(_typingIndicators),
        const DeepCollectionEquality().hash(_unreadCounts),
        const DeepCollectionEquality().hash(_hasNewMessages),
        const DeepCollectionEquality().hash(_mediaHistory),
        const DeepCollectionEquality().hash(_pinnedMessages),
        const DeepCollectionEquality().hash(_activePolls),
        isRecording,
        isPlayingVoiceNote,
        currentVoiceNoteId,
        const DeepCollectionEquality().hash(_voiceNoteProgress),
        isAiResponding,
        const DeepCollectionEquality().hash(_aiResponses),
        showEmojiPicker,
        showAttachmentOptions,
        replyingToMessageId,
        editingMessageId,
        const DeepCollectionEquality().hash(_expandedMessages),
        isUploading,
        quickReactionEmoji,
        const DeepCollectionEquality().hash(_quickReactionEmojis),
        typingUser,
        replyToMessage,
        isOnline,
        isSyncing,
        const DeepCollectionEquality().hash(_lastSyncTimestamps),
        const DeepCollectionEquality().hash(_pendingMessages),
        syncError,
        const DeepCollectionEquality().hash(_syncConflicts),
        const DeepCollectionEquality().hash(_messageAnalytics),
        const DeepCollectionEquality().hash(_messageReactions),
        const DeepCollectionEquality().hash(_searchResults),
        searchQuery,
        isSearching,
        const DeepCollectionEquality().hash(_voiceChatActive),
        const DeepCollectionEquality().hash(_voiceChatParticipants),
        const DeepCollectionEquality().hash(_mutedChats),
        const DeepCollectionEquality().hash(_pinnedChats),
        const DeepCollectionEquality().hash(_chatThemes),
        notificationsEnabled
      ]);

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatStateImplCopyWith<_$ChatStateImpl> get copyWith =>
      __$$ChatStateImplCopyWithImpl<_$ChatStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatStateImplToJson(
      this,
    );
  }
}

abstract class _ChatState implements ChatState {
  const factory _ChatState(
      {required final bool isInitialized,
      required final bool isInitialDataLoaded,
      required final String displayName,
      final String? profileImage,
      required final Map<String, List<Message>> chatMessages,
      required final Map<String, ChatGroup> chatGroups,
      required final Map<String, ChatGroup> userChatGroups,
      final String? selectedChatGroupId,
      required final Map<String, DateTime> lastReadTimestamps,
      required final Map<String, Set<String>> typingIndicators,
      required final Map<String, int> unreadCounts,
      required final Map<String, bool> hasNewMessages,
      required final List<Map<String, dynamic>> mediaHistory,
      required final Map<String, List<String>> pinnedMessages,
      required final Map<String, Map<String, Poll>> activePolls,
      required final bool isRecording,
      required final bool isPlayingVoiceNote,
      final String? currentVoiceNoteId,
      required final Map<String, double> voiceNoteProgress,
      required final bool isAiResponding,
      required final Map<String, String> aiResponses,
      required final bool showEmojiPicker,
      required final bool showAttachmentOptions,
      final String? replyingToMessageId,
      final String? editingMessageId,
      required final Map<String, bool> expandedMessages,
      required final bool isUploading,
      required final String quickReactionEmoji,
      required final List<String> quickReactionEmojis,
      final String? typingUser,
      final Message? replyToMessage,
      required final bool isOnline,
      required final bool isSyncing,
      required final Map<String, DateTime> lastSyncTimestamps,
      required final List<Map<String, dynamic>> pendingMessages,
      final String? syncError,
      required final List<Map<String, dynamic>> syncConflicts,
      required final Map<String, Map<String, dynamic>> messageAnalytics,
      required final Map<String, List<Map<String, dynamic>>> messageReactions,
      required final List<Message> searchResults,
      required final String searchQuery,
      required final bool isSearching,
      required final Map<String, bool> voiceChatActive,
      required final Map<String, List<String>> voiceChatParticipants,
      required final Map<String, bool> mutedChats,
      required final Map<String, bool> pinnedChats,
      required final Map<String, String> chatThemes,
      required final bool notificationsEnabled}) = _$ChatStateImpl;

  factory _ChatState.fromJson(Map<String, dynamic> json) =
      _$ChatStateImpl.fromJson;

  @override
  bool get isInitialized;
  @override
  bool get isInitialDataLoaded;
  @override
  String get displayName;
  @override
  String? get profileImage; // Messages and groups
  @override
  Map<String, List<Message>> get chatMessages; // chatGroupId -> messages
  @override
  Map<String, ChatGroup> get chatGroups;
  @override
  Map<String, ChatGroup> get userChatGroups;
  @override
  String? get selectedChatGroupId;
  @override
  Map<String, DateTime> get lastReadTimestamps; // Real-time state
  @override
  Map<String, Set<String>>
      get typingIndicators; // chatGroupId -> typing user UIDs
  @override
  Map<String, int> get unreadCounts; // chatGroupId -> unread count
  @override
  Map<String, bool> get hasNewMessages; // Media and attachments
  @override
  List<Map<String, dynamic>> get mediaHistory;
  @override
  Map<String, List<String>>
      get pinnedMessages; // chatGroupId -> pinned message IDs
  @override
  Map<String, Map<String, Poll>>
      get activePolls; // chatGroupId -> pollId -> poll data
// Voice and audio
  @override
  bool get isRecording;
  @override
  bool get isPlayingVoiceNote;
  @override
  String? get currentVoiceNoteId;
  @override
  Map<String, double> get voiceNoteProgress; // AI integration
  @override
  bool get isAiResponding;
  @override
  Map<String, String> get aiResponses; // UI state
  @override
  bool get showEmojiPicker;
  @override
  bool get showAttachmentOptions;
  @override
  String? get replyingToMessageId;
  @override
  String? get editingMessageId;
  @override
  Map<String, bool> get expandedMessages;
  @override
  bool get isUploading;
  @override
  String get quickReactionEmoji;
  @override
  List<String> get quickReactionEmojis;
  @override
  String? get typingUser;
  @override
  Message? get replyToMessage; // Connection and sync
  @override
  bool get isOnline;
  @override
  bool get isSyncing;
  @override
  Map<String, DateTime> get lastSyncTimestamps;
  @override
  List<Map<String, dynamic>> get pendingMessages;
  @override
  String? get syncError;
  @override
  List<Map<String, dynamic>> get syncConflicts; // Analytics and metadata
  @override
  Map<String, Map<String, dynamic>> get messageAnalytics;
  @override
  Map<String, List<Map<String, dynamic>>>
      get messageReactions; // Search and filtering
  @override
  List<Message> get searchResults;
  @override
  String get searchQuery;
  @override
  bool get isSearching; // Voice chat integration
  @override
  Map<String, bool> get voiceChatActive; // chatGroupId -> is active
  @override
  Map<String, List<String>>
      get voiceChatParticipants; // chatGroupId -> participant UIDs
// Settings and preferences
  @override
  Map<String, bool> get mutedChats;
  @override
  Map<String, bool> get pinnedChats;
  @override
  Map<String, String> get chatThemes;
  @override
  bool get notificationsEnabled;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatStateImplCopyWith<_$ChatStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
