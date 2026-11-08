import 'chat_surface.dart';

/// Result of a chat list / thread page fetch. No backend of its own —
/// [fetch] is the existing Supabase / repository call.
class ChatListLoad<T> {
  const ChatListLoad({
    required this.phase,
    this.items = const [],
    this.error,
  });

  final ChatSurfacePhase phase;
  final List<T> items;
  final Object? error;

  bool get isEmpty => phase == ChatSurfacePhase.empty;
  bool get hasError => phase == ChatSurfacePhase.error;
}

/// Load a chat list or thread page and map it to empty / error / data.
///
/// Offline with no rows is error (Retry), not a settled empty. A thrown
/// fetch is error. Retry is calling this again with the same [fetch].
Future<ChatListLoad<T>> loadChatList<T>({
  required Future<List<T>> Function() fetch,
  bool isOffline = false,
}) async {
  try {
    final items = await fetch();
    return ChatListLoad<T>(
      phase: resolveChatSurfacePhase(
        isLoading: false,
        error: null,
        isEmpty: items.isEmpty,
        isOffline: isOffline,
        itemCount: items.length,
      ),
      items: items,
    );
  } catch (e) {
    return ChatListLoad<T>(
      phase: resolveChatSurfacePhase(
        isLoading: false,
        error: e,
        isEmpty: true,
        isOffline: isOffline,
        itemCount: 0,
      ),
      error: e,
    );
  }
}

/// Re-fetch alias so Retry units call the same loader path.
Future<ChatListLoad<T>> retryChatList<T>({
  required Future<List<T>> Function() fetch,
  bool isOffline = false,
}) =>
    loadChatList(fetch: fetch, isOffline: isOffline);
