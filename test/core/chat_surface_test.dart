import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/chat_list_loader.dart';
import 'package:squad_sync/core/chat_surface.dart';

void main() {
  group('resolveChatSurfacePhase', () {
    test('in-flight with no rows is loading, not a settled empty', () {
      expect(
        resolveChatSurfacePhase(
          isLoading: true,
          itemCount: 0,
        ),
        ChatSurfacePhase.loading,
      );
    });

    test('never-settled idle is empty, not a dead spinner', () {
      expect(
        resolveChatSurfacePhase(
          isLoading: false,
          itemCount: 0,
        ),
        ChatSurfacePhase.empty,
      );
    });

    test('hydrated empty list is empty copy', () {
      expect(
        resolveChatSurfacePhase(
          isLoading: false,
          isEmpty: true,
          itemCount: 0,
        ),
        ChatSurfacePhase.empty,
      );
    });

    test('error with no rows is error', () {
      expect(
        resolveChatSurfacePhase(
          isLoading: false,
          error: 'offline',
          itemCount: 0,
        ),
        ChatSurfacePhase.error,
      );
    });

    test('offline with no rows is error, not empty', () {
      expect(
        resolveChatSurfacePhase(
          isLoading: false,
          isOffline: true,
          itemCount: 0,
        ),
        ChatSurfacePhase.error,
      );
      expect(
        resolveChatSurfacePhase(
          isLoading: true,
          isOffline: true,
          itemCount: 0,
        ),
        ChatSurfacePhase.error,
      );
    });

    test('error or offline with rows stays data, not empty', () {
      expect(
        resolveChatSurfacePhase(
          isLoading: false,
          error: 'timeout',
          itemCount: 3,
        ),
        ChatSurfacePhase.data,
      );
      expect(
        resolveChatSurfacePhase(
          isLoading: false,
          isOffline: true,
          itemCount: 2,
        ),
        ChatSurfacePhase.data,
      );
    });

    test('rows are data', () {
      expect(
        resolveChatSurfacePhase(
          isLoading: false,
          itemCount: 4,
        ),
        ChatSurfacePhase.data,
      );
    });
  });

  group('chat surface copy', () {
    test('empty / error / offline / loading copy is arm length', () {
      expect(
        chatSurfaceMessage(ChatSurfaceKind.thread, ChatSurfacePhase.empty),
        kChatThreadEmptyCopy,
      );
      expect(
        chatSurfaceHint(ChatSurfaceKind.thread, ChatSurfacePhase.empty),
        kChatThreadEmptyHint,
      );
      expect(
        chatSurfaceMessage(ChatSurfaceKind.thread, ChatSurfacePhase.error),
        kChatThreadErrorCopy,
      );
      expect(
        chatSurfaceHint(ChatSurfaceKind.thread, ChatSurfacePhase.error),
        kChatSurfaceErrorHint,
      );
      expect(
        chatSurfaceMessage(
          ChatSurfaceKind.thread,
          ChatSurfacePhase.error,
          isOffline: true,
        ),
        kChatSurfaceOfflineCopy,
      );
      expect(
        chatSurfaceMessage(ChatSurfaceKind.list, ChatSurfacePhase.empty),
        kChatListEmptyCopy,
      );
      expect(
        chatSurfaceHint(ChatSurfaceKind.list, ChatSurfacePhase.empty),
        kChatListEmptyHint,
      );
      expect(
        chatSurfaceMessage(ChatSurfaceKind.list, ChatSurfacePhase.error),
        kChatListErrorCopy,
      );
      expect(
        chatSurfaceMessage(ChatSurfaceKind.list, ChatSurfacePhase.loading),
        kChatListLoadingCopy,
      );
      expect(chatSurfaceErrorDetail('offline'), 'offline');
      expect(chatSurfaceErrorDetail(Exception('denied')), 'denied');
    });
  });

  group('loadChatList', () {
    test('empty fetch is empty, not a spinner', () async {
      final loaded = await loadChatList(fetch: () async => <String>[]);
      expect(loaded.phase, ChatSurfacePhase.empty);
      expect(loaded.items, isEmpty);
      expect(loaded.hasError, isFalse);
    });

    test('thrown fetch is error', () async {
      final loaded = await loadChatList<String>(
        fetch: () async => throw Exception('offline'),
      );
      expect(loaded.phase, ChatSurfacePhase.error);
      expect(loaded.hasError, isTrue);
      expect(loaded.items, isEmpty);
      expect(chatSurfaceErrorDetail(loaded.error), 'offline');
    });

    test('offline with no rows is error', () async {
      final loaded = await loadChatList(
        fetch: () async => <String>[],
        isOffline: true,
      );
      expect(loaded.phase, ChatSurfacePhase.error);
      expect(loaded.isEmpty, isFalse);
    });

    test('rows are data', () async {
      final loaded = await loadChatList(
        fetch: () async => ['chat-1', 'chat-2'],
      );
      expect(loaded.phase, ChatSurfacePhase.data);
      expect(loaded.items, ['chat-1', 'chat-2']);
    });

    test('offline with cached rows stays data', () async {
      final loaded = await loadChatList(
        fetch: () async => ['cached'],
        isOffline: true,
      );
      expect(loaded.phase, ChatSurfacePhase.data);
      expect(loaded.items, ['cached']);
    });
  });

  group('retryChatList', () {
    test('retry re-fetches after error and can succeed', () async {
      var calls = 0;
      Future<List<String>> fetch() async {
        calls++;
        if (calls == 1) throw Exception('offline');
        return ['thread-1'];
      }

      final first = await loadChatList(fetch: fetch);
      expect(first.phase, ChatSurfacePhase.error);
      expect(first.items, isEmpty);
      expect(calls, 1);

      final second = await retryChatList(fetch: fetch);
      expect(second.phase, ChatSurfacePhase.data);
      expect(second.items, ['thread-1']);
      expect(calls, 2);
    });

    test('retry of empty stays empty', () async {
      var calls = 0;
      Future<List<String>> fetch() async {
        calls++;
        return const <String>[];
      }

      final first = await loadChatList(fetch: fetch);
      expect(first.phase, ChatSurfacePhase.empty);
      final second = await retryChatList(fetch: fetch);
      expect(second.phase, ChatSurfacePhase.empty);
      expect(calls, 2);
    });

    test('retry after error can stay error', () async {
      Future<List<String>> fetch() async => throw Exception('denied');
      final first = await loadChatList(fetch: fetch);
      final second = await retryChatList(fetch: fetch);
      expect(first.phase, ChatSurfacePhase.error);
      expect(second.phase, ChatSurfacePhase.error);
      expect(chatSurfaceErrorDetail(second.error), 'denied');
    });
  });
}
