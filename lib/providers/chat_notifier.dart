import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';
import '../chat/message.dart';
import '../models/poll.dart';
import '../chat/chat_service.dart';
import '../services/services.dart';
import '../providers/service_providers.dart';
import '../services/ai_service.dart';
import '../managers/sync_manager.dart';
import '../utils.dart';

part 'chat_notifier.freezed.dart';
part 'chat_notifier.g.dart';

@freezed
class ChatState with _$ChatState {
  const factory ChatState({
    required bool isRecording,
    required bool isUploading,
    required List<String> typingUsers,
    required List<Message> messages,
    required int unreadCount,
    required Map<String, bool> sendingStatus,
    required String quickReactionEmoji,
    required List<String> quickReactionEmojis,
    required Map<String, dynamic>? replyToMessage,
    required bool isDMView,
    required int dmUnreadCount,
    required bool isInitialized,
    DocumentSnapshot? lastDocument,
    String? errorMessage,
    // Sync-related fields
    required bool isOnline,
    required bool isSyncing,
    required List<Map<String, dynamic>> syncConflicts,
    required int lastSyncTimestamp,
    String? syncError,
  }) = _ChatState;

  factory ChatState.initial() => const ChatState(
        isRecording: false,
        isUploading: false,
        typingUsers: [],
        messages: [],
        unreadCount: 0,
        sendingStatus: {},
        quickReactionEmoji: '👍',
        quickReactionEmojis: ['❤️', '👍', '😂', '😢', '😡', '😮'],
        replyToMessage: null,
        isDMView: false,
        dmUnreadCount: 0,
        isInitialized: false,
        errorMessage: null,
        // Sync-related initial values
        isOnline: true,
        isSyncing: false,
        syncConflicts: [],
        lastSyncTimestamp: 0,
        syncError: null,
      );
}

@riverpod
class ChatNotifier extends _$ChatNotifier {
  late final ChatService _chatService;
  late final MessageService _messageService;
  late final MediaService _mediaService;
  late final ReactionService _reactionService;
  late final PollService _pollService;
  late final AiService _aiService;
  late final SyncManager _syncManager;

  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  Future<ChatState> build() async {
    _chatService = ref.read(chatServiceProvider);
    _messageService = ref.read(messageServiceProvider);
    _mediaService = ref.read(mediaServiceProvider);
    _reactionService = ref.read(reactionServiceProvider);
    _pollService = ref.read(pollServiceProvider);
    _aiService = ref.read(aiServiceProvider);
    _syncManager = ref.read(syncManagerProvider);

    // Set up connectivity monitoring
    _setupConnectivityMonitoring();

    return ChatState.initial().copyWith(isInitialized: true);
  }

  // Connectivity and sync management
  void _setupConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) async {
        final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
        final isOnline = result != ConnectivityResult.none;
        final currentState = state.value;
        if (currentState != null && currentState.isOnline != isOnline) {
          final newState = currentState.copyWith(isOnline: isOnline);
          state = AsyncValue.data(newState);

          // Trigger sync when coming back online
          if (isOnline && currentState.isInitialized) {
            await _performSync();
          }
        }
      },
    );
  }

  Future<void> _performSync({String? chatGroupId}) async {
    if (!state.value!.isOnline || state.value!.isSyncing) return;

    try {
      // Update sync state
      var newState = state.value!.copyWith(
        isSyncing: true,
        syncError: null,
      );
      state = AsyncValue.data(newState);

      // Perform delta sync
      final syncResult = await _syncManager.deltaSync(chatGroupId ?? '');

      // Update state with sync results
      newState = state.value!.copyWith(
        isSyncing: false,
        syncConflicts: syncResult.conflicts.map((c) => {
          'local': c.localMessage,
          'remote': c.remoteMessage,
          'resolution': c.resolution.toString(),
        }).toList(),
        lastSyncTimestamp: await _syncManager.getLastSyncTimestamp(),
        syncError: syncResult.error,
      );
      state = AsyncValue.data(newState);

      // If there are unresolved conflicts, notify user
      if (syncResult.conflicts.any((c) => c.resolution == ConflictResolution.unresolved)) {
        // This would typically show a notification or dialog
        // For now, we'll just update the state
      }

      // Refresh messages if sync was successful
      if (syncResult.success && chatGroupId != null) {
        await _refreshMessages(chatGroupId);
      }
    } catch (e) {
      final errorState = state.value!.copyWith(
        isSyncing: false,
        syncError: e.toString(),
      );
      state = AsyncValue.data(errorState);
    }
  }

  Future<void> _refreshMessages(String chatGroupId) async {
    // Trigger a refresh of the current chat view
    // This would typically reload messages from the updated cache
    final currentMessages = await _messageService.getCachedMessages(0, 50, chatGroupId: chatGroupId);
    final messages = currentMessages.map((data) {
      return Message(
        sender: data['sender_name'] ?? data['sender'] ?? 'Unknown',
        timestamp: data['timestamp_ms'] != null
            ? DateTime.fromMillisecondsSinceEpoch(data['timestamp_ms'])
            : DateTime.now(),
        content: data['content'] ?? data['text'] ?? '',
        reactions: (data['reactions'] as List<dynamic>?)
                ?.map((r) => Map<String, String>.from(r))
                .toList() ??
            [],
      );
    }).toList();

    final newState = state.value!.copyWith(messages: messages);
    state = AsyncValue.data(newState);
  }

  // Manual sync trigger
  Future<void> syncNow({String? chatGroupId}) async {
    await _performSync(chatGroupId: chatGroupId);
  }

  // Resolve sync conflicts manually
  Future<void> resolveConflict(String messageId, ConflictResolution resolution) async {
    // Update the conflict resolution in state
    final currentConflicts = List<Map<String, dynamic>>.from(state.value!.syncConflicts);
    final conflictIndex = currentConflicts.indexWhere((c) => c['local']['id'] == messageId);

    if (conflictIndex != -1) {
      currentConflicts[conflictIndex]['resolution'] = resolution.toString();

      final newState = state.value!.copyWith(syncConflicts: currentConflicts);
      state = AsyncValue.data(newState);

      // For now, just update the state
      // TODO: Implement actual conflict resolution with SyncManager
    }
  }

  // Message management
  Future<void> sendMessage(BuildContext context, String content,
      {String? chatGroupId, Map<String, dynamic>? replyTo}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final messageId = DateTime.now().millisecondsSinceEpoch.toString();

      // Update sending status
      final currentStatus = Map<String, bool>.from(state.value!.sendingStatus);
      currentStatus[messageId] = true;
      var newState = state.value!.copyWith(sendingStatus: currentStatus);
      state = AsyncValue.data(newState);

      // Send message using ChatService
      final result = await _chatService.sendMessage(
        context,
        senderUid: user.uid,
        text: content,
        replyTo: replyTo?['id'],
        chatGroupId: chatGroupId,
        chatType: chatGroupId != null ? ChatType.userGroup : ChatType.squad,
      );

      if (result.success) {
        // Create Message object for local state
        final message = Message(
          sender: user.displayName ?? user.uid,
          content: content,
          timestamp: DateTime.now(),
          reactions: [],
        );

        // Update local state
        final currentMessages = List<Message>.from(state.value!.messages);
        currentMessages.add(message);

        newState = state.value!.copyWith(
          messages: currentMessages,
          sendingStatus: {...currentStatus}..[messageId] = false,
        );
        state = AsyncValue.data(newState);
      }
    } catch (e) {
      showErrorSnackBar(context, 'Failed to send message: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> loadMessages(String? chatGroupId, ChatType chatType,
      {int limit = 50}) async {
    try {
      // Perform sync first to ensure data is up to date
      if (chatGroupId != null && state.value!.isOnline) {
        await _performSync(chatGroupId: chatGroupId);
      }

      // First try to load from cache (SQLite) for offline support
      final cachedMessages = await _messageService.getCachedMessages(0, limit,
          chatGroupId: chatGroupId);

      if (cachedMessages.isNotEmpty) {
        // Use cached messages if available
        final messages = cachedMessages.map((data) {
          return Message(
            sender: data['sender_name'] ?? data['sender'] ?? 'Unknown',
            timestamp: data['timestamp_ms'] != null
                ? DateTime.fromMillisecondsSinceEpoch(data['timestamp_ms'])
                : DateTime.now(),
            content: data['content'] ?? data['text'] ?? '',
            reactions: (data['reactions'] as List<dynamic>?)
                    ?.map((r) => Map<String, String>.from(r))
                    .toList() ??
                [],
          );
        }).toList();

        final newState = state.value!.copyWith(messages: messages);
        state = AsyncValue.data(newState);
      }

      // Set up real-time listener from Firestore with conflict-aware merging
      _messagesSubscription?.cancel();

      String collectionPath;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (chatType == ChatType.userGroup) {
        collectionPath = 'users/${user.uid}/chat_groups/$chatGroupId/messages';
      } else if (chatType == ChatType.dm) {
        collectionPath = 'chats/$chatGroupId/messages';
      } else {
        // For squad chat, use the main chat collection
        collectionPath = 'chat';
      }

      _messagesSubscription = FirebaseFirestore.instance
          .collection(collectionPath)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .listen((snapshot) async {
        final remoteMessages = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();

        // For now, just use remote messages
        // TODO: Implement conflict detection and resolution in a future update
        final messages = remoteMessages.map((data) {
          return Message(
            sender: data['sender'] ?? 'Unknown',
            timestamp:
                (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            content: data['content'] ?? data['text'] ?? '',
            reactions: (data['reactions'] as List<dynamic>?)
                    ?.map((r) => Map<String, String>.from(r))
                    .toList() ??
                [],
          );
        }).toList();

        final newState = state.value!.copyWith(
          messages: messages,
          lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        );
        state = AsyncValue.data(newState);
      });
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> loadMoreMessages(String chatGroupId) async {
    // Simplified - not implementing pagination for now
    // TODO: Implement proper pagination
  }

  // Recording and media
  void startRecording() {
    final newState = state.value!.copyWith(isRecording: true);
    state = AsyncValue.data(newState);
  }

  void stopRecording() {
    final newState = state.value!.copyWith(isRecording: false);
    state = AsyncValue.data(newState);
  }

  Future<void> uploadMedia(BuildContext context, String filePath) async {
    try {
      final newState = state.value!.copyWith(isUploading: true);
      state = AsyncValue.data(newState);

      // Upload media using MediaService
      final file = File(filePath);
      final fileName = file.path.split('/').last;
      final isVideo = fileName.toLowerCase().endsWith('.mp4') ||
          fileName.toLowerCase().endsWith('.mov') ||
          fileName.toLowerCase().endsWith('.avi');

      final mediaUrl = await _mediaService.uploadMedia(file, fileName, isVideo);

      // Send media message
      await sendMessage(context, '[Media: $mediaUrl]');

      final finalState = state.value!.copyWith(isUploading: false);
      state = AsyncValue.data(finalState);
    } catch (e) {
      final errorState = state.value!.copyWith(
        isUploading: false,
        errorMessage: e.toString(),
      );
      state = AsyncValue.data(errorState);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload media: $e')),
        );
      }
    }
  }

  // Typing indicators
  void updateTypingStatus(String userId, bool isTyping) {
    final currentTyping = List<String>.from(state.value!.typingUsers);

    if (isTyping && !currentTyping.contains(userId)) {
      currentTyping.add(userId);
    } else if (!isTyping) {
      currentTyping.remove(userId);
    }

    final newState = state.value!.copyWith(typingUsers: currentTyping);
    state = AsyncValue.data(newState);
  }

  // Reactions
  Future<void> addReaction(BuildContext context, String messageId, String emoji,
      {String? chatGroupId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final chatType =
          chatGroupId != null ? ChatType.userGroup : ChatType.squad;

      await _reactionService.addReaction(
        chatGroupId: chatGroupId ?? 'default',
        messageId: messageId,
        emoji: emoji,
        chatType: chatType,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reaction added')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add reaction: $e')),
        );
      }
    }
  }

  Future<void> removeReaction(
      BuildContext context, String messageId, String emoji,
      {String? chatGroupId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final chatType =
          chatGroupId != null ? ChatType.userGroup : ChatType.squad;

      await _reactionService.removeReaction(
        chatGroupId: chatGroupId ?? 'default',
        messageId: messageId,
        emoji: emoji,
        chatType: chatType,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reaction removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove reaction: $e')),
        );
      }
    }
  }

  // Polls
  Future<void> createPoll(BuildContext context, Map<String, dynamic> pollData,
      {String? chatGroupId}) async {
    try {
      final title = pollData['title'] as String?;
      final options = pollData['options'] as List<String>?;
      final settings = pollData['settings'] as PollSettings?;

      if (title == null || options == null || settings == null) {
        throw Exception('Invalid poll data');
      }

      final pollId = await _pollService.createPoll(
        title: title,
        options: options,
        settings: settings,
        chatGroupId: chatGroupId,
      );

      if (pollId != null) {
        // Send poll message
        await sendMessage(context, '[Poll: $pollId]');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Poll created successfully')),
          );
        }
      } else {
        throw Exception('Failed to create poll');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create poll: $e')),
        );
      }
    }
  }

  Future<void> voteOnPoll(
      BuildContext context, String pollId, List<String> optionIds,
      {String? chatGroupId}) async {
    try {
      final success = await _pollService.voteOnPoll(
        pollId: pollId,
        optionIds: optionIds,
        chatGroupId: chatGroupId,
      );

      if (success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vote recorded')),
          );
        }
      } else {
        throw Exception('Failed to vote on poll');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to vote: $e')),
        );
      }
    }
  }

  // Reply functionality
  void setReplyToMessage(Message? message) {
    final newState = state.value!.copyWith(replyToMessage: message?.toJson());
    state = AsyncValue.data(newState);
  }

  void clearReplyToMessage() {
    final newState = state.value!.copyWith(replyToMessage: null);
    state = AsyncValue.data(newState);
  }

  // Quick reactions
  void setQuickReactionEmoji(String emoji) {
    final newState = state.value!.copyWith(quickReactionEmoji: emoji);
    state = AsyncValue.data(newState);
  }

  // View switching
  void switchToDMView() {
    final newState = state.value!.copyWith(isDMView: true);
    state = AsyncValue.data(newState);
  }

  void switchToGroupView() {
    final newState = state.value!.copyWith(isDMView: false);
    state = AsyncValue.data(newState);
  }

  // Sync management methods
  Future<void> performSync() async {
    if (!state.value!.isOnline) return;

    final newState = state.value!.copyWith(isSyncing: true, syncError: null);
    state = AsyncValue.data(newState);

    try {
      await _syncManager.deltaSync(''); // Empty string for global sync
      final updatedState = state.value!.copyWith(
        isSyncing: false,
        lastSyncTimestamp: DateTime.now().millisecondsSinceEpoch,
      );
      state = AsyncValue.data(updatedState);
    } catch (e) {
      final errorState = state.value!.copyWith(
        isSyncing: false,
        syncError: e.toString(),
      );
      state = AsyncValue.data(errorState);
    }
  }

  void clearSyncError() {
    final newState = state.value!.copyWith(syncError: null);
    state = AsyncValue.data(newState);
  }

  void dispose() {
    _messagesSubscription?.cancel();
  }

  Future<List<String>> generatePollOptions(String pollQuestion) async {
    try {
      return await _aiService.generatePollOptions(pollQuestion);
    } catch (e) {
      // Return empty list on error
      return [];
    }
  }
}
