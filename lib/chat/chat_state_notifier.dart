import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chat UI state model for Riverpod
class ChatUIState {
  final String? typingUser;
  final bool isRecording;
  final bool isUploading;
  final Map<String, bool> sendingStatus;
  final String quickReactionEmoji;
  final List<String> quickReactionEmojis;
  final Map<String, dynamic>? replyToMessage;
  final bool isDMView;
  final int dmUnreadCount;

  const ChatUIState({
    this.typingUser,
    this.isRecording = false,
    this.isUploading = false,
    this.sendingStatus = const {},
    this.quickReactionEmoji = '👍',
    this.quickReactionEmojis = const ['❤️', '👍', '😂', '😢', '😡', '😮'],
    this.replyToMessage,
    this.isDMView = false,
    this.dmUnreadCount = 0,
  });

  bool get hasPendingMessages => sendingStatus.isNotEmpty;

  ChatUIState copyWith({
    String? Function()? typingUser,
    bool? isRecording,
    bool? isUploading,
    Map<String, bool>? sendingStatus,
    String? quickReactionEmoji,
    List<String>? quickReactionEmojis,
    Map<String, dynamic>? Function()? replyToMessage,
    bool? isDMView,
    int? dmUnreadCount,
  }) {
    return ChatUIState(
      typingUser: typingUser != null ? typingUser() : this.typingUser,
      isRecording: isRecording ?? this.isRecording,
      isUploading: isUploading ?? this.isUploading,
      sendingStatus: sendingStatus ?? this.sendingStatus,
      quickReactionEmoji: quickReactionEmoji ?? this.quickReactionEmoji,
      quickReactionEmojis: quickReactionEmojis ?? this.quickReactionEmojis,
      replyToMessage:
          replyToMessage != null ? replyToMessage() : this.replyToMessage,
      isDMView: isDMView ?? this.isDMView,
      dmUnreadCount: dmUnreadCount ?? this.dmUnreadCount,
    );
  }

  static const initial = ChatUIState();
}

/// Riverpod StateNotifier for chat UI state (using legacy for Riverpod 3.0)
class ChatStateNotifier extends StateNotifier<ChatUIState> {
  ChatStateNotifier() : super(ChatUIState.initial) {
    loadQuickReactionEmojis();
  }

  void setTypingUser(String? user) {
    if (state.typingUser != user) {
      state = state.copyWith(typingUser: () => user);
    }
  }

  void setRecording(bool value) {
    if (state.isRecording != value) {
      state = state.copyWith(isRecording: value);
    }
  }

  void toggleRecording() {
    state = state.copyWith(isRecording: !state.isRecording);
  }

  void setUploading(bool value) {
    if (state.isUploading != value) {
      state = state.copyWith(isUploading: value);
    }
  }

  void updateSendingStatus(String tempId, bool isSending) {
    try {
      _validateTempId(tempId);
      final newStatus = Map<String, bool>.from(state.sendingStatus);
      if (isSending) {
        newStatus[tempId] = true;
      } else {
        newStatus.remove(tempId);
      }
      state = state.copyWith(sendingStatus: newStatus);
    } catch (e) {
      debugPrint('Error updating sending status: $e');
    }
  }

  void removeSendingStatus(String tempId) {
    try {
      _validateTempId(tempId);
      final newStatus = Map<String, bool>.from(state.sendingStatus);
      if (newStatus.remove(tempId) != null) {
        state = state.copyWith(sendingStatus: newStatus);
      }
    } catch (e) {
      debugPrint('Error removing sending status: $e');
    }
  }

  bool isMessageSending(String tempId) {
    try {
      _validateTempId(tempId);
      return state.sendingStatus[tempId] ?? false;
    } catch (e) {
      debugPrint('Error checking sending status: $e');
      return false;
    }
  }

  void clearSendingStatus() {
    if (state.sendingStatus.isNotEmpty) {
      state = state.copyWith(sendingStatus: {});
    }
  }

  void reset() {
    state = ChatUIState.initial;
  }

  void setReplyToMessage(Map<String, dynamic>? message) {
    state = state.copyWith(replyToMessage: () => message);
  }

  void clearReplyToMessage() {
    state = state.copyWith(replyToMessage: () => null);
  }

  void setDMView(bool value) {
    if (state.isDMView != value) {
      state = state.copyWith(isDMView: value);
    }
  }

  void setDMUnreadCount(int count) {
    if (state.dmUnreadCount != count) {
      state = state.copyWith(dmUnreadCount: count);
    }
  }

  void toggleDMView() {
    state = state.copyWith(isDMView: !state.isDMView);
  }

  void incrementDMUnreadCount() {
    state = state.copyWith(dmUnreadCount: state.dmUnreadCount + 1);
  }

  void decrementDMUnreadCount() {
    state = state.copyWith(dmUnreadCount: state.dmUnreadCount - 1);
  }

  void _validateTempId(String tempId) {
    if (tempId.isEmpty || tempId.trim().isEmpty) {
      throw ArgumentError('tempId cannot be empty or null');
    }
  }

  Future<void> setQuickReactionEmoji(String emoji) async {
    try {
      state = state.copyWith(quickReactionEmoji: emoji);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('quick_reaction_emoji', emoji);
    } catch (e) {
      debugPrint('Error setting quick reaction emoji: $e');
    }
  }

  Future<void> setQuickReactionEmojis(List<String> emojis) async {
    try {
      state = state.copyWith(quickReactionEmojis: List.from(emojis));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('quick_reaction_emojis', emojis);
    } catch (e) {
      debugPrint('Error setting quick reaction emojis: $e');
    }
  }

  Future<void> loadQuickReactionEmojis() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('quick_reaction_emojis');
      if (saved != null && saved.isNotEmpty) {
        state = state.copyWith(quickReactionEmojis: List.from(saved));
      }
    } catch (e) {
      debugPrint('Error loading quick reaction emojis: $e');
    }
  }
}

/// Provider for chat UI state (using legacy StateNotifierProvider for Riverpod 3.0)
final chatStateProvider =
    StateNotifierProvider<ChatStateNotifier, ChatUIState>((ref) {
  return ChatStateNotifier();
});
