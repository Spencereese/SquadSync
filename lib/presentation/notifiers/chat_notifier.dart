import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:squad_sync/domain/entities/chat_group.dart';
import 'package:squad_sync/domain/entities/chat_state.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/usecases/send_message.dart';
import 'package:squad_sync/domain/usecases/load_messages.dart';
import 'package:squad_sync/domain/usecases/delta_sync.dart';
import 'package:squad_sync/domain/usecases/add_reaction.dart';
import 'package:squad_sync/domain/usecases/create_poll.dart';
import 'package:squad_sync/domain/usecases/vote_poll.dart';
import 'package:squad_sync/domain/usecases/upload_media.dart';
import 'package:squad_sync/domain/usecases/create_group.dart';
import 'package:squad_sync/domain/usecases/join_group.dart';
import 'package:squad_sync/domain/usecases/leave_group.dart';
import 'package:squad_sync/domain/usecases/update_typing_indicator.dart';
import 'package:squad_sync/domain/usecases/pin_message.dart';
import 'package:squad_sync/domain/usecases/load_media_history.dart';
import 'package:squad_sync/core/injection.dart' as di;

part 'chat_notifier.g.dart';

@riverpod
class ChatNotifier extends _$ChatNotifier {
  late final SendMessage _sendMessage;
  late final LoadMessages _loadMessages;
  late final DeltaSync _deltaSync;
  late final AddReaction _addReaction;
  late final CreatePoll _createPoll;
  late final VotePoll _votePoll;
  late final UploadMedia _uploadMedia;
  late final CreateGroup _createGroup;
  late final JoinGroup _joinGroup;
  late final LeaveGroup _leaveGroup;
  late final UpdateTypingIndicator _updateTypingIndicator;
  late final PinMessage _pinMessage;
  late final LoadMediaHistory _loadMediaHistory;

  @override
  Future<ChatState> build() async {
    // Get dependencies from get_it
    _sendMessage = di.getIt<SendMessage>();
    _loadMessages = di.getIt<LoadMessages>();
    _deltaSync = di.getIt<DeltaSync>();
    _addReaction = di.getIt<AddReaction>();
    _createPoll = di.getIt<CreatePoll>();
    _votePoll = di.getIt<VotePoll>();
    _uploadMedia = di.getIt<UploadMedia>();
    _createGroup = di.getIt<CreateGroup>();
    _joinGroup = di.getIt<JoinGroup>();
    _leaveGroup = di.getIt<LeaveGroup>();
    _updateTypingIndicator = di.getIt<UpdateTypingIndicator>();
    _pinMessage = di.getIt<PinMessage>();
    _loadMediaHistory = di.getIt<LoadMediaHistory>();

    return ChatState.initial();
  }

  // Message operations
  Future<void> sendMessage(String chatGroupId, String text,
      MessageType messageType, ChatType chatType,
      {String? mediaUrl,
      String? mediaType,
      String? replyTo,
      Poll? poll,
      String? voiceNoteUrl,
      int? voiceNoteDuration}) async {
    await _sendMessage(chatGroupId, text, messageType, chatType,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        replyTo: replyTo,
        poll: poll,
        voiceNoteUrl: voiceNoteUrl,
        voiceNoteDuration: voiceNoteDuration);
    // State will be updated via streams/watchers
  }

  Future<void> loadMessages(String chatGroupId,
      {int limit = 50, DateTime? before}) async {
    final messages =
        await _loadMessages(chatGroupId, limit: limit, before: before);
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      final updatedMessages =
          Map<String, List<Message>>.from(currentState.chatMessages);
      updatedMessages[chatGroupId] = messages;
      return currentState.copyWith(chatMessages: updatedMessages);
    });
  }

  Future<void> syncMessages(String chatGroupId) async {
    await _deltaSync(chatGroupId);
    // Reload messages after sync
    await loadMessages(chatGroupId);
  }

  // Reactions
  Future<void> addReaction(
      String chatGroupId, String messageId, String reaction) async {
    await _addReaction(chatGroupId, messageId, reaction);
  }

  // Polls
  Future<void> createPoll(
      String chatGroupId, String question, List<String> options) async {
    await _createPoll(chatGroupId, question, options);
  }

  Future<void> votePoll(
      String chatGroupId, String pollId, String option, String voterId) async {
    await _votePoll(chatGroupId, pollId, option, voterId);
  }

  // Media
  Future<String> uploadMedia(String filePath, String mediaType) async {
    return await _uploadMedia(filePath, mediaType);
  }

  Future<void> loadMediaHistory(String chatGroupId) async {
    final mediaHistory = await _loadMediaHistory(chatGroupId);
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      return currentState.copyWith(mediaHistory: mediaHistory);
    });
  }

  // Group management
  Future<void> createGroup(String name, bool isPublic,
      {String? description}) async {
    final group = await _createGroup(name, isPublic, description: description);
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      final updatedGroups =
          Map<String, ChatGroup>.from(currentState.chatGroups);
      updatedGroups[group.id] = group;
      return currentState.copyWith(chatGroups: updatedGroups);
    });
  }

  Future<void> joinGroup(String groupId) async {
    await _joinGroup(groupId);
  }

  Future<void> leaveGroup(String groupId) async {
    await _leaveGroup(groupId);
  }

  // Typing indicators
  Future<void> updateTypingIndicator(String chatGroupId, bool isTyping) async {
    await _updateTypingIndicator(chatGroupId, isTyping);
  }

  // Pinning
  Future<void> pinMessage(String chatGroupId, String messageId) async {
    await _pinMessage(chatGroupId, messageId);
  }

  // UI state management
  Future<void> selectChatGroup(String? groupId) async {
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      return currentState.copyWith(selectedChatGroupId: groupId);
    });
  }

  Future<void> setReplyingToMessage(String? messageId) async {
    state = await AsyncValue.guard(() async {
      final currentState = await future;

      Message? replyToMessage;
      if (messageId != null && currentState.selectedChatGroupId != null) {
        final messages =
            currentState.chatMessages[currentState.selectedChatGroupId] ?? [];
        try {
          replyToMessage = messages.firstWhere(
            (message) => message.id == messageId,
          );
        } catch (e) {
          replyToMessage = null;
        }
      }

      return currentState.copyWith(
        replyingToMessageId: messageId,
        replyToMessage: replyToMessage,
      );
    });
  }

  Future<void> setReplyingToMessageObject(Message? message) async {
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      return currentState.copyWith(
        replyingToMessageId: message?.id,
        replyToMessage: message,
      );
    });
  }

  Future<void> clearReplyToMessage() async {
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      return currentState.copyWith(
          replyingToMessageId: null, replyToMessage: null);
    });
  }

  // Sync operations
  Future<void> performSync() async {
    // TODO: Implement delta sync
    // await _deltaSync();
  }

  Future<void> clearSyncError() async {
    state = await AsyncValue.guard(() async {
      final currentState = await future;
      return currentState.copyWith(syncError: null);
    });
  }

  // Dispose method (for compatibility)
  void dispose() {
    // AsyncNotifier handles disposal automatically
  }

  // Helper methods for computed properties
  List<Message> getMessagesForGroup(String chatGroupId) {
    return state.maybeWhen(
      data: (data) => data.chatMessages[chatGroupId] ?? [],
      orElse: () => [],
    );
  }

  Set<String> getTypingUsers(String chatGroupId) {
    return state.maybeWhen(
      data: (data) => data.typingIndicators[chatGroupId] ?? {},
      orElse: () => {},
    );
  }

  int getUnreadCount(String chatGroupId) {
    return state.maybeWhen(
      data: (data) => data.unreadCounts[chatGroupId] ?? 0,
      orElse: () => 0,
    );
  }

  bool isUserTyping(String chatGroupId, String userId) {
    return getTypingUsers(chatGroupId).contains(userId);
  }

  List<Map<String, dynamic>> getMediaHistory() {
    return state.maybeWhen(
      data: (data) => data.mediaHistory,
      orElse: () => [],
    );
  }

  Map<String, Poll> getActivePolls(String chatGroupId) {
    return state.maybeWhen(
      data: (data) => (data.activePolls[chatGroupId] ?? {}).map(
        (key, value) => MapEntry(key, value),
      ),
      orElse: () => {},
    );
  }
}
