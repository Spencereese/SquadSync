import 'package:flutter/foundation.dart';

/// Empty / loading / error for ChatScreen threads and the shared chat list.
enum ChatSurfaceKind { thread, list }

enum ChatSurfacePhase { data, empty, loading, error }

const kChatSurfaceRetryLabel = 'Retry';

const kChatSurfaceErrorHint = 'Check your connection and try again.';
const kChatSurfaceOfflineCopy = "You're offline";

const kChatThreadEmptyCopy = 'No messages yet';
const kChatThreadEmptyHint = 'Say something to start the thread.';
const kChatThreadErrorCopy = "Couldn't load chat";
const kChatThreadLoadingCopy = 'Loading chat...';

const kChatListEmptyCopy = 'No chats yet';
const kChatListEmptyHint = 'Create a group to start chatting.';
const kChatListErrorCopy = "Couldn't load chats";
const kChatListLoadingCopy = 'Loading chats...';

const kChatSurfaceTitleSize = 18.0;
const kChatSurfaceBodySize = 15.0;
const kChatSurfaceHintSize = 14.0;
const kChatSurfaceActionMinHeight = 44.0;

/// Empty / error / loading for a chat thread or chat list.
///
/// Loading only while a fetch is in flight with no rows — never a settled
/// spinner. Offline or error with no rows is error + Retry, not empty.
ChatSurfacePhase resolveChatSurfacePhase({
  required bool isLoading,
  Object? error,
  bool isEmpty = false,
  bool isOffline = false,
  int itemCount = 0,
}) {
  final hasRows = itemCount > 0 && !isEmpty;
  if (isLoading && !hasRows && error == null && !isOffline) {
    return ChatSurfacePhase.loading;
  }
  if ((error != null || isOffline) && !hasRows) {
    return ChatSurfacePhase.error;
  }
  if (!hasRows) return ChatSurfacePhase.empty;
  return ChatSurfacePhase.data;
}

Key chatSurfaceKey(ChatSurfaceKind kind, ChatSurfacePhase phase) {
  switch (kind) {
    case ChatSurfaceKind.thread:
      switch (phase) {
        case ChatSurfacePhase.empty:
          return const Key('chat-thread-empty');
        case ChatSurfacePhase.loading:
          return const Key('chat-thread-loading');
        case ChatSurfacePhase.error:
          return const Key('chat-thread-error');
        case ChatSurfacePhase.data:
          return const Key('chat-thread-messages');
      }
    case ChatSurfaceKind.list:
      switch (phase) {
        case ChatSurfacePhase.empty:
          return const Key('chat-list-empty');
        case ChatSurfacePhase.loading:
          return const Key('chat-list-loading');
        case ChatSurfacePhase.error:
          return const Key('chat-list-error');
        case ChatSurfacePhase.data:
          return const Key('chat-list-rows');
      }
  }
}

Key chatSurfaceRetryKey(ChatSurfaceKind kind) {
  switch (kind) {
    case ChatSurfaceKind.thread:
      return const Key('chat-thread-retry');
    case ChatSurfaceKind.list:
      return const Key('chat-list-retry');
  }
}

Key chatSurfaceEmptyActionKey(ChatSurfaceKind kind) {
  switch (kind) {
    case ChatSurfaceKind.thread:
      return const Key('chat-thread-empty-cta');
    case ChatSurfaceKind.list:
      return const Key('chat-list-empty-cta');
  }
}

Key chatSurfaceHintKey(ChatSurfaceKind kind, ChatSurfacePhase phase) {
  switch (kind) {
    case ChatSurfaceKind.thread:
      return phase == ChatSurfacePhase.error
          ? const Key('chat-thread-error-hint')
          : const Key('chat-thread-empty-hint');
    case ChatSurfaceKind.list:
      return phase == ChatSurfacePhase.error
          ? const Key('chat-list-error-hint')
          : const Key('chat-list-empty-hint');
  }
}

Key chatSurfaceDetailKey(ChatSurfaceKind kind) {
  switch (kind) {
    case ChatSurfaceKind.thread:
      return const Key('chat-thread-error-detail');
    case ChatSurfaceKind.list:
      return const Key('chat-list-error-detail');
  }
}

String chatSurfaceMessage(
  ChatSurfaceKind kind,
  ChatSurfacePhase phase, {
  bool isOffline = false,
}) {
  if (phase == ChatSurfacePhase.error && isOffline) {
    return kChatSurfaceOfflineCopy;
  }
  switch (kind) {
    case ChatSurfaceKind.thread:
      switch (phase) {
        case ChatSurfacePhase.empty:
          return kChatThreadEmptyCopy;
        case ChatSurfacePhase.loading:
          return kChatThreadLoadingCopy;
        case ChatSurfacePhase.error:
          return kChatThreadErrorCopy;
        case ChatSurfacePhase.data:
          return 'Chat';
      }
    case ChatSurfaceKind.list:
      switch (phase) {
        case ChatSurfacePhase.empty:
          return kChatListEmptyCopy;
        case ChatSurfacePhase.loading:
          return kChatListLoadingCopy;
        case ChatSurfacePhase.error:
          return kChatListErrorCopy;
        case ChatSurfacePhase.data:
          return 'Chats';
      }
  }
}

String? chatSurfaceHint(
  ChatSurfaceKind kind,
  ChatSurfacePhase phase, {
  bool isOffline = false,
}) {
  switch (phase) {
    case ChatSurfacePhase.empty:
      return kind == ChatSurfaceKind.thread
          ? kChatThreadEmptyHint
          : kChatListEmptyHint;
    case ChatSurfacePhase.error:
      return kChatSurfaceErrorHint;
    case ChatSurfacePhase.loading:
    case ChatSurfacePhase.data:
      return null;
  }
}

String? chatSurfaceErrorDetail(Object? error) {
  if (error == null) return null;
  final text = error.toString().trim();
  if (text.isEmpty) return null;
  const prefix = 'Exception: ';
  if (text.startsWith(prefix) && text.length > prefix.length) {
    return text.substring(prefix.length);
  }
  return text;
}
