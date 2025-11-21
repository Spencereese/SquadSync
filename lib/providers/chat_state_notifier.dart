import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../chat/message.dart';
import '../services/reaction_service.dart';
import '../chat/sqlite_helper.dart';
import '../providers.dart';
import '../services/ai_service.dart'; // for ChatType
import '../chat/chat_service.dart';
import '../managers/user_manager.dart';

part 'chat_state_notifier.freezed.dart';

// Typedef for consistent naming
typedef SquadStateData = ChatStateData;

@freezed
class ChatStateData with _$ChatStateData {
  const factory ChatStateData({
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
    String? errorMessage,
    required bool isInitialized,
    DocumentSnapshot? lastDocument,
  }) = _ChatStateData;

  factory ChatStateData.initial() => const ChatStateData(
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
        errorMessage: null,
        isInitialized: false,
        lastDocument: null,
      );
}

class ChatStateNotifier extends StateNotifier<ChatStateData> {
  final Ref ref;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final Map<String, Timer> _typingTimers = {}; // Per-user typing timers
  String? _currentChatGroupId;
  DocumentSnapshot? _lastDocument;

  late final ChatService _chatService;
  late final ReactionService _reactionService;
  late final UserManager _userManager;
  late final SQLiteHelper _sqliteHelper;
  late final dynamic _database; // From databaseProvider

  ChatStateNotifier(this.ref) : super(ChatStateData.initial()) {
    // Lazy initialization - don't initialize Firebase here
  }

  // Lazy initialization method
  void init() {
    if (state.isInitialized) return;

    _chatService = ref.read(chatServiceProvider);
    _reactionService = ref.read(reactionServiceProvider);
    _userManager = ref.read(userManagerProvider);
    _sqliteHelper = ref.read(sqliteHelperProvider);
    // _database = ref.watch(databaseProvider); // TODO: Add databaseProvider

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      handleOfflineSync();
    });

    ref.onDispose(() {
      _messagesSubscription?.cancel();
      _connectivitySubscription?.cancel();
      for (var timer in _typingTimers.values) {
        timer.cancel();
      }
      _typingTimers.clear();
    });

    state = state.copyWith(isInitialized: true);
  }

  void startRecording() {
    state = state.copyWith(isRecording: true);
  }

  void stopRecording() {
    state = state.copyWith(isRecording: false);
  }

  void updateTyping(String userId, bool isTyping) {
    // Cancel existing timer for this user
    _typingTimers[userId]?.cancel();

    if (isTyping) {
      // Add user to typing list
      final newTyping = List<String>.from(state.typingUsers);
      if (!newTyping.contains(userId)) {
        newTyping.add(userId);
      }
      state = state.copyWith(typingUsers: newTyping);

      // Set timer to remove user after 500ms
      _typingTimers[userId] = Timer(const Duration(milliseconds: 500), () {
        final updatedTyping = List<String>.from(state.typingUsers)
          ..remove(userId);
        state = state.copyWith(typingUsers: updatedTyping);
        _typingTimers.remove(userId);
      });
    } else {
      // Remove user immediately
      final updatedTyping = List<String>.from(state.typingUsers)
        ..remove(userId);
      state = state.copyWith(typingUsers: updatedTyping);
      _typingTimers.remove(userId);
    }
  }

  void loadMessages(String chatGroupId) {
    init(); // Ensure initialized
    _currentChatGroupId = chatGroupId;

    // Try Firestore first, fallback to SQLite
    final stream = FirebaseFirestore.instance
        .collection('chats/$chatGroupId/messages')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots();

    _messagesSubscription?.cancel();
    _messagesSubscription = stream.listen((snapshot) {
      final messages =
          snapshot.docs.map((doc) => Message.fromJson(doc.data())).toList();
      _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      state = state.copyWith(messages: messages, lastDocument: _lastDocument);
    }, onError: (error) {
      // Fallback to SQLite if offline
      _loadFromSQLite(chatGroupId);
    });
  }

  void _loadFromSQLite(String chatGroupId) async {
    final cachedMessages =
        await _sqliteHelper.getMessages(0, 20, chatGroupId: chatGroupId);
    final messages =
        cachedMessages.map((map) => Message.fromJson(map)).toList();
    state = state.copyWith(messages: messages);
  }

  void paginateMore() {
    if (_currentChatGroupId == null || _lastDocument == null) return;

    final stream = FirebaseFirestore.instance
        .collection('chats/$_currentChatGroupId/messages')
        .orderBy('timestamp', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(20)
        .snapshots();

    stream.listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final newMessages =
            snapshot.docs.map((doc) => Message.fromJson(doc.data())).toList();
        final allMessages = [...state.messages, ...newMessages];
        _lastDocument = snapshot.docs.last;
        state = state.copyWith(
          messages: allMessages,
          lastDocument: _lastDocument,
        );
      }
    }, onError: (error) {
      // Could fallback to SQLite pagination if needed
    });
  }

  void updateSendingStatus(String id, bool status) {
    final newStatus = Map<String, bool>.from(state.sendingStatus);
    if (status) {
      newStatus[id] = true;
    } else {
      newStatus.remove(id);
    }
    state = state.copyWith(sendingStatus: newStatus);
  }

  void removeSendingStatus(String id) {
    final newStatus = Map<String, bool>.from(state.sendingStatus)..remove(id);
    state = state.copyWith(sendingStatus: newStatus);
  }

  void clearReplyToMessage() {
    state = state.copyWith(replyToMessage: null);
  }

  void setReplyToMessage(Map<String, dynamic> message) {
    state = state.copyWith(replyToMessage: message);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<void> sendMessage(Message message) async {
    try {
      // Generate ID for Firestore
      final messageId = FirebaseFirestore.instance
          .collection('chats')
          .doc(_currentChatGroupId)
          .collection('messages')
          .doc()
          .id;

      // Create message data with ID
      final messageData = {
        'id': messageId,
        'sender': message.sender,
        'timestamp': message.timestamp,
        'content': message.content,
        'reactions': message.reactions,
      };

      // Try to send to Firestore
      final docRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(_currentChatGroupId)
          .collection('messages')
          .doc(messageId);
      await docRef.set(messageData);

      // Cache locally for offline access
      await _sqliteHelper.insertMessage(messageData);

      // Update state optimistically
      state = state.copyWith(messages: [...state.messages, message]);
    } catch (error) {
      // If offline, cache locally and mark for sync
      final offlineMessageData = {
        'sender': message.sender,
        'timestamp': message.timestamp,
        'content': message.content,
        'reactions': message.reactions,
      };
      await _sqliteHelper.insertMessage(offlineMessageData);
      state = state.copyWith(
        messages: [...state.messages, message],
        errorMessage: 'Message queued for sending when online',
      );
    }
  }

  void handleOfflineSync() {
    // Sync pending messages when online
    // TODO: Implement syncing logic
  }

  void handleMessageReactions(String messageId, String reaction) {
    _reactionService.addReaction(
      chatGroupId: _currentChatGroupId!,
      messageId: messageId,
      emoji: reaction,
      chatType: ChatType.dm,
    );
  }

  void startTyping() {
    // TODO: Implement typing start logic
  }
}

final chatStateNotifierProvider =
    StateNotifierProvider.autoDispose<ChatStateNotifier, ChatStateData>(
        (ref) => ChatStateNotifier(ref));
